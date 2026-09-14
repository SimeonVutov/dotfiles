import QtQuick
import QtQuick.Layouts
import qs.Common

// Shared chrome for the quick-settings menus: a centred card that fades up and
// scales in the way the bar's own popups do, and reverses on the way out.
FocusScope {
    id: root

    default property alias content: body.data
    property string title: ""
    property bool presenting: false
    property real reveal: 0
    property int panelWidth: 920
    property int panelHeight: 640
    readonly property int padding: Theme.popupPadding

    signal closeRequested
    signal closed

    onPresentingChanged: {
        transition.to = presenting ? 1 : 0;
        transition.duration = presenting ? Theme.durationNormal : Theme.durationFast;
        transition.restart();
        if (presenting)
            forceActiveFocus();
    }

    Keys.onEscapePressed: event => {
        root.closeRequested();
        event.accepted = true;
    }

    NumberAnimation {
        id: transition

        target: root
        property: "reveal"
        easing.type: Theme.easingEmphasized
        onFinished: if (!root.presenting)
            root.closed()
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.overlayAbyss
        opacity: root.reveal * .7
        MouseArea {
            anchors.fill: parent
            onClicked: root.closeRequested()
        }
    }

    Rectangle {
        id: panel

        anchors.centerIn: parent
        width: root.panelWidth
        height: root.panelHeight
        radius: Theme.popupRadius
        color: Theme.popupBackground
        border.color: Theme.popupBorder
        opacity: root.reveal
        scale: Math.min(1, (root.width - 32) / width, (root.height - 32) / height) * (.96 + .04 * root.reveal)
        visible: opacity > .01

        MouseArea {
            anchors.fill: parent
        }

        RowLayout {
            id: header

            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
                margins: root.padding
            }
            height: 52
            spacing: 16

            Dish {
                Layout.preferredWidth: 52
                Layout.preferredHeight: 52
                transmitting: root.presenting
            }

            BarText {
                Layout.fillWidth: true
                text: root.title
                color: Theme.popupText
                font.pixelSize: Theme.fontSizeXLarge
            }

            CloseButton {
                onClicked: root.closeRequested()
            }
        }

        Item {
            id: body

            anchors {
                top: header.bottom
                topMargin: 22
                left: parent.left
                right: parent.right
                bottom: parent.bottom
                margins: root.padding
            }
            enabled: root.presenting
        }
    }
}
