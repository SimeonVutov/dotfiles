pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.Common
import qs.Ui
import qs.Popups

BarModule {
    id: root

    moduleViewId: "clock"
    readonly property string selectedView: ModuleViewState.selection("clock")
    readonly property string view: autoView || selectedView
    preferredWidth: pill.paddingH * 2 + normalMeasure.implicitWidth

    function textFor(mode) {
        if (mode === "time")
            return Qt.formatDateTime(clock.date, "hh:mm AP");
        if (mode === "date")
            return Qt.formatDateTime(clock.date, "dd MMM");
        return Qt.formatDateTime(clock.date, mode === "longDate" ? Config.clock.formatAlt : Config.clock.format);
    }

    function widthForCompression(state) {
        return pill.paddingH * 2 + (state.view === "time" ? timeMeasure.implicitWidth : normalMeasure.implicitWidth);
    }

    // Ticks on the minute rather than on a polling timer.
    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    Pill {
        id: pill

        BarText {
            id: label
            text: root.textFor(root.view)
        }
    }

    BarText {
        id: normalMeasure
        visible: false
        width: 0
        height: 0
        text: root.textFor(root.selectedView)
    }

    BarText {
        id: timeMeasure
        visible: false
        width: 0
        height: 0
        text: root.textFor("time")
    }

    // Sits over the pill rather than inside it, so it doesn't feed back into
    // the pill's own sizing.
    MouseArea {
        anchors.fill: pill
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton
        onClicked: mouse => {
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
