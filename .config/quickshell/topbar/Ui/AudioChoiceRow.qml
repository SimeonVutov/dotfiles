import QtQuick
import qs.Common

Rectangle {
    id: root

    property string title: ""
    property string subtitle: ""
    property bool selected: false
    property bool busy: false
    property bool showDetails: false
    property bool detailsEnabled: true
    signal chosen
    signal detailsRequested

    implicitHeight: 52
    radius: 9
    color: selected || hover.hovered ? Theme.popupSurface : "transparent"
    opacity: busy ? 0.55 : 1

    Behavior on color {
        ColorAnimation {
            duration: Theme.durationFast
        }
    }
    Behavior on opacity {
        NumberAnimation {
            duration: Theme.durationFast
        }
    }

    HoverHandler {
        id: hover
    }

    Column {
        anchors.left: parent.left
        anchors.leftMargin: 12
        anchors.right: selector.left
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        spacing: 4

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
        id: selector
        anchors.right: root.showDetails ? detailsButton.left : parent.right
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
        anchors.fill: parent
        enabled: !root.busy
        cursorShape: Qt.PointingHandCursor
        onClicked: root.chosen()
    }

    Rectangle {
        id: detailsButton

        anchors.right: parent.right
        anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        width: 34
        height: 34
        radius: 9
        visible: root.showDetails
        color: detailsMouse.pressed ? Theme.popupBorder : (detailsMouse.containsMouse ? Theme.popupSurface : "transparent")
        opacity: root.detailsEnabled ? 1 : 0.35

        Behavior on color {
            ColorAnimation {
                duration: Theme.durationFast
            }
        }

        BarText {
            anchors.centerIn: parent
            text: Icons.audioProfile
            color: Theme.popupSubtleText
            font.pixelSize: 18
        }

        MouseArea {
            id: detailsMouse
            anchors.fill: parent
            enabled: root.detailsEnabled
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.detailsRequested()
        }
    }
}
