{
	config,
	lib,
	pkgs,
	...
}:
let
	inherit (import ../../../lib { inherit lib; }) indent;
	cfg = config.illustris.hyprland;
	target = "wayland-session@hyprland.desktop.target";
	panel = pkgs.writeScriptBin "desktop-panel" (indent ''
		#!${lib.getExe pkgs.python3}
	'' + builtins.readFile ./panel.py);
	headers = pkgs.stdenvNoCC.mkDerivation {
		name = "desktop-window-headers";
		dontUnpack = true;
		nativeBuildInputs = [ pkgs.wrapGAppsHook3 ];
		buildInputs = [ pkgs.gtk3 pkgs.gtk-layer-shell pkgs.gobject-introspection ];
		installPhase = let
			python = pkgs.python3.withPackages (p: [ p.pygobject3 p.pycairo ]);
			script = pkgs.writeText "desktop-window-headers.py" (
				"#!${python}/bin/python3\n"
				+ lib.replaceStrings [ "@hyprctl@" ] [ "${pkgs.hyprland}/bin/hyprctl" ] (builtins.readFile ./headers.py)
			);
		in indent ''
			mkdir -p $out/bin
			cp ${script} $out/bin/desktop-window-headers
			chmod +x $out/bin/desktop-window-headers
		'';
		meta.mainProgram = "desktop-window-headers";
	};
	# NVIDIA's EGL surface cleanup can spin after resume; keep the locker on Mesa.
	lockPackage =
		if cfg.softwareRendering then
			pkgs.symlinkJoin {
				name = "hyprlock-software";
				paths = [ pkgs.hyprlock ];
				nativeBuildInputs = [ pkgs.makeWrapper ];
				postBuild = indent ''
					wrapProgram "$out/bin/hyprlock" \
						--set LIBGL_ALWAYS_SOFTWARE 1 \
						--set __EGL_VENDOR_LIBRARY_FILENAMES ${pkgs.mesa}/share/glvnd/egl_vendor.d/50_mesa.json
				'';
				meta = pkgs.hyprlock.meta;
			}
		else
			pkgs.hyprlock;
	ctl = pkgs.writeShellApplication {
		name = "desktopctl";
		runtimeInputs =
			with pkgs;
			[
				hyprland
				jq
				wofi
				uwsm
				systemd
			]
			++ [
				lockPackage
				panel
			];
		text =
			lib.replaceStrings
				[ "@extraCases@" "@menuEntries@" "@menuCases@" ]
				[
					(lib.concatStringsSep "\n" (
						lib.mapAttrsToList (
							name: code: "  ${lib.escapeShellArg name}) hyprctl eval ${lib.escapeShellArg code} ;;"
						) cfg.extraCommands
					))
					(lib.escapeShellArgs (
						[
							"Grid"
							"Monocle"
							"Scroll"
						]
						++ builtins.attrNames cfg.extraMenuEntries
						++ [
							"Lock"
							"Suspend"
							"Log out"
						]
					))
					(lib.concatStringsSep "\n" (
						lib.mapAttrsToList (
							label: command: "      ${lib.escapeShellArg label}) desktopctl ${lib.escapeShellArg command} ;;"
						) cfg.extraMenuEntries
					))
				]
				(builtins.readFile ./desktopctl.sh);
	};
	screenshot = pkgs.writeShellApplication {
		name = "desktop-screenshot";
		runtimeInputs = with pkgs; [
			grim
			slurp
			wl-clipboard
			hyprland
			jq
			libnotify
		];
		text = builtins.readFile ./screenshot.sh;
	};
	clipboard = pkgs.writeShellApplication {
		name = "desktop-clipboard";
		runtimeInputs = with pkgs; [
			cliphist
			wofi
			wl-clipboard
		];
		text = indent ''
			choice=$(cliphist list | wofi --dmenu --prompt Clipboard) || exit 0
			[ -n "$choice" ] || exit 0
			printf '%s\n' "$choice" | cliphist decode | wl-copy
		'';
	};
	tools = {
		terminal = lib.getExe pkgs.st;
		launcher = "${lib.getExe pkgs.wofi} --show drun";
		files = lib.getExe pkgs.kdePackages.dolphin;
		clipboard = lib.getExe clipboard;
		lock = lib.getExe lockPackage;
		screenshot = lib.getExe screenshot;
		headers = lib.getExe headers;
		menu = "${lib.getExe ctl} menu";
		help = "${lib.getExe ctl} help";
		volume = "${pkgs.wireplumber}/bin/wpctl";
		player = lib.getExe pkgs.playerctl;
		brightness = lib.getExe pkgs.brightnessctl;
	};
	isolated = {
		Unit = {
			PartOf = lib.mkForce [ target ];
			After = lib.mkForce [ target ];
		};
		Install.WantedBy = lib.mkForce [ target ];
	};
	wallpaper = if cfg.wallpaper == null then "screenshot" else cfg.wallpaper;
