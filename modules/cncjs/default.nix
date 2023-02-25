{ self, ... }:
{ config, pkgs, lib, ... }:
with lib; with self.lib;
{
	options.services.cncjs = {
		enable = mkEnableOption "CNCjs";
		port = mkOption {
			default = 8000;
			type = types.port;
		};
		host = mkOption {
			default = "0.0.0.0";
			type = types.str;
		};
		extraFlags = mkOption {
			default = [];
			type = with types; listOf str;
		};
		openFirewall = mkOption {
			default = false;
			type = types.bool;
		};
	};
	config = let
		cfg = config.services.cncjs;
	in mkIf cfg.enable {
		systemd.services.cncjs = {
			environment.HOME = "/var/lib/cncjs";
			path = with pkgs; [ bash nodejs strace ];
			wantedBy = [ "multi-user.target" ];
			# TODO: package cncjs
			script = concatStringsSep " " ([
				"npx cncjs"
				"-p"
				(toString cfg.port)
				"-H"
				cfg.host
			] ++ cfg.extraFlags);
			serviceConfig = {
				DynamicUser = true;
				User = "cncjs";
				StateDirectory = "cncjs";
			};
		};

		networking.firewall.allowedTCPPorts = [ cfg.port ];
	};
}
