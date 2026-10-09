{ nixpkgs, firefox-addons, ...}@inputs:
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
			browsers = [ "firefox" ];
		};

		firefox = {
			enable = true;
			policies = {
				DisablePocket = true;
				DisableFirefoxStudies = true;
				DisableTelemetry = true;
				PasswordManagerEnabled = false;
				OfferToSaveLogins = false;
				NoDefaultBookmarks = true;
				FirefoxHome = {
					Pocket = false;
					TopSites = false;
				};
				UserMessaging = {
					ExtensionRecommendations = false;
					SkipOnboarding = true;
				};
			};
			profiles.default = {
				isDefault = true;
				extensions.packages = with firefox-addons.outputs.packages.${pkgs.system}; [
					bitwarden
					browserpass
					clearurls
					multi-account-containers
					single-file
					ublock-origin
				];
				# Firefox replaces this symlink and upgrades its JSON format on launch.
				# Keep the Nix container definitions authoritative across rebuilds.
				containersForce = true;
				containers = {
					personal = {
						id = 3;
						color = "blue";
						icon = "circle";
					};
					mn = {
						id = 1;
						color = "orange";
						icon = "tree";
					};
					at = {
						id = 2;
						color = "purple";
						icon = "briefcase";
					};
				};
			};
		};
	};
}
