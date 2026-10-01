pragma ComponentBehavior: Bound

import QtQuick
import qs.Ui
import Quickshell
import qs.Common
import qs.Services

DeviceListView {
    id: root

    property string mode: "output"
    signal profilesRequested(var device)

    readonly property var devices: mode === "output" ? AudioDevices.outputs : AudioDevices.inputs
    readonly property var selectedDevice: mode === "output" ? AudioDevices.defaultOutput : AudioDevices.defaultInput

    rowHeight: 56
    minimumHeight: 56
    spacing: 6
    emptyText: "No " + (root.mode === "output" ? "output" : "input") + " devices available."
    emptyWrapMode: Text.NoWrap

    ScriptModel {
        id: deviceModel
        comparisonMode: ObjectComparison.Identity
        values: root.devices
    }

    model: deviceModel
    delegate: AudioChoiceRow {
        required property var modelData

        width: ListView.view.width
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
