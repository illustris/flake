{ ... }: {
	services.gpg-agent = {
		enable = true;
		defaultCacheTtl = 60*60*24;
		defaultCacheTtlSsh = 60*60*24;
		extraConfig = "auto-expand-secmem";
	};
	home = {
		file.".emacs.d" = {
			source = ./emacs.d;
			recursive = true;
		};
		homeDirectory = "/home/illustris";
		stateVersion = "23.05";
		username = "illustris";
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
