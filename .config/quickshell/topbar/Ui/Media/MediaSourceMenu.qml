pragma ComponentBehavior: Bound

import QtQuick
import qs.Ui
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
                font.pixelSize: Theme.fontSize
                font.bold: true
            }
            CloseButton {
                anchors.right: parent.right
                onClicked: root.dismissed()
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

            ScrollBar.vertical: ThinScrollBar {
                id: scrollIndicator
            }

            Column {
                id: rows
                width: sources.width - (sources.contentHeight > sources.height ? scrollIndicator.gutter : 0)
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
