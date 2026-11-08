import QtQuick
import Quickshell.Hyprland
import qs.Common
import qs.Ui
import qs.Ui.Workspaces

BarModule {
    id: root

    readonly property var monitor: screen ? Hyprland.monitorFor(screen) : null
    readonly property var activeWorkspace: monitor ? monitor.activeWorkspace : null
    readonly property var workspaceSnapshot: {
        const values = Hyprland.workspaces.values.filter(workspace =>
            workspace && workspace.id > 0 && workspace.monitor === root.monitor);
        const active = root.activeWorkspace;
        if (active && active.id > 0 && active.monitor === root.monitor
                && !values.some(workspace => workspace.id === active.id))
            values.push(active);
        return values.map(workspace => ({ id: workspace.id, name: workspace.name }))
            .sort((a, b) => a.id - b.id);
    }

    OrbitScene {
        workspaceMonitor: root.monitor
        workspaces: root.workspaceSnapshot
        activeId: root.activeWorkspace && root.activeWorkspace.monitor === root.monitor
            ? root.activeWorkspace.id : -1
        scrollEnabled: Config.workspaces.scrollToSwitch
        onWorkspaceRequested: id => {
            const workspace = Hyprland.workspaces.values.find(workspace => workspace.id === id);
            if (workspace)
                Hyprland.dispatch('hl.dsp.focus({ workspace = "' + workspace.id + '" })');
        }
        onWheelRequested: direction => Hyprland.dispatch('hl.dsp.focus({ workspace = "' + (direction < 0 ? "r-1" : "r+1") + '" })')
    }
}
