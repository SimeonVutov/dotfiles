import QtQuick
import qs.Ui
import qs.Common

Rectangle {
    id: root

    property string title: ""
    property bool scanning: false
    property bool scanEnabled: true
    signal scanClicked

    implicitHeight: 36
    radius: 9
    color: Theme.popupSurface

    BarText {
        anchors.left: parent.left
        anchors.leftMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        text: root.scanning ? root.title + " · Scanning…" : root.title
        color: root.scanning ? Theme.popupText : Theme.popupSubtleText
        font.pixelSize: Theme.fontSizeCaption
    }

    ConnectionButton {
        anchors.right: parent.right
        anchors.rightMargin: 6
        anchors.verticalCenter: parent.verticalCenter
        text: root.scanning ? "Stop" : "Scan"
        subtle: true
        enabled: root.scanEnabled
        onClicked: root.scanClicked()
    }
}
