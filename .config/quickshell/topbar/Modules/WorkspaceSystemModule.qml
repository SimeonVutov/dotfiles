import QtQuick
import Quickshell.Hyprland
import qs.Common
import qs.Ui
import qs.Services
import qs.Ui.Workspaces

BarModule {
    id: root

    readonly property var monitor: screen ? Hyprland.monitorFor(screen) : null
    readonly property var activeWorkspace: monitor ? monitor.activeWorkspace : null
    property string registeredMonitor: ""

    function registerScene() {
        if (registeredMonitor)
            WorkspaceRocket.unregisterScene(registeredMonitor, orbit);

        registeredMonitor = monitor?.name || "";
        if (registeredMonitor && screen)
            WorkspaceRocket.registerScene(registeredMonitor, orbit, screen);
    }

    Component.onCompleted: registerScene()
    Component.onDestruction: {
        if (WorkspaceRocket)
            WorkspaceRocket.unregisterScene(registeredMonitor, orbit);
    }
    onMonitorChanged: Qt.callLater(registerScene)
    onActiveWorkspaceChanged: Qt.callLater(registerScene)

    Connections {
        target: root.screen
        function onGeometryChanged() {
            root.registerScene();
        }
    }

    Connections {
        target: orbit
        function onImplicitWidthChanged() {
            Qt.callLater(root.registerScene);
        }
    }

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
        id: orbit
        shipActive: !!root.monitor && WorkspaceRocket.monitorName === root.monitor.name && WorkspaceRocket.stage !== "transfer"
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
