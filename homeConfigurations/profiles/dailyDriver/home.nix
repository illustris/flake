{ pkgs, ... }: {
	home = {
		homeDirectory = "/home/illustris";
		packages = with pkgs.illustris; [ vpnpass fzpass ];
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
