-- -----------------------------------------------------
-- Environment Variables
-- name: "Hybrid (AMD iGPU primary, NVIDIA dGPU for external monitor + prime-run)"
-- -----------------------------------------------------

hl.env("AQ_DRM_DEVICES", "/dev/dri/amd-igpu:/dev/dri/nvidia-dgpu")
hl.env("XDG_SESSION_TYPE", "wayland")
hl.env("QT_AUTO_SCREEN_SCALE_FACTOR", "1")
hl.env("WLR_NO_HARDWARE_CURSORS", "1")

hl.config({ cursor = {
    no_hardware_cursors = true,
} })
