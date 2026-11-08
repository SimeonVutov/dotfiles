local cache = os.getenv("XDG_CACHE_HOME") or os.getenv("HOME") .. "/.cache"
local ok, colors = pcall(require, cache .. "/matugen/colors-hyprland.lua")

if not ok or type(colors) ~= "table" then
    colors = {}
    local legacy = io.open(cache .. "/matugen/colors-hyprland.conf", "r")
    if legacy then
        for line in legacy:lines() do
            local name, value = line:match("^%s*%$([%w_]+)%s*=%s*(.-)%s*$")
            if name then colors[name] = value end
        end
        legacy:close()
    end
end

colors.active_border = colors.active_border or "rgba(ffffffff)"
colors.inactive_border = colors.inactive_border or "rgba(444444ff)"

return colors
