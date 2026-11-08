import QtQuick
import qs.Common
import qs.Ui
import qs.Lockscreen as Lock
import "../../Lockscreen/Grid.js" as Grid
import "../../Lockscreen/WidgetCatalog.js" as Catalog

Rectangle {
    id: root

    required property var controller
    property real aspectRatio: 16 / 9
    property string hoveredWidget: ""
    readonly property real cellWidth: surface.width / root.controller.layout.columns
    readonly property real cellHeight: surface.height / root.controller.layout.rows

    color: Theme.popupSurface
    radius: Theme.popupRadius
    border.color: Theme.popupBorder
    clip: true

    Item {
        id: surface

        anchors.centerIn: parent
        width: Math.min(root.width - 32, (root.height - 32) * root.aspectRatio)
        height: width / root.aspectRatio
        clip: true

        HoverHandler {
            onHoveredChanged: if (!hovered)
                root.hoveredWidget = ""
        }

        Lock.CachedBackground {
            anchors.fill: parent
        }

        Rectangle {
            anchors.fill: parent
            color: "#000000"
            opacity: .4
        }

        Repeater {
            model: root.controller.layout.columns * root.controller.layout.rows

            delegate: Rectangle {
                required property int index
                readonly property int column: index % root.controller.layout.columns
                readonly property int row: Math.floor(index / root.controller.layout.columns)
                readonly property bool underPointer: !!root.controller.moving && Grid.contains(root.controller.moving, column, row)
                readonly property bool blocked: underPointer && Grid.occupied(root.controller.layout, column, row, root.controller.moving.id)

                x: column * root.cellWidth + 1
                y: row * root.cellHeight + 1
                width: root.cellWidth - 2
                height: root.cellHeight - 2
                radius: 3
                color: blocked ? "#55bc5555" : underPointer ? "#3368bb91" : "#16000000"
                border.width: underPointer ? 2 : 1
                border.color: blocked ? "#ee8888" : underPointer ? "#ffffff" : "#68707070"

                Behavior on color {
                    ColorAnimation {
                        duration: Theme.durationFast
                    }
                }

                Behavior on border.color {
                    ColorAnimation {
                        duration: Theme.durationFast
                    }
                }
            }
        }

        Repeater {
            model: root.controller.layout.widgets

            delegate: Rectangle {
                required property var modelData

                x: modelData.column * root.cellWidth + 4
                y: modelData.row * root.cellHeight + 4
                width: modelData.columns * root.cellWidth - 8
                height: modelData.rows * root.cellHeight - 8
                radius: 9
                color: root.controller.selected === modelData.id ? "#c02d2d2d" : "#b01a1a1a"
                opacity: root.controller.moving?.id === modelData.id ? .25 : 1
                border.color: root.controller.selected === modelData.id ? Theme.overlayBorderBright : Theme.popupBorder

                Text {
                    anchors.centerIn: parent
                    width: parent.width - 8
                    text: Catalog.find(modelData.type).name
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                    color: Theme.overlayText
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                }
            }
        }

        Rectangle {
            id: ghost
            property real shakeOffset: 0

            visible: !!root.controller.moving
            x: (root.controller.moving?.column || 0) * root.cellWidth + 3 + shakeOffset
            y: (root.controller.moving?.row || 0) * root.cellHeight + 3
            width: (root.controller.moving?.columns || 1) * root.cellWidth - 6
            height: (root.controller.moving?.rows || 1) * root.cellHeight - 6
            radius: 9
            color: "#30202020"
            border.width: 2
            border.color: Theme.overlayText

            Text {
                anchors.centerIn: parent
                text: root.controller.moving ? Catalog.find(root.controller.moving.type).name : ""
                color: Theme.overlayText
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
            }

            SequentialAnimation {
                id: rejection
                NumberAnimation {
                    target: ghost
                    property: "shakeOffset"
                    to: -7
                    duration: 55
                }
                NumberAnimation {
                    target: ghost
                    property: "shakeOffset"
                    to: 7
                    duration: 65
                }
                NumberAnimation {
                    target: ghost
                    property: "shakeOffset"
                    to: -4
                    duration: 55
                }
                NumberAnimation {
                    target: ghost
                    property: "shakeOffset"
                    to: 0
                    duration: 55
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: root.controller.moving ? Qt.ClosedHandCursor : root.hoveredWidget ? Qt.PointingHandCursor : Qt.ArrowCursor

            onPositionChanged: mouse => {
                const column = Math.floor(mouse.x / root.cellWidth);
                const row = Math.floor(mouse.y / root.cellHeight);
                root.controller.moveTo(column, row);

                const widget = root.controller.layout.widgets.find(item => Grid.contains(item, column, row));
                root.hoveredWidget = widget?.id || "";
            }
            onClicked: mouse => {
                root.forceActiveFocus();
                if (root.controller.moving) {
                    root.controller.place();
                    return;
                }

                const column = Math.floor(mouse.x / root.cellWidth);
                const row = Math.floor(mouse.y / root.cellHeight);
                const widget = root.controller.layout.widgets.find(item => Grid.contains(item, column, row));
                root.controller.selected = widget?.id || "";
            }
        }

        Repeater {
            model: root.controller.layout.widgets

            delegate: CloseButton {
                required property var modelData

                z: 3
                diameter: 24
                glyphSize: 10
                icon: Icons.move
                x: modelData.column * root.cellWidth + 8
                y: modelData.row * root.cellHeight + 8
                visible: root.controller.selected === modelData.id && !root.controller.moving
                enabled: root.controller.ready

                onClicked: {
                    root.forceActiveFocus();
                    root.controller.beginMove(modelData.id, modelData.column, modelData.row);
                }
            }
        }

        Repeater {
            model: root.controller.layout.widgets

            delegate: CloseButton {
                required property var modelData

                z: 3
                diameter: 24
                glyphSize: 10
                x: (modelData.column + modelData.columns) * root.cellWidth - width - 8
                y: modelData.row * root.cellHeight + 8
                visible: !Catalog.find(modelData.type).required && !root.controller.moving && (root.controller.selected === modelData.id || root.hoveredWidget === modelData.id || hovered)
                enabled: root.controller.ready
                onClicked: root.controller.removeWidget(modelData.id)
            }
        }
    }

    Connections {
        target: root.controller
        function onRejected() {
            rejection.restart();
        }
    }
}
