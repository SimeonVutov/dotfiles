import QtQuick
import Quickshell
import qs.Common
import qs.Ui
import qs.Services
import qs.Popups

// Transport controls plus "Title - Artist". Clicking the title opens the
// expanded player.
//
// All of this reads MPRIS directly through Services/Players.qml, which
// replaces the old media_player/*.sh scripts and the per-second playerctl
// calls they needed.
BarModule {
    id: root

    Pill {
        id: pill

        Row {
            spacing: Theme.groupSpacing

            IconButton {
                anchors.verticalCenter: parent.verticalCenter
                icon: Icons.mediaPrevious
                size: Theme.mediaControlFontSize
                enabled: Players.hasPlayer
                onClicked: Players.previous()
            }

            IconButton {
                anchors.verticalCenter: parent.verticalCenter
                icon: Players.isPlaying ? Icons.mediaPause : Icons.mediaPlay
                size: Theme.mediaControlFontSize
                enabled: Players.hasPlayer
                onClicked: Players.togglePlaying()
            }

            IconButton {
                anchors.verticalCenter: parent.verticalCenter
                icon: Icons.mediaNext
                size: Theme.mediaControlFontSize
                enabled: Players.canGoNext
                onClicked: Players.next()
            }

            // Collapses to nothing when there's no player, so the bar doesn't
            // keep a blank gap reserved.
            Item {
                anchors.verticalCenter: parent.verticalCenter
                width: Players.hasPlayer ? Config.media.textWidth : 0
                height: label.implicitHeight
                clip: true

                Behavior on width {
                    NumberAnimation {
                        duration: Theme.durationNormal
                        easing.type: Theme.easingEmphasized
                    }
                }

                BarText {
                    id: label
                    width: parent.width
                    font.pixelSize: Theme.fontSizeSmall
                    text: Players.label
                    elide: Text.ElideRight
                    opacity: Players.hasPlayer ? 1 : 0

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Theme.durationNormal
                            easing.type: Theme.easing
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    enabled: Players.hasPlayer
                    cursorShape: Qt.PointingHandCursor
                    onClicked: mediaPopup.toggle()
                }
            }
        }
    }

    MediaPopup {
        id: mediaPopup
        anchorItem: pill
    }
}
