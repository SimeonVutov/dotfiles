import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import qs.Common
import qs.Ui

// Output (and input) volume, live from PipeWire.
//
// Scrolling adjusts whichever half the pointer is over — the output reading or
// the mic reading. Clicking either opens pulsemixer.
BarModule {
    id: root

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource

    readonly property bool sinkReady: !!sink && !!sink.audio
    readonly property int sinkVolume: sinkReady ? Math.round(sink.audio.volume * 100) : 0
    readonly property bool sinkMuted: sinkReady && sink.audio.muted
    readonly property bool sinkIsBluetooth: !!sink && (sink.name || "").indexOf("bluez") !== -1

    readonly property bool sourceReady: !!source && !!source.audio
    readonly property int sourceVolume: sourceReady ? Math.round(source.audio.volume * 100) : 0
    readonly property bool sourceMuted: sourceReady && source.audio.muted

    // Binding these keeps their `audio` interfaces populated.
    PwObjectTracker {
        objects: [root.sink, root.source]
    }

    readonly property string volumeIcon: {
        if (sinkIsBluetooth)
            return Icons.headphone;
        const levels = Icons.volumeLevels;
        const index = Math.max(0, Math.min(levels.length - 1, Math.floor(sinkVolume / 100 * levels.length)));
        return levels[index];
    }

    function adjust(node, notches) {
        if (!node || !node.audio || notches === 0)
            return;
        const current = Math.round(node.audio.volume * 100);
        const next = current + notches * Config.volume.scrollStep;
        node.audio.volume = Math.max(0, Math.min(Config.volume.maxVolume, next)) / 100;
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
        Row {
            spacing: 0

            BarText {
                text: {
                    if (!root.sinkReady)
                        return "";
                    if (root.sinkMuted)
                        return Icons.volumeMuted;
                    const icon = root.sinkIsBluetooth ? root.volumeIcon + Icons.bluetooth : root.volumeIcon;
                    return root.sinkVolume + "% " + icon;
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Quickshell.execDetached(Config.volume.onClick)
                    onWheel: wheel => root.adjust(root.sink, root.notchesFrom(wheel))
                }
            }

            BarText {
                font.pixelSize: Theme.fontSizeSmall
                text: {
                    if (!root.sourceReady)
                        return "";
                    return root.sourceMuted ? " " + Icons.microphoneMuted : " " + root.sourceVolume + "% " + Icons.microphone;
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Quickshell.execDetached(Config.volume.onClick)
                    onWheel: wheel => root.adjust(root.source, root.notchesFrom(wheel))
                }
            }
        }
    }
}
