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
    // Only the modes this machine can actually reach are offered, so the row
    // never carries a control that does nothing.
    readonly property var presets: [
        {
            value: "laptop",
            label: "Laptop",
            available: controller.monitors.some(m => m.internal)
        },
        {
            value: "external",
            label: "External",
            available: controller.monitors.some(m => !m.internal)
        },
        {
            value: "extend",
            label: "Extend",
            available: controller.monitors.length > 1
        },
        {
            value: "duplicate",
            label: "Duplicate",
            available: controller.monitors.length > 1
        },
        {
            value: "custom",
            label: "Custom",
            available: controller.monitors.length > 2
        }
    ].filter(preset => preset.available)
    spacing: 20

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

    TabSwitcher {
        Layout.fillWidth: true
        implicitHeight: 42
        enabled: !root.controller.busy
        tabs: root.presets
        currentTab: root.controller.mode
        onSelected: mode => root.controller.chooseMode(mode)
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

        ColumnLayout {
            Layout.fillWidth: true
            Layout.preferredWidth: 150
            spacing: 8

            BarText {
                text: "Display"
                color: Theme.popupSubtleText
                font.pixelSize: Theme.fontSizeCaption
            }

            RowLayout {
                Layout.preferredHeight: 38
                spacing: 10

                BarText {
                    Layout.fillWidth: true
                    text: root.selected ? root.selected.internal ? "Laptop" : root.selected.name : ""
                    color: Theme.popupText
                    font.pixelSize: Theme.fontSizeLarge
                    elide: Text.ElideRight
                }

                ConnectionButton {
                    implicitHeight: 30
                    visible: root.controller.mode === "custom"
                    text: root.selected?.enabled ? "Disable" : "Enable"
                    enabled: !!root.selected && !root.controller.busy && (!root.selected.enabled || root.controller.monitors.filter(m => m.enabled).length > 1)
                    onClicked: root.controller.toggleDisplay(root.controller.selected)
                }
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
                color: Theme.popupSubtleText
                font.pixelSize: Theme.fontSizeCaption
            }
            TextField {
                id: refresh
                Layout.fillWidth: true
                implicitHeight: 38
                enabled: !!root.selected && !root.controller.busy
                selectByMouse: true
                color: acceptableInput ? Theme.popupText : Theme.criticalBackground
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
                    color: Theme.popupSurface
                    border.color: refresh.activeFocus ? Theme.popupText : Theme.popupBorder
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
