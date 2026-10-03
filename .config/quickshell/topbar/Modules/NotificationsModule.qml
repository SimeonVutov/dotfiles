import QtQuick
import qs.Common
import qs.Ui
import qs.Ui.Notifications
import qs.Services

BarModule {
    id: root
    readonly property string view: autoView === "icon" ? "icon" : autoView === "compact" ? "compact" : "full"
    readonly property int carrierWidth: view === "icon" ? 30 : view === "compact" ? 76 : 138
    preferredWidth: widthFor("full")

    function widthFor(mode) {
        const carrier = mode === "icon" ? 30 : mode === "compact" ? 76 : 138;
        const padding = mode === "full" ? 24 : 16;
        const slots = mode === "icon" ? 0 : mode === "compact" ? 2 : 4;
        const bufferWidth = buffer.widthFor(slots);
        return padding + carrier + (bufferWidth > 0 ? 6 + bufferWidth : 0);
    }

    function widthForCompression(state) {
        return widthFor(state.view || "full");
    }

    Component.onCompleted: {
        for (const message of Notifications.activeFor(screen?.name || ""))
            channel.enqueue(message, false);
    }

    ChannelReceiver {
        id: channel
    }

    Connections {
        target: Notifications
        function onReceived(message, screenName, arrival) {
            if (!screenName || root.screen?.name === screenName)
                channel.enqueue(message, arrival);
        }
        function onRemoved(id) {
            channel.forget(id);
        }
    }

    Connections {
        target: channel
        function onPhaseChanged() {
            terminal.open = channel.phase === "opening" || channel.phase === "reading" || channel.phase === "empty" || channel.phase === "handoff";
        }
    }

    Pill {
        id: pill
        paddingH: root.view === "full" ? 12 : 8
        animateWidth: false
        Row {
            spacing: 6
            ChannelWaveform {
                receiver: channel
                width: root.carrierWidth
                height: 24
            }
            ChannelBuffer {
                id: buffer
                receiver: channel
                capacity: root.view === "icon" ? 0 : root.view === "compact" ? 2 : 4
                anchors.verticalCenter: parent.verticalCenter
                visible: waitingCount > 0
            }
        }
        MouseArea {
            parent: pill
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (terminal.open)
                    channel.closeCurrent();
                else
                    channel.openConsole();
            }
        }
    }

    ChannelTerminal {
        id: terminal
        // The module's left edge stays fixed as the queue changes width.
        anchorItem: root
        anchorOffsetX: Math.round(root.carrierWidth / 2 + pill.paddingH - panelWidth / 2)
        receiver: channel
    }
}
