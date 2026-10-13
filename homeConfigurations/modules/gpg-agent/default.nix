{ config, lib, pkgs, ... }:
let
	inherit (import ../../../lib { inherit lib; }) indent;
	pinentry = import ./package.nix { inherit lib pkgs; };
	gpg = config.programs.gpg.package;
in {
	programs = {
		# This is required for HM to set GPG and SSH agent env vars.
		bash.enable = true;
		gpg.enable = true;
		bash.initExtra = indent ''
			# A scoped harness already has a prompt route. Do not publish it as
			# the shared agent's fallback when it starts an interactive shell.
			if [[ "''${PINENTRY_USER_DATA:-}" != pinentry-poc:* ]]; then
				GPG_TTY="$(tty)"
				export GPG_TTY
				${gpg}/bin/gpg-connect-agent --quiet updatestartuptty /bye > /dev/null
			fi
		'';
	};
	home.packages = [ pinentry ];
	# Home Manager wraps this in its usual forwarded-agent check.
	sshAuthSock.initialization.bash = lib.mkForce (indent ''
		if [[ "''${PINENTRY_USER_DATA:-}" != pinentry-poc:* ]]; then
			unset SSH_AGENT_PID
			if [ "''${gnupg_SSH_AUTH_SOCK_by:-0}" -ne $$ ]; then
				export SSH_AUTH_SOCK="$(${gpg}/bin/gpgconf --list-dirs agent-ssh-socket)"
			fi
		fi
	'');
	services.gpg-agent = {
		defaultCacheTtl = 60*60*24;
		defaultCacheTtlSsh = 60*60*24;
		enable = true;
		extraConfig = "auto-expand-secmem";
		enableSshSupport = true;
		enableBashIntegration = false;
		pinentry.package = pinentry;
	};
}
