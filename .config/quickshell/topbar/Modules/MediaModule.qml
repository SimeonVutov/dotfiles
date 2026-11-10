pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Ui
import qs.Ui.Media
import qs.Core.Media
import qs.Popups

BarModule {
    id: root

    readonly property alias player: playback

    Player {
        id: playback
    }

    moduleViewId: "media"
    readonly property string trackLabel: root.player.title ? (root.player.artist ? root.player.title + Config.media.separator + root.player.artist : root.player.title) : ""
    readonly property string selectedView: ModuleViewState.selection("media")
    readonly property string view: autoView === "controls" ? "controls" : autoView === "noName" && selectedView === "full" ? "noName" : selectedView
    readonly property int titleWidth: Math.min(Config.media.textWidth, Math.ceil(titleMeasure.implicitWidth))
    preferredWidth: widthFor(selectedView)

    function widthFor(mode) {
        const buttons = previousButton.implicitWidth + playButton.width + nextButton.implicitWidth;
        const hasIndicator = root.player.hasPlayer && mode !== "controls";
        const leading = hasIndicator ? indicator.implicitWidth + (mode === "full" ? 10 + titleWidth : 0) + 1 : 0;
        const spacing = root.player.hasPlayer ? 12 : 6;
        return pill.paddingH * 2 + buttons + leading + (hasIndicator ? 4 : 2) * spacing;
    }

    function widthForCompression(state) {
        return widthFor(state.view || selectedView);
    }

    Pill {
        id: pill
        paddingH: 12
        animateWidth: false
        Row {
            spacing: root.player.hasPlayer ? 12 : 6

            Item {
                id: nowPlaying
                width: !root.player.hasPlayer || root.view === "controls" ? 0 : (root.view === "full" ? indicator.implicitWidth + 10 + root.titleWidth : indicator.implicitWidth)
                height: 25
                clip: true
                visible: width > 0
                anchors.verticalCenter: parent.verticalCenter
                Behavior on width {
                    NumberAnimation {
                        duration: Theme.durationNormal
                        easing.type: Theme.easingEmphasized
                    }
                }
                PlaybackIndicator {
                    id: indicator
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    playing: root.player.isPlaying && root.visible && root.view !== "controls"
                    visible: root.player.hasPlayer && root.view !== "controls"
                    stepDuration: Config.media.animationStepDuration
                }
                MarqueeText {
                    anchors.left: indicator.right
                    anchors.leftMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.max(0, nowPlaying.width - indicator.implicitWidth - 10)
                    text: root.view === "full" ? (root.trackLabel || "Nothing playing") : ""
                    visible: root.player.hasPlayer && root.view === "full" && width > 0
                    restartKey: root.player.trackKey
                    fontSize: Theme.fontSizeSmall
                    color: titleMouse.containsMouse || root.player.isPlaying ? Theme.text : Theme.popupSubtleText
                    pixelsPerSecond: Config.media.scrollPixelsPerSecond
                    startPause: Config.media.scrollStartPause
                    endPause: Config.media.scrollEndPause
                }
                MouseArea {
                    id: titleMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    enabled: root.player.hasPlayer && root.view !== "controls"
                    onClicked: mediaPopup.toggle()
                }
            }
            Divider {
                width: nowPlaying.width > 0 ? 1 : 0
                visible: width > 0
                length: 14
                anchors.verticalCenter: parent.verticalCenter
            }
            IconButton {
                id: previousButton
                anchors.verticalCenter: parent.verticalCenter
                icon: Icons.mediaPrevious
                size: 18
                enabled: root.player.canGoPrevious
                onClicked: root.player.previous()
            }
            PlaybackButton {
                id: playButton
                anchors.verticalCenter: parent.verticalCenter
                diameter: 25
                iconSize: 17
                iconColor: root.player.isPlaying ? Theme.popupBackground : Theme.text
                playing: root.player.isPlaying
                enabled: !!root.player.activePlayer && root.player.activePlayer.canTogglePlaying
                onClicked: root.player.togglePlaying()
            }
            IconButton {
                id: nextButton
                anchors.verticalCenter: parent.verticalCenter
                icon: Icons.mediaNext
                size: 18
                enabled: root.player.canGoNext
                onClicked: root.player.next()
            }
        }
    }

    BarText {
        id: titleMeasure
        width: 0
        height: 0
        visible: false
        text: root.selectedView === "full" ? (root.trackLabel || "Nothing playing") : ""
        font.pixelSize: Theme.fontSizeSmall
    }

    TapHandler {
        acceptedButtons: Qt.MiddleButton
        onTapped: mediaPopup.toggle()
    }

    PopupHost {
        id: mediaPopup
        popup: Component {
            MediaPopup {
                player: root.player
                anchorItem: pill
            }
        }
    }
}
