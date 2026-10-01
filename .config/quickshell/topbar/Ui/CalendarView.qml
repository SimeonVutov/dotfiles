pragma ComponentBehavior: Bound

import QtQuick
import qs.Common

Item {
    id: root

    property date today: new Date()
    property int viewYear: today.getFullYear()
    property int viewMonth: today.getMonth()
    property int direction: 1

    readonly property int navButtonSize: 28
    readonly property int navButtonCount: 4

    readonly property bool showingToday: viewYear === today.getFullYear() && viewMonth === today.getMonth()
    readonly property string monthLabel: Qt.formatDate(new Date(viewYear, viewMonth, 1), "MMMM yyyy")
    readonly property var calendarCells: {
        const first = new Date(viewYear, viewMonth, 1);
        const offset = (first.getDay() + 6) % 7;
        const cells = [];
        for (let index = 0; index < 42; index++) {
            const date = new Date(viewYear, viewMonth, index - offset + 1);
            cells.push({
                day: date.getDate(),
                inMonth: date.getMonth() === viewMonth,
                isToday: date.getFullYear() === today.getFullYear() && date.getMonth() === today.getMonth() && date.getDate() === today.getDate()
            });
        }
        return cells;
    }

    implicitHeight: 247

    function move(months) {
        const next = new Date(viewYear, viewMonth + months, 1);
        direction = months > 0 ? 1 : -1;
        viewYear = next.getFullYear();
        viewMonth = next.getMonth();
        reveal.restart();
    }

    function reset() {
        direction = today > new Date(viewYear, viewMonth, 1) ? 1 : -1;
        viewYear = today.getFullYear();
        viewMonth = today.getMonth();
        reveal.restart();
    }

    component NavigationButton: Rectangle {
        required property string label
        required property int months

        implicitWidth: root.navButtonSize
        implicitHeight: root.navButtonSize
        radius: 8
        color: mouse.containsMouse ? Theme.popupBorder : "transparent"

        Behavior on color {
            ColorAnimation {
                duration: Theme.durationFast
            }
        }

        BarText {
            anchors.centerIn: parent
            text: parent.label
            font.pixelSize: Theme.fontSizeLarge
        }

        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.move(parent.months)
        }
    }

    Column {
        anchors.fill: parent
        spacing: 6

        Row {
            id: navRow
            width: parent.width
            spacing: 4

            NavigationButton {
                label: "«"
                months: -12
            }
            NavigationButton {
                label: "‹"
                months: -1
            }

            BarText {
                // Fills the space left by the 4 nav buttons and the gaps around them.
                width: parent.width - root.navButtonCount * (root.navButtonSize + navRow.spacing)
                height: root.navButtonSize
                text: root.monthLabel
                font.pixelSize: Theme.fontSize
                font.bold: true
                horizontalAlignment: Text.AlignHCenter
            }

            NavigationButton {
                label: "›"
                months: 1
            }
            NavigationButton {
                label: "»"
                months: 12
            }
        }

        Item {
            id: monthContent
            width: parent.width
            height: 183

            Column {
                anchors.fill: parent
                spacing: 3

                Row {
                    width: parent.width

                    Repeater {
                        model: ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]

                        BarText {
                            required property string modelData
                            width: parent.width / 7
                            height: 17
                            text: modelData
                            color: Theme.popupSubtleText
                            font.pixelSize: Theme.fontSizeTiny
                            horizontalAlignment: Text.AlignHCenter
                        }
                    }
                }

                Grid {
                    width: parent.width
                    columns: 7

                    Repeater {
                        model: root.calendarCells

                        Item {
                            required property var modelData
                            width: parent.width / 7
                            height: 27

                            Rectangle {
                                anchors.centerIn: parent
                                width: 24
                                height: 24
                                radius: 12
                                color: parent.modelData.isToday ? Theme.popupAccent : "transparent"
                            }

                            BarText {
                                anchors.centerIn: parent
                                text: parent.modelData.day
                                color: parent.modelData.isToday ? Theme.popupBackground : (parent.modelData.inMonth ? Theme.popupText : Theme.popupSubtleText)
                                opacity: parent.modelData.inMonth || parent.modelData.isToday ? 1 : 0.45
                                font.pixelSize: Theme.fontSizeCaption
                                font.bold: parent.modelData.isToday
                            }
                        }
                    }
                }
            }
        }

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 58
            height: 24
            radius: 12
            color: todayMouse.containsMouse || !root.showingToday ? Theme.popupBorder : "transparent"
            opacity: root.showingToday ? 0.55 : 1

            Behavior on color {
                ColorAnimation {
                    duration: Theme.durationFast
                }
            }
            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.durationFast
                }
            }

            BarText {
                anchors.centerIn: parent
                text: "Today"
                font.pixelSize: Theme.fontSizeTiny
            }

            MouseArea {
                id: todayMouse
                anchors.fill: parent
                hoverEnabled: true
                enabled: !root.showingToday
                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: root.reset()
            }
        }
    }

    ParallelAnimation {
        id: reveal

        NumberAnimation {
            target: monthContent
            property: "x"
            from: root.direction * 10
            to: 0
            duration: Theme.durationNormal
            easing.type: Theme.easingEmphasized
        }
        NumberAnimation {
            target: monthContent
            property: "opacity"
            from: 0.45
            to: 1
            duration: Theme.durationNormal
            easing.type: Theme.easing
        }
    }
}
