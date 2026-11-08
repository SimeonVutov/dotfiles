-- ----------------------------------------------------- 
-- General window layout and colors
-- name: "Default"
-- ----------------------------------------------------- 
local colors = require("conf.colors")
hl.config({ general = {
    gaps_in = 3,
    gaps_out = 12,
    border_size = 2,
    ["col.active_border"] = colors.active_border,
    ["col.inactive_border"] = colors.inactive_border,
    layout = "dwindle",
    resize_on_border = true,
    allow_tearing = false,
} })
