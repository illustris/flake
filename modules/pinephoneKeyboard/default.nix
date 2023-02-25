{ self }:
{ config, lib, pkgs, ... }:
with lib;
{
	options.services.pinephoneKeyboard.enable = mkEnableOption "Pinephone Keyboard userspace driver";
	config.systemd.services.pinephoneKeyboard = let
		cfg = config.services.pinephoneKeyboard;
	in mkIf cfg.enable {
		path = [ self.packages.${pkgs.system}.pinephoneKeyboard ];
		wantedBy = [ "multi-user.target" ];
		script = "ppkb-i2c-inputd";
		serviceConfig.StandardOutput = "null";
	};
}
