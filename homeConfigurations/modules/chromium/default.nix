{ pkgs, config, lib, ... }:
{
	home = lib.mkDefault {
		homeDirectory = "/home/${config.home.username}";
		stateVersion = "23.05";
		username = "illustris";
	};
	programs = {
		browserpass = {
			enable = true;
			browsers = [ "chromium" ];
		};
		chromium = {
			enable = true;
			package = pkgs.ungoogled-chromium;
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
				(ext "cjpalhdlnbpafiamejdnhcphjbkeiagm" "1.62.0"
					"sha256-5hauSUdYLtv42lB/YpQVup0Gqgp4pH07G4MD/9EE09I=")
				# Clutter Free
				(ext "iipjdmnoigaobkamfhnojmglcdbnfaaf" "9.3.0"
					"sha256-MOGx1d9ha3mjp9VXQBsNSJyLuoSqmSiDonX8M3d+K9I=")
				# xBrowserSync
				#(ext "lcbjdhceifofjlpecfpeimnnphbcjgnc" "1.5.2"
				#	"sha256-7fIofv1U7J6oYATiLq2/M8INAW4Bmy/gDV2XuF+d91s=")
				# just black
				(ext "aghfnjkcakhmadgdomlmlhhaocbkloab" "3"
					"sha256-lxRt9N0WgEV1yFmc6p5/SUEvTjafZMYx44wJvxEce7M=")
				# Browserpass
				(ext "naepdomgkenhinolocfifgehidddafch" "3.9.0"
					"sha256-bT1vT7RzQjCyBDfuAtfYjcyyoM0aSp+OLHAf2GFimhw=")
				# single-file
				(ext "mpiodijhokgodhhofbcjdecpffjipkle" "1.22.81"
					"sha256-z7lDSffJbld9ssL2ETn5umLpHes2Y/iSvni8gTjjyDs=")
			];
		};
	};
}
