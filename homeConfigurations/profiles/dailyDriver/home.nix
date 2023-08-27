{ ... }: {
	home = {
		homeDirectory = "/home/illustris";
		stateVersion = "23.05";
		username = "illustris";
	};
	imports = [
		../../modules/emacs
		../../modules/gpg-agent
		../../modules/chromium
	];
}
