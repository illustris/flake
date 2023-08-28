{ ... }: {
	home = {
		homeDirectory = "/home/illustris";
		stateVersion = "23.05";
		username = "illustris";
	};
	imports = [
		../../modules/chromium
		../../modules/dailyDriverUtils
		../../modules/emacs
		../../modules/git
		../../modules/gpg-agent
		../../modules/pass
		../../modules/serverUtils
	];
}
