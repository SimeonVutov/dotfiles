import QtQuick
import QtQuick.Window

// A shared texture of one SatelliteArt. It is drawn at the screen's density and
// the layout scale, so it maps 1:1 onto the satellites instead of being scaled
// (which blurs the solar cells), and is redrawn only when the art or the window
// changes, so it stays sharp and survives window rebuilds.
ShaderEffectSource {
    // Scale the satellites are laid out at.
    property real layoutScale: 1

    readonly property real margin: 3
    readonly property real density: (Screen.devicePixelRatio || 1) * Math.max(.1, layoutScale)

    width: 0
    height: 0
    hideSource: true
    smooth: true
    // A transparent margin keeps the antialiased edges inside the texture.
    sourceRect: sourceItem ? Qt.rect(-margin, -margin, sourceItem.width + margin * 2, sourceItem.height + margin * 2) : Qt.rect(0, 0, 0, 0)
    textureSize: Qt.size(Math.ceil(sourceRect.width * density), Math.ceil(sourceRect.height * density))
}
