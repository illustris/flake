# Shared Hyprland desktop

The flake exports `homeManagerModules.hyprland` and `nixosModules.hyprland`.
The `dailyDriver` Home Manager profile already imports the home module; do not
import it a second time when using that profile. Both modules require the
Hyprland 0.56 native Lua configuration supported by the pinned nixpkgs and
Home Manager revisions.

The NixOS module enables Hyprland with UWSM, the lock-screen PAM service,
Bluetooth/removable-storage support, and Hyprland screen-sharing with KDE file
dialogs. SDDM and the default session use `mkDefault` so hosts can choose another
display manager. Home Manager owns Waybar and hypridle instead of system units.

The home module provides Grid, Monocle and Scrolling, positional focus,
workspace/window movement, clipboard history, screenshots, a launcher and
session menu, notifications, portals, idle locking, and a per-output panel.
Services follow `wayland-session@hyprland.desktop.target` so they stop at logout.
No display EDIDs, NVIDIA settings, or host wallpaper paths are in these modules.

Qt applications use the existing KDE palette through Home Manager's Qt module,
which installs the integration and sets the environment for login shells and
user services, including GPG pinentry. GTK uses Breeze Dark. Session environment
defaults and `illustris.hyprland.environment` overrides are also written to
`uwsm/env-hyprland`, so UWSM applications inherit them at session startup instead
of relying on variables set only inside the compositor. Restart applications
after changing their theme environment; existing processes retain their old one.
The tmux configuration extends `update-environment` with these variables and
the Qt plugin paths, so attaching from a graphical terminal also updates new
panes in a server that was started before the graphical session.

## Use on another host

```nix
# NixOS imports:
imports = [ inputs.illustris.nixosModules.hyprland ];

# Home Manager imports (unless using dailyDriver):
home-manager.users.illustris.imports = [
	inputs.illustris.homeManagerModules.hyprland
];
home-manager.users.illustris.illustris.hyprland = {
	monitorRules = [
		{ output = ""; mode = "preferred"; position = "auto"; scale = 1; }
		{ output = "eDP-1"; mode = "preferred"; position = "auto"; scale = 2; }
	];
	fingerprint = true; # Also enable services.fprintd on the host.
};
```

Use `illustris.hyprland.enable = false` to opt out of the home module.
Other `illustris.hyprland` options:

| Option | Default / purpose |
| --- | --- |
| `wallpaper` | `null`; no hyprpaper, and lock screen uses a screenshot |
| `softwareRendering` | `false`; opt into the NVIDIA Hyprlock resume workaround |
| `xwaylandFirefox` | `false`; opt into the pinned Firefox/GTK workaround |
| `fingerprint` | `false`; show fingerprint authentication and prompts |
| `environment` | Session environment overrides |
| `compositorSettings` | Native Lua compositor settings overriding shared defaults |
| `monitorRules` | Preferred mode, automatic placement, scale 1 for every output |
| `monitorKeys` | `W = "left"; E = "right"`; focus or Shift-move to a monitor |
| `extraLuaConfig` | Host Lua loaded after the shared controller and bindings |
| `extraCommands` | Additional `desktopctl` subcommands mapped to Lua expressions |
| `extraMenuEntries` | Menu labels mapped to `desktopctl` subcommands |

Host Lua files can be added through
`wayland.windowManager.hyprland.extraLuaFiles`, with `autoLoad = false`, then
required by `extraLuaConfig`. The `desktop` controller exposes `later`, `save`,
`workspace_selector`, and boolean `flags` for extensions. Optional `on_wake` and
`on_restore` callbacks run after DPMS wake and at startup/config reload.
Use standard Home Manager settings to override the Waybar widgets/style,
hypridle listeners, lock-screen appearance, and other application configuration.

The desktop host keeps its Alienware/LG EDIDs, HDR and HDMI recovery in
`~/src/desktop/modules/hyprland/outputs.lua`. Yoga keeps its eDP/dock profiles,
fingerprint, brightness dimming and battery bar in
`~/src/nix-yoga/modules/hyprland/`.

