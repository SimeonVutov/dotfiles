import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import qs.Common
import qs.Ui
import "Layout.js" as DisplayLayout

ColumnLayout {
    id: root

    required property var controller
    property bool active: false
    readonly property var selected: controller.selectedMonitor
    readonly property var scaleFactors: DisplayLayout.scales(selected)
    readonly property var presets: [
        {
            id: "laptop",
            title: "Laptop"
        },
        {
            id: "external",
            title: "External"
        },
        {
            id: "extend",
            title: "Extend"
        },
        {
            id: "duplicate",
            title: "Duplicate"
        },
        {
            id: "custom",
            title: "Custom"
        }
    ]
    spacing: 22

    function syncFields() {
        if (!selected)
            return;
        resolution.currentIndex = resolution.model.indexOf(selected.width + "x" + selected.height);
        scale.currentIndex = scaleFactors.findIndex(f => Math.abs(f - selected.scale) < .001);
        refresh.text = String(selected.rate);
    }

    function apply() {
        if (refresh.activeFocus)
            controller.setRefresh(refresh.text);
        if (!controller.error)
            controller.apply();
    }

    onSelectedChanged: Qt.callLater(syncFields)

    RowLayout {
        Layout.fillWidth: true
        spacing: 6
        Repeater {
            model: root.presets
            ConnectionButton {
                required property var modelData
                Layout.fillWidth: true
                implicitHeight: 42
                text: modelData.title
                checked: root.controller.mode === modelData.id
                subtle: false
                visible: modelData.id !== "custom" || root.controller.monitors.length >= 3
                enabled: !root.controller.busy && (modelData.id === "laptop" ? root.controller.monitors.some(m => m.internal) : modelData.id === "external" ? root.controller.monitors.some(m => !m.internal) : root.controller.monitors.length > 0)
                onClicked: root.controller.chooseMode(modelData.id)
            }
        }
    }

    DisplayMap {
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.minimumHeight: 200
        controller: root.controller
        active: root.active
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 14

        Column {
            Layout.fillWidth: true
            Layout.preferredWidth: 120
            spacing: 5
            BarText {
                text: root.selected ? root.selected.internal ? "Laptop" : root.selected.name : ""
                font.pixelSize: Theme.fontSizeLarge
            }
            ConnectionButton {
                visible: root.controller.mode === "custom"
                text: root.selected?.enabled ? "Disable" : "Enable"
                subtle: true
                enabled: !!root.selected && !root.controller.busy && (!root.selected.enabled || root.controller.monitors.filter(m => m.enabled).length > 1)
                onClicked: root.controller.toggleDisplay(root.controller.selected)
            }
        }

        SettingsChoice {
            id: resolution
            Layout.preferredWidth: 170
            label: "Resolution"
            enabled: !!root.selected && !root.controller.busy
            model: DisplayLayout.resolutions(root.selected)
            onChosen: index => root.controller.chooseResolution(model[index])
        }

        ColumnLayout {
            Layout.preferredWidth: 140
            spacing: 8
            BarText {
                text: root.selected ? "Refresh · ≤" + DisplayLayout.maxRefresh(root.selected) + " Hz" : "Refresh · Hz"
                color: Theme.overlayMuted
                font.pixelSize: Theme.fontSizeCaption
            }
            TextField {
                id: refresh
                Layout.fillWidth: true
                implicitHeight: 38
                enabled: !!root.selected && !root.controller.busy
                selectByMouse: true
                color: acceptableInput ? Theme.overlayText : Theme.criticalBackground
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                inputMethodHints: Qt.ImhFormattedNumbersOnly
                validator: DoubleValidator {
                    bottom: 1
                    top: root.selected ? DisplayLayout.maxRefresh(root.selected) : 1
                    decimals: 5
                    notation: DoubleValidator.StandardNotation
                    locale: "C"
                }
                onEditingFinished: {
                    root.controller.setRefresh(text);
                    text = String(root.selected?.rate || "");
                }
                background: Rectangle {
                    radius: 9
                    color: Theme.overlaySurface
                    border.color: refresh.activeFocus ? Theme.overlayText : Theme.overlayBorder
                }
            }
        }

        SettingsChoice {
            id: scale
            Layout.preferredWidth: 110
            label: "Scale"
            enabled: !!root.selected && !root.controller.busy
            model: root.scaleFactors.map(f => Number(f.toFixed(5)) + "×")
            onChosen: index => root.controller.setScale(root.scaleFactors[index])
        }

        ConnectionButton {
            Layout.alignment: Qt.AlignBottom
            implicitHeight: 38
            text: "Apply"
            checked: true
            enabled: root.controller.dirty && !root.controller.busy && refresh.acceptableInput
            onClicked: root.apply()
        }
    }

    RowLayout {
        visible: !!root.controller.error
        Layout.fillWidth: true
        BarText {
            Layout.fillWidth: true
            text: root.controller.error
            color: Theme.criticalBackground
            font.pixelSize: Theme.fontSizeCaption
            wrapMode: Text.WordWrap
        }
        ConnectionButton {
            text: "Retry"
            enabled: !root.controller.busy
            onClicked: root.controller.refresh()
        }
    }
}
