{ pkgs, config, lib, ... }:
{
	home.packages = with pkgs; [
		wl-clipboard
		illustris.hyprland-keybinds
		illustris.grimregion
		grim
	];
	wayland.windowManager.hyprland = {
		enable = true;
		plugins = [
			# pkgs.illustris.hyprland-bsp-layout
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
				"$mainMod, E, exec, $fileManager"
				# "$mainMod, R, exec, $menu"
				"$mainMod, P, pseudo"
				"$mainMod, J, togglesplit"
				"$mainMod, d, exec, $menu"
				# "$mainMod SHIFT, RETURN, layoutmsg, swapwithmaster"
				"$mainMod CTRL, m, layoutmsg, focusmaster"
				"$mainMod, f, fullscreen"
				"$mainMod SHIFT, SPACE, togglefloating"
				# TODO: implement monocle layout
				# "$mainMod, m, fullscreen"
				# TODO: fix bsp plugin
				# "$mainMod, b, exec, hyprctl keyword general:layout bsp"
				"$mainMod, left, movefocus, l"
				"$mainMod, right, movefocus, r"
				"$mainMod, up, movefocus, u"
				"$mainMod, down, movefocus, d"
				"$mainMod, S, togglespecialworkspace, magic"
				"$mainMod SHIFT, S, movetoworkspace, special:magic"
				"$mainMod SHIFT, slash, exec, ${pkgs.illustris.hyprland-keybinds}/bin/hyprland-keybinds"
				"$mainMod, slash, exec, $terminal -e ${pkgs.illustris.hyprland-keybinds}/bin/hyprland-keybinds --terminal"
				", Print, exec, ${lib.getExe pkgs.grim}"
				"$mainMod SHIFT, Print, exec, grimregion"
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
				preserve_split = "yes";
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
				layout = "dwindle";
				allow_tearing = false;
			};
			master.new_status = "master";
			"$menu" = "${pkgs.wofi}/bin/wofi --show drun";
			misc.force_default_wallpaper = 0;
			"$mainMod" = "SUPER";
			monitor = ",highres,auto,1,bitdepth,10";
			"$terminal" = "${pkgs.st}/bin/st";
			windowrulev2 = "suppressevent maximize, class:.*";
		};
	};
	services.dunst.enable = true;
	wayland.systemd.target = "graphical-session.target";
}
