{ stdenv, python3, hyprlock }:
stdenv.mkDerivation {
	pname = "hyprlock-shm-pool-test";
	inherit (hyprlock) version src patches;
	nativeBuildInputs = [ python3 ];
	dontConfigure = true;
	dontBuild = true;
	doCheck = true;
	checkPhase = ''
		runHook preCheck
		python3 ${./test-hyprlock-pool.py} src/helpers/MiscFunctions.cpp
		runHook postCheck
	'';
	installPhase = ''touch "$out"'';
}
