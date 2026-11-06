-- ----------------------------------------------------- 
-- Environment Variables
-- name: "Nvidia"
-- ----------------------------------------------------- 

-- Default Settings in ml4w.conf

-- NVIDIA https://wiki.hypr.land/configuring/extra/nvidia/
hl.env("LIBVA_DRIVER_NAME", "nvidia")
hl.env("GBM_BACKEND", "nvidia-drm")
hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")
hl.env("XDG_SESSION_TYPE", "wayland")
hl.env("QT_AUTO_SCREEN_SCALE_FACTOR", "1")
hl.env("WLR_NO_HARDWARE_CURSORS", "1")
hl.env("WLR_RENDERER", "vulkan")
hl.env("WLR_DRM_DEVICES", "/dev/dri/card1")

hl.config({ cursor = {
    no_hardware_cursors = true,
} })
