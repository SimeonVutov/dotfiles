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
        if (active && active.id > 0 && !values.some(workspace => workspace.id === active.id))
            values.push(active);
        return values.map(workspace => ({ id: workspace.id, name: workspace.name }))
            .sort((a, b) => a.id - b.id);
    }

    OrbitScene {
        workspaces: root.workspaceSnapshot
        activeId: root.activeWorkspace ? root.activeWorkspace.id : -1
        onWorkspaceRequested: id => {
            const workspace = Hyprland.workspaces.values.find(workspace => workspace.id === id);
            if (workspace)
                workspace.activate();
        }
        onWheelRequested: direction => {
            if (Config.workspaces.scrollToSwitch)
                Hyprland.dispatch(direction < 0 ? "workspace r-1" : "workspace r+1");
        }
    }
}
