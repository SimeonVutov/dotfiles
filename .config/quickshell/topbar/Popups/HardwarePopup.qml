import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Ui
import qs.Services

PopupPanel {
    id: root
    panelWidth: 480
    contentPadding: 24
    rowSpacing: 16
    overlayActive: powerMenu.expanded || fanMenu.expanded
    onOverlayDismissed: {
        powerMenu.expanded = false;
        fanMenu.expanded = false;
    }
    onOpenChanged: {
        if (open) {
            HardwareControls.refresh();
            PowerPresets.refresh();
        } else {
            powerMenu.expanded = false;
            fanMenu.expanded = false;
        }
    }

    Item {
        Layout.fillWidth: true
        implicitHeight: 28
        BarText {
            text: "Resources"
            font.pixelSize: 20
            font.bold: true
        }
        BarText {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: "2 min history"
            color: Theme.popupSubtleText
            font.pixelSize: 11
        }
    }
    Row {
        Layout.fillWidth: true
        spacing: Theme.popupSpacing
        SelectMenu {
            id: powerMenu
            width: (parent.width - parent.spacing) / 2
            overlayParent: root.overlayItem
            title: "Power mode"
            footerText: "Opens a terminal for your password."
            currentLabel: PowerPresets.label
            selectedValue: PowerPresets.currentMode
            currentIcon: PowerPresets.currentMode === "ultimate" ? Icons.rocket : Icons.balance
            options: [
                {
                    value: "ultimate",
                    label: "Ultimate",
                    icon: Icons.rocket
                },
                {
                    value: "balanced",
                    label: "Balanced",
                    icon: Icons.balance
                }
            ]
            onExpandedChanged: if (expanded)
                fanMenu.expanded = false
            onSelected: value => {
                HardwareControls.setPowerMode(value);
                root.close();
            }
        }
        SelectMenu {
            id: fanMenu
            width: powerMenu.width
            overlayParent: root.overlayItem
            title: "Fan profile"
            currentLabel: HardwareControls.profile || "Select profile"
            currentIcon: HardwareControls.profile === "Quiet" ? Icons.leaf : HardwareControls.profile === "Performance" ? Icons.flame : Icons.balance
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
            onSelected: value => HardwareControls.setFanProfile(value)
        }
    }
    BarText {
        Layout.fillWidth: true
        visible: text !== ""
        text: HardwareControls.error
        color: Theme.graphTemperature
        font.pixelSize: 12
        wrapMode: Text.WordWrap
    }
    ResourceGraph {
        Layout.fillWidth: true
        metric: "cpu"
        label: "CPU"
        valueLabel: Math.round(SysMon.cpuUsage) + "%"
        accent: Theme.graphCpu
        consuming: root.open
    }
    ResourceGraph {
        Layout.fillWidth: true
        metric: "memory"
        label: "Memory"
        valueLabel: SysMon.memoryUsed.toFixed(1) + " / " + SysMon.memoryTotal.toFixed(1) + " GiB"
        accent: Theme.graphMemory
        consuming: root.open
    }
    ResourceGraph {
        Layout.fillWidth: true
        metric: "temperature"
        label: "Temperature"
        valueLabel: isFinite(SysMon.temperature) ? Math.round(SysMon.temperature) + "°C" : "Unavailable"
        accent: Theme.graphTemperature
        maximum: 110
        consuming: root.open
    }
    ResourceGraph {
        Layout.fillWidth: true
        metric: "gpu"
        label: "GPU"
        valueLabel: isFinite(SysMon.gpuUsage) ? Math.round(SysMon.gpuUsage) + "%" : "Unavailable"
        accent: Theme.graphGpu
        consuming: root.open
    }
}
