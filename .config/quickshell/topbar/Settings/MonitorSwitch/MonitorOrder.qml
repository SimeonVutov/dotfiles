pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Ui

RowLayout {
    id: root

    required property var controller
    readonly property var monitors: controller.monitors.filter(m => m.enabled)
    readonly property var names: monitors.map(m => m.name).sort()
    property string dragging: ""
    property real dragX: 0
    spacing: 14
    implicitHeight: 36

    BarText {
        text: "Workspace order"
        color: Theme.popupSubtleText
        font.pixelSize: Theme.fontSizeCaption
    }

    Item {
        id: track
        Layout.fillWidth: true
        Layout.preferredHeight: 36
        readonly property real gap: 8
        readonly property real chipWidth: Math.max(1, (width - gap * Math.max(0, root.names.length - 1)) / Math.max(1, root.names.length))

        // Stable delegates retain their pointer grab while the ordered list changes.
        Repeater {
            model: root.names.length

            Rectangle {
                id: chip
                required property int index
                readonly property string name: root.names[index]
                readonly property int position: root.monitors.findIndex(m => m.name === name)
                readonly property var monitor: root.monitors.find(m => m.name === name)
                readonly property bool moving: root.dragging === name
                property real startX: 0

                x: moving ? root.dragX : position * (track.chipWidth + track.gap)
                width: track.chipWidth
                height: track.height
                z: moving ? 1 : 0
                radius: 9
                color: moving || pointer.hovered ? Theme.popupBorder : Theme.popupSurface
                border.color: moving ? Theme.popupText : Theme.popupBorder
                Accessible.name: "Workspace order " + (position + 1) + ", " + name + ". Drag to reorder."

                Behavior on x {
                    enabled: !chip.moving
                    NumberAnimation { duration: Theme.durationFast; easing.type: Theme.easingEmphasized }
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 9
                    spacing: 8

                    BarText {
                        text: String(chip.position + 1)
                        font.pixelSize: Theme.fontSizeSmall
                        font.weight: Font.DemiBold
                    }
                    BarText {
                        Layout.fillWidth: true
                        text: chip.monitor?.internal ? "Laptop" : chip.name
                        font.pixelSize: Theme.fontSizeSmall
                        elide: Text.ElideRight
                    }
                    BarText {
                        text: "⠿"
                        color: Theme.popupSubtleText
                        font.pixelSize: Theme.fontSizeSmall
                    }
                }

                HoverHandler {
                    id: pointer
                    cursorShape: drag.active ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                }

                DragHandler {
                    id: drag
                    target: null
                    enabled: !root.controller.busy
                    yAxis.enabled: false
                    onActiveChanged: {
                        if (active) {
                            chip.startX = chip.x;
                            root.dragX = chip.x;
                            root.dragging = chip.name;
                            root.controller.selected = chip.name;
                        } else {
                            root.dragging = "";
                        }
                    }
                    onTranslationChanged: {
                        if (!active)
                            return;
                        root.dragX = Math.max(0, Math.min(track.width - chip.width, chip.startX + translation.x));
                        const position = Math.round(root.dragX / (track.chipWidth + track.gap));
                        if (position !== chip.position)
                            root.controller.setOrder(chip.name, position);
                    }
                }
            }
        }
    }
}
