import QtQuick

Rectangle {
    id: root

    property bool mirrored: false

    readonly property real tiltDegrees: 4
    readonly property int panelRadius: 3

    readonly property int connectorWidth: 9
    readonly property int connectorHeight: 3
    readonly property int connectorY: 22

    readonly property int cellColumns: 2
    readonly property int cellRows: 4
    readonly property int cellWidth: 12
    readonly property int cellHeight: 7
    readonly property int cellColumnStride: 16
    readonly property int cellRowStride: 10
    readonly property int cellInset: 5
    readonly property int cellRadius: 1
    readonly property real cellBorderWidth: .5
    readonly property color cellColor: "#252525"
    readonly property color cellBorder: "#484848"

    width: 39
    height: 48
    radius: panelRadius
    color: Theme.surface
    border.color: Theme.border
    rotation: mirrored ? tiltDegrees : -tiltDegrees

    Rectangle {
        x: root.mirrored ? -width : root.width
        y: root.connectorY
        width: root.connectorWidth
        height: root.connectorHeight
        color: Theme.muted
    }

    Repeater {
        model: root.cellColumns * root.cellRows

        Rectangle {
            required property int index

            x: root.cellInset + index % root.cellColumns * root.cellColumnStride
            y: root.cellInset + Math.floor(index / root.cellColumns) * root.cellRowStride
            width: root.cellWidth
            height: root.cellHeight
            radius: root.cellRadius
            color: root.cellColor
            border.color: root.cellBorder
            border.width: root.cellBorderWidth
        }
    }
}
