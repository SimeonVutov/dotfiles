import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: root

    property string monitor: ""
    property bool presenting: false
    property bool busy: false
    property alias armed: menu.armed
    property alias backdrop: menu.backdrop

    signal dismissed
    signal actionRequested(string action)

    function reset() {
        menu.reset();
    }

    function arm() {
        menu.arm();
    }

    function dismiss() {
        menu.dismiss();
    }

    function showError(message) {
        menu.error = message;
    }

    visible: root.presenting && root.armed
    screen: Quickshell.screens.find(screen => screen.name === root.monitor) || Quickshell.screens[0]
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-session-menu"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    OrbitMenu {
        id: menu

        anchors.fill: parent
        presenting: root.presenting
        busy: root.busy
        onDismissed: root.dismissed()
        onActionRequested: action => root.actionRequested(action)
    }
}
