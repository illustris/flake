{ stdenv, lib, fetchurl, autoPatchelfHook, ... }:
with lib;
stdenv.mkDerivation rec {
	pname = "oss-cad-suite";
	version = "2022-04-15";

	src = fetchurl {
		url = "https://github.com/YosysHQ/oss-cad-suite-build/releases/download/${version}/oss-cad-suite-linux-x64-${replaceStrings ["-"] [""] version}.tgz";
		hash = "sha256-EV41H/0V2lLxkAHwtHhu/HZaNOrE/m1G5vhhDLAyglQ=";
	};

	nativeBuildInputs = [ autoPatchelfHook ];

	installPhase = ''
		mkdir -p $out
		mv * $out/
	'';
}