# Session-aware pinentry and opt-in TUI routing

Ordinary remote shells use pinentry-curses when `DISPLAY` is unset and
`XDG_SESSION_TYPE` is not `wayland`. Desktop shells retain pinentry-qt. This
avoids Qt following the shared agent's stale `WAYLAND_DISPLAY` into the desktop
after `UPDATESTARTUPTTY` from SSH/mosh.

## Try the POC

The current targeted installation is `~/.local/bin/with-pinentry`; use that full
path until the next Home Manager activation puts `with-pinentry` on your usual
PATH through `home.packages`.

```sh
~/.local/bin/with-pinentry -- codex
~/.local/bin/with-pinentry -- claude
```

Inside tmux, prompts open in a modal popup on an attached client for the
requesting pane's session. Outside tmux, the launcher starts a new tmux session
for the command. This also works over plain SSH/mosh. The popup captures input
while the harness continues running underneath. Select Cancel with Tab then
Enter to cancel the operation.

To keep the harness outside tmux, reserve another terminal for prompts:

```sh
# In a second SSH/mosh session; leave this command running:
tty; sleep infinity

# In the harness session, use the path printed above:
~/.local/bin/with-pinentry --tty /dev/pts/42 -- codex
```

The prompt terminal must belong to you and remain open. Keep it idle so another
program is not reading its keyboard. Exiting the harness removes its temporary
SSH socket. All routing is opt-in; existing sessions keep their usual behavior.

## How it works

The launcher creates a private SSH-agent proxy for the command and its children.
For every upstream connection, it uses GnuPG's `ssh-env@gnupg.org` extension to
set the prompt environment for that connection. It never issues
`UPDATESTARTUPTTY`. Native GPG inherits a `PINENTRY_USER_DATA` routing marker.
Bash startup hooks preserve the proxy and skip the shared startup-TTY update
inside this scope, including nested interactive and login shells.

The pinentry dispatcher decodes the marker and runs pinentry-curses on the
selected terminal. For popups, a helper holds open the popup's PTY without
reading it. Curses reads that PTY, and its Assuan responses go directly to
gpg-agent; the routing wrapper does not parse or log passphrases. The private
socket directories are mode 0700, sockets are 0600, and local peer UIDs are
checked.

The proxy deliberately connects to the local agent for `GNUPGHOME`, even if the
parent shell has a forwarded `SSH_AUTH_SOCK`. It needs a GnuPG agent supporting
`ssh-env@gnupg.org` (tested with 2.4.9); it checks support before launching the
command. Agent key storage and passphrase caches remain shared.

## POC limits

- A popup needs an attached tmux client. If several clients share a session, it
  prefers one viewing the requesting window, then the most recently active.
- A closed/detached popup or a 120-second timeout cancels the operation. It does
  not fall back to drawing under the harness.
- Gpg-agent still serializes prompts. This does not make separate prompts run
  concurrently or give each harness a separate cache.
- Routing follows the command's environment. Tools that deliberately replace
  `SSH_AUTH_SOCK`/`PINENTRY_USER_DATA`, or other shells with their own agent
  startup hooks, can bypass it. Bash is integrated here.
- This is a local-user convenience boundary, not isolation from other processes
  running as the same user. Do not enable GnuPG protocol debugging with real
  passphrases.

## Validation

`test_integration.py /nix/store/...-pinentry-session` uses a temporary GNUPGHOME,
a disposable protected signing/authentication key, private tmux servers, and
synthetic terminal input. It checks GPG and OpenSSH signatures, popup keyboard
isolation against a concurrently reading TUI, cancellation, automatic tmux
startup, and unchanged shared startup environment. It never uses personal keys.

For the targeted installation, the previous `.bashrc`, `.profile`, and
`.gnupg/gpg-agent.conf` symlinks are saved beside them with suffix
`.before-pinentry-poc`. Restoring those symlinks and reloading gpg-agent removes
the opt-in integration while retaining the earlier remote/desktop prompt fix.
The matching source change must also be reverted to keep future activations
from reinstalling the POC.

The underlying extension is implemented in
[GnuPG command-ssh.c](https://github.com/gpg/gnupg/blob/gnupg-2.4.9/agent/command-ssh.c).
The popup/PTY arrangement follows the approach described by
[run-in-tmux-popup](https://github.com/ngicks/run-in-tmux-popup).
