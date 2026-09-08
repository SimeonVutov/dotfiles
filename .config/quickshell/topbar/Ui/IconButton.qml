import QtQuick
import qs.Common

// A clickable glyph that reacts to hover and press. Used by the media
// transport and the power button; the animation lives here so restyling every
// button in the bar is a one-file change.
Item {
    id: root

    property string icon: ""
    property int size: Theme.fontSize
    property color color: Theme.text
    property bool enabled: true
    property real disabledOpacity: 0.35
    property alias containsMouse: mouseArea.containsMouse

    signal clicked

    implicitWidth: label.implicitWidth
    implicitHeight: label.implicitHeight

    opacity: enabled ? 1 : disabledOpacity

    Behavior on opacity {
        NumberAnimation {
            duration: Theme.durationFast
            easing.type: Theme.easing
        }
    }

    Text {
        id: label
        anchors.centerIn: parent
        text: root.icon
        color: root.color
        font.family: Theme.fontFamily
        font.pixelSize: root.size
        textFormat: Text.PlainText
        renderType: Text.NativeRendering

        scale: mouseArea.pressed ? 0.88 : (mouseArea.containsMouse && root.enabled ? 1.15 : 1)

        Behavior on scale {
            NumberAnimation {
                duration: Theme.durationFast
                easing.type: Theme.easingEmphasized
            }
        }

        Behavior on color {
            ColorAnimation {
                duration: Theme.durationFast
            }
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        anchors.margins: -4      // a little slack so small glyphs stay easy to hit
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        enabled: root.enabled
        onClicked: root.clicked()
    }
}
