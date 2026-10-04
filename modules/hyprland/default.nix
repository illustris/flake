{ self, ... }:
{ lib, pkgs, ... }:
{
	programs.hyprland = {
		enable = true;
		xwayland.enable = true;
		withUWSM = true;
	};
	# Home Manager owns these daemons and their Hyprland session lifecycle.
	programs.waybar.enable = lib.mkForce false;
	programs.hyprlock.enable = true;
	services.hypridle.enable = lib.mkForce false;
	services.blueman.enable = true;
	services.udisks2.enable = true;
	services.xserver.enable = lib.mkDefault true;
	services.displayManager = {
		defaultSession = lib.mkDefault "hyprland-uwsm";
		sddm.enable = lib.mkDefault true;
		sddm.wayland.enable = lib.mkDefault true;
	};
	xdg.portal = {
		extraPortals = [ pkgs.kdePackages.xdg-desktop-portal-kde ];
		config.hyprland = {
			default = [
				"hyprland"
				"kde"
			];
			"org.freedesktop.impl.portal.FileChooser" = [ "kde" ];
			"org.freedesktop.impl.portal.ScreenCast" = [ "hyprland" ];
			"org.freedesktop.impl.portal.Screenshot" = [ "hyprland" ];
		};
	};
}
