pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
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
        opened = true;
        menuLoader.item.reset();
        menuLoader.item.backdrop = "";

        if (!capture.start(monitor))
            menuLoader.item.arm();
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

        if (menuLoader.item && menuLoader.item.armed)
            menuLoader.item.dismiss();
        else
            finish();
    }

    function finish() {
        pendingOpen = false;
        if (menuLoader.item)
            menuLoader.item.backdrop = "";
        opened = false;
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
            if (root.opened && menuLoader.item && !menuLoader.item.armed)
                menuLoader.item.backdrop = source;
            else
                capture.release();
        }
        onFailed: if (root.opened)
            menuLoader.item.arm()
        onIdle: if (root.pendingOpen && OverlayController.owner === root.overlayId)
            root.beginOpen()
    }

    Connections {
        target: menuLoader.item

        function onBackdropChanged() {
            if (!target.backdrop)
                capture.release();
        }
    }

    // Fall back without waiting indefinitely for the compositor's capture.
    Timer {
        interval: 500
        running: root.opened && menuLoader.item && !menuLoader.item.armed
        onTriggered: menuLoader.item.arm()
    }

    Process {
        id: actionProcess

        onExited: (code, status) => {
            if (code === 0 && status === 0)
                root.finish();
            else
                menuLoader.item.showError("Action failed. Try again or press Escape.");
        }
    }

    LazyLoader {
        id: menuLoader
        active: root.opened

        SessionMenuView {
            monitor: root.monitor
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
