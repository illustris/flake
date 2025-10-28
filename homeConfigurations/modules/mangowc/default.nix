{ mango, ... }@inputs:
{ pkgs, config, lib, ... }:
{
	imports = [
		mango.hmModules.mango
	];

	home.packages = with pkgs; [
		wl-clipboard
		illustris.grimregion
		grim
	];

	wayland.windowManager.mango = {
		enable = true;
		autostart_sh = "";
		settings = ''
			# Appearance
			gappih=5
			gappiv=5
			gappoh=10
			gappov=10
			borderpx=2
			focuscolor=0x33ccffee
			bordercolor=0x595959aa

			# Blur and effects
			blur=1
			blur_optimized=1
			shadows=1
			shadows_size=4
			shadows_blur=3
			shadowscolor=0x1a1a1aee

			# Animations
			animations=1
			animation_type_open=slide
			animation_type_close=slide
			animation_fade_in=1
			animation_fade_out=1
			animation_duration_open=200
			animation_duration_close=200
			animation_duration_move=150
			animation_duration_tag=200

			# Layouts
			default_mfact=0.55
			default_nmaster=1
			smartgaps=1
			tagrule=id:1,layout_name:tile
			tagrule=id:2,layout_name:tile
			tagrule=id:3,layout_name:tile
			tagrule=id:4,layout_name:tile
			tagrule=id:5,layout_name:tile
			tagrule=id:6,layout_name:tile
			tagrule=id:7,layout_name:tile
			tagrule=id:8,layout_name:tile
			tagrule=id:9,layout_name:tile

			# Input
			repeat_rate=50
			repeat_delay=300
			xkb_rules_layout=us

			# Environment
			env=GDK_SCALE,2
			env=NIXOS_OZONE_WL,1
			env=QT_QPA_PLATFORM,wayland
			env=QT_QPA_PLATFORMTHEME,${pkgs.qt6ct}/bin/qt6ct
			env=WLR_NO_HARDWARE_CURSORS,1
			env=XCURSOR_SIZE,32

			# Key bindings
			bind=SUPER,RETURN,spawn,${pkgs.st}/bin/st
			bind=SUPER+SHIFT,C,killclient
			bind=SUPER+SHIFT,Q,quit
			bind=SUPER,d,spawn,${pkgs.wofi}/bin/wofi --show drun
			bind=SUPER,f,togglefullscreen
			bind=SUPER+SHIFT,SPACE,togglefloating
			bind=SUPER,left,focusdir,l
			bind=SUPER,right,focusdir,r
			bind=SUPER,up,focusdir,u
			bind=SUPER,down,focusdir,d
			bind=SUPER,S,toggle_scratchpad
			bind=none,Print,spawn,${lib.getExe pkgs.grim}
			bind=SUPER+SHIFT,Print,spawn,${pkgs.illustris.grimregion}/bin/grimregion

			# Workspace bindings
			bind=SUPER,1,view,1
			bind=SUPER,2,view,2
			bind=SUPER,3,view,3
			bind=SUPER,4,view,4
			bind=SUPER,5,view,5
			bind=SUPER,6,view,6
			bind=SUPER,7,view,7
			bind=SUPER,8,view,8
			bind=SUPER,9,view,9

			bind=SUPER+SHIFT,1,tag,1
			bind=SUPER+SHIFT,2,tag,2
			bind=SUPER+SHIFT,3,tag,3
			bind=SUPER+SHIFT,4,tag,4
			bind=SUPER+SHIFT,5,tag,5
			bind=SUPER+SHIFT,6,tag,6
			bind=SUPER+SHIFT,7,tag,7
			bind=SUPER+SHIFT,8,tag,8
			bind=SUPER+SHIFT,9,tag,9

			# Mouse bindings
			mousebind=SUPER,btn_left,movewin
			mousebind=SUPER,btn_right,resizewin
		'';
	};

	services.dunst.enable = true;
	wayland.systemd.target = "graphical-session.target";
}
