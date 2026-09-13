import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.Common

Item {
    id: root

    readonly property string overlayId: "session-menu"
    property bool opened: false
    property bool pendingOpen: false
    property string monitor: ""

    function open() {
        if (opened || pendingOpen)
            return;

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
        menu.reset();
        menu.backdrop = "";
        opened = true;

        if (!capture.start(monitor))
            menu.arm();
    }

    function close() {
        if (pendingOpen && !opened) {
            pendingOpen = false;
            OverlayController.cancel(overlayId);
            OverlayController.release(overlayId);
            return;
        }

        if (!opened)
            return;

        if (menu.armed)
            menu.dismiss();
        else
            finish();
    }

    function finish() {
        pendingOpen = false;
        opened = false;
        menu.backdrop = "";
        capture.cancel();
        OverlayController.release(overlayId);
    }

    function toggle() {
        if (opened || pendingOpen)
            close();
        else
            open();
    }

    IpcHandler {
        target: "menu"

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

        prefix: "session-menu"
        onCompleted: source => {
            if (root.opened && !menu.armed)
                menu.backdrop = source;
            else
                capture.release();
        }
        onFailed: if (root.opened)
            menu.arm()
        onIdle: if (root.pendingOpen && OverlayController.owner === root.overlayId)
            root.beginOpen()
    }

    Connections {
        target: menu

        function onBackdropChanged() {
            if (!menu.backdrop)
                capture.release();
        }
    }

    // Fall back without waiting indefinitely for the compositor's capture.
    Timer {
        interval: 500
        running: root.opened && !menu.armed
        onTriggered: menu.arm()
    }

    Process {
        id: actionProcess

        onExited: (code, status) => {
            if (code === 0 && status === 0)
                root.finish();
            else
                menu.error = "Action failed. Try again or press Escape.";
        }
    }

    PanelWindow {
        visible: root.opened && menu.armed
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
            presenting: root.opened
            busy: actionProcess.running
            onDismissed: root.finish()
            onActionRequested: action => {
                if (action === "lock") {
                    root.finish();
                    Quickshell.execDetached(["hyprlock"]);
                    return;
                }

                const commands = {
                    exit: ["hyprctl", "dispatch", "exit"],
                    reboot: ["systemctl", "reboot"],
                    shutdown: ["systemctl", "poweroff"],
                    suspend: ["sh", "-c", "loginctl lock-session && systemctl suspend"],
                    hibernate: ["sh", "-c", "loginctl lock-session && systemctl hibernate"]
                };
                if (!commands[action])
                    return;

                actionProcess.command = commands[action];
                actionProcess.running = true;
            }
        }
    }

    Component.onDestruction: {
        capture.cancel();
        OverlayController.release(overlayId);
    }
}
