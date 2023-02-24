{ pkgs, system, ... }:
with pkgs.lib;

filterAttrs (_: isDerivation) (genAttrs (dirs ./.) (name: (
	# replace drvs for unsupported archs with null
	let pkg = (pkgs.callPackage (./. + "/${name}") {}); in
	tern (elem system (attrByPath [ "meta" "platforms" ] [system] pkg)) pkg null
)))
