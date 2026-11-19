import QtQuick

// One colour of the wallpaper's palette. It is outlined while focused or
// selected, and the automatically chosen primary colour carries an "A" badge.
Item {
    id: root

    required property color swatchColor
    property bool focused: false
    property bool selected: false
    property bool autoPrimary: false

    signal clicked

    readonly property int transitionDuration: 140
    readonly property color highlight: "#ffffff"
    readonly property color badgeBackground: "#111111"

    width: 34
    height: 34

    Rectangle {
        anchors.fill: parent
        radius: 10
        color: root.swatchColor
        border.color: root.focused || root.selected ? root.highlight : "#00000000"
        border.width: root.focused ? 3 : (root.selected ? 2 : 0)
        scale: root.focused ? 1.10 : (root.selected ? 1.06 : (area.containsMouse ? 1.04 : 1.0))

        Behavior on scale {
            NumberAnimation {
                duration: root.transitionDuration
                easing.type: Easing.OutQuad
            }
        }
    }

    Rectangle {
        visible: root.autoPrimary
        width: 14
        height: 14
        radius: 7
        anchors {
            right: parent.right
            top: parent.top
            margins: -2
        }
        color: root.badgeBackground
        border.color: root.highlight
        border.width: 1

        Text {
            anchors.centerIn: parent
            text: "A"
            color: root.highlight
            font.pixelSize: 9
            font.bold: true
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
