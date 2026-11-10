import QtQuick
import Quickshell
import ".."

Widget {
    id: root

    widgetType: "clock"
    designWidth: referenceSize.width * 8 / 18
    designHeight: referenceSize.height / 2

    SystemClock {
        id: clock
        precision: SystemClock.Seconds
    }

    Repeater {
        model: [
            {
                format: "dddd",
                size: 90,
                offset: 350
            },
            {
                format: "dd MMMM",
                size: 40,
                offset: 250
            },
            {
                format: "- hh:mm AP -",
                size: 20,
                offset: 190
            }
        ]

        delegate: Text {
            required property var modelData
            anchors.horizontalCenter: parent.horizontalCenter
            y: root.referenceSize.height / 2 - modelData.offset - height / 2
            text: Qt.formatDateTime(clock.date, modelData.format).replace(/ (AM|PM)/, "")
            color: root.settings.textColor
            font.family: "SF Pro Display"
            font.bold: true
            font.pointSize: modelData.size
        }
    }
}