## Shortcuts

| Shortcut | Action |
| --- | --- |
| Super+Enter / D / Ctrl+E | Terminal / launcher / Dolphin |
| Super+G / M / R | Grid / Monocle / Scrolling |
| Super+Space | Cycle layouts |
| Super+arrows | Positional focus; tab order in Monocle; bounded column focus in Scrolling |
| Super+J / K | Next / previous window or tab |
| Super+Shift+J / K | Swap next / previous window |
| Super+Shift+Enter / Ctrl+M | Promote / focus first window |
| Super+1..9 / Shift+1..9 | Select workspace / move selected window |
| Super+W / E | Focus left / right monitor by default; Shift moves window |
| Super+Ctrl+arrows | Move workspace to another monitor |
| Super+S / Shift+S | Show scratchpad / send selected window |
| Super+minus / equal | Narrow / widen scrolling column |
| Super+Ctrl+minus / equal | Lower / raise this workspace's Grid aspect ratio |
| Super+Ctrl+Backspace | Reset Grid ratio to 1.20 |
| Super+F / Ctrl+Space / Shift+Space | Fullscreen / toggle floating / return to tiling |
| Super+H | Show full window titles for three seconds; press again to restart the timer |
| Super+V / slash | Clipboard history / shortcut help |
| Print / Shift+Print / Super+Shift+Print | Monitor / all outputs / region screenshot |
| Super+Shift+L / Q | Lock / session menu |

Screenshots are saved to `~/Pictures/Screenshots` and copied to the clipboard.
Hypridle locks at 420 seconds and sleeps displays at 480 seconds; it also locks
before suspend. Launch Hyprland from the display manager's UWSM session or with
`uwsm start -e -D Hyprland hyprland.desktop` from a TTY.

Grid follows XMonad GridVariants with a default width/height target of 1.20.
Its per-workspace ratio is adjustable from 0.25 to 4.00 in 0.10 steps. Layouts,
order, ratios and extension flags survive reloads in the same compositor session
as plain data under `$XDG_RUNTIME_DIR`. Fresh sessions start in Grid.

Monocle uses native window hiding and shows its ordered tabs in the bottom bar.
The separate Tabs layout and Super+T binding are removed; saved Tabs workspaces
migrate to Monocle on reload. Super+Left/Right and J/K follow the same order as
the bar, including after swaps and promotion. Grid and Scrolling have no window
list. The tab strip clips to the space remaining after the tray/status widgets;
scroll it to reach overflow tabs, or use the keyboard to reveal the selected tab.
Hover a tab for its full title. Super+H shows wrapped, click-through full-title
headers on visible windows for three seconds; repeated presses restart the timer.

Waybar is patched for native Lua workspace clicks and socket reconnection,
output names/colors on tags, and a controller-backed Monocle tab module.
Each tag names its output and keeps that output's color on every bar. A top
stroke marks tags assigned to this bar's output; a bottom stroke marks active tags.
The layout widget watches state changes with inotify, avoiding polling delay and
Hyprland's incorrect Lua layout names. Each output displays its own workspace's
layout and ratio. The idle inhibitor displays "Keep Awake: On/Off" by default.

## Validation

```sh
nix build .#checks.x86_64-linux.hyprland
XDG_RUNTIME_DIR=$(mktemp -d) HYPRLAND_INSTANCE_SIGNATURE=test \
  lua homeConfigurations/modules/hyprland/test.lua
PYTHONDONTWRITEBYTECODE=1 python homeConfigurations/modules/hyprland/test_panel.py
env -u HYPRLAND_INSTANCE_SIGNATURE Hyprland --verify-config -c ~/.config/hypr/hyprland.lua
hyprctl configerrors
```

For Lua IPC, use `hyprctl eval 'desktop.layout_set("monocle")'`. Legacy dispatcher
and `keyword` commands are incompatible with this configuration. The exported
`hyprland-layouts` and `hyprland-keybinds` packages remain available for legacy
configurations; this module does not install them.

`COPYING.grid` retains the upstream BSD license for the GridVariants port.
