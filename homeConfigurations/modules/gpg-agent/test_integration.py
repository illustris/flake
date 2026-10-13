"""End-to-end checks using an isolated agent, disposable key, and tmux server."""
import contextlib
import fcntl
import json
import os
from pathlib import Path
import pty
import select
import shlex
import shutil
import signal
import struct
import subprocess
import sys
import tempfile
import termios
import time

PACKAGE = Path(sys.argv[1])
LAUNCH = str(PACKAGE / "bin/with-pinentry")
PINENTRY = str(PACKAGE / "bin/pinentry-session")
SECRET = "disposable-test-passphrase"


def wait_for(check, description, timeout=20):
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        value = check()
        if value:
            return value
        time.sleep(.05)
    raise AssertionError("timed out: " + description)


class Terminal:
    def __init__(self):
        self.master, self.slave = pty.openpty()
        fcntl.ioctl(self.slave, termios.TIOCSWINSZ, struct.pack("HHHH", 35, 110, 0, 0))
        self.tty = os.ttyname(self.slave)
        self.output = b""
        self.process = None

    def spawn(self, command, env):
        def setup():
            os.setsid()
            fcntl.ioctl(0, termios.TIOCSCTTY, 0)
        self.process = subprocess.Popen(command, env=env, stdin=self.slave, stdout=self.slave, stderr=self.slave, preexec_fn=setup)

    def read(self):
        while select.select([self.master], [], [], 0)[0]:
            try:
                block = os.read(self.master, 65536)
            except OSError:
                break
            if not block:
                break
            self.output += block
        return self.output

    def expect(self, text):
        wait_for(lambda: text in self.read(), "terminal prompt " + repr(text))

    def send(self, value):
        os.write(self.master, value)

    def close(self):
        if self.process and self.process.poll() is None:
            self.process.terminate()
            self.process.wait(timeout=5)
        os.close(self.master)
        os.close(self.slave)


