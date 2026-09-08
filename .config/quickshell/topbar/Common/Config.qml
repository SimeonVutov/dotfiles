pragma Singleton

import QtQuick
import Quickshell

// The bar's layout and per-module settings.
//
// To add, remove or reorder a module, edit the three arrays below — nothing
// else needs to change. Each string is a module id registered in Registry.qml.
// These are plain (non-readonly) properties so a future drag-and-drop editor
// can reassign them at runtime and the bar will rebuild itself.
Singleton {
    id: root

    property var modulesLeft: ["clock", "media"]
    property var modulesCenter: ["workspaces"]
    property var modulesRight: ["hardware", "volume", "connections", "battery", "power"]

    // ── Module settings ────────────────────────────────────────
    readonly property var clock: ({
            format: "dd MMM, hh:mm AP",       // 08 Sep, 09:30 PM
            formatAlt: "ddd MMM dd, yyyy",    // Mon Sep 08, 2026
            openDashboardOnClick: true
        })

    readonly property var hardware: ({
            // One shared tick drives cpu/memory/temperature so the bar wakes
            // the CPU once every 2s instead of three times on three timers.
            tickInterval: 2000,
            memoryEveryNTicks: 2,             // ~4s, matched the old waybar interval
            temperatureEveryNTicks: 3,        // ~6s
            thermalZone: "/sys/class/thermal/thermal_zone0/temp",
            onRightClick: ["kitty", "--class", "wm-floating", "--title", "all_is_kitty", "--hold", "--detach", "sh", "-c", "btop"]
        })

    readonly property var volume: ({
            onClick: ["kitty", "--title", "pulsemixer", "-e", "pulsemixer"],
            // Scrolling over the output part changes the output, over the mic
            // part changes the mic. 1% per notch is what waybar defaulted to.
            scrollStep: 1,
            maxVolume: 100
        })

    readonly property var network: ({
            onClick: ["kitty", "--single-instance", "--title", "wifi-tui", "-e", "impala"]
        })

    readonly property var bluetooth: ({
            onClick: ["kitty", "--single-instance", "--title", "bluetooth-tui", "-e", "bluetui"]
        })

    readonly property var battery: ({
            warningThreshold: 30,
            criticalThreshold: 15
        })

    readonly property var power: ({
            onClick: ["wlogout"]
        })

    readonly property var workspaces: ({
            // Hyprland owns which workspaces exist per monitor (the monitor
            // switcher scripts keep those rules current), so the bar just
            // renders what the compositor reports for its own screen.
            scrollToSwitch: true
        })

    readonly property var media: ({
            textWidth: 250,                   // ≈ the 30 characters waybar reserved
            separator: " - "
        })
}
