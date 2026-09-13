import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.Common

// Map only once the snapshot is ready, or the capture deadline expires.
Item {
    id: root

    readonly property string overlayId: "launcher"
    property string monitor: ""

    property bool pendingOpen: false
    property bool opened: false
    property bool armed: false

    function open() {
        if (opened || pendingOpen)
            return;

        // A grant can arrive synchronously while the previous overlay closes.
        pendingOpen = true;
        if (OverlayController.request(overlayId))
            beginOpen();
    }

    function beginOpen() {
        if (opened)
            return;

        if (capture.busy) {
            pendingOpen = true;
            return;
        }

        pendingOpen = false;
        monitor = Hyprland.focusedMonitor?.name || Quickshell.screens[0]?.name || "";
        opened = true;

        if (!capture.start(monitor))
            arm();
    }

    // Idempotent: whichever of snapshotReady, capture failure or the watchdog
    // arrives first is the one that maps the window.
    function arm() {
        if (!opened || armed)
            return;

        armed = true;
        Qt.callLater(menu.focusSearch);
    }

    function close() {
        if (pendingOpen && !opened) {
            pendingOpen = false;
            OverlayController.cancel(overlayId);
            OverlayController.release(overlayId);
            return;
        }

        if (opened)
            menu.cancel();
    }

    function toggle() {
        if (opened || pendingOpen)
            close();
        else
            open();
    }

    function finish() {
        pendingOpen = false;
        opened = false;
        armed = false;
        menu.snapshot = "";
        capture.cancel();
        OverlayController.release(overlayId);
        Qt.callLater(menu.prepare);
    }

    function launch(entry) {
        if (!entry) {
            menu.launchFailed("No application to launch");
            return;
        }

        try {
            entry.execute();
            finish();
        } catch (error) {
            const name = entry.name || "application";
            const message = "Could not launch " + name;
            menu.launchFailed(message);
            console.warn(message, error);
        }
    }

    IpcHandler {
        target: "launcher"

        function open(): void {
            root.open();
        }

        function close(): void {
            root.close();
        }

        function toggle(): void {
            root.toggle();
        }
    }

    Connections {
        target: OverlayController

        function onCloseRequested(owner) {
            if (owner === root.overlayId)
                root.close();
        }

        function onGranted(owner) {
            if (owner === root.overlayId)
                root.beginOpen();
        }
    }

    DesktopCapture {
        id: capture

        prefix: "launcher"

        onCompleted: source => {
            // A capture that lands after arming has missed its slot; handing it
            // over now would pop the desktop in mid-animation.
            if (root.opened && !root.armed)
                menu.snapshot = source;
            else
                capture.release();
        }

        onFailed: {
            if (root.opened)
                root.arm();
        }

        onIdle: {
            if (root.pendingOpen && OverlayController.owner === root.overlayId)
                root.beginOpen();
        }
    }

    // Fall back without waiting indefinitely for the compositor's capture.
    Timer {
        interval: 250
        running: root.opened && !root.armed
        onTriggered: root.arm()
    }

    PanelWindow {
        visible: root.opened && root.armed
        screen: Quickshell.screens.find(screen => screen.name === root.monitor) || Quickshell.screens[0]
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell-launcher"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        Launcher {
            id: menu

            anchors.fill: parent
            presenting: root.armed
            onSnapshotReady: root.arm()
            onDismissed: root.finish()
            onLaunchRequested: entry => root.launch(entry)
        }
    }

    Component.onCompleted: menu.prepare()
    Component.onDestruction: {
        capture.cancel();
        OverlayController.release(overlayId);
    }
}
