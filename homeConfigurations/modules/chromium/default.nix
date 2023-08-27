{ pkgs, config, lib, ... }:
{
	config = {
		home = lib.mkDefault {
			homeDirectory = "/home/${config.home.username}";
			stateVersion = "23.05";
			username = "illustris";
		};
		programs.chromium = {
			enable = true;
			package = pkgs.chromium;
			extensions = let
				createChromiumExtensionFor = browserVersion: id: version: hash: {
					inherit id;
					crxPath = pkgs.fetchurl {
						url = "https://clients2.google.com/service/update2/crx?response=redirect&acceptformat=crx2,crx3&prodversion=${
							browserVersion
						}&x=id%3D${
							id
						}%26installsource%3Dondemand%26uc";
						name = "${id}.crx";
						inherit hash;
					};
					inherit version;
				};
				ext = createChromiumExtensionFor (lib.versions.major config.programs.chromium.package.version);
			in [
				# ublock origin
				(ext "cjpalhdlnbpafiamejdnhcphjbkeiagm" "1.51.0"
					"sha256-N+tdaQ2Z948aiaqs6kLGJRVs+O37fKp2G8pduwUtaEU=")
				# Clutter Free
				(ext "iipjdmnoigaobkamfhnojmglcdbnfaaf" "9.1.0"
					"sha256-HLPMFm+i5aQjHlzR05KjwEQzIHWgR98E/3+oiq5+ciE=")
				# xBrowserSync
				(ext "lcbjdhceifofjlpecfpeimnnphbcjgnc" "1.5.2"
					"sha256-7fIofv1U7J6oYATiLq2/M8INAW4Bmy/gDV2XuF+d91s=")
				# just black
				(ext "aghfnjkcakhmadgdomlmlhhaocbkloab" "3"
					"sha256-lxRt9N0WgEV1yFmc6p5/SUEvTjafZMYx44wJvxEce7M=")
				# Browserpass
				(ext "naepdomgkenhinolocfifgehidddafch" "3.7.2"
					"sha256-eEKjfaqxLtiV/YuL2c59P7IkbnY6o3+1st4cEJQ7nr8=")
			];
		};
	};
}
