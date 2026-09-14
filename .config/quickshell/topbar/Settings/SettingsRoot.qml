import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.Common
import qs.Ui
import "MonitorSwitch" as Displays

Item {
    id: root

    readonly property string overlayId: "settings"
    property bool opened: false
    property bool pendingOpen: false
    property bool presenting: false
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
        pendingOpen = false;
        monitor = Hyprland.focusedMonitor?.name || Quickshell.screens[0]?.name || "";
        opened = true;
        presenting = true;
    }

    function close() {
        pendingOpen = false;
        OverlayController.cancel(overlayId);
        displays.revert();
        presenting = false;
        if (!opened)
            OverlayController.release(overlayId);
    }

    IpcHandler {
        target: "settings"
        function open(menu: string): void {
            if (menu === "monitors")
                root.open();
        }
        function toggle(menu: string): void {
            if (menu === "monitors") {
                if (root.opened || root.pendingOpen)
                    root.close();
                else
                    root.open();
            }
        }
        function close(): void {
            root.close();
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

    Displays.MonitorService {
        id: displays
        active: root.presenting
    }

    PanelWindow {
        visible: root.opened
        // Stay on the screen the panel was opened on. It only moves when that
        // screen is the one being switched off, or the confirmation would
        // appear on a display the user is not looking at.
        screen: {
            const screens = Quickshell.screens;
            const current = screens.find(s => s.name === root.monitor);
            const losingCurrent = displays.applying && displays.monitors.some(m => m.name === root.monitor && !m.enabled);
            if (current && !losingCurrent)
                return current;
            const active = displays.monitors.filter(m => m.enabled);
            const targets = displays.mode === "duplicate" ? active.slice(0, 1) : active;
            return screens.find(s => targets.some(m => m.name === s.name)) || current || screens[0];
        }
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell-settings"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        QuickSettingsPanel {
            anchors.fill: parent
            title: "Monitor Switch"
            presenting: root.presenting
            onCloseRequested: if (!displays.previewing)
                root.close()
            onClosed: {
                root.opened = false;
                OverlayController.release(root.overlayId);
            }

            Displays.MonitorSwitch {
                anchors.fill: parent
                controller: displays
                active: root.presenting
            }
        }

        ConfirmDialog {
            anchors.fill: parent
            open: displays.previewing
            title: "Keep this display arrangement?"
            message: "The previous setup is restored on its own if you do nothing."
            acceptText: "Keep"
            rejectText: "Revert"
            seconds: displays.secondsLeft
            total: displays.previewSeconds
            onAccepted: displays.keep()
            onRejected: displays.revert()
        }
    }

    Component.onDestruction: {
        OverlayController.cancel(overlayId);
        OverlayController.release(overlayId);
    }
}
