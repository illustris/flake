{ pkgs, config, lib, ... }:

{
	home.packages = with pkgs; [
		nix-diff
		nix-index
		nmap
		perl536Packages.AppClusterSSH
		python3
		signal-desktop
	];
}
