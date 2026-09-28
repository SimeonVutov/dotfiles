pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.Common
import qs.Ui
import qs.Services
import qs.Popups

// CPU, memory and temperature share one sampler.
BarModule {
    id: root

    moduleViewId: "hardware"
    readonly property var selectedMetrics: ModuleViewState.selection("hardware")
    readonly property var displayedMetrics: selectedMetrics.filter(metric => !autoHiddenItems.includes(metric))
    preferredWidth: measureRow.implicitWidth + pill.paddingH * 2

    function widthForCompression(state) {
        const remaining = selectedMetrics.filter(metric => !state.hide.includes(metric));
        if (remaining.length === 0)
            return preferredWidth;
        return pill.paddingH * 2 + remaining.reduce((width, metric) => width + (measureRow.itemWidths[metric] || 0), 0);
    }

    function metricText(metric) {
        if (metric === "usage")
            return Icons.cpu + "   " + Math.round(SysMon.cpuUsage) + "%";
        if (metric === "memory")
            return Icons.memory + "   " + SysMon.memoryUsed.toFixed(2) + "GB";
        return Icons.temperature + "   " + (isFinite(SysMon.temperature) ? Math.round(SysMon.temperature) + "°C" : "—");
    }

    // The sampler only runs while at least one of these is on screen.
    Subscriber {
        active: root.visible
        metrics: root.displayedMetrics.map(metric => metric === "usage" ? "cpu" : metric)
        onToggled: (enabled, metrics) => SysMon.subscribe(enabled, metrics)
    }

    Pill {
        id: pill
        animateWidth: false

        // Each reading carries its own 5px side padding, which is what puts
        // 10px between them and 5px inside the pill's edges.
        Row {
            id: readings
            spacing: 0

            Repeater {
                model: Config.moduleViews.hardware.items

                BarText {
                    id: reading
                    required property var modelData
                    leftPadding: Theme.groupItemPaddingH
                    rightPadding: Theme.groupItemPaddingH
                    font.pixelSize: Theme.fontSizeSmall
                    readonly property string metric: modelData.value
                    readonly property bool selected: root.displayedMetrics.includes(metric)
                    text: selected ? root.metricText(metric) : ""
                    clip: true
                    width: selected ? implicitWidth : 0
                    visible: width > 0

                    Behavior on width {
                        NumberAnimation {
                            duration: Theme.durationNormal
                            easing.type: Theme.easingEmphasized
                        }
                    }
                }
            }
        }
    }

    Row {
        id: measureRow
        visible: false
        width: 0
        height: 0
        spacing: 0
        readonly property var itemWidths: {
            const widths = {};
            for (let i = 0; i < measureRepeater.count; i++) {
                const item = measureRepeater.itemAt(i);
                if (item)
                    widths[item.modelData] = item.implicitWidth;
            }
            return widths;
        }

        Repeater {
            id: measureRepeater
            model: root.selectedMetrics
            BarText {
                required property var modelData
                leftPadding: Theme.groupItemPaddingH
                rightPadding: Theme.groupItemPaddingH
                font.pixelSize: Theme.fontSizeSmall
                text: root.metricText(modelData)
            }
        }
    }

    PopupHost {
        id: hardwarePopup
        popup: Component {
            HardwarePopup {
                anchorItem: pill
            }
        }
    }

    MouseArea {
        anchors.fill: pill
        acceptedButtons: Qt.LeftButton
        cursorShape: Qt.PointingHandCursor
        onClicked: hardwarePopup.toggle()
    }

    TapHandler {
        acceptedButtons: Qt.MiddleButton
        onTapped: Quickshell.execDetached(Config.hardware.onRightClick)
    }
}
