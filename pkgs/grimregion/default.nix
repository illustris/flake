{ writeShellApplication, grim, slurp, libnotify, ... }:

writeShellApplication {
	name = "grimregion";

	runtimeInputs = [
		grim
		slurp
		libnotify
	];

	text = ''
		screenshot_filename="$HOME/Pictures/$(date +"%d-%m-%Y-%H%M%S").png"

		# Take screenshot of selected region
		grim -g "$(slurp)" "$screenshot_filename"

		if [ -e "$screenshot_filename" ]; then
			notify-send -i "$screenshot_filename" "Grim" "Screenshot Saved\n$screenshot_filename"
		fi
	'';

	meta.description = "Take screenshot of selection in wayland";
}
