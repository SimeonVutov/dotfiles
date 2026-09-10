import QtQuick
import QtQuick.Controls.Basic
import qs.Common

Button {
    id: root
    property string heading: ""
    property string subtitle: ""
    property string glyph: ""
    property bool powered: false
    implicitHeight: 44
    padding: 6
    hoverEnabled: true
    Accessible.name: heading + (powered ? " on; turn off" : " off; turn on")
    background: Rectangle {
        radius: 10
        color: root.hovered || root.down ? Theme.popupSurface : "transparent"
        border.color: root.activeFocus ? Theme.popupSubtleText : "transparent"
        Behavior on color {
            ColorAnimation {
                duration: Theme.durationFast
            }
        }
    }
    contentItem: Item {
        BarText {
            id: glyph
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: 30
            text: root.glyph
            font.pixelSize: 20
            color: root.powered ? Theme.popupText : Theme.popupSubtleText
        }
        Column {
            anchors.left: glyph.right
            anchors.leftMargin: 8
            anchors.right: state.left
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4
            BarText {
                text: root.heading
                font.pixelSize: 14
                font.bold: true
            }
            BarText {
                width: parent.width
                text: root.subtitle
                color: Theme.popupSubtleText
                font.pixelSize: 11
                elide: Text.ElideRight
            }
        }
        Row {
            id: state
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8
            BarText {
                text: root.powered ? "On" : "Off"
                font.pixelSize: 12
                color: root.powered ? Theme.popupText : Theme.popupSubtleText
            }
            Rectangle {
                width: 30
                height: 16
                radius: 8
                anchors.verticalCenter: parent.verticalCenter
                color: root.powered ? Theme.popupAccent : Theme.popupBorder
                Rectangle {
                    x: root.powered ? 17 : 3
                    y: 3
                    width: 10
                    height: 10
                    radius: 5
                    color: root.powered ? Theme.popupBackground : Theme.popupSubtleText
                    Behavior on x {
                        NumberAnimation {
                            duration: Theme.durationFast
                            easing.type: Theme.easingEmphasized
                        }
                    }
                }
                Behavior on color {
                    ColorAnimation {
                        duration: Theme.durationFast
                    }
                }
            }
        }
    }
}
