{ pkgs, lib, system, ... }:
with lib;

# drop nulls
filterAttrs (_: isDerivation) (
	mapAttrs (name: value:(
		# replace drvs for unsupported archs with null
		let pkg = (pkgs.callPackage (./. + "/${name}") {}); in
		if (elem system (attrByPath [ "meta" "platforms" ] [system] pkg)) then pkg
		else null
	)) (filterAttrs
		# attrset will contain an attr for each dir in pkgs
		(_: hasPrefix "directory") (builtins.readDir ./.)
	)
)
