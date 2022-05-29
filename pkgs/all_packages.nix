{ pkgs, ... }:
with pkgs.lib;

mapAttrs
	(name: value:
		(pkgs.callPackage (./. + "/${name}") {})
	)
	# attrset will contain an attr for each dir in pkgs
	(filterAttrs (name: value: value == "directory") (builtins.readDir ./.))
