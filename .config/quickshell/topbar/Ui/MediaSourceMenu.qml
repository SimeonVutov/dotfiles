pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import qs.Common
import qs.Services

Item {
    id: root
    signal dismissed

    function choosePlayer(player) {
        Players.selectPlayer(player);
        dismissed();
    }

    onVisibleChanged: if (visible)
        sources.contentY = 0

    ColumnLayout {
        anchors.fill: parent
        spacing: 8

        Item {
            Layout.fillWidth: true
            implicitHeight: 30

            BarText {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: "Choose media source"
                font.pixelSize: 15
                font.bold: true
            }
            Rectangle {
                anchors.right: parent.right
                width: 28
                height: 28
                radius: 14
                color: dismiss.containsMouse ? Theme.popupBorder : Theme.popupSurface
                Behavior on color {
                    ColorAnimation {
                        duration: Theme.durationFast
                    }
                }

                IconButton {
                    id: dismiss
                    anchors.centerIn: parent
                    width: parent.width
                    height: parent.height
                    size: 12
                    icon: Icons.close
                    onClicked: root.dismissed()
                }
            }
        }

        Flickable {
            id: sources
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            contentHeight: rows.implicitHeight
            boundsBehavior: Flickable.StopAtBounds
            interactive: contentHeight > height

            ScrollBar.vertical: ScrollBar {
                id: scrollIndicator
                policy: ScrollBar.AsNeeded
                width: 3
                contentItem: Rectangle {
                    radius: width / 2
                    color: Theme.popupSubtleText
                    opacity: scrollIndicator.active ? 0.8 : 0.35
                }
                background: Item {}
            }

            Column {
                id: rows
                width: sources.width - (sources.contentHeight > sources.height ? 9 : 0)
                spacing: 3

                MediaSourceOption {
                    width: parent.width
                    title: "Automatic"
                    subtitle: "Follow the playing source"
                    icon: Icons.automatic
                    selected: Players.manualPlayerId === ""
                    onChosen: root.choosePlayer(null)
                }
                Repeater {
                    model: Players.allPlayers
                    MediaSourceOption {
                        required property var modelData
                        width: rows.width
                        title: Players.sourceName(modelData)
                        subtitle: (modelData.isPlaying ? "Playing · " : "") + (modelData.trackTitle || "No track information")
                        artUrl: modelData.trackArtUrl || ""
                        selected: Players.manualPlayerId === modelData.dbusName
                        onChosen: root.choosePlayer(modelData)
                    }
                }
            }
        }
    }
}
