pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Services.Pipewire
import qs.Common
import qs.Ui
import qs.Popups

// Scrolling adjusts the output or input under the pointer; clicking opens its panel.
BarModule {
    id: root

    moduleViewId: "volume"
    readonly property var selectedViews: ModuleViewState.selection("volume")
    readonly property bool outputSelected: selectedViews.includes("output")
    readonly property bool inputSelected: ModuleViewState.enabled("volume", "input")
    readonly property bool showOutput: outputSelected && !autoHiddenItems.includes("output")
    readonly property bool showInput: inputSelected && !autoHiddenItems.includes("input")
    preferredWidth: pill.paddingH * 2 + (outputSelected ? outputSection.implicitWidth : 0) + (inputSelected ? inputSection.implicitWidth : 0) + (outputSelected && inputSelected ? 9 : 0)

    function widthForCompression(state) {
        const output = outputSelected && !state.hide.includes("output");
        const input = inputSelected && !state.hide.includes("input");
        if (!output && !input)
            return preferredWidth;
        return pill.paddingH * 2 + (output ? outputSection.implicitWidth : 0) + (input ? inputSection.implicitWidth : 0) + (output && input ? 9 : 0);
    }

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource

    readonly property bool sinkReady: outputSelected && !!sink && !!sink.audio
    readonly property int sinkVolume: sinkReady ? Math.round(sink.audio.volume * 100) : 0
    readonly property bool sinkMuted: sinkReady && sink.audio.muted
    readonly property bool sinkIsBluetooth: !!sink && (sink.name || "").indexOf("bluez") !== -1

    readonly property bool sourceReady: inputSelected && !!source && !!source.audio
    readonly property int sourceVolume: sourceReady ? Math.round(source.audio.volume * 100) : 0
    readonly property bool sourceMuted: sourceReady && source.audio.muted

    // Binding these keeps their `audio` interfaces populated.
    PwObjectTracker {
        objects: [
            ...(root.outputSelected || audioPopup.loaded ? [root.sink] : []),
            ...(root.inputSelected || audioPopup.loaded ? [root.source] : [])
        ]
    }

    readonly property string volumeIcon: {
        if (sinkIsBluetooth)
            return Icons.headphone;
        const levels = Icons.volumeLevels;
        const index = Math.max(0, Math.min(levels.length - 1, Math.floor(sinkVolume / 100 * levels.length)));
        return levels[index];
    }

    function adjust(node, notches, maximum) {
        if (!node || !node.audio || notches === 0)
            return;
        const current = Math.round(node.audio.volume * 100);
        const next = current + notches * Config.volume.scrollStep;
        node.audio.volume = Math.max(0, Math.min(maximum, next)) / 100;
    }

    // Mouse wheels report in 120ths of a notch; touchpads send much smaller
    // deltas, so they're accumulated until they add up to one.
    property real scrollAccumulator: 0

    function notchesFrom(wheel) {
        scrollAccumulator += wheel.angleDelta.y;
        const notches = scrollAccumulator > 0 ? Math.floor(scrollAccumulator / 120) : Math.ceil(scrollAccumulator / 120);
        scrollAccumulator -= notches * 120;
        return notches;
    }

    Pill {
        id: pill
        animateWidth: false

        Row {
            spacing: root.showOutput && root.showInput ? 4 : 0

            BarText {
                id: outputSection
                leftPadding: Theme.groupItemPaddingH
                rightPadding: Theme.groupItemPaddingH
                clip: true
                width: root.showOutput ? implicitWidth : 0
                visible: width > 0
                text: {
                    if (!root.sinkReady)
                        return "";
                    if (root.sinkMuted)
                        return root.sinkVolume + "% " + Icons.volumeMuted;
                    const icon = root.sinkIsBluetooth ? root.volumeIcon + Icons.bluetooth : root.volumeIcon;
                    return root.sinkVolume + "% " + icon;
                }

                Behavior on width {
                    NumberAnimation {
                        duration: Theme.durationNormal
                        easing.type: Theme.easingEmphasized
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: audioPopup.showTab("output")
                    onWheel: wheel => root.adjust(root.sink, root.notchesFrom(wheel), Config.volume.maxOutputVolume)
                }
            }

            Divider {
                anchors.verticalCenter: parent.verticalCenter
                width: root.showOutput && root.showInput ? 1 : 0
                visible: width > 0
            }

            BarText {
                id: inputSection
                leftPadding: Theme.groupItemPaddingH
                rightPadding: Theme.groupItemPaddingH
                font.pixelSize: Theme.fontSizeSmall
                clip: true
                width: root.showInput ? implicitWidth : 0
                visible: width > 0
                text: {
                    if (!root.sourceReady)
                        return "";
                    return root.sourceVolume + "% " + (root.sourceMuted ? Icons.microphoneMuted : Icons.microphone);
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: audioPopup.showTab("input")
                    onWheel: wheel => root.adjust(root.source, root.notchesFrom(wheel), Config.volume.maxInputVolume)
                }

                Behavior on width {
                    NumberAnimation {
                        duration: Theme.durationNormal
                        easing.type: Theme.easingEmphasized
                    }
                }
            }
        }
    }

    PopupHost {
        id: audioPopup
        popup: Component {
            AudioPopup {
                anchorItem: pill
            }
        }
    }
}
