"""Opt-in per-command pinentry routing. Secret responses bypass this process."""

import argparse
import base64
import contextlib
import json
import os
from pathlib import Path
import re
import select
import shlex
import signal
import socket
import stat
import struct
import subprocess
import sys
import tempfile
import threading
import time

TMUX = "@tmux@"
GPGCONF = "@gpgconf@"
CONNECT = "@connect@"
CURSES = "@curses@"
QT = "@qt@"
PREFIX = "pinentry-poc:"
PROGRAM = str(Path(__file__).resolve())
LAUNCHER = str(Path(PROGRAM).with_name("with-pinentry"))


def run(*args):
    return subprocess.check_output(args, text=True, stderr=subprocess.PIPE, timeout=10).strip()


def validate_tty(name):
    if not re.fullmatch(r"/dev/(pts/[0-9]+|tty[0-9]+)", name):
        raise ValueError("expected an explicit /dev/pts/N or /dev/ttyN terminal")
    fd = os.open(name, os.O_RDWR | os.O_NOCTTY | os.O_NONBLOCK)
    try:
        info = os.fstat(fd)
        if info.st_uid != os.getuid() or not stat.S_ISCHR(info.st_mode) or not os.isatty(fd):
            raise ValueError("prompt terminal must belong to the current user")
    finally:
        os.close(fd)
    return name


def encode_route(route):
    return PREFIX + base64.urlsafe_b64encode(json.dumps(route).encode()).decode()


def decode_route(value):
    if len(value) > 8192:
        raise ValueError("invalid pinentry route")
    route = json.loads(base64.b64decode(value[len(PREFIX):], altchars=b"-_", validate=True))
    if route.get("kind") == "tty":
        validate_tty(route["tty"])
    elif route.get("kind") == "popup":
        if not re.fullmatch(r"%[0-9]+", route["pane"]):
            raise ValueError("invalid tmux pane")
        info = os.stat(route["socket"])
        if info.st_uid != os.getuid() or not stat.S_ISSOCK(info.st_mode):
            raise ValueError("tmux socket must belong to the current user")
    else:
        raise ValueError("unknown pinentry route")
    return route


def wire_string(value):
    if isinstance(value, str):
        value = value.encode()
    return struct.pack(">I", len(value)) + value


def receive(sock, size):
    result = b""
    while len(result) < size:
        part = sock.recv(size - len(result))
        if not part:
            raise EOFError("agent connection closed")
        result += part
    return result


def set_connection_environment(sock, values):
    message = b"\x1b" + wire_string("ssh-env@gnupg.org")
    for name, value in values.items():
        message += wire_string(name) + wire_string(value)
    sock.sendall(wire_string(message))
    size = struct.unpack(">I", receive(sock, 4))[0]
    if size != 1 or receive(sock, size) != b"\x06":
        raise RuntimeError("SSH agent does not support connection-scoped environments")


def same_user(sock):
    _, uid, _ = struct.unpack("3i", sock.getsockopt(socket.SOL_SOCKET, socket.SO_PEERCRED, 12))
    return uid == os.getuid()


class AgentProxy:
    def __init__(self, path, upstream, values):
        self.upstream, self.values = upstream, values
        self.closed = threading.Event()
        self.connections = set()
        self.lock = threading.Lock()
        self.listener = socket.socket(socket.AF_UNIX)
        self.listener.bind(path)
        os.chmod(path, 0o600)
        self.listener.listen(16)
        self.listener.settimeout(0.2)
        threading.Thread(target=self.accept, daemon=True).start()

    def accept(self):
        while not self.closed.is_set():
            try:
                client, _ = self.listener.accept()
            except socket.timeout:
                continue
            except OSError:
                break
            threading.Thread(target=self.relay, args=(client,), daemon=True).start()

    def relay(self, client):
        with client, socket.socket(socket.AF_UNIX) as upstream:
            with self.lock:
                if self.closed.is_set():
                    return
                self.connections.update((client, upstream))
            try:
                if not same_user(client):
                    return
                upstream.settimeout(10)
                upstream.connect(self.upstream)
                set_connection_environment(upstream, self.values)
                upstream.settimeout(None)
                # No parsing, logging, or storing key requests or replies.
                peers = {client: upstream, upstream: client}
                while not self.closed.is_set():
                    ready, _, _ = select.select(list(peers), [], [], 0.2)
                    for source in ready:
                        block = source.recv(65536)
                        if not block:
                            return
                        peers[source].sendall(block)
            except (OSError, EOFError, RuntimeError):
                if not self.closed.is_set():
                    print("with-pinentry: agent proxy connection failed", file=sys.stderr)
            finally:
                with self.lock:
                    self.connections.difference_update((client, upstream))

    def close(self):
        self.closed.set()
        self.listener.close()
        with self.lock:
            for connection in self.connections:
                with contextlib.suppress(OSError):
                    connection.shutdown(socket.SHUT_RDWR)


