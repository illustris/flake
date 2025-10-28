{ self, ... }:
{ config, lib, pkgs, ... }:
with lib;
{
	programs = {
		hyprland = {
			enable = true;
			xwayland.enable = true;
			withUWSM = true;
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
