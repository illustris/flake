{
	lib,
	stdenv,
	hyprland,
	hyprlandPlugins,
	pkg-config,
	...
}:

stdenv.mkDerivation {
	pname = "hyprscrolling";
	version = hyprlandPlugins.hyprscrolling.version;

	# Use the same source as nixpkgs hyprlandPlugins
	src = hyprlandPlugins.hyprscrolling.src;

	patches = [
		./boundary-fix.patch
		./workspace-column-tracking.patch
	];

	nativeBuildInputs = [
		pkg-config
	] ++ hyprland.nativeBuildInputs;

	buildInputs = hyprland.buildInputs ++ [
		hyprland.dev
	];

	# Disable meson configuration phase
	dontUseMesonConfigure = true;

	configurePhase = ''
		runHook preConfigure
		runHook postConfigure
	'';

	buildPhase = ''
		runHook preBuild
		make all
		runHook postBuild
	'';

	installPhase = ''
		runHook preInstall
		mkdir -p $out/lib
		cp hyprscrolling.so $out/lib/libhyprscrolling.so
		runHook postInstall
	'';

	meta = with lib; {
		description = "Scrolling/PaperWM-like layout for Hyprland";
		homepage = "https://github.com/hyprwm/hyprland-plugins";
		license = licenses.bsd3;
		platforms = platforms.linux;
	};
}
