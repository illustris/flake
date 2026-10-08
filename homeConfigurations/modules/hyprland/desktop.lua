local geometry = require("geometry")
local D = { modes = {}, orders = {}, ratios = {}, flags = {} }
desktop = D
local layouts = { grid = "lua:grid", monocle = "monocle", tabbed = "lua:tabbed", scrolling = "scrolling" }
local cycle = { "grid", "monocle", "tabbed", "scrolling" }
local busy, queued = false, false
local timers = {}
local signature = (os.getenv("HYPRLAND_INSTANCE_SIGNATURE") or "verify"):gsub("[^%w_-]", "_")
local state_path = (os.getenv("XDG_RUNTIME_DIR") or "/tmp") .. "/hypr-desktop-" .. signature .. ".state"

local function later(ms, fn)
    -- --verify-config has no event loop; upstream cannot clean up Lua timers there.
    if not os.getenv("HYPRLAND_INSTANCE_SIGNATURE") then return end
    local timer
    timer = hl.timer(function()
        timers[timer] = nil
        fn()
    end, { timeout = ms, type = "oneshot" })
    timers[timer] = true
end

local function key(ws) return tostring(ws.id) end
local function wid(w) return tostring(w.stable_id) end
local function dispatch(action) return hl.dispatch(action) end
local function active_workspace()
    return hl.get_active_special_workspace() or hl.get_active_workspace()
end
local function selector(ws) return ws.special and ("special:" .. ws.name:gsub("^special:", "")) or tostring(ws.id) end

local function save()
    local f = io.open(state_path .. ".tmp", "w")
    if not f then return end
    for name, enabled in pairs(D.flags) do f:write("flag ", name, " ", enabled and "1" or "0", "\n") end
    for id, mode in pairs(D.modes) do
        f:write("mode ", id, " ", mode, "\n")
        if D.orders[id] then f:write("order ", id, " ", table.concat(D.orders[id], ","), "\n") end
    end
    for id, ratio in pairs(D.ratios) do f:write("ratio ", id, " ", string.format("%.2f", ratio), "\n") end
    local function panel(output, ws)
        if ws then
            f:write("panel ", output, " ", key(ws), " ", D.mode(ws), " ", string.format("%.2f", D.grid_ratio(ws)), "\n")
        end
    end
    panel("*", active_workspace())
    for _, m in ipairs(hl.get_monitors()) do
        panel(m.name, hl.get_active_special_workspace(m) or hl.get_active_workspace(m))
    end
    f:close()
    os.rename(state_path .. ".tmp", state_path)
end

-- Session state is data, never executable Lua. A fresh compositor gets Grid.
local f = io.open(state_path, "r")
if f then
    for line in f:lines() do
        local id, mode = line:match("^mode (%-?%d+) (%a+)$")
        if id and layouts[mode] then D.modes[id] = mode end
        local rid, ratio = line:match("^ratio (%-?%d+) ([%d.]+)$")
        ratio = tonumber(ratio)
        if rid and ratio and ratio >= 0.25 and ratio <= 4 then D.ratios[rid] = ratio end
        local oid, order = line:match("^order (%-?%d+) ([%d,]+)$")
        if oid then
            D.orders[oid] = {}
            for item in order:gmatch("%d+") do table.insert(D.orders[oid], item) end
        end
        local name, enabled = line:match("^flag ([%w_-]+) ([01])$")
        -- Read the previous host-specific flag format during migration.
        if not name then name, enabled = line:match("^(%a+) ([01])$") end
        if name then D.flags[name] = enabled == "1" end
    end
    f:close()
end

