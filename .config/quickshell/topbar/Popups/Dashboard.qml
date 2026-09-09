pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Ui
import qs.Services

// Dashboard: who you are, the time, a month calendar, and whatever is playing.
PopupPanel {
    id: root

    panelWidth: 340

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    FileView {
        id: hostnameFile
        path: "/etc/hostname"
    }

    readonly property string username: Quickshell.env("USER") || "user"
    readonly property string hostname: (hostnameFile.text() || "").trim()

    // ── Calendar maths ─────────────────────────────────────────
    readonly property date today: clock.date
    readonly property int viewYear: today.getFullYear()
    readonly property int viewMonth: today.getMonth()

    // 42 cells, Monday first. 0 means "not part of this month".
    readonly property var calendarCells: {
        const first = new Date(viewYear, viewMonth, 1);
        const offset = (first.getDay() + 6) % 7;
        const daysInMonth = new Date(viewYear, viewMonth + 1, 0).getDate();
        const cells = [];
        for (let i = 0; i < 42; i++) {
            const day = i - offset + 1;
            cells.push(day >= 1 && day <= daysInMonth ? day : 0);
        }
        return cells;
    }

    PanelHeader {
        Layout.fillWidth: true
        icon: Icons.person
        title: root.username
        subtitle: root.hostname
    }

    Column {
        Layout.fillWidth: true
        spacing: 2

        Text {
            text: Qt.formatDateTime(clock.date, "HH:mm")
            color: Theme.popupText
            font.family: Theme.fontFamily
            font.pixelSize: 46
            textFormat: Text.PlainText
        }

        Text {
            text: Qt.formatDateTime(clock.date, "dddd, dd MMMM yyyy")
            color: Theme.popupSubtleText
            font.family: Theme.fontFamily
            font.pixelSize: 13
            textFormat: Text.PlainText
        }
    }

    Column {
        Layout.fillWidth: true
        spacing: 6

        Row {
            width: parent.width

            Repeater {
                model: ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]

                Text {
                    required property var modelData
                    width: (parent.width) / 7
                    text: modelData
                    color: Theme.popupSubtleText
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                    horizontalAlignment: Text.AlignHCenter
                    textFormat: Text.PlainText
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

                    readonly property bool isToday: modelData === root.today.getDate()

                    width: parent.width / 7
                    height: 28

                    Rectangle {
                        anchors.centerIn: parent
                        width: 26
                        height: 26
                        radius: 13
                        color: parent.isToday ? Theme.popupAccent : "transparent"
                    }

                    Text {
                        anchors.centerIn: parent
                        text: parent.modelData > 0 ? parent.modelData : ""
                        color: parent.isToday ? Theme.popupBackground : Theme.popupText
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        font.bold: parent.isToday
                        textFormat: Text.PlainText
                    }
                }
            }
        }
    }

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: 64
        radius: 12
        color: Theme.popupSurface

        Row {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 12

            AlbumArt {
                width: 44
                height: 44
                radius: 8
                anchors.verticalCenter: parent.verticalCenter
                source: Players.artUrl
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 44 - 34 - 24
                spacing: 2

                Text {
                    width: parent.width
                    text: Players.title || "Nothing playing"
                    color: Theme.popupText
                    font.family: Theme.fontFamily
                    font.pixelSize: 13
                    elide: Text.ElideRight
                    textFormat: Text.PlainText
                }

                Text {
                    width: parent.width
                    text: Players.artist || Players.identity || "Open a player to get started"
                    color: Theme.popupSubtleText
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                    elide: Text.ElideRight
                    textFormat: Text.PlainText
                }
            }

            IconButton {
                anchors.verticalCenter: parent.verticalCenter
                icon: Players.isPlaying ? Icons.mediaPause : Icons.mediaPlay
                size: 20
                color: Theme.popupText
                enabled: !!Players.activePlayer && Players.activePlayer.canTogglePlaying
                onClicked: Players.togglePlaying()
            }
        }
    }
}