in
{
	options.illustris.hyprland = {
		enable = lib.mkOption {
			type = lib.types.bool;
			default = true;
			description = "Enable the shared Lua Hyprland desktop.";
		};
		wallpaper = lib.mkOption {
			type = lib.types.nullOr lib.types.str;
			default = null;
			description = "Wallpaper path; null uses the compositor background and a lock screenshot.";
		};
		softwareRendering = lib.mkEnableOption "Mesa software rendering for Hyprlock (NVIDIA resume workaround)";
		xwaylandFirefox = lib.mkEnableOption "the Hyprland-only Firefox XWayland workaround";
		fingerprint = lib.mkEnableOption "fingerprint authentication in Hyprlock";
		environment = lib.mkOption {
			type = lib.types.attrsOf lib.types.str;
			default = { };
			description = "Additional or overridden Hyprland session environment variables.";
		};
		compositorSettings = lib.mkOption {
			type = lib.types.attrsOf lib.types.anything;
			default = { };
			description = "Native Lua compositor settings applied after the shared defaults.";
		};
		monitorRules = lib.mkOption {
			type = lib.types.listOf (lib.types.attrsOf lib.types.anything);
			default = [
				{
					output = "";
					mode = "preferred";
					position = "auto";
					scale = 1;
				}
			];
			description = "Native Lua monitor rules. Device-specific EDIDs and HDR settings belong in the host configuration.";
		};
		monitorKeys = lib.mkOption {
			type = lib.types.attrsOf lib.types.str;
			default = {
				W = "left";
				E = "right";
			};
			description = "Super key to monitor selector mapping; Shift moves the selected window.";
		};
		extraLuaConfig = lib.mkOption {
			type = lib.types.lines;
			default = "";
			description = "Host Lua configuration loaded after the shared controller and bindings.";
		};
		extraCommands = lib.mkOption {
			type = lib.types.attrsOf lib.types.str;
			default = { };
			description = "Additional desktopctl subcommands mapped to Lua expressions.";
		};
		extraMenuEntries = lib.mkOption {
			type = lib.types.attrsOf lib.types.str;
			default = { };
			description = "Additional desktop menu labels mapped to desktopctl subcommands.";
		};
	};
	config = lib.mkIf cfg.enable {
		assertions = [
			{
				assertion = lib.versionAtLeast pkgs.hyprland.version "0.56";
				message = "The shared Hyprland module requires Hyprland 0.56 or newer for native Lua layouts.";
			}
		];
		home.packages = with pkgs; [
			ctl
			screenshot
			clipboard
			wl-clipboard
			cliphist
			grim
			slurp
			wofi
			hyprpaper
			pavucontrol
			playerctl
			brightnessctl
			networkmanagerapplet
			blueman
			udiskie
			kdePackages.kdeconnect-kde
			kdePackages.breeze
			kdePackages.breeze-icons
			kdePackages.qtwayland
			xdg-utils
		];
		wayland.systemd.target = target;
		wayland.windowManager.hyprland = {
			enable = true;
			configType = "lua";
			systemd.enable = false;
			extraLuaFiles = {
				geometry = {
					content = ./geometry.lua;
					autoLoad = false;
				};
				desktop = {
					content = ./desktop.lua;
					autoLoad = false;
				};
				bindings = {
					content = ./bindings.lua;
					autoLoad = false;
				};
			};
			extraConfig = lib.concatStringsSep "\n" [
				"package.path = ${lib.generators.toLua { } (config.xdg.configHome + "/hypr/?.lua;")} .. package.path"
				"tools = ${lib.generators.toLua { } tools}"
				"desktop_settings = ${
					lib.generators.toLua { } {
						inherit (cfg) monitorKeys;
						settings = cfg.compositorSettings;
						environment = cfg.environment;
					}
				}"
				(indent ''
					require("desktop")
					require("bindings")
				'')
				"for _, rule in ipairs(${lib.generators.toLua { } cfg.monitorRules}) do hl.monitor(rule) end"
				cfg.extraLuaConfig
			];
		};
		programs.wofi = {
			enable = true;
			settings = {
				width = 600;
				height = 480;
				allow_images = true;
				insensitive = true;
				term = "st";
			};
			style = indent ''
				window { background: #232629; color: #eff0f1; border: 1px solid #00ccff; }
				#input { background: #31363b; color: #eff0f1; margin: 10px; border: 0; border-radius: 0; }
				#entry { padding: 8px 12px; }
				#entry:selected { background: #00576b; }
				#text:selected { color: #eff0f1; }
			'';
		};
		# The pinned Firefox/GTK build crashes in xdg_output_handle_name on native Wayland.
		# At scale 1 XWayland stays sharp, and this wrapper only changes Hyprland sessions.
		programs.firefox.package = lib.mkIf cfg.xwaylandFirefox (
			pkgs.firefox.overrideAttrs (old: {
				makeWrapperArgs = old.makeWrapperArgs ++ [
					"--run"
					(indent ''
						if [ "''${XDG_CURRENT_DESKTOP:-}" = Hyprland ]; then
							export GDK_BACKEND=x11 MOZ_ENABLE_WAYLAND=0
						fi
					'')
				];
			})
		);
		services = {
			dunst = {
				enable = true;
				settings.global = {
					font = "Noto Sans 11";
					frame_color = "#00ccff";
					background = "#232629";
					foreground = "#eff0f1";
					frame_width = 1;
					corner_radius = 2;
					origin = "top-right";
					offset = "16x16";
					width = 420;
				};
			};
			cliphist = {
				enable = true;
				allowImages = true;
				systemdTargets = [ target ];
			};
			hyprpaper = {
				enable = cfg.wallpaper != null;
				systemdTarget = target;
				settings = {
					ipc = true;
					splash = false;
					wallpaper = [
						{
							monitor = "";
							path = wallpaper;
							fit_mode = "cover";
						}
					];
				};
			};
			network-manager-applet.enable = true;
			blueman-applet = {
				enable = true;
				systemdTargets = [ target ];
			};
			polkit-gnome.enable = true;
			udiskie = {
				enable = true;
				tray = "auto";
			};
			hypridle = {
				enable = true;
				systemdTarget = target;
				settings = {
					general = {
						lock_cmd = "pidof hyprlock || ${lib.getExe pkgs.uwsm} app -- ${lib.getExe lockPackage}";
						before_sleep_cmd = "loginctl lock-session";
						after_sleep_cmd = "${lib.getExe ctl} wake";
						ignore_dbus_inhibit = false;
					};
					listener = [
						{
							timeout = 420;
							on-timeout = "loginctl lock-session";
						}
						{
							timeout = 480;
							on-timeout = "${lib.getExe ctl} sleep";
							on-resume = "${lib.getExe ctl} wake";
						}
					];
				};
			};
		};
		programs.hyprlock = {
			enable = true;
			package = lockPackage;
			settings = {
				general = {
					hide_cursor = true;
					ignore_empty_input = true;
					screencopy_mode = if cfg.softwareRendering then 1 else 0;
				};
				auth.pam.enabled = true;
				auth.fingerprint = {
					enabled = cfg.fingerprint;
					ready_message = "Place your finger on the sensor";
					present_message = "Fingerprint detected";
				};
				background = [
					{
						monitor = "";
						path = wallpaper;
						blur_passes = 2;
						blur_size = 6;
					}
				];
				input-field = [
					{
						monitor = "";
						size = "360, 52";
						outline_thickness = 2;
						outer_color = "rgb(00ccff)";
						inner_color = "rgb(232629)";
						font_color = "rgb(eff0f1)";
						placeholder_text = "Password";
						position = "0, -100";
						halign = "center";
						valign = "center";
					}
				];
				label = [
					{
						monitor = "";
						text = "$TIME";
						font_family = "Noto Sans";
						font_size = 72;
						color = "rgb(eff0f1)";
						position = "0, 80";
						halign = "center";
						valign = "center";
					}
				]
				++ lib.optionals cfg.fingerprint [
					{
						monitor = "";
						text = "$FPRINTPROMPT $FPRINTFAIL $PAMPROMPT";
						font_size = 16;
						color = "rgb(eff0f1)";
						position = "0, -170";
						halign = "center";
						valign = "center";
					}
				];
			};
		};
		programs.waybar = {
			enable = true;
			package = pkgs.waybar.overrideAttrs (old: {
				patches = (old.patches or [ ]) ++ [
					./waybar-lua.patch
					./waybar-ipc.patch
					./waybar-desktop.patch
				];
				postPatch = (old.postPatch or "") + ''
					cp ${./waybar-tabs.hpp} include/modules/hyprland/desktop_tabs.hpp
					cp ${./waybar-tabs.cpp} src/modules/hyprland/desktop_tabs.cpp
				'';
			});
			systemd = {
				enable = true;
				targets = [ target ];
			};
			settings.main = lib.mapAttrs (_: value: lib.mkDefault value) {
				layer = "top";
				position = "bottom";
				height = 32;
				spacing = 6;
				fixed-center = false;
				expand-center = true;
				modules-left = [
					"custom/menu"
					"hyprland/workspaces"
					"custom/layout"
				];
				modules-center = [ "hyprland/desktop-tabs" ];
				modules-right = [
					"clock"
					"mpris"
					"idle_inhibitor"
					"pulseaudio"
					"network"
					"bluetooth"
					"tray"
				];
				"custom/menu" = {
					format = "Apps";
					on-click = tools.launcher;
					on-click-right = tools.menu;
					tooltip = false;
				};
				"hyprland/workspaces" = {
					all-outputs = true;
					format = "{name} <small>{output}</small>";
					sort-by-number = true;
					move-to-monitor = true;
				};
				"custom/layout" = {
					exec = lib.getExe panel;
					return-type = "json";
					restart-interval = 1;
					on-click = "${lib.getExe ctl} cycle";
					on-click-right = tools.menu;
				};
				"hyprland/desktop-tabs" = { expand = true; };
				clock = {
					format = "{:%a %d %b  %H:%M}";
					tooltip-format = "<tt>{calendar}</tt>";
				};
				mpris = {
					format = "{artist} - {title}";
					max-length = 35;
				};
				idle_inhibitor = {
					format = "{icon}";
					format-icons = {
						activated = "Keep Awake: On";
						deactivated = "Keep Awake: Off";
					};
					tooltip = true;
					tooltip-format-activated = "Automatic locking and display sleep are paused. Click to resume.";
					tooltip-format-deactivated = "Automatic locking and display sleep are enabled. Click to keep awake.";
				};
				pulseaudio = {
					format = "Vol {volume}%";
					format-muted = "Muted";
					on-click = "pavucontrol";
					on-click-right = "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle";
				};
				network = {
					format-ethernet = "LAN";
					format-wifi = "{essid} {signalStrength}%";
					format-disconnected = "Offline";
					tooltip-format = "{ifname}: {ipaddr}";
					on-click = "nm-connection-editor";
				};
				bluetooth = {
					format = "BT {status}";
					on-click = "blueman-manager";
				};
				tray = {
					icon-size = 20;
					spacing = 8;
				};
			};
			style = lib.mkDefault (indent ''
				* { font-family: "Noto Sans"; font-size: 12px; border: none; border-radius: 0; min-height: 0; }
				window#waybar { background: #232629; color: #eff0f1; border-top: 1px solid #4d5257; }
				#workspaces button { padding: 0 10px; color: #bdc3c7; background: transparent; }
				#workspaces button.active { background: #31363b; border-bottom: 2px solid currentColor; }
				#workspaces button.output-0 { color: #00ccff; }
				#workspaces button.output-1 { color: #f6b26b; }
				#workspaces button.output-2 { color: #a6e3a1; }
				#workspaces button.output-3 { color: #cba6f7; }
				#workspaces button.output-4 { color: #f38ba8; }
				#workspaces button.output-5 { color: #f9e2af; }
				#workspaces button.hosting-monitor { border-top: 2px solid currentColor; }
				#workspaces button.urgent { background: #da4453; }
				#custom-menu, #custom-layout, #clock, #pulseaudio, #network, #bluetooth, #idle_inhibitor, #mpris, #tray { padding: 0 8px; }
				#custom-layout { color: #00ccff; }
				#idle_inhibitor.activated { color: #00ccff; }
				#desktop-tabs button { padding: 0 8px; color: #bdc3c7; background: transparent; }
				#desktop-tabs button.active { background: #31363b; color: #eff0f1; border-bottom: 2px solid #00ccff; }
				tooltip { background: #31363b; color: #eff0f1; }
			'');
		};
		systemd.user.services = {
			waybar = isolated;
			network-manager-applet = isolated;
			polkit-gnome = isolated;
			udiskie = isolated;
			dunst.Install.WantedBy = [ target ];
			dunst.Unit.ConditionEnvironment = "XDG_CURRENT_DESKTOP=Hyprland";
			kdeconnect-hyprland = {
				Unit = {
					Description = "KDE Connect for Hyprland";
					PartOf = [ target ];
					After = [ target ];
				};
				Service.ExecStart = "${pkgs.kdePackages.kdeconnect-kde}/bin/kdeconnect-indicator";
				Install.WantedBy = [ target ];
			};
		};
		# These packages also install XDG autostarts; the Hyprland units own their lifecycle.
		xdg.configFile = {
			"autostart/nm-applet.desktop".text = indent ''
				[Desktop Entry]
				Type=Application
				Name=NetworkManager Applet
				Exec=${pkgs.networkmanagerapplet}/bin/nm-applet
				NotShowIn=KDE;GNOME;COSMIC;Hyprland;
			'';
			"autostart/blueman.desktop".text = indent ''
				[Desktop Entry]
				Type=Application
				Name=Blueman Applet
				Exec=${pkgs.blueman}/bin/blueman-applet
				NotShowIn=Hyprland;
			'';
			"autostart/picom.desktop".text = indent ''
				[Desktop Entry]
				Type=Application
				Name=picom
				Exec=${pkgs.picom}/bin/picom
				NotShowIn=Hyprland;
			'';
		};
	};
}
