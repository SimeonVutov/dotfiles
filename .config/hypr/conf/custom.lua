-- Add your additional Hyprland configurations here
-- 
-- This is an additional key binding 
-- hl.bind(mainMod .. " + CTRL + up", hl.dsp.focus({ workspace = "empty" }))
-- 
-- Example for xwayland
-- hl.config({ xwayland = {
--   force_zero_scaling = true,
-- } })

-- qt5ct environment variable
-- hl.env("QT_QPA_PLATFORMTHEME", "qt5ct")

-- SDL version
-- hl.env("SDL_VIDEODRIVER", "wayland")
-- hl.env("SDL_VIDEODRIVER", "x11")


-- Example per-device config
-- See https://wiki.hypr.land/configuring/core/devices/ for more
hl.device({
    name = "epic-mouse-v1",
    sensitivity = -0.5,
})


