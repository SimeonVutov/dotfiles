pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Ui
import qs.Ui.Media
import qs.Services
import qs.Popups

BarModule {
    id: root

    moduleViewId: "media"
    readonly property string selectedView: ModuleViewState.selection("media")
    readonly property string view: autoView === "controls" ? "controls" : autoView === "noName" && selectedView === "full" ? "noName" : selectedView
    readonly property int titleWidth: Math.min(Config.media.textWidth, Math.ceil(titleMeasure.implicitWidth))
    preferredWidth: widthFor(selectedView)

    function widthFor(mode) {
        const buttons = previousButton.implicitWidth + playButton.width + nextButton.implicitWidth;
        const hasIndicator = Players.hasPlayer && mode !== "controls";
        const leading = hasIndicator ? indicator.implicitWidth + (mode === "full" ? 10 + titleWidth : 0) + 1 : 0;
        const spacing = Players.hasPlayer ? 12 : 6;
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
            spacing: Players.hasPlayer ? 12 : 6

            Item {
                id: nowPlaying
                width: !Players.hasPlayer || root.view === "controls" ? 0 : (root.view === "full" ? indicator.implicitWidth + 10 + root.titleWidth : indicator.implicitWidth)
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
                    playing: Players.isPlaying && root.visible && root.view !== "controls"
                    visible: Players.hasPlayer && root.view !== "controls"
                    stepDuration: Config.media.animationStepDuration
                }
                MarqueeText {
                    anchors.left: indicator.right
                    anchors.leftMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.max(0, nowPlaying.width - indicator.implicitWidth - 10)
                    text: root.view === "full" ? (Players.label || "Nothing playing") : ""
                    visible: Players.hasPlayer && root.view === "full" && width > 0
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
                    enabled: Players.hasPlayer && root.view !== "controls"
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
                enabled: Players.canGoPrevious
                onClicked: Players.previous()
            }
            PlaybackButton {
                id: playButton
                anchors.verticalCenter: parent.verticalCenter
                diameter: 25
                iconSize: 17
                iconColor: Players.isPlaying ? Theme.popupBackground : Theme.text
                playing: Players.isPlaying
                enabled: !!Players.activePlayer && Players.activePlayer.canTogglePlaying
                onClicked: Players.togglePlaying()
            }
            IconButton {
                id: nextButton
                anchors.verticalCenter: parent.verticalCenter
                icon: Icons.mediaNext
                size: 18
                enabled: Players.canGoNext
                onClicked: Players.next()
            }
        }
    }

    BarText {
        id: titleMeasure
        width: 0
        height: 0
        visible: false
        text: root.selectedView === "full" ? (Players.label || "Nothing playing") : ""
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
                anchorItem: pill
            }
        }
    }
}
