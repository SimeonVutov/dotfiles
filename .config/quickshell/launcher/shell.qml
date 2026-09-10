import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

ShellRoot {
    PanelWindow {
        id: window
        onVisibleChanged: if (visible)
            Qt.callLater(launcher.focusSearch)
        screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) || Quickshell.screens[0]
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell-launcher"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        color: "transparent"
        Launcher {
            id: launcher
            anchors.fill: parent
            onDismissed: Qt.quit()
            onLaunchRequested: entry => {
                try {
                    entry.execute();
                    Qt.quit();
                } catch (error) {
                    launcher.launchError = "Could not launch " + entry.name;
                    console.warn(error);
                }
            }
        }
    }
}
