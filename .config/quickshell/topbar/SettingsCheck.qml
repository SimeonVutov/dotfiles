import QtQuick
import Quickshell
import qs.Ui
import qs.Settings.MonitorSwitch

ShellRoot {
    FloatingWindow {
        id: window
        implicitWidth: 1200
        implicitHeight: 850

        MonitorService {
            id: controller
            monitors: [
                {
                    name: "eDP-1",
                    internal: true,
                    enabled: true,
                    width: 1920,
                    height: 1200,
                    rate: 60,
                    scale: 1,
                    transform: 0,
                    x: 0,
                    y: 0,
                    modes: ["1920x1200@60", "1920x1200@120", "2560x1440@120"],
                    mirror: "none"
                },
                {
                    name: "DP-1",
                    internal: false,
                    enabled: true,
                    width: 2560,
                    height: 1440,
                    rate: 144,
                    scale: 1,
                    transform: 0,
                    x: 1920,
                    y: 0,
                    modes: ["2560x1440@144", "1920x1080@60"],
                    mirror: "none"
                },
                {
                    name: "HDMI-A-1",
                    internal: false,
                    enabled: true,
                    width: 1920,
                    height: 1080,
                    rate: 60,
                    scale: 1,
                    transform: 0,
                    x: 4480,
                    y: 0,
                    modes: ["1920x1080@60"],
                    mirror: "none"
                }
            ]
            selected: "eDP-1"
        }

        QuickSettingsPanel {
            id: panel
            anchors.fill: parent
            title: "Monitor Switch"
            MonitorSwitch {
                anchors.fill: parent
                controller: controller
                active: panel.presenting
            }
        }

        ConfirmDialog {
            id: confirm
            anchors.fill: parent
            title: "Keep this display arrangement?"
            seconds: 9
            total: 15
            property int kept: 0
            property int reverted: 0
            onAccepted: kept++
            onRejected: reverted++
        }

        Timer {
            interval: 100
            running: true
            onTriggered: panel.presenting = true
        }

        Timer {
            interval: 850
            running: true
            onTriggered: {
                if (panel.reveal !== 1)
                    throw new Error("Panel entrance did not settle");
                controller.chooseMode("laptop");
                if (controller.monitors.filter(m => m.enabled).length !== 1)
                    throw new Error("Laptop mode did not disable external displays");
                controller.chooseMode("external");
                if (controller.monitors[0].enabled || controller.monitors.filter(m => m.enabled).length !== 2)
                    throw new Error("External mode did not activate both external displays");
                controller.chooseMode("duplicate");
            }
        }

        Timer {
            interval: 1000
            running: true
            onTriggered: {
                controller.chooseMode("custom");
                controller.toggleDisplay("DP-1");
                controller.toggleDisplay("HDMI-A-1");
                controller.toggleDisplay("eDP-1");
                if (!controller.monitors[0].enabled)
                    throw new Error("Custom mode disabled the final display");
                controller.chooseMode("extend");
                controller.move("DP-1", -2560, 0);
                controller.setMode("2560x1440", "100", "1");
                if (controller.selectedMonitor.rate !== 100)
                    throw new Error("Custom refresh rate did not update");

                const before = JSON.stringify(controller.monitors.map(m => [m.name, m.x, m.y]));
                controller.monitors = controller.monitors.slice();
                if (JSON.stringify(controller.monitors.map(m => [m.name, m.x, m.y])) !== before)
                    throw new Error("A settled arrangement was rewritten");

                const at = name => controller.monitors.find(m => m.name === name);
                controller.move("DP-1", at("eDP-1").x - 2560, at("eDP-1").y + 24, 200);
                if (at("DP-1").y !== at("eDP-1").y)
                    throw new Error("Near-level displays did not snap flush");
                controller.move("DP-1", at("eDP-1").x - 2560, at("eDP-1").y + 24, 0);
                if (at("DP-1").y === at("eDP-1").y)
                    throw new Error("Precise placement was overridden by snapping");

                confirm.open = true;
                panel.presenting = false;
            }
        }

        Timer {
            interval: 1400
            running: true
            onTriggered: {
                if (panel.reveal !== 0)
                    throw new Error("Panel exit did not settle");
                if (confirm.opacity !== 1)
                    throw new Error("Confirmation did not present");
                confirm.accepted();
                confirm.rejected();
                if (confirm.kept !== 1 || confirm.reverted !== 1)
                    throw new Error("Confirmation did not report both answers");
                console.log("PASS settings panel, display modes, custom toggle guard, edge snapping, precise placement and confirmation");
                Qt.quit();
            }
        }
    }
}
