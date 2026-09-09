import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Common
import qs.Ui

PopupPanel {
    id: root

    panelWidth: 320
    contentPadding: 18
    rowSpacing: 12

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    Column {
        Layout.fillWidth: true
        spacing: 2

        BarText {
            text: Qt.formatDateTime(clock.date, "HH:mm")
            font.pixelSize: 40
        }

        BarText {
            text: Qt.formatDateTime(clock.date, "dddd, dd MMMM yyyy")
            color: Theme.popupSubtleText
            font.pixelSize: 12
        }
    }

    CalendarView {
        Layout.fillWidth: true
        today: clock.date
    }
}
