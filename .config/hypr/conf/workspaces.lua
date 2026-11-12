-- Workspace placement saved by Quickshell Monitor Switch.
pcall(require, "conf.workspaces.current")

-- Rebind workspaces when the connected setup changes or saved rules are reloaded.
local function sync_monitor_workspaces()
    hl.exec_cmd("python3 ~/.config/scripts/hyprland/monitor_control.py sync-workspaces")
end

hl.on("hyprland.start", sync_monitor_workspaces)
hl.on("monitor.layout_changed", sync_monitor_workspaces)