def launch(argv):
    parser = argparse.ArgumentParser(description="Run a command with its own pinentry destination and SSH-agent proxy.")
    group = parser.add_mutually_exclusive_group()
    group.add_argument("--tty", help="idle terminal reserved for prompts (run 'tty; sleep infinity' there)")
    group.add_argument("--popup", action="store_true", help="tmux popup (default; starts tmux when needed)")
    parser.add_argument("command", nargs=argparse.REMAINDER)
    args = parser.parse_args(argv)
    command = args.command
    if command[:1] == ["--"]:
        command = command[1:]
    if not command:
        parser.error("supply a command after --")
    if args.tty:
        route = {"kind": "tty", "tty": validate_tty(args.tty)}
    elif not os.environ.get("TMUX"):
        # Opt-in, new session; the user's existing sessions are not modified.
        cmd = shlex.join([LAUNCHER, "--popup", "--", *command])
        # An existing tmux server may have an older GNUPGHOME in its environment.
        home = os.environ.get("GNUPGHOME", str(Path.home() / ".gnupg"))
        os.execv(TMUX, [TMUX, "new-session", "-s", f"pinentry-{os.getpid()}", "-e", f"GNUPGHOME={home}", cmd])
    else:
        route = {"kind": "popup", "socket": os.environ["TMUX"].rsplit(",", 2)[0], "pane": os.environ["TMUX_PANE"]}
    encoded = encode_route(route)
    decode_route(encoded)
    # Ask for this GNUPGHOME's local agent, never substitute a forwarded agent.
    run(CONNECT, "/bye")
    upstream = run(GPGCONF, "--list-dirs", "agent-ssh-socket")
    tty = route.get("tty", os.environ.get("GPG_TTY", ""))
    values = {"GPG_TTY": tty, "TERM": os.environ.get("TERM", "xterm-256color"), "DISPLAY": "", "WAYLAND_DISPLAY": "", "XDG_SESSION_TYPE": "tty", "PINENTRY_USER_DATA": encoded}
    # Fail before starting the command if this isn't a compatible gpg-agent.
    with socket.socket(socket.AF_UNIX) as probe:
        probe.settimeout(10)
        probe.connect(upstream)
        set_connection_environment(probe, values)
    with tempfile.TemporaryDirectory(prefix="pinentry-proxy-") as directory:
        path = str(Path(directory) / "agent")
        proxy = AgentProxy(path, upstream, values)
        child = None
        try:
            env = dict(os.environ, SSH_AUTH_SOCK=path, PINENTRY_USER_DATA=encoded, GPG_TTY=tty)
            child = subprocess.Popen(command, env=env)
            # Ctrl-C belongs to the foreground command. Keep its proxy alive.
            signal.signal(signal.SIGINT, lambda *_: None)
            def terminate(signum, _frame):
                if child.poll() is None:
                    child.send_signal(signum)
            signal.signal(signal.SIGTERM, terminate)
            signal.signal(signal.SIGHUP, terminate)
            returncode = child.wait()
            return returncode if returncode >= 0 else 128 - returncode
        finally:
            proxy.close()


def popup_client(route):
    base = [TMUX, "-S", route["socket"]]
    session, window = run(*base, "display-message", "-p", "-t", route["pane"], "#{session_id} #{window_id}").split()
    clients = run(*base, "list-clients", "-F", "#{client_tty}\t#{session_id}\t#{window_id}\t#{client_activity}")
    choices = []
    for line in clients.splitlines():
        tty, client_session, client_window, activity = line.split("\t")
        if client_session == session:
            choices.append((client_window == window, int(activity), tty))
    if not choices:
        raise RuntimeError("no attached tmux client for the requesting pane")
    return max(choices)[2]


