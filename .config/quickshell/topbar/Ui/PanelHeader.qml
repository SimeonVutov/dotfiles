import QtQuick
import QtQuick.Layouts
import qs.Common

RowLayout {
    id: root
    property string icon: ""
    property string title: ""
    property string subtitle: ""
    spacing: Theme.popupSpacing

    Rectangle {
        implicitWidth: 42
        implicitHeight: 42
        radius: width / 2
        color: Theme.popupSurface
        BarText {
            anchors.centerIn: parent
            text: root.icon
            font.pixelSize: 18
        }
    }
    Column {
        Layout.fillWidth: true
        spacing: 2
        BarText {
            width: parent.width
            text: root.title
            font.pixelSize: 15
            font.bold: true
            elide: Text.ElideRight
        }
        BarText {
            width: parent.width
            text: root.subtitle
            visible: text !== ""
            font.pixelSize: 12
            color: Theme.popupSubtleText
            elide: Text.ElideRight
        }
    }
}
