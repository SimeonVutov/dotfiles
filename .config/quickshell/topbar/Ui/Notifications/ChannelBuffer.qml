pragma ComponentBehavior: Bound

import QtQuick
import qs.Common

// Anchored FIFO preview: appending messages cannot reposition existing slots.
Item {
    id: root
    required property var receiver
    property int capacity: 4
    readonly property int waitingCount: receiver.queue.length
    readonly property int overflowCount: Math.max(0, waitingCount - capacity)
    implicitWidth: widthFor(capacity)
    implicitHeight: 24

    function widthFor(slots) {
        if (waitingCount === 0)
            return 0;
        const shown = Math.min(waitingCount, slots);
        const segments = shown > 0 ? shown * 7 - 3 : 0;
        const label = slots === 0 ? String(waitingCount) : waitingCount > slots ? "+" + (waitingCount - slots) : "";
        return segments + (segments && label ? 5 : 0) + Math.ceil(labelFont.advanceWidth(label));
    }

    function synchronize() {
        const ids = receiver.queue.slice(0, capacity).map(message => message.id);
        // Keep delegates for the oldest waiting messages. New messages append;
        // removing/reading one shifts only its successors toward the front.
        for (let i = entries.count - 1; i >= 0; i--) {
            if (!ids.includes(entries.get(i).messageId))
                entries.remove(i);
        }
        for (let i = 0; i < ids.length; i++) {
            if (i >= entries.count)
                entries.append({
                    messageId: ids[i]
                });
        }
    }

    onCapacityChanged: Qt.callLater(synchronize)
    Component.onCompleted: Qt.callLater(synchronize)
    Connections {
        target: root.receiver
        function onQueueChanged() {
            Qt.callLater(root.synchronize);
        }
    }
    ListModel {
        id: entries
    }
    FontMetrics {
        id: labelFont
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeTiny
    }
    Repeater {
        model: entries
        Rectangle {
            required property int index
            required property int messageId
            x: index * 7
            y: (root.height - height) / 2
            width: 4
            height: 10
            radius: 1.5
            color: Theme.popupAccent
            opacity: 0
            Component.onCompleted: opacity = 0.75
            Behavior on opacity {
                NumberAnimation {
                    duration: 220
                }
            }
            Behavior on x {
                NumberAnimation {
                    duration: 220
                    easing.type: Easing.InOutCubic
                }
            }
        }
    }
    Text {
        x: root.capacity > 0 ? root.capacity * 7 - 3 + 5 : 0
        anchors.verticalCenter: parent.verticalCenter
        text: root.capacity === 0 ? root.waitingCount : root.overflowCount > 0 ? "+" + root.overflowCount : ""
        color: Theme.popupSubtleText
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeTiny
    }
}
