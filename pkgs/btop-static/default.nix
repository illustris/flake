{ pkgsStatic, stdenv, lib, btop, ... }:

(btop.overrideAttrs (old: {
	meta = old.meta // { platforms = [
		"x86_64-linux"
	]; };
})).override{
	stdenv = pkgsStatic.stdenv;
}
