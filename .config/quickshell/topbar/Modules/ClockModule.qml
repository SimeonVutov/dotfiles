pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.Common
import qs.Ui
import qs.Popups

// Left click opens the dashboard; right click toggles the date format.
BarModule {
    id: root

    property bool showAlt: false

    // Ticks on the minute rather than on a polling timer.
    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    Pill {
        id: pill

        BarText {
            id: label
            text: Qt.formatDateTime(clock.date, root.showAlt ? Config.clock.formatAlt : Config.clock.format)
        }
    }

    // Sits over the pill rather than inside it, so it doesn't feed back into
    // the pill's own sizing.
    MouseArea {
        anchors.fill: pill
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: mouse => {
            if (mouse.button === Qt.RightButton) {
                root.showAlt = !root.showAlt;
                return;
            }
            if (Config.clock.openDashboardOnClick)
                dashboard.toggle();
        }
    }

    PopupHost {
        id: dashboard
        popup: Component {
            Dashboard {
                anchorItem: pill
            }
        }
    }
}
