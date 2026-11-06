-- ----------------------------------------------------- 
-- Key bindings
-- name: "Default"
-- ----------------------------------------------------- 

-- SUPER KEY
mainMod = "SUPER"
local variables = require("conf.variables")
-- Example binds, see https://wiki.hypr.land/configuring/core/binds/ for more
hl.bind(mainMod .. " + RETURN", hl.dsp.exec_cmd(variables.terminal))
hl.bind(mainMod .. " + Q", hl.dsp.window.close())
hl.bind(mainMod .. " + M", hl.dsp.exit())
hl.bind(mainMod .. " + B", hl.dsp.exec_cmd(variables.browser))
hl.bind(mainMod .. " + V", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + P", hl.dsp.exec_cmd("~/.config/scripts/session-menu.sh"))
hl.bind(mainMod .. " + J", hl.dsp.layout("togglesplit")) -- dwindle
hl.bind(mainMod .. " + F", hl.dsp.window.fullscreen())
hl.bind(mainMod .. " + W", hl.dsp.exec_cmd("~/.config/scripts/app-launcher.sh"))
hl.bind(mainMod .. " + SHIFT + W", hl.dsp.exec_cmd("sh ~/.config/scripts/wallpaper-select.sh"))
hl.bind(mainMod .. " + SHIFT + Z", hl.dsp.exec_cmd("sh ~/.config/scripts/quickshell-start.sh topbar restart"))
hl.bind(mainMod .. " + F12", hl.dsp.exec_cmd("sleep 0.1 && bash ~/.config/scripts/screenshot.sh"))

hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl set 5%+"))
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl set 5%-"))
hl.bind("XF86KbdBrightnessUp", hl.dsp.exec_cmd("brightnessctl --device='asus::kbd_backlight' set 1+"))
hl.bind("XF86KbdBrightnessDown", hl.dsp.exec_cmd("brightnessctl --device='asus::kbd_backlight' set 1-"))

-- Move focus with mainMod + arrow keys
hl.bind(mainMod .. " + left", hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + up", hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + down", hl.dsp.focus({ direction = "down" }))

hl.bind("SUPER + SHIFT + H", hl.dsp.window.move({ direction = "left" }))
hl.bind("SUPER + SHIFT + L", hl.dsp.window.move({ direction = "right" }))
hl.bind("SUPER + SHIFT + K", hl.dsp.window.move({ direction = "up" }))
hl.bind("SUPER + SHIFT + J", hl.dsp.window.move({ direction = "down" }))


hl.bind(mainMod .. " + L", hl.dsp.exec_cmd("hyprlock"))

-- Monitors
hl.bind(mainMod .. " + SHIFT + R", hl.dsp.exec_cmd("sh ~/.config/scripts/quick-settings.sh monitors"))

-- Workspaces
hl.bind(mainMod .. " + 1", hl.dsp.focus({ workspace = "1" })) -- Open workspace 1
hl.bind(mainMod .. " + 2", hl.dsp.focus({ workspace = "2" })) -- Open workspace 2
hl.bind(mainMod .. " + 3", hl.dsp.focus({ workspace = "3" })) -- Open workspace 3
hl.bind(mainMod .. " + 4", hl.dsp.focus({ workspace = "4" })) -- Open workspace 4
hl.bind(mainMod .. " + 5", hl.dsp.focus({ workspace = "5" })) -- Open workspace 5
hl.bind(mainMod .. " + 6", hl.dsp.focus({ workspace = "6" })) -- Open workspace 6
hl.bind(mainMod .. " + 7", hl.dsp.focus({ workspace = "7" })) -- Open workspace 7
hl.bind(mainMod .. " + 8", hl.dsp.focus({ workspace = "8" })) -- Open workspace 8
hl.bind(mainMod .. " + 9", hl.dsp.focus({ workspace = "9" })) -- Open workspace 9
hl.bind(mainMod .. " + 0", hl.dsp.focus({ workspace = "10" })) -- Open workspace 10
hl.bind(mainMod .. " + SHIFT + 1", hl.dsp.window.move({ workspace = "1" })) -- Move active window to workspace 1
hl.bind(mainMod .. " + SHIFT + 2", hl.dsp.window.move({ workspace = "2" })) -- Move active window to workspace 2
hl.bind(mainMod .. " + SHIFT + 3", hl.dsp.window.move({ workspace = "3" })) -- Move active window to workspace 3
hl.bind(mainMod .. " + SHIFT + 4", hl.dsp.window.move({ workspace = "4" })) -- Move active window to workspace 4
hl.bind(mainMod .. " + SHIFT + 5", hl.dsp.window.move({ workspace = "5" })) -- Move active window to workspace 5
hl.bind(mainMod .. " + SHIFT + 6", hl.dsp.window.move({ workspace = "6" })) -- Move active window to workspace 6
hl.bind(mainMod .. " + SHIFT + 7", hl.dsp.window.move({ workspace = "7" })) -- Move active window to workspace 7
hl.bind(mainMod .. " + SHIFT + 8", hl.dsp.window.move({ workspace = "8" })) -- Move active window to workspace 8
hl.bind(mainMod .. " + SHIFT + 9", hl.dsp.window.move({ workspace = "9" })) -- Move active window to workspace 9
hl.bind(mainMod .. " + SHIFT + 0", hl.dsp.window.move({ workspace = "10" })) -- Move active window to workspace 10
hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" })) -- Open next workspace
hl.bind(mainMod .. " + mouse_up", hl.dsp.focus({ workspace = "e-1" })) -- Open previous workspace
hl.bind(mainMod .. " + CTRL + down", hl.dsp.focus({ workspace = "empty" })) -- Open the next empty workspace

-- Example special workspace (scratchpad)
hl.bind(mainMod .. " + S", hl.dsp.workspace.toggle_special("magic"))
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.window.move({ workspace = "special:magic" }))

-- Move/resize windows with mainMod + LMB/RMB and dragging
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })


-- Fn keys
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl -q s +5%")) -- Increase brightness by 10%
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl -q s 5%-")) -- Reduce brightness by 10%
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("pactl set-sink-volume @DEFAULT_SINK@ +5%")) -- Increase volume by 5%
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("pactl set-sink-volume @DEFAULT_SINK@ -5%")) -- Reduce volume by 5%
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle")) -- Toggle mute
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause")) -- Audio play pause
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl pause")) -- Audio pause
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next")) -- Audio next
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous")) -- Audio previous
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("pactl set-source-mute @DEFAULT_SOURCE@ toggle")) -- Toggle microphone
-- hl.bind("XF86Lock", hl.dsp.exec_cmd("hyprlock")) -- Open screenlock
-- XF86Lock is not a recognized keysym; SUPER+L above remains the lock shortcut.
