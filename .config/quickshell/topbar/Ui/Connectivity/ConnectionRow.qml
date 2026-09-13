import QtQuick
import qs.Ui
import qs.Common

Rectangle {
    id: root

    property string title: ""
    property string subtitle: ""
    property string action: "Connect"
    property string secondaryAction: ""
    property bool active: false
    property bool busy: false
    signal activated
    signal secondaryActivated

    implicitHeight: 52
    radius: 9
    color: hover.hovered ? Theme.popupSurface : "transparent"

    HoverHandler {
        id: hover
    }

    Behavior on color {
        ColorAnimation {
            duration: Theme.durationFast
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        enabled: !root.busy
        cursorShape: Qt.PointingHandCursor
        onClicked: root.activated()
    }

    Column {
        x: 12
        y: 6
        width: parent.width - 24
        spacing: 4
        BarText {
            width: parent.width
            text: root.title
            font.pixelSize: Theme.fontSizeLabel
            elide: Text.ElideRight
        }
        BarText {
            width: Math.max(0, parent.width - actions.width - 8)
            text: root.subtitle
            font.pixelSize: Theme.fontSizeTiny
            color: Theme.popupSubtleText
            elide: Text.ElideRight
        }
    }

    Row {
        id: actions
        anchors.right: parent.right
        anchors.rightMargin: 8
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 3
        spacing: 6
        ConnectionButton {
            visible: root.secondaryAction !== ""
            text: root.secondaryAction
            subtle: true
            enabled: !root.busy
            onClicked: root.secondaryActivated()
        }
        ConnectionButton {
            text: root.action
            subtle: true
            enabled: !root.busy
            onClicked: root.activated()
        }
    }
}
