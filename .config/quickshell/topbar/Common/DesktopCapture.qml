import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    property string prefix: "overlay"
    readonly property bool busy: capture.running || cancelling

    signal completed(string source)
    signal failed
    signal idle

    property bool cancelling: false
    property int requestId: 0
    property string path: ""

    function start(monitor) {
        if (busy)
            return false;

        release();
        requestId++;
        path = (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/quickshell-" + prefix + "-" + Date.now() + "-" + requestId + ".ppm";
        capture.command = monitor ? ["grim", "-t", "ppm", "-o", monitor, path] : ["grim", "-t", "ppm", path];
        cancelling = false;
        capture.running = true;
        return true;
    }

    function cancel() {
        if (!capture.running) {
            release();
            return;
        }

        cancelling = true;
        capture.running = false;
    }

    function release() {
        if (!path)
            return;

        Quickshell.execDetached(["rm", "-f", "--", path]);
        path = "";
    }

    Process {
        id: capture

        onExited: (code, status) => {
            if (root.cancelling) {
                root.cancelling = false;
                root.release();
                root.idle();
                return;
            }

            if (code === 0 && status === 0 && root.path)
                root.completed("file://" + root.path);
            else {
                root.release();
                root.failed();
            }

            root.idle();
        }
    }

    Component.onDestruction: root.cancel()
}
