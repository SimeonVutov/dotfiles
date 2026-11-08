-- -----------------------------------------------------
-- Window rules
-- -----------------------------------------------------
hl.window_rule({ match = { class = "^(Firefox)$" }, tile = true })

hl.window_rule({ match = { class = "^(blueman-manager)$" }, float = true })
hl.window_rule({ match = { title = "^(Picture-in-Picture)$" }, float = true, pin = true, move = "(monitor_w*0.695) (monitor_h*0.04)" })
hl.window_rule({ match = { class = ".*" }, suppress_event = "maximize" })
hl.layer_rule({ match = { namespace = "^(quickshell-session-menu)$" }, no_anim = true })
hl.layer_rule({ match = { namespace = "^(quickshell-launcher)$" }, no_anim = true })
hl.layer_rule({ match = { namespace = "^(quickshell-settings)$" }, no_anim = true })
hl.window_rule({ match = { title = "^(wifi-tui|bluetooth-tui|pulsemixer)$" }, float = true, center = true, size = { 900, 600 } })
