{
	lib,
	stdenv,
	hyprland,
	pkg-config,
	...
}:

stdenv.mkDerivation {
	pname = "hyprland-bsp-layout";
	version = "1.0";

	src = ./.;

	nativeBuildInputs = [
		pkg-config
	] ++ hyprland.nativeBuildInputs;

	buildInputs = hyprland.buildInputs;

	# Disable meson configuration phase
	dontUseMesonConfigure = true;

	configurePhase = ''
		runHook preConfigure
		runHook postConfigure
	'';

	buildPhase = ''
		runHook preBuild
		make compile HYPRLAND_HEADERS="${hyprland.dev}/include"
		runHook postBuild
	'';

	installPhase = ''
		runHook preInstall
		mkdir -p $out/lib
		cp hyprland-bsp-layout.so $out/lib/libhyprland-bsp-layout.so
		runHook postInstall
	'';

	meta = with lib; {
		description = "BSP (Binary Space Partitioning) layout plugin for Hyprland";
		license = licenses.bsd3;
		platforms = platforms.linux;
	};
}
