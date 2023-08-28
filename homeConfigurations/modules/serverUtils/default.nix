{ pkgs, config, lib, ... }:

{
	home.packages = with pkgs; [
		arp-scan
		arping
		bmon
		dnsutils
		htop
		lm_sensors
		nethogs
		nix-tree
		tcpdump
		tmux
	];
}
