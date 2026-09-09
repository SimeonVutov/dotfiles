import QtQuick
import qs.Common

Rectangle {
    id: root

    property string title: ""
    property string subtitle: ""
    property string artUrl: ""
    property string icon: Icons.music
    property bool selected: false
    signal chosen

    implicitHeight: 52
    radius: 9
    color: mouse.pressed ? Theme.popupBorder : (selected || mouse.containsMouse || activeFocus ? Theme.popupSurface : "transparent")
    activeFocusOnTab: true
    Accessible.role: Accessible.RadioButton
    Accessible.name: title + ". " + subtitle
    Accessible.checked: selected
    Accessible.onPressAction: chosen()
    Keys.onSpacePressed: chosen()
    Keys.onReturnPressed: chosen()

    Behavior on color {
        ColorAnimation {
            duration: Theme.durationFast
        }
    }

    Item {
        id: artwork
        x: 10
        width: 32
        height: 32
        anchors.verticalCenter: parent.verticalCenter

        AlbumArt {
            anchors.fill: parent
            radius: 7
            source: root.artUrl
            visible: root.artUrl !== ""
        }
        BarText {
            anchors.centerIn: parent
            text: root.icon
            color: Theme.popupSubtleText
            font.pixelSize: 18
            visible: root.artUrl === ""
        }
    }

    Column {
        anchors.left: artwork.right
        anchors.leftMargin: 10
        anchors.right: radio.left
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        spacing: 3

        BarText {
            width: parent.width
            text: root.title
            font.pixelSize: 13
            elide: Text.ElideRight
        }
        BarText {
            width: parent.width
            text: root.subtitle
            color: Theme.popupSubtleText
            font.pixelSize: 11
            elide: Text.ElideRight
        }
    }

    Rectangle {
        id: radio
        anchors.right: parent.right
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        width: 16
        height: 16
        radius: 8
        color: "transparent"
        border.color: root.selected ? Theme.popupAccent : Theme.popupSubtleText

        Rectangle {
            anchors.centerIn: parent
            width: 8
            height: 8
            radius: 4
            color: Theme.popupAccent
            opacity: root.selected ? 1 : 0
            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.durationFast
                }
            }
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.chosen()
    }
}
