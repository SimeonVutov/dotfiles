pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Ui
import qs.Ui.Media
import qs.Services

// The expanded player: art, track, timeline, transport.
PopupPanel {
    id: root

    panelWidth: 400
    contentPadding: 18
    rowSpacing: Theme.popupSpacing
    overlayActive: sourcePicker.expanded
    onOverlayDismissed: sourcePicker.expanded = false
    overlayPage: Component {
        MediaSourceMenu {
            onDismissed: sourcePicker.expanded = false
        }
    }

    // Position updates only run while this is actually on screen.
    onOpenChanged: {
        Players.watchPosition(open);
        if (!open)
            sourcePicker.expanded = false;
    }
    Component.onDestruction: {
        if (open)
            Players.watchPosition(false);
    }

    Item {
        Layout.fillWidth: true
        implicitHeight: 132

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
                font.pixelSize: Theme.fontSize
                font.bold: true
                elide: Text.ElideRight
                textFormat: Text.PlainText
            }

            Text {
                width: parent.width
                text: Players.artist || Players.identity
                color: Theme.popupSubtleText
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeLabel
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
                    font.pixelSize: Theme.fontSizeTiny
                    textFormat: Text.PlainText
                }

                Text {
                    anchors.right: parent.right
                    text: Players.formatTime(Players.length)
                    color: Theme.popupSubtleText
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeTiny
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
                    enabled: Players.canGoPrevious
                    onClicked: Players.previous()
                }

                PlaybackButton {
                    anchors.verticalCenter: parent.verticalCenter
                    diameter: 34
                    idleColor: Theme.popupAccent
                    iconColor: Theme.popupBackground
                    iconSize: 18
                    playing: Players.isPlaying
                    enabled: !!Players.activePlayer && Players.activePlayer.canTogglePlaying
                    onClicked: Players.togglePlaying()
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
    MediaSourcePicker {
        id: sourcePicker
        Layout.fillWidth: true
    }
}