local function ordered(windows, id, retain_missing)
    local present, result, order = {}, {}, {}
    for _, w in ipairs(windows) do present[wid(w)] = w end
    for _, w_id in ipairs(D.orders[id] or {}) do
        if present[w_id] then
            result[#result + 1] = present[w_id]
            order[#order + 1] = w_id
            present[w_id] = nil
        elseif retain_missing then
            order[#order + 1] = w_id
        end
    end
    for _, w in ipairs(windows) do
        if present[wid(w)] then
            result[#result + 1] = w
            order[#order + 1] = wid(w)
            present[wid(w)] = nil
        end
    end
    D.orders[id] = order
    return result
end

local function tiled(ws)
    return ordered(hl.get_windows({ workspace = ws, floating = false, mapped = true }), key(ws))
end

function D.mode(ws) return D.modes[key(ws or active_workspace())] or "grid" end

function D.grid_ratio(ws)
    ws = ws or active_workspace()
    return ws and D.ratios[key(ws)] or geometry.default_ratio
end

function D.grid_ratio_set(ratio)
    assert(type(ratio) == "number" and ratio >= 0.25 and ratio <= 4, "Grid ratio must be between 0.25 and 4")
    local ws = active_workspace()
    if not ws then return end
    D.ratios[key(ws)] = math.floor(ratio * 100 + 0.5) / 100
    if D.mode(ws) == "grid" then dispatch(hl.dsp.layout("reorder")) end
    save()
end

function D.grid_ratio_adjust(delta)
    D.grid_ratio_set(math.max(0.25, math.min(4, D.grid_ratio() + delta)))
end

local function dissolve(ws)
    for _, group in ipairs(ws:get_groups()) do
        local w = group.current
        if w then dispatch(hl.dsp.group.toggle({ window = w })) end
    end
end

local function tabs(ws)
    local windows = tiled(ws)
    if #windows == 0 then return end
    local layout = windows[1].layout
    -- Workspace rules apply on the next event-loop turn. Grouping while
    -- Monocle still owns the targets strands its inactive input flags.
    if layout and layout.name and layout.name ~= layouts.tabbed then
        later(15, function() if D.mode(ws) == "tabbed" then tabs(ws) end end)
        return
    end
    local active = hl.get_active_window()
    local root, changed = windows[1], false
    -- One native group supplies real tabs, hiding and input isolation.
    if not root.group then
        dispatch(hl.dsp.group.toggle({ window = root }))
        changed = true
    end
    local group = root.group
    if not group then return end
    for i = 2, #windows do
        local w = windows[i]
        if w.group ~= group then
            if w.group then dispatch(hl.dsp.group.toggle({ window = w })) end
            group:add(w)
            changed = true
        end
    end
    -- Title/rule updates also reconcile tabs. Only restore focus when actual
    -- regrouping displaced it; redundant focus dispatches warp the cursor.
    if changed and active and active.mapped and active.workspace == ws and not active.floating
        and hl.get_active_window() ~= active then
        dispatch(hl.dsp.focus({ window = active }))
    end
end

local function reconcile()
    if busy then return end
    busy = true
    for _, ws in ipairs(hl.get_workspaces()) do
        local mode = D.mode(ws)
        D.modes[key(ws)] = mode
        if mode == "tabbed" then tabs(ws) else tiled(ws) end
    end
    save()
    busy = false
end

local function schedule()
    if queued or busy then return end
    queued = true
    later(30, function() queued = false; reconcile() end)
end

function D.layout_set(mode)
    assert(layouts[mode], "expected grid, monocle, tabbed, or scrolling")
    local ws = active_workspace()
    if not ws then return end
    local old, active = D.mode(ws), hl.get_active_window()
    local order = D.orders[key(ws)]
    D.modes[key(ws)] = mode
    busy = true
    if old == "tabbed" and mode ~= "tabbed" then dissolve(ws) end
    D.orders[key(ws)] = order
    hl.workspace_rule({ workspace = selector(ws), layout = layouts[mode] })
    if mode == "tabbed" then tabs(ws) end
    busy = false
    save()
    local function finish()
        if D.mode(ws) ~= mode then return end
        local windows = tiled(ws)
        local layout = windows[1] and windows[1].layout
        if layout and layout.name and layout.name ~= layouts[mode] then later(15, finish); return end
        busy = true
        if mode == "tabbed" then tabs(ws) end
        if active and active.mapped and active.workspace == ws and active_workspace() == ws
            and hl.get_active_window() ~= active then
            dispatch(hl.dsp.focus({ window = active }))
        end
        busy = false
        save()
    end
    later(15, finish)
end

function D.layout_cycle()
    local current = D.mode()
    for i, mode in ipairs(cycle) do
        if mode == current then D.layout_set(cycle[i % #cycle + 1]); return end
    end
end

local function detach(w)
    if w and w.group then w.group:remove(w) end
end

function D.move(workspace)
    local w = hl.get_active_window()
    if not w then return end
    local source = w.workspace
    local source_selector, source_special = selector(source), source.special
    local remaining = {}
    for _, other in ipairs(tiled(source)) do
        if other ~= w then remaining[#remaining + 1] = other end
    end
    busy = true
    detach(w)
    dispatch(hl.dsp.window.move({ window = w, workspace = workspace, silent = true }))
    -- Moving its last window can destroy a special workspace immediately.
    if #remaining > 0 then dispatch(hl.dsp.focus({ window = remaining[1] }))
    elseif not source_special then dispatch(hl.dsp.focus({ workspace = source_selector })) end
    busy = false
    schedule()
end

function D.float(action)
    local w = hl.get_active_window()
    if not w then return end
    busy = true
    if action ~= "disable" then detach(w) end
    dispatch(hl.dsp.window.float({ window = w, action = action or "toggle" }))
    busy = false
    schedule()
end

function D.scratchpad()
    dispatch(hl.dsp.workspace.toggle_special("magic"))
    local ws = hl.get_active_special_workspace()
    if ws and ws.name == "special:magic" then
        local windows = hl.get_windows({ workspace = ws, mapped = true })
        if #windows > 0 then dispatch(hl.dsp.focus({ window = windows[1] })) end
    end
end

function D.focus_step(delta)
    local ws = active_workspace()
    if not ws then return end
    local windows = tiled(ws)
    local active, index = hl.get_active_window(), nil
    for i, w in ipairs(windows) do if w == active then index = i; break end end
    if #windows > 0 then
        dispatch(hl.dsp.focus({ window = windows[index and (index - 1 + delta) % #windows + 1 or 1] }))
    end
end

local function spatial_direction(windows, active, direction)
    local boxes, index = {}, nil
    for i, w in ipairs(windows) do
        local at, size = w.at, w.size
        boxes[i] = { x = at.x, y = at.y, w = size.x, h = size.y }
        if w == active then index = i end
    end
    if not index then
        local at, size = active.at, active.size
        index = #boxes + 1
        boxes[index] = { x = at.x, y = at.y, w = size.x, h = size.y }
    end
    local next_index = geometry.neighbor(boxes, index, direction, active.floating)
    return next_index and windows[next_index]
end

local function scroll_direction(windows, active, direction)
    local layout = active.layout
    if not layout or not layout.column then return active end
    local column, row = layout.column.index, layout.index_in_column
    local horizontal = direction == "left" or direction == "right"
    local delta = (direction == "left" or direction == "up") and -1 or 1
    local candidates = {}
    for _, w in ipairs(windows) do
        local other = w.layout
        if other and other.column then
            if horizontal and other.column.index == column + delta then
                candidates[#candidates + 1] = w
            elseif not horizontal and other.column.index == column and other.index_in_column == row + delta then
                return w
            end
        end
    end
    return spatial_direction(candidates, active, direction) or candidates[1] or active
end

function D.direction(direction)
    local ws, active = active_workspace(), hl.get_active_window()
    if not ws then return end
    local mode = D.mode(ws)
    if mode == "tabbed" or mode == "monocle" then
        D.focus_step((direction == "left" or direction == "up") and -1 or 1)
        return
    end
    local windows = {}
    for _, w in ipairs(hl.get_windows({ workspace = ws, mapped = true })) do
        if not w.hidden and w.accepts_input ~= false then windows[#windows + 1] = w end
    end
    if #windows == 0 then return end
    if not active or active.workspace ~= ws or not active.mapped or active.hidden then
        -- A tape drag or native focus message can leave the viewport unfocused.
        local first = windows[1]
        for _, w in ipairs(windows) do
            local col = w.layout and w.layout.column
            local current = first.layout and first.layout.column
            if col and (not current or col.index < current.index) then first = w end
        end
        dispatch(hl.dsp.focus({ window = first }))
        return
    end
    local target
    if mode == "scrolling" and not active.floating then
        target = scroll_direction(windows, active, direction)
    else
        target = spatial_direction(windows, active, direction)
    end
    -- Explicit focus brings the tape into view before warping the cursor.
    -- Native scrolling focus can warp into empty space and clear input focus.
    if target then dispatch(hl.dsp.focus({ window = target })) end
end

function D.master(promote)
    local ws, active = active_workspace(), hl.get_active_window()
    if not ws then return end
    local windows = tiled(ws)
    if #windows == 0 then return end
    if not promote then dispatch(hl.dsp.focus({ window = windows[1] })); return end
    for i, w in ipairs(windows) do
        if w == active then
            local order = D.orders[key(ws)]
            order[1], order[i] = order[i], order[1]
            save()
            if D.mode(ws) == "grid" then dispatch(hl.dsp.layout("reorder"))
            elseif D.mode(ws) == "tabbed" then busy = true; dissolve(ws); tabs(ws); busy = false
            else dispatch(hl.dsp.window.swap({ target = windows[1], window = active })) end
            return
        end
    end
end

function D.swap_step(delta)
    local ws, active = active_workspace(), hl.get_active_window()
    if not ws or not active then return end
    local windows = tiled(ws)
    for i, w in ipairs(windows) do
        if w == active then
            local j = (i - 1 + delta) % #windows + 1
            local order = D.orders[key(ws)]
            order[i], order[j] = order[j], order[i]
            save()
            if D.mode(ws) == "grid" then dispatch(hl.dsp.layout("reorder"))
            elseif D.mode(ws) == "tabbed" then busy = true; dissolve(ws); tabs(ws); busy = false
            else dispatch(hl.dsp.window.swap({ target = windows[j], window = active })) end
            return
        end
    end
end

hl.layout.register("grid", {
    recalculate = function(ctx)
        if #ctx.targets == 0 then return end
        local windows, targets = {}, {}
        for _, target in ipairs(ctx.targets) do
            if target.window then
                windows[#windows + 1] = target.window
                targets[wid(target.window)] = target
            end
        end
        if #windows == 0 then return end
        -- During layout changes targets arrive one at a time. Sorting that
        -- temporary subset must not discard the workspace's complete order.
        windows = ordered(windows, key(windows[1].workspace), true)
        local boxes = geometry.grid(ctx.area, #windows, D.grid_ratio(windows[1].workspace))
        for i, w in ipairs(windows) do targets[wid(w)]:place(boxes[i]) end
    end,
    layout_msg = function(_, msg) return msg == "reorder" end,
})
hl.layout.register("tabbed", {
    recalculate = function(ctx)
        for _, target in ipairs(ctx.targets) do target:place(ctx.area) end
    end,
})

function D.monitor_focus(selector, move)
    local monitor = hl.get_monitor(selector)
    if not monitor then return end
    if move then
        local ws = hl.get_active_workspace(monitor)
        if ws then D.move(tostring(ws.id)) end
    else dispatch(hl.dsp.focus({ monitor = monitor.name })) end
end

function D.wake()
    dispatch(hl.dsp.dpms({ action = "enable" }))
    if D.on_wake then D.on_wake() end
end

local function restore()
    for id, mode in pairs(D.modes) do
        hl.workspace_rule({ workspace = id, layout = layouts[mode] })
    end
    if D.on_restore then D.on_restore() end
    schedule()
end
for _, event in ipairs({ "window.open", "window.close", "window.move_to_workspace", "window.update_rules", "workspace.created" }) do
    hl.on(event, schedule)
end
hl.on("workspace.active", function() save(); schedule() end)
hl.on("workspace.special_active", save)
hl.on("monitor.focused", save)
hl.on("monitor.added", schedule)
hl.on("monitor.removed", schedule)
hl.on("config.reloaded", function() later(40, restore) end)
hl.on("hyprland.start", function() restore(); hl.exec_cmd("uwsm finalize") end)

D.later, D.save, D.workspace_selector = later, save, selector
return D
