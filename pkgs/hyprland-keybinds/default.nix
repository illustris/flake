{ writeShellApplication, hyprland, gawk, wofi, fzf, gnused, ... }:

writeShellApplication {
	name = "hyprland-keybinds";
	runtimeInputs = [ hyprland gawk wofi fzf gnused ];
	text = ''
		# Parse flags
		USE_TERMINAL=0
		FULL_PATHS=0

		while [[ $# -gt 0 ]]; do
			case $1 in
				-t|--terminal)
					USE_TERMINAL=1
					shift
					;;
				-f|--full-paths)
					FULL_PATHS=1
					shift
					;;
				*)
					echo "Unknown option: $1"
					echo "Usage: hyprland-keybinds [--terminal] [--full-paths]"
					exit 1
					;;
			esac
		done

		# Get bindings and format them
		BINDINGS=$(hyprctl binds | awk -v full_paths="$FULL_PATHS" '
			BEGIN {
				modmask = ""
				key = ""
				dispatcher = ""
				arg = ""
			}

			/^bind$/ {
				# Output previous bind if we have data
				if (key != "") {
					# Format modifier mask as readable text
					if (modmask == "64") mod_text = "SUPER"
					else if (modmask == "65") mod_text = "SUPER+SHIFT"
					else if (modmask == "68") mod_text = "SUPER+CTRL"
					else if (modmask == "69") mod_text = "SUPER+CTRL+SHIFT"
					else if (modmask == "72") mod_text = "SUPER+ALT"
					else if (modmask == "1") mod_text = "SHIFT"
					else if (modmask == "4") mod_text = "CTRL"
					else if (modmask == "8") mod_text = "ALT"
					else mod_text = "mod(" modmask ")"

					# Format action
					if (arg != "") {
						action = dispatcher " " arg
					} else {
						action = dispatcher
					}

					# Strip nix store paths unless full_paths is requested
					if (full_paths == "0" && action ~ /\/nix\/store\//) {
						# Remove /nix/store/hash-package-version/bin/ prefix
						gsub(/\/nix\/store\/[^\/]+\/bin\//, "", action)
					}

					printf "%-30s → %s\n", mod_text "+" key, action
				}

				# Reset for next bind
				modmask = ""
				key = ""
				dispatcher = ""
				arg = ""
			}

			/^\tmodmask:/ {
				modmask = $2
			}

			/^\tkey:/ {
				key = $2
			}

			/^\tdispatcher:/ {
				dispatcher = $2
			}

			/^\targ:/ {
				# Arg might be empty or have multiple parts
				arg = ""
				for (i = 2; i <= NF; i++) {
					if (i > 2) arg = arg " "
					arg = arg $i
				}
			}

			END {
				# Output last bind
				if (key != "") {
					if (modmask == "64") mod_text = "SUPER"
					else if (modmask == "65") mod_text = "SUPER+SHIFT"
					else if (modmask == "68") mod_text = "SUPER+CTRL"
					else if (modmask == "69") mod_text = "SUPER+CTRL+SHIFT"
					else if (modmask == "72") mod_text = "SUPER+ALT"
					else if (modmask == "1") mod_text = "SHIFT"
					else if (modmask == "4") mod_text = "CTRL"
					else if (modmask == "8") mod_text = "ALT"
					else mod_text = "mod(" modmask ")"

					if (arg != "") {
						action = dispatcher " " arg
					} else {
						action = dispatcher
					}

					# Strip nix store paths unless full_paths is requested
					if (full_paths == "0" && action ~ /\/nix\/store\//) {
						gsub(/\/nix\/store\/[^\/]+\/bin\//, "", action)
					}

					printf "%-30s → %s\n", mod_text "+" key, action
				}
			}
		')

		# Display with appropriate tool
		if [[ $USE_TERMINAL -eq 1 ]]; then
			echo "$BINDINGS" | fzf --prompt "Keybindings> " --height 100% --reverse
		else
			echo "$BINDINGS" | wofi --dmenu --prompt "Keybindings" --width 800 --height 600
		fi
	'';
}
