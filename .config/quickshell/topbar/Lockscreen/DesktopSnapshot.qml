import QtQuick
import Quickshell

Item {
    id: root

    property bool requested: false
    property bool ready: false
    property string source: ""
    property var monitors: []
    property var pending: []
    property real scale: 1

    function start() {
        release();
        monitors = Quickshell.screens.map(screen => ({
                    name: screen.name,
                    x: screen.x,
                    y: screen.y,
                    width: screen.width,
                    height: screen.height,
                    scale: screen.devicePixelRatio
                }));
        pending = monitors.map(screen => screen.name);
        scale = Math.max(1, ...monitors.map(screen => screen.scale || 1));
        requested = true;

        if (!monitors.length || !capture.start(""))
            complete();
    }

    function complete() {
        if (requested)
            ready = true;
    }

    function contains(screen) {
        return monitors.some(monitor => monitor.name === screen?.name);
    }

    function rectangle(screen) {
        const monitor = monitors.find(monitor => monitor.name === screen?.name);
        if (!monitor)
            return Qt.rect(0, 0, 0, 0);

        const left = Math.min(...monitors.map(monitor => monitor.x));
        const top = Math.min(...monitors.map(monitor => monitor.y));
        return Qt.rect((monitor.x - left) * scale, (monitor.y - top) * scale, monitor.width * scale, monitor.height * scale);
    }

    function finished(screen) {
        pending = pending.filter(name => name !== screen?.name);
        if (!pending.length)
            release();
    }

    function release() {
        requested = false;
        ready = false;
        source = "";
        monitors = [];
        pending = [];
        capture.cancel();
    }

    DesktopCapture {
        id: capture

        prefix: "lockscreen"
        directory: Quickshell.env("XDG_RUNTIME_DIR") || ""
        scale: root.scale
        privateFile: true

        onCompleted: source => {
            if (root.requested && !root.ready)
                root.source = source;
            else
                capture.release();
        }
        onFailed: root.complete()
    }

    Image {
        source: root.source
        visible: false
        cache: false
        asynchronous: false

        onStatusChanged: {
            if (status === Image.Ready)
                root.complete();
            else if (status === Image.Error) {
                root.source = "";
                root.complete();
            }
        }
    }

    Timer {
        interval: 300
        running: root.requested && !root.ready
        onTriggered: {
            capture.cancel();
            root.complete();
        }
    }

    Component.onDestruction: release()
}
