{ pkgs, ... }:

pkgs.btop.override{
	stdenv = pkgs.pkgsStatic.stdenv;
}
