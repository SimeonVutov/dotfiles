import QtQuick
import qs.Common
import qs.Ui
import "Layout.js" as Layout

Rectangle {
    id: root

    required property var controller
    property bool active: false
    property string dragging: ""
    property real dragX: 0
    property real dragY: 0
    property var dragViewport: null
    property real signalPhase: 0
    readonly property bool duplicate: controller.mode === "duplicate"
    readonly property var rectangles: Layout.displayRects(controller.monitors, duplicate)
    readonly property var extent: Layout.bounds(rectangles)
    readonly property real mapPadding: 48
    readonly property real fit: Math.min((width - mapPadding * 2) / extent.width, (height - mapPadding * 2) / extent.height)
    readonly property real zoom: dragViewport ? dragViewport.zoom : fit
    readonly property real originX: dragViewport ? dragViewport.x : (width - extent.width * fit) / 2 - extent.x * fit
    readonly property real originY: dragViewport ? dragViewport.y : (height - extent.height * fit) / 2 - extent.y * fit
    readonly property var snapPreview: dragging ? Layout.move(controller.monitors, dragging, (dragX - originX) / zoom, (dragY - originY) / zoom).find(m => m.name === dragging) : null

    color: Theme.overlaySurfaceHover
    radius: 20
    border.color: Theme.overlayBorderBright
    clip: true

    function nudge(dx, dy) {
        const monitor = controller.selectedMonitor;
        if (!monitor || !monitor.enabled || duplicate)
            return;
        const box = Layout.size(monitor);
        controller.move(monitor.name, monitor.x + dx * box.width, monitor.y + dy * box.height);
    }

    Keys.onLeftPressed: nudge(-1, 0)
    Keys.onRightPressed: nudge(1, 0)
    Keys.onUpPressed: nudge(0, -1)
    Keys.onDownPressed: nudge(0, 1)

    Repeater {
        model: 2
        Rectangle {
            required property int index
            anchors.centerIn: parent
            width: Math.min(root.width, root.height) * (.72 + index * .36)
            height: width
            radius: width / 2
            color: "transparent"
            border.color: Theme.overlayBorder
            opacity: .45
        }
    }

    Rectangle {
        anchors.centerIn: parent
        width: parent.width - 40
        height: 1
        color: Theme.overlayBorder
        opacity: .45
    }

    NumberAnimation on signalPhase {
        from: 0
        to: 1
        duration: 4200
        loops: Animation.Infinite
        running: root.active && root.duplicate
    }

    Rectangle {
        visible: root.snapPreview !== null
        x: root.originX + (root.snapPreview?.x || 0) * root.zoom
        y: root.originY + (root.snapPreview?.y || 0) * root.zoom
        width: root.snapPreview ? Layout.size(root.snapPreview).width * root.zoom : 0
        height: root.snapPreview ? Layout.size(root.snapPreview).height * root.zoom : 0
        radius: 7
        color: Theme.overlayBorderBright
        opacity: .5
        border.color: Theme.overlayText
        border.width: 2
        Behavior on x {
            NumberAnimation {
                duration: 100
                easing.type: Easing.OutCubic
            }
        }
        Behavior on y {
            NumberAnimation {
                duration: 100
                easing.type: Easing.OutCubic
            }
        }
    }

    Repeater {
        model: root.rectangles.length

        Rectangle {
            id: tile
            required property int index
            readonly property var monitor: root.rectangles[index]
            readonly property bool selected: monitor.name === root.controller.selected
            readonly property bool moving: root.dragging === monitor.name
            readonly property real scenePhase: root.duplicate ? root.signalPhase : index * .17

            x: moving ? root.dragX : root.originX + monitor.x * root.zoom
            y: moving ? root.dragY : root.originY + monitor.y * root.zoom
            width: monitor.width * root.zoom
            height: monitor.height * root.zoom
            z: moving ? 3 : selected ? 2 : 1
            radius: 10
            color: selected ? Theme.overlayBorder : Theme.overlaySurface
            border.width: selected ? 2 : 1
            border.color: selected ? Theme.overlayText : Theme.overlayBorderBright
            opacity: monitor.enabled ? 1 : .3
            clip: true
            scale: moving ? 1.025 : 1

            Behavior on x {
                enabled: !tile.moving
                NumberAnimation {
                    duration: 200
                    easing.type: Easing.OutCubic
                }
            }
            Behavior on y {
                enabled: !tile.moving
                NumberAnimation {
                    duration: 200
                    easing.type: Easing.OutCubic
                }
            }
            Behavior on width {
                NumberAnimation {
                    duration: 200
                    easing.type: Easing.OutCubic
                }
            }
            Behavior on height {
                NumberAnimation {
                    duration: 200
                    easing.type: Easing.OutCubic
                }
            }
            Behavior on opacity {
                NumberAnimation {
                    duration: 180
                }
            }
            Behavior on color {
                ColorAnimation {
                    duration: 180
                }
            }
            Behavior on border.color {
                ColorAnimation {
                    duration: 180
                }
            }
            Behavior on scale {
                NumberAnimation {
                    duration: 160
                    easing.type: Easing.OutCubic
                }
            }

            Item {
                anchors.fill: parent
                visible: tile.monitor.enabled && root.duplicate
                opacity: .28
                Rectangle {
                    anchors.centerIn: parent
                    width: Math.min(parent.width, parent.height) * .7
                    height: width
                    radius: width / 2
                    color: "transparent"
                    border.color: Theme.overlayText
                    Rectangle {
                        x: parent.width / 2 + Math.cos(tile.scenePhase * Math.PI * 2) * parent.width / 2 - 3
                        y: parent.height / 2 + Math.sin(tile.scenePhase * Math.PI * 2) * parent.height / 2 - 3
                        width: 6
                        height: 6
                        radius: 3
                        color: Theme.overlayText
                    }
                }
                Rectangle {
                    anchors.centerIn: parent
                    width: Math.min(parent.width, parent.height) * .35
                    height: width
                    rotation: 45
                    color: "transparent"
                    border.color: Theme.overlayText
                }
                Rectangle {
                    width: parent.width * .2
                    height: 2
                    x: parent.width * .1
                    y: parent.height * .8
                    color: Theme.overlayText
                }
            }

            Column {
                anchors.centerIn: parent
                width: parent.width - 12
                spacing: 3
                BarText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.duplicate && tile.monitor.enabled ? "◎" : String(tile.index + 1)
                    font.pixelSize: Math.max(14, Math.min(34, tile.height * .24))
                    font.bold: true
                }
                BarText {
                    width: parent.width
                    text: tile.monitor.internal ? "LAPTOP" : "EXTERNAL"
                    horizontalAlignment: Text.AlignHCenter
                    font.pixelSize: Theme.fontSizeTiny
                    elide: Text.ElideRight
                    visible: tile.height > 68
                }
                BarText {
                    width: parent.width
                    text: tile.monitor.name
                    horizontalAlignment: Text.AlignHCenter
                    color: Theme.overlayMuted
                    font.pixelSize: Theme.fontSizeTiny
                    elide: Text.ElideRight
                    visible: tile.height > 95
                }
            }

            Rectangle {
                anchors {
                    top: parent.top
                    right: parent.right
                    margins: 9
                }
                width: 5
                height: 5
                radius: 3
                color: tile.monitor.enabled ? Theme.overlayText : Theme.overlayMuted
            }

            MouseArea {
                id: pointer
                anchors.fill: parent
                enabled: !root.controller.busy
                hoverEnabled: true
                cursorShape: tile.monitor.enabled && !root.duplicate ? (pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor) : Qt.PointingHandCursor
                property real pressX: 0
                property real pressY: 0
                property real tileX: 0
                property real tileY: 0

                onPressed: mouse => {
                    root.controller.selected = tile.monitor.name;
                    root.forceActiveFocus();
                    const point = mapToItem(root, mouse.x, mouse.y);
                    pressX = point.x;
                    pressY = point.y;
                    tileX = tile.x;
                    tileY = tile.y;
                }
                onPositionChanged: mouse => {
                    if (!pressed || !tile.monitor.enabled || root.duplicate)
                        return;
                    const point = mapToItem(root, mouse.x, mouse.y);
                    if (!root.dragging && Math.hypot(point.x - pressX, point.y - pressY) < 5)
                        return;
                    if (!root.dragging) {
                        root.dragViewport = {
                            zoom: root.zoom,
                            x: root.originX,
                            y: root.originY
                        };
                        root.dragX = tileX;
                        root.dragY = tileY;
                        root.dragging = tile.monitor.name;
                    }
                    root.dragX = Math.max(0, Math.min(root.width - tile.width, tileX + point.x - pressX));
                    root.dragY = Math.max(0, Math.min(root.height - tile.height, tileY + point.y - pressY));
                }
                onReleased: {
                    if (!tile.moving)
                        return;
                    const x = (root.dragX - root.originX) / root.zoom;
                    const y = (root.dragY - root.originY) / root.zoom;
                    root.controller.move(tile.monitor.name, x, y);
                    root.dragging = "";
                    root.dragViewport = null;
                }
                onCanceled: {
                    root.dragging = "";
                    root.dragViewport = null;
                }
            }
        }
    }

    BarText {
        anchors.centerIn: parent
        visible: !root.rectangles.length
        text: root.controller.busy ? "Acquiring displays…" : "No displays available"
        color: Theme.overlayMuted
    }
}
