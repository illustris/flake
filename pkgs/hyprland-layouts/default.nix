{ stdenv, lib, hyprland, jq, makeWrapper, ... }:

stdenv.mkDerivation {
	name = "hyprland-layouts";
	version = "0.1.0";

	src = ../../homeConfigurations/modules/hyprland/scripts;

	nativeBuildInputs = [ makeWrapper ];
	buildInputs = [ hyprland jq ];

	installPhase = ''
		mkdir -p $out/bin

		# Install each layout script with hypr-layout- prefix
		for script in officedesk landscape laptop-only; do
			install -Dm755 "$script" "$out/bin/hypr-layout-$script"
			# Wrap scripts to ensure runtime dependencies are in PATH
			wrapProgram "$out/bin/hypr-layout-$script" \
				--prefix PATH : ${lib.makeBinPath [ hyprland jq ]}
		done
	'';

	meta = {
		description = "Display layout switching scripts for Hyprland";
		mainProgram = "hypr-layout-officedesk";
	};
}
