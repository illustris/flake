{ pkgs, config, lib, ... }:

{
	programs.git = {
		enable = true;
		package = pkgs.gitFull;
		extraConfig = {
			user = rec {
				email = "rharikrishnan95@gmail.com";
				signingkey = email;
				name = config.home.username;
			};
			commit.gpgsign = config.programs.gpg.enable;
		};
	};
}
