{ pkgs, config, lib, ... }:
let
	smart-focus = pkgs.writeShellApplication {
		name = "smart-focus";
		runtimeInputs = [ pkgs.hyprland ];
		text = ''
			direction="$1"

			# Get current layout from hyprctl
			current_layout=$(hyprctl workspacelayout)

			if [ "$current_layout" = "scrolling" ]; then
				case "$direction" in
					left)
						hyprctl dispatch layoutmsg "focus l"
						;;
					right)
						hyprctl dispatch layoutmsg "focus r"
						;;
					up)
						hyprctl dispatch movefocus u
						;;
					down)
						hyprctl dispatch movefocus d
						;;
				esac
			else
				case "$direction" in
					left)
						hyprctl dispatch movefocus l
						;;
					right)
						hyprctl dispatch movefocus r
						;;
					up)
						hyprctl dispatch movefocus u
						;;
					down)
						hyprctl dispatch movefocus d
						;;
				esac
			fi
		'';
	};
in
{
	home.packages = with pkgs; [
		wl-clipboard
		illustris.hyprland-keybinds
		illustris.hyprland-layouts
		illustris.grimregion
		grim
		hypridle
		brightnessctl
	];
	wayland.windowManager.hyprland = {
		enable = true;
		plugins = [
			pkgs.illustris.hyprscrolling
			pkgs.illustris.hyprland-workspace-layouts
		];
		settings = {
			animations = {
				enabled = lib.mkDefault "no";
				bezier = "myBezier, 0.05, 0.9, 0.1, 1.05";
				animation = [
					"windows, 1, 7, myBezier"
					"windowsOut, 1, 7, default, popin 80%"
					"border, 1, 10, default"
					"borderangle, 1, 8, default"
					"fade, 1, 7, default"
					"workspaces, 1, 6, default"
				];
			};
			bind = [
				"$mainMod, RETURN, exec, $terminal"
				"$mainMod SHIFT, C, killactive"
				"$mainMod SHIFT, Q, exit"
				"$mainMod SHIFT, L, exec, ${config.programs.hyprlock.package}/bin/hyprlock"
				"$mainMod, E, exec, $fileManager"
				# "$mainMod, R, exec, $menu"
				"$mainMod, P, pseudo"
				"$mainMod, J, togglesplit"
				"$mainMod, d, exec, $menu"
				# "$mainMod SHIFT, RETURN, layoutmsg, swapwithmaster"
				"$mainMod CTRL, m, layoutmsg, focusmaster"
				"$mainMod, f, fullscreen"
				"$mainMod SHIFT, SPACE, togglefloating"
				"$mainMod, SPACE, layoutmsg, cyclelayout next"
				"$mainMod, minus, layoutmsg, colresize all -0.167"
				"$mainMod, equal, layoutmsg, colresize all +0.167"
				# TODO: implement monocle layout
				# "$mainMod, m, fullscreen"
				# TODO: fix bsp plugin
				# "$mainMod, b, exec, hyprctl keyword general:layout bsp"
				"$mainMod, left, exec, ${smart-focus}/bin/smart-focus left"
				"$mainMod, right, exec, ${smart-focus}/bin/smart-focus right"
				"$mainMod, up, exec, ${smart-focus}/bin/smart-focus up"
				"$mainMod, down, exec, ${smart-focus}/bin/smart-focus down"
				"$mainMod, S, togglespecialworkspace, magic"
				"$mainMod SHIFT, S, movetoworkspace, special:magic"
				"$mainMod SHIFT, slash, exec, ${pkgs.illustris.hyprland-keybinds}/bin/hyprland-keybinds"
				"$mainMod, slash, exec, $terminal -e ${pkgs.illustris.hyprland-keybinds}/bin/hyprland-keybinds --terminal"
				", Print, exec, ${lib.getExe pkgs.grim}"
				"$mainMod SHIFT, Print, exec, grimregion"
				# Display layout switching
				"$mainMod SHIFT ALT, 1, exec, ${pkgs.illustris.hyprland-layouts}/bin/hypr-layout-officedesk"
				"$mainMod SHIFT ALT, 2, exec, ${pkgs.illustris.hyprland-layouts}/bin/hypr-layout-landscape"
				"$mainMod SHIFT ALT, 3, exec, ${pkgs.illustris.hyprland-layouts}/bin/hypr-layout-laptop-only"
				# Workspace movement between monitors
				"$mainMod CTRL, left, movecurrentworkspacetomonitor, l"
				"$mainMod CTRL, right, movecurrentworkspacetomonitor, r"
				"$mainMod CTRL, up, movecurrentworkspacetomonitor, u"
				"$mainMod CTRL, down, movecurrentworkspacetomonitor, d"
				"$mainMod SHIFT, comma, movecurrentworkspacetomonitor, -1"
				"$mainMod SHIFT, period, movecurrentworkspacetomonitor, +1"
				# "SHIFT ALT, 1, swapactiveworkspaces, current 0"
				# "SHIFT ALT, 2, swapactiveworkspaces, current 1"
				# "SHIFT ALT, 3, swapactiveworkspaces, current 2"
			] ++ (lib.concatLists (
				lib.genList (x: [
					"$mainMod, ${builtins.toString (x+1)}, workspace, ${builtins.toString (x+1)}"
					"$mainMod SHIFT, ${builtins.toString (x+1)}, movetoworkspace, ${builtins.toString (x+1)}"
				]) 9
			));
			bindm = [
				"$mainMod,mouse:272,movewindow"
				"$mainMod, mouse:273, resizewindow"
			];
			debug.disable_logs = false;
			decoration = {
				rounding = 4;
				blur = {
					enabled = true;
					size = 3;
					passes = 1;
				};
				shadow = {
					enabled = "yes";
					range = 4;
					render_power = 3;
					color = "rgba(1a1a1aee)";
				};
			};
			dwindle = {
				pseudotile = "yes";
				# preserve_split = "yes";
			};
			env  = [
				"GDK_SCALE,2"
				"NIXOS_OZONE_WL,1"
				"QT_QPA_PLATFORM,wayland"
				"QT_QPA_PLATFORMTHEME,${pkgs.qt6ct}/bin/qt6ct"
				"WLR_NO_HARDWARE_CURSORS,1"
				"XCURSOR_SIZE,32"
			];
			"$fileManager" = "${pkgs.kdePackages.dolphin}/bin/dolphin";
			general = {
				gaps_in = 1;
				gaps_out = 2;
				border_size = 1;
				"col.active_border" = "rgba(33ccffee) rgba(00ff99ee) 45deg";
				"col.inactive_border" = "rgba(595959aa)";
				layout = "workspacelayout";
				allow_tearing = false;
			};
			master.new_status = "master";
			"$menu" = "${pkgs.wofi}/bin/wofi --show drun";
			misc.force_default_wallpaper = 0;
			"$mainMod" = "SUPER";
			monitor = ",highres,auto,1,bitdepth,10";
			plugin.hyprscrolling.column_width = 0.5;
			"$terminal" = "${pkgs.st}/bin/st";
			windowrulev2 = "suppressevent maximize, class:.*";
		};
	};
	services.dunst.enable = true;

	# Hyprlock configuration
	programs.hyprlock = {
		enable = true;
		settings = {
			general = {
				grace = 5;
				hide_cursor = true;
				ignore_empty_input = true;
			};

			auth = {
				fingerprint = {
					enabled = true;
					ready_message = "Place your finger on the sensor";
					present_message = "Fingerprint detected";
				};
				pam = {
					enabled = true;
				};
			};

			background = [{
				monitor = "";
				path = "screenshot";
				blur_passes = 3;
				blur_size = 7;
				noise = 0.0117;
				contrast = 0.8916;
				brightness = 0.8172;
				vibrancy = 0.1696;
				vibrancy_darkness = 0.0;
			}];

			input-field = [{
				monitor = "";
				size = "300, 50";
				outline_thickness = 2;
				dots_size = 0.2;
				dots_spacing = 0.35;
				dots_center = true;
				outer_color = "rgba(33ccffee)";
				inner_color = "rgba(20, 20, 20, 0.8)";
				font_color = "rgb(200, 200, 200)";
				fade_on_empty = false;
				placeholder_text = "<span foreground=\"##cccccc\">Enter password...</span>";
				hide_input = false;
				position = "0, -120";
				halign = "center";
				valign = "center";
			}];

			label = [
				{
					monitor = "";
					text = ''cmd[update:1000] echo "$(date +'%H:%M:%S')"'';
					color = "rgba(200, 200, 200, 1.0)";
					font_size = 90;
					font_family = "Sans";
					position = "0, 80";
					halign = "center";
					valign = "center";
				}
				{
					monitor = "";
					text = ''cmd[update:1000] echo "$(date +'%A, %B %d')"'';
					color = "rgba(200, 200, 200, 1.0)";
					font_size = 25;
					font_family = "Sans";
					position = "0, 0";
					halign = "center";
					valign = "center";
				}
				{
					monitor = "";
					text = "Hi, $USER";
					color = "rgba(200, 200, 200, 1.0)";
					font_size = 20;
					font_family = "Sans";
					position = "0, -200";
					halign = "center";
					valign = "center";
				}
				{
					monitor = "";
					text = "$FPRINTPROMPT $FPRINTFAIL $PAMPROMPT";
					color = "rgba(255, 165, 0, 1.0)";
					font_size = 16;
					font_family = "Sans";
					position = "0, -170";
					halign = "center";
					valign = "center";
				}
			];
		};
	};

	# Hypridle configuration
	xdg.configFile."hypr/hypridle.conf".text = ''
		general {
			lock_cmd = pidof hyprlock || ${config.programs.hyprlock.package}/bin/hyprlock
			before_sleep_cmd = loginctl lock-session
			after_sleep_cmd = hyprctl dispatch dpms on
			ignore_dbus_inhibit = false
		}

		listener {
			timeout = 300
			on-timeout = ${pkgs.brightnessctl}/bin/brightnessctl -s set 50%
			on-resume = ${pkgs.brightnessctl}/bin/brightnessctl -r
		}

		listener {
			timeout = 420
			on-timeout = loginctl lock-session
		}

		listener {
			timeout = 480
			on-timeout = hyprctl dispatch dpms off
			on-resume = hyprctl dispatch dpms on
		}
	'';

	# Enable hypridle service
	systemd.user.services.hypridle = {
		Unit = {
			Description = "Hypridle idle daemon";
			PartOf = [ "graphical-session.target" ];
			After = [ "graphical-session.target" ];
		};
		Service = {
			ExecStart = "${pkgs.hypridle}/bin/hypridle";
			Restart = "always";
			RestartSec = 10;
		};
		Install.WantedBy = [ "graphical-session.target" ];
	};

	wayland.systemd.target = "graphical-session.target";
}
