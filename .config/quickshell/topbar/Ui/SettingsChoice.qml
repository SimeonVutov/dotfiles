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
        color: Theme.popupSubtleText
        font.pixelSize: Theme.fontSizeCaption
    }

    ComboBox {
        id: choice
        Layout.fillWidth: true
        implicitHeight: 38
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeSmall
        palette.text: Theme.popupText
        palette.buttonText: Theme.popupText
        palette.base: Theme.popupSurface
        palette.window: Theme.popupSurface
        palette.button: Theme.popupSurface
        palette.highlight: Theme.popupBorder
        palette.highlightedText: Theme.popupText
        onActivated: index => root.chosen(index)
        background: Rectangle {
            radius: 9
            color: Theme.popupSurface
            border.color: choice.activeFocus ? Theme.popupText : Theme.popupBorder
        }
    }
}
