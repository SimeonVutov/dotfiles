import QtQuick
import Quickshell
import qs.Common
import qs.Ui
import qs.Services

// The expanded player: art, track, timeline, transport.
PopupPanel {
    id: root

    panelWidth: 400
    panelHeight: 168

    // Position updates only run while this is actually on screen.
    onOpenChanged: Players.watchPosition(open)
    Component.onDestruction: {
        if (open)
            Players.watchPosition(false);
    }

    Item {
        anchors.fill: parent
        anchors.margins: 18

        AlbumArt {
            id: art
            width: 112
            height: 112
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            source: Players.artUrl
        }

        Column {
            anchors.left: art.right
            anchors.leftMargin: 18
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4

            Text {
                width: parent.width
                text: Players.title || "Nothing playing"
                color: Theme.popupText
                font.family: Theme.fontFamily
                font.pixelSize: 15
                font.bold: true
                elide: Text.ElideRight
                textFormat: Text.PlainText
            }

            Text {
                width: parent.width
                text: Players.artist || Players.identity
                color: Theme.popupSubtleText
                font.family: Theme.fontFamily
                font.pixelSize: 13
                elide: Text.ElideRight
                textFormat: Text.PlainText
                visible: text !== ""
            }

            Item {
                width: 1
                height: 8
            }

            SeekBar {
                width: parent.width
                visible: Players.length > 0
            }

            Item {
                width: parent.width
                height: 14
                visible: Players.length > 0

                Text {
                    anchors.left: parent.left
                    text: Players.formatTime(Players.position)
                    color: Theme.popupSubtleText
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                    textFormat: Text.PlainText
                }

                Text {
                    anchors.right: parent.right
                    text: Players.formatTime(Players.length)
                    color: Theme.popupSubtleText
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                    textFormat: Text.PlainText
                }
            }

            Item {
                width: 1
                height: 4
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 22

                IconButton {
                    anchors.verticalCenter: parent.verticalCenter
                    icon: Icons.mediaPrevious
                    size: 20
                    color: Theme.popupText
                    enabled: Players.hasPlayer
                    onClicked: Players.previous()
                }

                Rectangle {
                    width: 34
                    height: 34
                    radius: 17
                    color: Theme.popupAccent
                    anchors.verticalCenter: parent.verticalCenter

                    IconButton {
                        anchors.centerIn: parent
                        icon: Players.isPlaying ? Icons.mediaPause : Icons.mediaPlay
                        size: 18
                        color: Theme.popupBackground
                        enabled: Players.hasPlayer
                        onClicked: Players.togglePlaying()
                    }
                }

                IconButton {
                    anchors.verticalCenter: parent.verticalCenter
                    icon: Icons.mediaNext
                    size: 20
                    color: Theme.popupText
                    enabled: Players.canGoNext
                    onClicked: Players.next()
                }
            }
        }
    }
}
