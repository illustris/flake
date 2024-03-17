{ pkgs, config, lib, ... }:

{
	home.packages = with pkgs; [
		flamegraph
		ncdu
		nix-diff
		nix-index
		nmap
		perl536Packages.AppClusterSSH
		python3
		signal-desktop
		sysstat
	];
}
