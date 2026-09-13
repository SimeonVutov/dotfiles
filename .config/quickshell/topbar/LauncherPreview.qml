import QtQuick
import Quickshell
import qs.Launcher

// Safe preview: selecting an application never executes it.
ShellRoot {
    FloatingWindow {
        implicitWidth: 1280
        implicitHeight: 900
        Launcher {
            id: launcher
            snapshot: Quickshell.env("LAUNCHER_BACKDROP")
            anchors.fill: parent
            onDismissed: Qt.quit()
            onLaunchRequested: entry => console.log("Selected:", entry.name)
        }
        Timer {
            interval: 800
            running: !!Quickshell.env("LAUNCHER_QUERY")
            onTriggered: launcher.query = Quickshell.env("LAUNCHER_QUERY")
        }
        Timer {
            interval: parseInt(Quickshell.env("LAUNCHER_CAPTURE_DELAY") || "1800")
            running: !!Quickshell.env("LAUNCHER_CAPTURE")
            onTriggered: launcher.grabToImage(result => {
                result.saveToFile(Quickshell.env("LAUNCHER_CAPTURE"));
                Qt.quit();
            })
        }
    }
}