with tempfile.TemporaryDirectory(prefix="pinentry-integration-") as directory:
    root = Path(directory)
    home = root / "gnupg"
    home.mkdir(mode=0o700)
    env = dict(os.environ, GNUPGHOME=str(home), GPG_TTY="/dev/pts/default-test", TERM="xterm-256color", XDG_SESSION_TYPE="tty")
    for key in ("DISPLAY", "WAYLAND_DISPLAY", "PINENTRY_USER_DATA", "TMUX", "TMUX_PANE"):
        env.pop(key, None)
    (home / "gpg-agent.conf").write_text(f"enable-ssh-support\ndisable-scdaemon\nno-allow-external-cache\npinentry-program {PINENTRY}\n")
    terminals = []
    socket = root / "tmux"

    def run(*command, **kwargs):
        result = subprocess.run(command, env=env, capture_output=True, timeout=30, **kwargs)
        if result.returncode:
            raise AssertionError(f"command {command[0]} failed: " + result.stderr.decode())
        return result.stdout

    def clear():
        run("gpg-connect-agent", "CLEAR_PASSPHRASE --mode=normal " + grip, "CLEAR_PASSPHRASE --mode=ssh " + grip, "/bye")

    def fallback():
        return run("gpg-connect-agent", "GETINFO std_startup_env", "/bye")

    harness = root / "harness.py"
    harness.write_text('''import base64, json, os, select, subprocess, sys, termios, threading, time, tty
from pathlib import Path
root = Path(sys.argv[1])
tty.setraw(0)
seen = bytearray()
stop = threading.Event()
def read_input():
    while not stop.is_set():
        if select.select([0], [], [], .05)[0]:
            seen.extend(os.read(0, 4096))
thread = threading.Thread(target=read_input, daemon=True)
thread.start()
(root / "ready").touch()
while not (root / "go").exists():
    time.sleep(.05)
with (root / "operation.log").open("wb") as output:
    child = subprocess.run(sys.argv[2:], stdin=subprocess.DEVNULL, stdout=output, stderr=output)
stop.set()
thread.join(timeout=1)
(root / "result").write_text(json.dumps({"rc":child.returncode, "input":base64.b64encode(seen).decode()}))
''')

    try:
        run("gpg", "--batch", "--pinentry-mode", "loopback", "--passphrase", SECRET, "--quick-generate-key", "Disposable pinentry POC test", "ed25519", "sign,auth", "1d")
        listing = run("gpg", "--with-colons", "--with-keygrip", "--list-secret-keys").decode()
        fingerprint = next(line.split(":")[9] for line in listing.splitlines() if line.startswith("fpr:"))
        grip = next(line.split(":")[9] for line in listing.splitlines() if line.startswith("grp:"))
        (home / "sshcontrol").write_text(grip + " 0 confirm\n")
        public = root / "test.pub"
        public.write_bytes(run("gpg", "--export-ssh-key", fingerprint))
        message = root / "message"
        message.write_text("disposable pinentry test\n")
        run("gpg-connect-agent", "UPDATESTARTUPTTY", "/bye")
        baseline = fallback()

        # Native GPG uses PINENTRY_USER_DATA and the chosen idle TTY.
        prompt = Terminal()
        terminals.append(prompt)
        clear()
        signer = subprocess.Popen([LAUNCH, "--tty", prompt.tty, "--", "gpg", "--batch", "--yes", "--output", str(root / "signature"), "--detach-sign", str(message)], env=env, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        prompt.expect(b"Passphrase:")
        prompt.send(SECRET.encode() + b"\r")
        stdout, stderr = signer.communicate(timeout=20)
        assert signer.returncode == 0, stderr.decode()
        run("gpg", "--verify", str(root / "signature"), str(message))
        assert fallback() == baseline
        print("PASS: native GPG signs through the dedicated TTY; shared fallback unchanged", flush=True)

        # Actual OpenSSH signing traverses the per-command socket proxy.
        prompt.output = b""
        signer = subprocess.Popen([LAUNCH, "--tty", prompt.tty, "--", "ssh-add", "-T", str(public)], env=env, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        prompt.expect(b"Allow")
        prompt.send(b"\r")
        stdout, stderr = signer.communicate(timeout=20)
        assert signer.returncode == 0, stderr.decode()
        assert fallback() == baseline
        print("PASS: OpenSSH signs through the dedicated TTY; shared fallback unchanged", flush=True)

        # A TUI reads its pane input concurrently with pinentry in the popup.
        def popup_test(name, cancel=False, auto=False):
            case = root / name
            case.mkdir()
            clear()
            command = [LAUNCH, "--popup", "--", sys.executable, str(harness), str(case), "gpg", "--batch", "--yes", "--output", str(case / "signature"), "--detach-sign", str(message)]
            terminal = Terminal()
            terminals.append(terminal)
            if auto:
                terminal.spawn(command, dict(env, TMUX_TMPDIR=str(root)))
            else:
                run("tmux", "-S", str(socket), "-f", "/dev/null", "new-session", "-d", "-s", name, "-x", "110", "-y", "35", shlex.join(command))
                terminal.spawn(["tmux", "-S", str(socket), "attach-session", "-t", name], env)
            wait_for(lambda: (case / "ready").exists(), "harness start")
            time.sleep(.3)
            (case / "go").touch()
            try:
                terminal.expect(b"Passphrase:")
            except AssertionError:
                print("Diagnostic terminal:", repr(terminal.output), flush=True)
                if (case / "operation.log").exists():
                    print("Diagnostic operation:", (case / "operation.log").read_text(), flush=True)
                if (home / "agent.log").exists():
                    print("Diagnostic agent:", (home / "agent.log").read_text(), flush=True)
                raise
            if cancel == "close":
                run("tmux", "-S", str(socket), "display-popup", "-C", "-c", terminal.tty)
            elif cancel:
                terminal.send(b"\t\r")
            else:
                terminal.send(SECRET.encode() + b"\r")
            wait_for(lambda: (case / "result").exists(), "harness result")
            result = json.loads((case / "result").read_text())
            assert (result["rc"] != 0) == bool(cancel), (result, (case / "operation.log").read_text())
            assert result["input"] == "", "popup keystrokes leaked to the TUI"
            assert fallback() == baseline
            if not cancel:
                run("gpg", "--verify", str(case / "signature"), str(message))
            terminal.process.wait(timeout=5)
            print("PASS: " + name + "; no keystrokes leaked to TUI and shared fallback unchanged", flush=True)

        popup_test("popup-success")
        popup_test("popup-cancel", cancel=True)
        popup_test("popup-forced-close", cancel="close")
        popup_test("automatic-tmux", auto=True)
    finally:
        subprocess.run(["tmux", "-S", str(socket), "kill-server"], env=env, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        auto_socket = root / f"tmux-{os.getuid()}" / "default"
        subprocess.run(["tmux", "-S", str(auto_socket), "kill-server"], env=env, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        for terminal in terminals:
            terminal.close()
        subprocess.run(["gpgconf", "--kill", "all"], env=env, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
