import QtQuick
import Quickshell

Item {
    id: root
    property var widgetSettings: ({
            textColor: "#ffffff"
        })
    readonly property real fit: Math.max(.1, Math.min(1, width / 850, height / 500))
    SystemClock {
        id: clock
        precision: SystemClock.Seconds
    }
    Column {
        anchors.centerIn: parent
        spacing: 12 * root.fit
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatDateTime(clock.date, "dddd")
            color: root.widgetSettings.textColor
            font.family: "SF Pro Display"
            font.bold: true
            font.pointSize: 90 * root.fit
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatDateTime(clock.date, "dd MMMM")
            color: root.widgetSettings.textColor
            font.family: "SF Pro Display"
            font.bold: true
            font.pointSize: 40 * root.fit
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatDateTime(clock.date, "- hh:mm -")
            color: root.widgetSettings.textColor
            font.family: "SF Pro Display"
            font.bold: true
            font.pointSize: 20 * root.fit
        }
    }
}
