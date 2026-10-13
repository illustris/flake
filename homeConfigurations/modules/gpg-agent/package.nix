{ lib, pkgs }:
let
	inherit (import ../../../lib { inherit lib; }) indent;
	script = pkgs.writeText "pinentry-session.py" (
		"#!${pkgs.python3}/bin/python3\n"
		+ lib.replaceStrings
			[ "@tmux@" "@gpgconf@" "@connect@" "@curses@" "@qt@" ]
			[ "${pkgs.tmux}/bin/tmux" "${pkgs.gnupg}/bin/gpgconf" "${pkgs.gnupg}/bin/gpg-connect-agent" "${pkgs.pinentry-all}/bin/pinentry-curses" "${pkgs.pinentry-all}/bin/pinentry-qt" ]
			(builtins.readFile ./pinentry_session.py)
	);
in
pkgs.runCommand "pinentry-session" { meta.mainProgram = "pinentry-session"; } (indent ''
	mkdir -p $out/bin
	cp ${script} $out/bin/pinentry-session
	chmod +x $out/bin/pinentry-session
	ln -s pinentry-session $out/bin/with-pinentry
'')
