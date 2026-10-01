import QtQuick
import qs.Ui
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
            font.pixelSize: Theme.fontSizeLarge
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
            font.pixelSize: Theme.fontSizeLabel
            elide: Text.ElideRight
        }
        BarText {
            width: parent.width
            text: root.subtitle
            color: Theme.popupSubtleText
            font.pixelSize: Theme.fontSizeTiny
            elide: Text.ElideRight
        }
    }

    SelectionDot {
        id: radio
        anchors.right: parent.right
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        selected: root.selected
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.chosen()
    }
}
