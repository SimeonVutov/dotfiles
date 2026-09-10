pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic
import Quickshell
import qs.Common
import qs.Services

AdaptiveHeightItem {
    id: root

    property string mode: "output"
    signal profilesRequested(var device)
    readonly property var devices: mode === "output" ? AudioDevices.outputs : AudioDevices.inputs
    readonly property var selectedDevice: mode === "output" ? AudioDevices.defaultOutput : AudioDevices.defaultInput
    readonly property int desiredHeight: list.count > 0 ? Math.min(196, list.count * 56 + Math.max(0, list.count - 1) * list.spacing) : 56

    targetHeight: desiredHeight

    ScriptModel {
        id: deviceModel
        comparisonMode: ObjectComparison.Identity
        values: root.devices
    }

    ListView {
        id: list
        anchors.fill: parent
        clip: true
        spacing: 6
        model: deviceModel
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollBar {}

        delegate: AudioChoiceRow {
            required property var modelData

            width: list.width
            implicitHeight: 56
            title: AudioDevices.labelFor(modelData)
            subtitle: {
                const audio = modelData.audio;
                const volume = audio ? Math.round(audio.volume * 100) + "%" : "Volume unavailable";
                const muted = audio && audio.muted ? " · Muted" : "";
                return (selected ? "Selected · " : "") + volume + muted;
            }
            selected: root.selectedDevice === modelData
            showDetails: true
            detailsEnabled: !!AudioDevices.cardFor(modelData) && !AudioDevices.profileBusy
            onChosen: AudioDevices.selectNode(modelData, root.mode)
            onDetailsRequested: root.profilesRequested(modelData)
        }
    }

    BarText {
        anchors.centerIn: parent
        width: parent.width - 32
        visible: list.count === 0
        text: "No " + (root.mode === "output" ? "output" : "input") + " devices available."
        color: Theme.popupSubtleText
        horizontalAlignment: Text.AlignHCenter
        font.pixelSize: 13
    }
}
