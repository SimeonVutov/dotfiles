import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    property string prefix: "overlay"
    property string directory: Quickshell.env("XDG_RUNTIME_DIR") || "/tmp"
    property real scale: 0
    property bool privateFile: false
    readonly property bool busy: capture.running || cancelling

    signal completed(string source)
    signal failed
    signal idle

    property bool cancelling: false
    property int requestId: 0
    property string path: ""

    function start(monitor) {
        if (busy || !directory)
            return false;

        release();
        requestId++;
        path = directory + "/quickshell-" + prefix + "-" + Quickshell.processId + "-" + Date.now() + "-" + requestId + ".ppm";
        const command = ["grim", "-t", "ppm"];
        if (scale > 0)
            command.push("-s", String(scale));
        if (monitor)
            command.push("-o", monitor);
        command.push(path);

        capture.command = privateFile ? ["sh", "-c", 'umask 077; exec "$@"', "quickshell-capture"].concat(command) : command;
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
