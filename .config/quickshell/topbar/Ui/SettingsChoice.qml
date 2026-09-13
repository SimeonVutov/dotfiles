import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import qs.Common

ColumnLayout {
    id: root

    property string label: ""
    property alias model: choice.model
    property alias currentIndex: choice.currentIndex
    signal chosen(int index)
    spacing: 8

    BarText {
        text: root.label
        color: Theme.overlayMuted
        font.pixelSize: Theme.fontSizeCaption
    }

    ComboBox {
        id: choice
        Layout.fillWidth: true
        implicitHeight: 38
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeSmall
        palette.text: Theme.overlayText
        palette.buttonText: Theme.overlayText
        palette.base: Theme.overlaySurface
        palette.window: Theme.overlaySurface
        palette.button: Theme.overlaySurface
        palette.highlight: Theme.overlayBorderBright
        palette.highlightedText: Theme.overlayText
        onActivated: index => root.chosen(index)
        background: Rectangle {
            radius: 9
            color: Theme.overlaySurface
            border.color: choice.activeFocus ? Theme.overlayText : Theme.overlayBorder
        }
    }
}
