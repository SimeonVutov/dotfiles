import QtQuick

// Sizes, timings and colours shared by the picker's wallpaper cards.
QtObject {
    readonly property int cardWidth: 400
    readonly property int cardHeight: 420
    readonly property real expandedCardWidth: cardWidth * 1.5
    readonly property real collapsedCardWidth: cardWidth * 0.5
    readonly property int expandedCardHeight: cardHeight + 30
    readonly property int cardSpacing: 10
    readonly property int borderWidth: 3
    readonly property real skewFactor: -0.35
    readonly property int cardTransitionDuration: 260
    readonly property int cardFadeDuration: 220
    readonly property int thumbnailMinWidth: 900
    readonly property int thumbnailMinHeight: 540
    readonly property real thumbnailResolutionScale: 1.35
    readonly property int thumbnailOverscan: 80
    readonly property color placeholderBackdrop: "#0d0d0d"
    readonly property color badgeScrim: "#99000000"
    readonly property color appliedBadgeInk: "#10131a"
    readonly property color nameplateScrim: "#cc000000"
}
