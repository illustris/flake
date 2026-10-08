local source = debug.getinfo(1, "S").source:sub(2)
package.path = (source:match("^(.*/)") or "") .. "?.lua;" .. package.path
local geometry = require("geometry")
for _, area in ipairs({ { x = 0, y = 1680, w = 3840, h = 2128 }, { x = 3840, y = 0, w = 2160, h = 3808 },
    { x = 7, y = 13, w = 1919, h = 1079 } }) do
    for _, aspect in ipairs({ 0.25, 0.8, 1.2, 1.6, 2.4, 4 }) do
      for n = 1, 40 do
        local boxes, covered = geometry.grid(area, n, aspect), 0
        assert(#boxes == n)
        for i, a in ipairs(boxes) do
            assert(a.w > 0 and a.h > 0 and a.x >= area.x and a.y >= area.y)
            assert(a.x + a.w <= area.x + area.w and a.y + a.h <= area.y + area.h)
            covered = covered + a.w * a.h
            for j = i + 1, #boxes do
                local b = boxes[j]
                assert(a.x + a.w <= b.x or b.x + b.w <= a.x or a.y + a.h <= b.y or b.y + b.h <= a.y,
                    "overlapping grid windows")
            end
        end
        assert(covered == area.w * area.h, "unfilled grid space")
      end
    end
end
local reference = geometry.grid({ x = 0, y = 0, w = 3840, h = 2160 }, 5, 1.6)
assert(reference[1].w == 1920 and reference[1].h == 1080)
assert(reference[3].x == 1920 and reference[3].h == 720)
local portrait = { x = 3840, y = 0, w = 2160, h = 3808 }
assert(geometry.default_ratio == 1.2)
assert(geometry.grid(portrait, 4)[4].x == portrait.x, "1.20 keeps the four-window portrait stack")
assert(geometry.grid(portrait, 5)[5].x > portrait.x, "1.20 splits the portrait stack at five windows")
assert(geometry.grid(portrait, 4, 0.8)[4].x > portrait.x, "lower ratio must split into columns sooner")
assert(geometry.grid(portrait, 6, 2.4)[6].x == portrait.x, "higher ratio must defer the split")
local unequal = geometry.grid(portrait, 7)
assert(not geometry.neighbor(unequal, 1, "up"), "top of a short column must not jump diagonally")
assert(not geometry.neighbor(unequal, 4, "up"), "top of a tall column must not jump diagonally")

local windows, workspaces, events, pending, active, rules = {}, {}, {}, {}, nil, {}
local providers = {}
local monitors, clock, current_workspace, focused_monitor = {}, 0, nil, nil
local dpms = false
local focus_calls, group_changes, displace_on_group = 0, 0, false
local function workspace(id)
    local ws = { id = id, name = tostring(id), special = false }
    function ws:get_groups()
        local result, seen = {}, {}
        for _, w in ipairs(windows) do
            if w.workspace == self and w.group and not seen[w.group] then
                seen[w.group] = true; result[#result + 1] = w.group
            end
        end
        return result
    end
    workspaces[#workspaces + 1] = ws
    return ws
end
local one, two = workspace(1), workspace(2)
local function window(id, ws, floating)
    local w = { stable_id = id, workspace = ws, floating = floating or false, mapped = true }
    windows[#windows + 1] = w
    return w
end
local a, b, c = window(1, one), window(2, one), window(3, one)
local dialog = window(4, one, true)
active = b
local function group(w)
    local g = { windows = { w }, current = w }
    function g:add(item)
        group_changes = group_changes + 1
        self.windows[#self.windows + 1] = item; item.group = self
        -- Native regrouping can select a different tab and displace focus.
        if displace_on_group and active and active.workspace == item.workspace and not active.floating then
            active = item
        end
    end
    function g:remove(item)
        for i, member in ipairs(self.windows) do
            if member == item then table.remove(self.windows, i); break end
        end
        item.group = nil
        self.current = self.windows[1]
    end
    w.group = g
    return g
end
local function action(op) return function(args) return { op = op, args = args or {} } end end
hl = {
    layout = { register = function(name, provider) providers[name] = provider end },
    timer = function(fn, opts) pending[#pending + 1] = { fn = fn, at = clock + opts.timeout }; return fn end,
    on = function(event, fn)
        local previous = events[event]
        events[event] = previous and function(...) previous(...); fn(...) end or fn
    end,
    bind = function() end,
    get_monitor = function(selector)
        for _, monitor in ipairs(monitors) do if monitor.name == selector then return monitor end end
    end,
    exec_cmd = function() end,
    monitor = function() end,
    workspace_rule = function(rule) rules[rule.workspace] = rule.layout end,
    get_active_workspace = function(m) return m and m.active_workspace or active and active.workspace or current_workspace or one end,
    get_active_special_workspace = function(m) return m and m.active_special_workspace end,
    get_active_window = function() return active end,
    get_workspaces = function() return workspaces end,
    get_monitors = function() return monitors end,
    get_windows = function(filter)
        local result = {}
        for _, w in ipairs(windows) do
            if w.workspace == filter.workspace and (filter.floating == nil or w.floating == filter.floating) and w.mapped then
                result[#result + 1] = w
            end
        end
        return result
    end,
    dsp = { group = { toggle = action("group") }, focus = action("focus"),
        window = { move = action("move"), float = action("float"), swap = action("swap") },
        dpms = action("dpms"), layout = action("layout") },
}
function hl.dispatch(dsp)
    local args, w = dsp.args, dsp.args.window
    if dsp.op == "group" then
        group_changes = group_changes + 1
        if w.group then
            local members = w.group.windows
            for _, member in ipairs(members) do member.group = nil end
        else group(w) end
    elseif dsp.op == "focus" then
        focus_calls = focus_calls + 1
        if args.monitor then focused_monitor = args.monitor else active = w end
    elseif dsp.op == "move" then
        -- Model the native behavior: a move carries the group unless detached first.
        local members = w.group and w.group.windows or { w }
        for _, member in ipairs(members) do member.workspace = args.workspace == "2" and two or one end
    elseif dsp.op == "float" then
        if args.action == "enable" then w.floating = true
        elseif args.action == "disable" then w.floating = false
        else w.floating = not w.floating end
    elseif dsp.op == "dpms" then
        if args.action == "enable" then dpms = true
        elseif args.action == "disable" then dpms = false
        else dpms = not dpms end
    end
end
local function flush()
    local list = pending; pending = {}
    for _, timer in ipairs(list) do clock = math.max(clock, timer.at); timer.fn() end
end
local function advance(ms)
    local until_time = clock + ms
    while #pending > 0 do
        table.sort(pending, function(a, b) return a.at < b.at end)
        if pending[1].at > until_time then break end
        local timer = table.remove(pending, 1)
        clock = timer.at
        timer.fn()
    end
    clock = until_time
end
local D = require("desktop")
D.layout_set("tabbed")
assert(a.group and a.group == b.group and a.group == c.group and not dialog.group)
assert(active == b and #a.group.windows == 3)
flush()
assert(focus_calls == 0, "grouping and layout completion must leave correct focus alone")
local focus_before, groups_before = focus_calls, group_changes
for _ = 1, 30 do
    events["window.update_rules"](); advance(30)
end
assert(active == b and focus_calls == focus_before, "title/rule refreshes must not refocus the selected tab")
assert(group_changes == groups_before, "unchanged tabs must not be regrouped on refresh")
D.layout_set("tabbed"); flush()
assert(focus_calls == focus_before, "layout completion must not refocus an already active window")
D.focus_step(1)
assert(active == c and focus_calls == focus_before + 1, "keyboard navigation must still dispatch focus")
active, displace_on_group = b, true
local new = window(5, one)
events["window.open"](); flush()
assert(new.group == a.group and #a.group.windows == 4, "new window must join workspace tabs")
assert(active == b and focus_calls == focus_before + 2, "regrouping must restore displaced focus exactly once")
displace_on_group = false
local closing = window(6, one)
events["window.open"](); flush()
focus_before, groups_before = focus_calls, group_changes
closing.group:remove(closing); closing.mapped = false
events["window.close"](); flush()
assert(active == b and focus_calls == focus_before and group_changes == groups_before,
    "closing an inactive tab must preserve focus and the remaining group")
active = dialog
events["window.update_rules"](); flush()
assert(active == dialog and focus_calls == focus_before, "refresh must preserve a focused floating dialog")
active = b; D.move("2"); flush()
assert(b.workspace == two and not b.group)
assert(a.workspace == one and c.workspace == one and new.workspace == one, "move must affect only selected tab")
active = c; D.float("enable"); flush()
assert(c.floating and not c.group and a.group == new.group)
D.float("disable"); flush()
assert(not c.floating and c.group == a.group, "sinking must rejoin tabs")
D.float("disable"); flush()
assert(not c.floating and c.group == a.group, "sinking a tiled tab must be a no-op")
D.wake(); assert(dpms, "wake must turn outputs on")
D.wake(); assert(dpms, "repeated wake must leave outputs on")
D.layout_set("monocle")
assert(not a.group and not c.group and not new.group, "leaving tabs must dissolve group")
D.flags.custom_flag = true
D.grid_ratio_set(0.8)
assert(D.grid_ratio(one) == 0.8 and D.grid_ratio(two) == 1.2, "ratio changes must be per workspace")
assert(not pcall(D.grid_ratio_set, 0) and not pcall(D.grid_ratio_set, 0/0), "invalid ratios must be rejected")
active = b; D.layout_set("scrolling")
D.grid_ratio_set(2.4)
package.loaded.desktop = nil
events = {}
D = require("desktop")
assert(D.mode(one) == "monocle" and D.mode(two) == "scrolling", "reload must preserve workspace modes")
assert(D.grid_ratio(one) == 0.8 and D.grid_ratio(two) == 2.4, "reload must preserve ratios")
assert(D.flags.custom_flag, "reload must preserve host extension flags")
active = a; D.layout_cycle()
assert(D.mode(one) == "tabbed")
D.grid_ratio_adjust(-100); assert(D.grid_ratio() == 0.25)
D.grid_ratio_adjust(100); assert(D.grid_ratio() == 4)
D.grid_ratio_set(geometry.default_ratio)
advance(100)

-- Reproduce WS4: three columns, two rows, with actual border/gap insets.
local navigation = workspace(4)
local cells = {}
for col = 0, 2 do
    for row = 0, 1 do
        local w = window(10 + #cells, navigation)
        w.at = { x = col * 1280 + 3, y = 1683 + row * 1064 }
        w.size = { x = 1274, y = 1058 }
        cells[#cells + 1] = w
    end
end
active = cells[5]
D.direction("left"); assert(active == cells[3], "Left must reach the middle column")
D.direction("left"); assert(active == cells[1], "Left must reach the first column")
D.direction("left"); assert(active == cells[1], "Left boundary must keep focus on this workspace")
D.direction("down"); assert(active == cells[2])
D.direction("right"); assert(active == cells[4])
D.direction("right"); assert(active == cells[6])
D.direction("right"); assert(active == cells[6], "Right must not move focus onto LG")
D.direction("up"); assert(active == cells[5])
D.direction("up"); assert(active == cells[5], "Up must stop at the top row")
current_workspace, active = navigation, nil
D.direction("right"); assert(active == cells[1], "arrows must recover missing focus")
active = nil
D.focus_step(1); assert(active == cells[1], "cycle recovery must not skip the first window")

-- Native column order can differ from the controller's saved window order.
D.layout_set("scrolling")
for i, w in ipairs(cells) do
    local col = 2 - math.floor((i - 1) / 2)
    w.at.x = col * 1920 + 3
    w.layout = { column = { index = col }, index_in_column = (i - 1) % 2 }
end
active = cells[5]
for _ = 1, 20 do D.direction("left"); assert(active == cells[5], "scrolling must clamp at first column") end
D.direction("right"); assert(active == cells[3], "scrolling must follow native columns")
D.direction("down"); assert(active == cells[4], "scrolling Down must stay in its column")
D.direction("right"); assert(active == cells[2], "scrolling must preserve vertical position")
for _ = 1, 20 do D.direction("right"); assert(active == cells[2], "scrolling must clamp at last column") end
D.direction("down"); assert(active == cells[2], "scrolling must stop at last row")
active = nil
D.direction("left"); assert(active == cells[5], "scrolling must recover focus at the first column")

-- Rule application is deferred: tabs must wait until Monocle releases its
-- targets, otherwise grouping strands inactive input flags on the old windows.
for _, w in ipairs(cells) do w.layout = { name = "monocle" } end
D.layout_set("tabbed")
assert(not cells[1].group, "must not group targets while Monocle still owns them")
advance(20)
assert(not cells[1].group, "must wait for actual layout activation, not a fixed delay")
for _, w in ipairs(cells) do w.layout = { name = "lua:tabbed" } end
advance(20)
assert(cells[1].group and cells[6].group == cells[1].group, "tabs must group once the new layout owns the targets")
D.layout_set("grid")
assert(not cells[1].group and not cells[6].group)
local saved_order = table.concat(D.orders["4"], ",")
local area = { x = 0, y = 1680, w = 3840, h = 2128 }
providers.grid.recalculate({ area = area, targets = { { window = cells[5], place = function() end } } })
assert(table.concat(D.orders["4"], ",") == saved_order, "partial target transfer must preserve complete window order")
local previous_focus = active
active = nil
for _, w in ipairs(cells) do w.layout = { name = "lua:grid" } end
advance(20)
assert(active == previous_focus, "layout completion must restore selected window after native focus loss")
for _, w in ipairs(cells) do w.mapped = false end
active = nil
D.direction("left"); assert(active == nil, "empty workspace must be safe")
current_workspace, active = nil, a

-- Generic monitor navigation must work without the desktop's EDID extension.
monitors = { { name = "eDP-1", active_workspace = one }, { name = "DP-1", active_workspace = two } }
D.monitor_focus("DP-1", false)
assert(focused_monitor == "DP-1", "monitor focus must use the selected output")
D.monitor_focus("unplugged", false)
assert(focused_monitor == "DP-1", "missing outputs must leave focus alone")
D.monitor_focus("DP-1", true)
assert(a.workspace == two, "monitor move must select that output's active workspace")
active = a
D.monitor_focus("eDP-1", true)
assert(a.workspace == one, "monitor move must also work back to the internal output")
local wake_calls, restore_calls = 0, 0
D.on_wake = function() wake_calls = wake_calls + 1 end
D.on_restore = function() restore_calls = restore_calls + 1 end
D.wake()
assert(dpms and wake_calls == 1, "wake must turn on DPMS and call the host extension")
events["config.reloaded"](); advance(100)
assert(restore_calls == 1, "reload must restore layouts and call the host extension")
D.on_wake, D.on_restore, monitors = nil, nil, {}

print("PASS: refresh focus preservation, displaced focus restoration, shared Grid/Scrolling navigation, boundaries, focus recovery, deferred tabs, ratio, order, moves, monitors, host hooks, idle wake and reload state")
return setmetatable({ desktop = D, events = events, one = one, two = two, advance = advance,
    clock = function() return clock end }, {
    __index = function(_, field) if field == "monitors" then return monitors end end,
    __newindex = function(t, field, value)
        if field == "monitors" then monitors = value else rawset(t, field, value) end
    end,
})