@contextlib.contextmanager
def popup(route):
    with tempfile.TemporaryDirectory(prefix="pinentry-popup-") as directory:
        path = str(Path(directory) / "control")
        with socket.socket(socket.AF_UNIX) as listener:
            listener.bind(path)
            os.chmod(path, 0o600)
            listener.listen(1)
            listener.settimeout(0.2)
            client = popup_client(route)
            cmd = shlex.join([PROGRAM, "--popup-peer", path])
            proc = subprocess.Popen([TMUX, "-S", route["socket"], "display-popup", "-E", "-c", client, "-w", "90%", "-h", "70%", "-T", " Unlock key ", cmd], stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            control = None
            try:
                deadline = time.monotonic() + 10
                while control is None:
                    if proc.poll() is not None or time.monotonic() > deadline:
                        raise RuntimeError("could not open tmux pinentry popup")
                    try:
                        control, _ = listener.accept()
                    except socket.timeout:
                        pass
                if not same_user(control):
                    raise RuntimeError("unexpected popup owner")
                control.settimeout(5)
                line = bytearray()
                while not line.endswith(b"\n") and len(line) < 256:
                    line.extend(receive(control, 1))
                tty = validate_tty(line.decode().strip())
                control.settimeout(None)
                yield tty, control, proc
            finally:
                if control is not None:
                    control.close()
                try:
                    proc.wait(timeout=3)
                except subprocess.TimeoutExpired:
                    proc.terminate()
                    proc.wait(timeout=3)


def popup_peer(path):
    with socket.socket(socket.AF_UNIX) as control:
        control.connect(path)
        if not same_user(control):
            raise RuntimeError("unexpected pinentry owner")
        control.sendall((os.ttyname(0) + "\n").encode())
        # Never read the terminal: pinentry-curses alone consumes its keystrokes.
        while control.recv(1):
            pass


def routed_pinentry(tty, args, control=None, popup_process=None):
    env = os.environ.copy()
    for key in ("DISPLAY", "WAYLAND_DISPLAY", "QT_QPA_PLATFORM", "QT_QPA_PLATFORMTHEME"):
        env.pop(key, None)
    # Responses (including the passphrase) go directly to gpg-agent on stdout.
    child = subprocess.Popen([CURSES, "--ttyname", tty, "--ttytype", "xterm-256color", *args], stdin=subprocess.PIPE, bufsize=0, env=env)
    finished = threading.Event()

    def forward():
        try:
            pending = b""
            while not finished.is_set():
                if not select.select([0], [], [], 0.1)[0]:
                    continue
                block = os.read(0, 4096)
                if not block:
                    break
                pending += block
                while b"\n" in pending:
                    line, pending = pending.split(b"\n", 1)
                    if line.startswith(b"OPTION ttyname="):
                        line = b"OPTION ttyname=" + tty.encode()
                    elif line.startswith(b"OPTION ttytype="):
                        line = b"OPTION ttytype=xterm-256color"
                    child.stdin.write(line + b"\n")
        except (BrokenPipeError, OSError):
            pass
        finally:
            with contextlib.suppress(BrokenPipeError, OSError):
                child.stdin.close()

    threading.Thread(target=forward, daemon=True).start()
    try:
        deadline = time.monotonic() + 120
        while child.poll() is None:
            if control is not None:
                if popup_process.poll() is not None or time.monotonic() > deadline:
                    raise RuntimeError("pinentry popup closed or timed out")
                if select.select([control], [], [], 0.1)[0] and not control.recv(1):
                    raise RuntimeError("pinentry popup closed")
            else:
                time.sleep(0.1)
        return child.returncode
    finally:
        finished.set()
        if child.poll() is None:
            child.terminate()
            try:
                child.wait(timeout=2)
            except subprocess.TimeoutExpired:
                child.kill()
                child.wait()


def pinentry(args):
    value = os.environ.get("PINENTRY_USER_DATA", "")
    if value.startswith(PREFIX):
        def interrupted(signum, _frame):
            raise RuntimeError("pinentry interrupted")
        for signum in (signal.SIGTERM, signal.SIGHUP, signal.SIGINT):
            signal.signal(signum, interrupted)
        route = decode_route(value)
        if route["kind"] == "tty":
            return routed_pinentry(route["tty"], args)
        with popup(route) as (tty, control, proc):
            return routed_pinentry(tty, args, control, proc)
    # Preserve the ordinary remote/desktop behavior fixed separately.
    backend = QT if os.environ.get("DISPLAY") or os.environ.get("XDG_SESSION_TYPE") == "wayland" else CURSES
    os.execv(backend, [backend, *args])


def main():
    try:
        if sys.argv[1:2] == ["--popup-peer"]:
            popup_peer(sys.argv[2])
            return 0
        if Path(sys.argv[0]).name == "with-pinentry":
            return launch(sys.argv[1:])
        return pinentry(sys.argv[1:])
    except (OSError, ValueError, KeyError, RuntimeError, EOFError, subprocess.SubprocessError) as error:
        # No environment, protocol traffic, or secret material in diagnostics.
        if Path(sys.argv[0]).name == "with-pinentry":
            print(f"with-pinentry: {error}", file=sys.stderr)
        else:
            print(f"pinentry-session: {error}", file=sys.stderr)
            print("ERR 83886179 Pinentry route unavailable or cancelled", flush=True)
        return 1


if __name__ == "__main__":
    sys.exit(main())
