{
	lib,
	stdenv,
	fetchFromGitHub,
	hyprland,
	pkg-config,
	...
}:

stdenv.mkDerivation {
	pname = "hyprWorkspaceLayouts";
	version = "0-unstable-2025-01-14";

	src = fetchFromGitHub {
		owner = "zakk4223";
		repo = "hyprworkspacelayouts";
		rev = "e44a2dbaa5a8b7d116dd284bc28f39a9067a2cbc";
		hash = "sha256-kUUPeijIxnS7LZzz24r2vw5Ghiz0XJwUXGovZpgajCo=";
	};

	patches = [ ./add-getlayout.patch ];

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
		cp workspaceLayoutPlugin.so $out/lib/libhyprWorkspaceLayouts.so
		runHook postInstall
	'';

	meta = with lib; {
		description = "Workspace-specific window layouts for Hyprland";
		homepage = "https://github.com/zakk4223/hyprworkspacelayouts";
		license = licenses.bsd3;
		platforms = platforms.linux;
	};
}
