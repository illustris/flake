{ self, ... }:
{ config, lib, pkgs, ... }:
with lib;
{
	imports = [
		self.inputs.mango.nixosModules.mango
	];

	programs = {
		mango = {
			enable = true;
			package = mkDefault self.inputs.mango.packages.${pkgs.system}.default;
		};
		uwsm = {
			enable = true;
			waylandCompositors.mango = {
				prettyName = "Mango";
				comment = "Mango compositor session managed by UWSM";
				binPath = "${config.programs.mango.package}/bin/mango";
			};
		};
		waybar = {
			enable = true;
			systemd.target = "graphical-session.target";
		};
	};

	services.xserver = {
		enable = true;
		displayManager.sddm = {
			enable = true;
			wayland.enable = true;
		};
	};
}
