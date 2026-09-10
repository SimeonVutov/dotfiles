import QtQuick
import Quickshell

// Safe preview: selecting an application never executes it.
ShellRoot {
    FloatingWindow {
        implicitWidth: 1760
        implicitHeight: 1090
        Launcher {
            id: launcher
            anchors.fill: parent
            onDismissed: Qt.quit()
            onLaunchRequested: entry => console.log("Selected:", entry.name)
        }
        Timer {
            interval: 800
            running: Quickshell.env("LAUNCHER_QUERY") !== ""
            onTriggered: launcher.query = Quickshell.env("LAUNCHER_QUERY")
        }
        Timer {
            interval: parseInt(Quickshell.env("LAUNCHER_CAPTURE_DELAY") || "1400")
            running: Quickshell.env("LAUNCHER_CAPTURE") !== ""
            onTriggered: launcher.grabToImage(result => {
                result.saveToFile(Quickshell.env("LAUNCHER_CAPTURE"));
                Qt.quit();
            })
        }
    }
}
