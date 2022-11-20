{ stdenv, lib, fetchurl, autoPatchelfHook, ... }:
with lib;
let
	supportedPlatforms = {
		x86_64-linux = {
			name = "linux-x64";
			hash = "sha256-EV41H/0V2lLxkAHwtHhu/HZaNOrE/m1G5vhhDLAyglQ=";
		};
		aarch64-linux = {
			name = "linux-arm64";
			hash = "sha256-pTpWbHuah7TxW2Uuw5zbMWszJDIzg6NPPNCs6Cl8YjU=";
		};
		riscv64-linux = {
			name = "linux-riscv64";
			hash = fakeHash;
		};
	};
in
stdenv.mkDerivation rec {
	pname = "oss-cad-suite";
	version = "2022-04-15";

	src = fetchurl {
		url = "https://github.com/YosysHQ/oss-cad-suite-build/releases/download/${
			version
		}/oss-cad-suite-${
			supportedPlatforms.${stdenv.system}.name
		}-${replaceStrings ["-"] [""] version}.tgz";
		inherit (supportedPlatforms.${stdenv.system}) hash;
	};

	nativeBuildInputs = [ autoPatchelfHook ];

	installPhase = indent ''
		mkdir -p $out
		mv * $out/
	'';
	meta ={
		platforms = attrNames supportedPlatforms;
	};
}
