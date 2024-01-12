{ pkgs, ... }:
with pkgs.lib;

# inspired by (i.e. stolen from) github:juliosueiras-nix/nix-utils
drv: pkgs.stdenv.mkDerivation {
	pname = drv.pname+"-deb";
	inherit (drv) version;
	buildInputs = [
		pkgs.fpm
	];
	unpackPhase = "true";
	buildPhase = ''
		export HOME=$PWD
		mkdir -p ./nix/store/
		mkdir -p ./bin
		for item in "$(cat ${pkgs.referencesByPopularity drv})"
		do
			cp -r $item ./nix/store/
		done

		ln -s ${drv}/bin/* ./bin/

		chmod -R a+rwx ./nix
		chmod -R a+rwx ./bin
		fpm --input-type dir \
			--output-type deb \
			--name ${drv.pname} \
			--version ${drv.version} \
			nix bin
	'';
	installPhase = ''
		mkdir -p $out
		cp -r *.deb $out
	'';
}
