pragma Singleton

import QtQuick
import Quickshell

Singleton {
    id: root

    readonly property string homeDir: Quickshell.env("HOME") || ""
    readonly property string configDir: Quickshell.env("XDG_CONFIG_HOME") || homeDir + "/.config"

    property var modulesLeft: ["clock", "media"]
    property var modulesCenter: ["workspaces"]
    property var modulesRight: ["hardware", "volume", "connections", "battery", "power"]

    readonly property var moduleFiles: ({
            clock: "ClockModule.qml",
            media: "MediaModule.qml",
            workspaces: "WorkspacesModule.qml",
            hardware: "HardwareModule.qml",
            volume: "VolumeModule.qml",
            connections: "ConnectionsModule.qml",
            battery: "BatteryModule.qml",
            power: "PowerModule.qml"
        })

    function moduleUrlFor(id) {
        const file = moduleFiles[id];
        if (!file) {
            console.warn("[topbar] unknown module id:", id);
            return "";
        }
        return Qt.resolvedUrl("../Modules/" + file);
    }

    // ── Module settings ────────────────────────────────────────
    readonly property var clock: ({
            format: "dd MMM, hh:mm AP",
            formatAlt: "ddd MMM dd, yyyy",
            openDashboardOnClick: true
        })

    // Session preferences shared by every monitor's hardware popup.
    property var hardwareGraphs: ({
            cpu: true,
            memory: true,
            temperature: true,
            gpu: true
        })

    function toggleHardwareGraph(metric) {
        const next = Object.assign({}, hardwareGraphs);
        next[metric] = !next[metric];
        hardwareGraphs = next;
    }

    readonly property var hardware: ({
            // Graphs temporarily raise the shared cadence while visible.
            tickInterval: 2000,
            graphInterval: 500,
            memoryEveryNTicks: 2,
            temperatureEveryNTicks: 3,
            gpuPath: "/sys/class/drm/card2/device/gpu_busy_percent",
            // 240 samples * 500ms keeps the same 2-minute window at 2x resolution.
            historySamples: 240,
            powerCommand: root.configDir + "/power-mode/power-mode",
            powerConfig: "/etc/auto-cpufreq.conf",
            powerPresets: {
                ultimate: root.configDir + "/power-mode/auto-cpufreq.ultimate.conf",
                balanced: root.configDir + "/power-mode/auto-cpufreq.balanced.conf"
            },
            thermalZone: "/sys/class/thermal/thermal_zone0/temp",
            onRightClick: ["kitty", "--class", "wm-floating", "--title", "all_is_kitty", "--hold", "--detach", "sh", "-c", "btop"]
        })

    readonly property var volume: ({
            // Scrolling over the output part changes the output, over the mic
            // part changes the mic. 1% per notch is what waybar defaulted to.
            scrollStep: 1,
            maxVolume: 100
        })

    readonly property var battery: ({
            warningThreshold: 30,
            criticalThreshold: 15
        })

    readonly property var power: ({
            onClick: [root.configDir + "/scripts/session-menu.sh"]
        })

    readonly property var workspaces: ({
            // Hyprland owns which workspaces exist per monitor (the monitor
            // switcher scripts keep those rules current), so the bar just
            // renders what the compositor reports for its own screen.
            scrollToSwitch: true
        })

    readonly property var media: ({
            textWidth: 250,
            animationStepDuration: 420,
            scrollPixelsPerSecond: 32,
            scrollStartPause: 1100,
            scrollEndPause: 700,
            separator: " - "
        })
}
