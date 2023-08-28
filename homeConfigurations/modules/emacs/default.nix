{ pkgs, config, lib, ... }:
{
	home = {
		file.".emacs.d" = {
			source = ./emacs.d;
			recursive = true;
		};
		homeDirectory = lib.mkDefault "/home/${config.home.username}";
		stateVersion = lib.mkDefault "23.05";
		username = lib.mkDefault "illustris";
	};
	programs.emacs = {
		enable = true;
		extraPackages = (epkgs: (with epkgs; [
			bpftrace-mode
			cmake-mode
			color-theme-modern
			docker-compose-mode
			dockerfile-mode
			dtrace-script-mode
			gitlab-ci-mode
			go-mode
			graphviz-dot-mode
			haskell-mode
			json-mode
			lsp-mode
			markdown-mode
			material-theme
			nix-mode
			puppet-mode
			python-mode
			strace-mode
			verilog-mode
			yaml-mode
		]));
	};
}
