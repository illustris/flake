local M = {}
M.default_ratio = 1.2

-- Port of XMonad.Layout.GridVariants (BSD-3-Clause, Norbert Zeh).
-- Distribute the rounding remainder like splitEvenly, including short columns.
local function boundaries(n, parts)
    local size = math.ceil(n / parts)
    local extra = size * parts - n
    local result = {0}
    for i = 1, parts do result[i + 1] = i * size - math.min(i, extra) end
    return result
end

function M.grid(area, n, aspect)
    if n == 0 then return {} end
    aspect = aspect or M.default_ratio
    local screen = area.w / area.h
    local ideal = math.sqrt(screen * n / aspect)
    local lo, hi = math.floor(ideal), math.ceil(ideal)
    local cols
    if lo == 0 then cols = hi
    elseif math.floor(n / hi) == 0 then cols = lo
    elseif (screen * math.ceil(n / lo) / lo) / aspect
        < aspect / (screen * math.floor(n / hi) / hi) then cols = lo
    else cols = hi end
    cols = math.min(n, math.max(1, cols))
    local xs, counts = boundaries(area.w, cols), boundaries(n, cols)
    local boxes = {}
    for col = 1, cols do
        local rows = counts[col + 1] - counts[col]
        local ys = boundaries(area.h, rows)
        for row = 1, rows do
            boxes[#boxes + 1] = {
                x = area.x + xs[col], y = area.y + ys[row],
                w = xs[col + 1] - xs[col], h = ys[row + 1] - ys[row],
            }
        end
    end
    return boxes
end

-- Prefer an aligned neighbor, then the nearest edge and center. Gaps and
-- uneven column heights must not make another cell unreachable.
function M.neighbor(boxes, index, direction, allow_diagonal)
    local origin = boxes[index]
    if not origin then return end
    local horizontal = direction == "left" or direction == "right"
    local sign = (direction == "left" or direction == "up") and -1 or 1
    local function axes(box)
        if horizontal then return box.x, box.w, box.y, box.h end
        return box.y, box.h, box.x, box.w
    end
    local a, length, cross, extent = axes(origin)
    local best, score
    for i, box in ipairs(boxes) do
        local b, size, other, span = axes(box)
        local forward = sign * (b + size / 2 - a - length / 2)
        local overlap = math.min(cross + extent, other + span) - math.max(cross, other)
        if i ~= index and forward > 0 and (overlap > 0 or allow_diagonal) then
            local gap = sign > 0 and b - a - length or a - b - size
            local candidate = { overlap > 0 and 0 or 1, math.max(0, gap),
                math.max(0, -overlap), math.abs(other + span / 2 - cross - extent / 2), forward }
            local better = not score
            if score then
                for j, value in ipairs(candidate) do
                    if value ~= score[j] then better = value < score[j]; break end
                end
            end
            if better then best, score = i, candidate end
        end
    end
    return best
end

return M
