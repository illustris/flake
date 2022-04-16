{ pkgs, ... }:

{
	oss-cad-suite-bin = pkgs.callPackage ./oss-cad-suite-bin {};
	vhd2vl = pkgs.callPackage ./vhd2vl {};
}
