local D = desktop
local function run(command) hl.exec_cmd("uwsm app -- " .. command) end
local function bind(keys, description, action, opts)
    opts = opts or {}
    opts.description = description
    hl.bind(keys, action, opts)
end
local function command(keys, description, cmd) bind(keys, description, function() run(cmd) end) end

hl.config({
    general = { layout = "lua:grid", gaps_in = 1, gaps_out = 2, border_size = 1,
        ["col.active_border"] = "rgb(00ccff)", ["col.inactive_border"] = "rgb(808080)" },
    decoration = { rounding = 2, blur = { enabled = false }, shadow = { enabled = false } },
    animations = { enabled = false },
    input = { kb_layout = "us", follow_mouse = 1, repeat_delay = 300, repeat_rate = 40 },
    misc = { disable_hyprland_logo = true, force_default_wallpaper = 0 },
    scrolling = { column_width = 0.5, follow_focus = true, wrap_focus = false,
        explicit_column_widths = "0.333, 0.5, 0.667, 1.0" },
    group = { auto_group = false, groupbar = { enabled = false } },
})
-- Also generated as uwsm/env-hyprland so services inherit the same settings.
for name, value in pairs(desktop_settings.environment) do hl.env(name, value) end
hl.config(desktop_settings.settings)

hl.window_rule({ name = "no-maximize", match = { class = ".*" }, suppress_event = "maximize" })
hl.window_rule({ name = "dialogs", match = { title = "^(Open File|Save File|Save As|Authentication Required|Select what to share|Hyprland portal check).*$" }, float = true, center = true })

command("SUPER + Return", "Open st", tools.terminal)
command("SUPER + D", "Application launcher", tools.launcher)
command("SUPER + CTRL + E", "Open Dolphin", tools.files)
command("SUPER + H", "Show full window titles for 3 seconds", tools.headers)
command("SUPER + V", "Clipboard history", tools.clipboard)
command("SUPER + SHIFT + L", "Lock desktop", tools.lock)
command("SUPER + SHIFT + slash", "Keyboard shortcuts", tools.help)
command("SUPER + slash", "Keyboard shortcuts", tools.help)
command("Print", "Screenshot focused monitor", tools.screenshot .. " monitor")
command("SHIFT + Print", "Screenshot all monitors", tools.screenshot .. " all")
command("SUPER + SHIFT + Print", "Screenshot selection", tools.screenshot .. " region")
command("SUPER + SHIFT + Q", "Session menu", tools.menu)
bind("SUPER + SHIFT + C", "Close window", hl.dsp.window.close())
for key, mode in pairs({ G = "grid", M = "monocle", R = "scrolling" }) do
    bind("SUPER + " .. key, "Layout: " .. mode, function() D.layout_set(mode) end)
end
bind("SUPER + space", "Cycle layouts", D.layout_cycle)
bind("SUPER + F", "Fullscreen window", hl.dsp.window.fullscreen())
bind("SUPER + SHIFT + space", "Return window to tiling", function() D.float("disable") end)
bind("SUPER + CTRL + space", "Toggle floating", function() D.float("toggle") end)
bind("SUPER + J", "Focus next window/tab", function() D.focus_step(1) end, { repeating = true })
bind("SUPER + K", "Focus previous window/tab", function() D.focus_step(-1) end, { repeating = true })
bind("SUPER + SHIFT + J", "Swap next window", function() D.swap_step(1) end)
bind("SUPER + SHIFT + K", "Swap previous window", function() D.swap_step(-1) end)
bind("SUPER + SHIFT + Return", "Promote to first window", function() D.master(true) end)
bind("SUPER + CTRL + M", "Focus first window", function() D.master(false) end)
for key, direction in pairs({ Left = "left", Right = "right", Up = "up", Down = "down" }) do
    bind("SUPER + " .. key, "Focus " .. direction, function() D.direction(direction) end, { repeating = true })
    bind("SUPER + CTRL + " .. key, "Move workspace " .. direction, hl.dsp.workspace.move({ monitor = direction }))
end
bind("SUPER + minus", "Narrow scrolling column", hl.dsp.layout("colresize -conf"))
bind("SUPER + equal", "Widen scrolling column", hl.dsp.layout("colresize +conf"))
bind("SUPER + CTRL + minus", "Grid: reduce width/height ratio, split into columns sooner", function() D.grid_ratio_adjust(-0.1) end, { repeating = true })
bind("SUPER + CTRL + equal", "Grid: increase width/height ratio, split into columns later", function() D.grid_ratio_adjust(0.1) end, { repeating = true })
bind("SUPER + CTRL + BackSpace", "Grid: reset width/height ratio to 1.20", function() D.grid_ratio_set(1.2) end)
bind("SUPER + S", "Show scratchpad", D.scratchpad)
bind("SUPER + SHIFT + S", "Send window to scratchpad", function() D.move("special:magic") end)
for i = 1, 9 do
    local workspace = tostring(i)
    bind("SUPER + " .. workspace, "Workspace " .. workspace,
        hl.dsp.focus({ workspace = workspace, on_current_monitor = true }))
    bind("SUPER + SHIFT + " .. workspace, "Send window to workspace " .. workspace, function() D.move(workspace) end)
end
for key, selector in pairs(desktop_settings.monitorKeys) do
    bind("SUPER + " .. key, "Focus " .. selector .. " monitor", function() D.monitor_focus(selector, false) end)
    bind("SUPER + SHIFT + " .. key, "Send window to " .. selector .. " monitor", function() D.monitor_focus(selector, true) end)
end
bind("SUPER + mouse:272", "Move window with mouse", hl.dsp.window.drag(), { drag = true })
bind("SUPER + mouse:273", "Resize window with mouse", hl.dsp.window.resize(), { drag = true })
command("XF86AudioRaiseVolume", "Volume up", tools.volume .. " set-volume -l 1.5 @DEFAULT_AUDIO_SINK@ 5%+")
command("XF86AudioLowerVolume", "Volume down", tools.volume .. " set-volume @DEFAULT_AUDIO_SINK@ 5%-")
command("XF86AudioMute", "Mute speakers", tools.volume .. " set-mute @DEFAULT_AUDIO_SINK@ toggle")
command("XF86AudioMicMute", "Mute microphone", tools.volume .. " set-mute @DEFAULT_AUDIO_SOURCE@ toggle")
command("XF86AudioPlay", "Play/pause", tools.player .. " play-pause")
command("XF86AudioNext", "Next track", tools.player .. " next")
command("XF86AudioPrev", "Previous track", tools.player .. " previous")
command("XF86MonBrightnessUp", "Brightness up", tools.brightness .. " set +5%")
command("XF86MonBrightnessDown", "Brightness down", tools.brightness .. " set 5%-")
