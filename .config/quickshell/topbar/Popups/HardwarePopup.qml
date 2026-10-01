pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Ui
import qs.Services

PopupPanel {
    id: root

    panelWidth: 380
    animateHeight: true
    smoothAnchorMovement: true
    contentPadding: 14
    rowSpacing: 8
    overlayActive: powerMenu.expanded || coolingMenu.expanded
    onOverlayDismissed: {
        powerMenu.expanded = false;
        coolingMenu.expanded = false;
    }

    onOpenChanged: {
        if (open) {
            HardwareControls.refresh();
            PowerPresets.refresh();
        } else {
            powerMenu.expanded = false;
            coolingMenu.expanded = false;
        }
    }

    Row {
        Layout.fillWidth: true
        spacing: 12

        SelectMenu {
            id: powerMenu

            width: (parent.width - parent.spacing) / 2
            overlayParent: root.overlayItem
            title: "Power"
            currentLabel: PowerPresets.label
            currentIcon: PowerPresets.currentMode === "ultimate" ? Icons.rocket : Icons.balance
            selectedValue: PowerPresets.currentMode
            footerText: "Opens a terminal for authorization."
            options: [
                {
                    value: "balanced",
                    label: "Balanced",
                    icon: Icons.balance
                },
                {
                    value: "ultimate",
                    label: "Ultimate",
                    icon: Icons.rocket
                }
            ]
            onExpandedChanged: if (expanded)
                coolingMenu.expanded = false
            onSelected: value => {
                if (value !== PowerPresets.currentMode) {
                    HardwareControls.setPowerMode(value);
                    root.close();
                }
            }
        }

        SelectMenu {
            id: coolingMenu

            width: (parent.width - parent.spacing) / 2
            overlayParent: root.overlayItem
            title: "Cooling"
            currentLabel: HardwareControls.busy ? "Applying…" : (HardwareControls.profile || "Unavailable")
            currentIcon: HardwareControls.profile === "Performance" ? Icons.flame : HardwareControls.profile === "Quiet" ? Icons.leaf : Icons.balance
            selectedValue: HardwareControls.profile
            interactive: !HardwareControls.busy
            options: [
                {
                    value: "Quiet",
                    label: "Quiet",
                    icon: Icons.leaf
                },
                {
                    value: "Balanced",
                    label: "Balanced",
                    icon: Icons.balance
                },
                {
                    value: "Performance",
                    label: "Performance",
                    icon: Icons.flame
                }
            ]
            onExpandedChanged: if (expanded)
                powerMenu.expanded = false
            onSelected: value => {
                if (value !== HardwareControls.profile)
                    HardwareControls.setFanProfile(value);
            }
        }
    }

    Item {
        Layout.fillWidth: true
        Layout.preferredHeight: 6
    }

    PopupPanel.ErrorBanner {
        text: HardwareControls.error
    }

    Column {
        Layout.fillWidth: true
        spacing: 6

        ResourceGraph {
            width: parent.width
            metric: "cpu"
            icon: Icons.cpu
            label: "CPU"
            valueLabel: Math.round(SysMon.cpuUsage) + "%"
            accent: Theme.graphCpu
            consuming: root.open
        }

        ResourceGraph {
            width: parent.width
            metric: "memory"
            icon: Icons.memory
            label: "Memory"
            valueLabel: SysMon.memoryTotal > 0 ? SysMon.memoryUsed.toFixed(1) + " / " + SysMon.memoryTotal.toFixed(1) + " GiB" : "Unavailable"
            accent: Theme.graphMemory
            consuming: root.open
        }

        ResourceGraph {
            width: parent.width
            metric: "temperature"
            icon: Icons.temperature
            label: "Temperature"
            valueLabel: isFinite(SysMon.temperature) ? Math.round(SysMon.temperature) + "°C" : "Unavailable"
            accent: Theme.graphTemperature
            maximum: 110
            consuming: root.open
        }

        ResourceGraph {
            width: parent.width
            metric: "gpu"
            icon: Icons.gpu
            label: "GPU"
            valueLabel: isFinite(SysMon.gpuUsage) ? Math.round(SysMon.gpuUsage) + "%" : "Unavailable"
            accent: Theme.graphGpu
            consuming: root.open
        }
    }
}
