import QtQuick
import Quickshell

// Harmless harness: no session action can run from here.
// SESSION_MENU_BACKDROP  path/URL of a stand-in desktop for the vortex
// SESSION_MENU_FREEZE    hold the reveal at this 0..1 phase instead of playing
// SESSION_MENU_CAPTURE   write one frame here and quit
ShellRoot {
    FloatingWindow {
        implicitWidth: 800
        implicitHeight: 740
        color: "#111111"
        // Set once rather than bound: a frozen phase must not fight the animation.
        Component.onCompleted: if (!preview.presenting) {
            preview.armed = true;
            preview.arrival = parseFloat(Quickshell.env("SESSION_MENU_FREEZE"));
        }
        OrbitMenu {
            id: preview
            anchors.fill: parent
            backdrop: Quickshell.env("SESSION_MENU_BACKDROP")
            presenting: Quickshell.env("SESSION_MENU_FREEZE") === ""
            onDismissed: Qt.quit()
            onActionRequested: action => {
                error = "Preview: " + action;
                pending = "";
            }
        }
        Timer {
            interval: parseInt(Quickshell.env("SESSION_MENU_CAPTURE_DELAY") || "1600")
            running: Quickshell.env("SESSION_MENU_CAPTURE") !== ""
            onTriggered: preview.grabToImage(result => {
                result.saveToFile(Quickshell.env("SESSION_MENU_CAPTURE"));
                Qt.quit();
            })
        }
    }
}
