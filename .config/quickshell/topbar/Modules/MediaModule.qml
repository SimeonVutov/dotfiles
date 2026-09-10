import QtQuick
import qs.Common
import qs.Ui
import qs.Services
import qs.Popups

BarModule {
    id: root

    Pill {
        id: pill
        paddingH: 12
        animateWidth: false
        Row {
            spacing: Players.hasPlayer ? 12 : 6
            Item {
                width: Players.hasPlayer ? Config.media.textWidth : 0
                height: 25
                clip: true
                anchors.verticalCenter: parent.verticalCenter
                Behavior on width {
                    NumberAnimation {
                        duration: Theme.durationFast
                        easing.type: Theme.easingEmphasized
                    }
                }
                PlaybackIndicator {
                    id: indicator
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    playing: Players.isPlaying && root.visible
                    visible: Players.hasPlayer
                    stepDuration: Config.media.animationStepDuration
                }
                MarqueeText {
                    anchors.left: indicator.right
                    anchors.leftMargin: 10
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: Players.label || "Nothing playing"
                    visible: Players.hasPlayer
                    restartKey: Players.trackKey
                    fontSize: Theme.fontSizeSmall
                    color: titleMouse.containsMouse || Players.isPlaying ? Theme.text : Theme.popupSubtleText
                    pixelsPerSecond: Config.media.scrollPixelsPerSecond
                    startPause: Config.media.scrollStartPause
                    endPause: Config.media.scrollEndPause
                }
                MouseArea {
                    id: titleMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    enabled: Players.hasPlayer
                    onClicked: mediaPopup.toggle()
                }
            }
            Rectangle {
                width: Players.hasPlayer ? 1 : 0
                height: 14
                anchors.verticalCenter: parent.verticalCenter
                color: Theme.popupBorder
            }
            IconButton {
                anchors.verticalCenter: parent.verticalCenter
                icon: Icons.mediaPrevious
                size: 18
                enabled: Players.canGoPrevious
                onClicked: Players.previous()
            }
            Rectangle {
                width: 25
                height: 25
                radius: 13
                anchors.verticalCenter: parent.verticalCenter
                color: Players.isPlaying ? Theme.popupAccent : Theme.popupSurface
                Behavior on color {
                    ColorAnimation {
                        duration: Theme.durationFast
                    }
                }
                IconButton {
                    anchors.centerIn: parent
                    icon: Players.isPlaying ? Icons.mediaPause : Icons.mediaPlay
                    size: 17
                    color: Players.isPlaying ? Theme.popupBackground : Theme.text
                    enabled: !!Players.activePlayer && Players.activePlayer.canTogglePlaying
                    onClicked: Players.togglePlaying()
                }
            }
            IconButton {
                anchors.verticalCenter: parent.verticalCenter
                icon: Icons.mediaNext
                size: 18
                enabled: Players.canGoNext
                onClicked: Players.next()
            }
        }
    }
    MediaPopup {
        id: mediaPopup
        anchorItem: pill
    }
}
