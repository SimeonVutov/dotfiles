import QtQuick
import QtQuick.Window

// The capsule's window frame during the landing (shaders/cockpit.frag). It
// slides in from past the screen edges and out again after touchdown.
ShaderEffect {
    id: root

    // A Flight.js state.
    required property var flight
    // The window: centre (x, y) and half size (width, height), in screen heights.
    required property rect pane
    property real clock: 0

    readonly property real unit: Math.max(1, parent ? parent.height : 1)

    // Draws one invisible pixel to build its pipeline before a landing.
    property bool warming: false
    readonly property bool shown: flight.frame > 0

    width: shown ? (parent ? parent.width : 0) : 1
    height: shown ? (parent ? parent.height : 0) : 1
    visible: shown || warming
    opacity: shown ? flight.frame : .004

    property real aspect: (parent ? parent.width : width) / unit
    property real corner: Theme.paneCorner * flight.frameZoom
    property real heat: flight.plasma
    property real pixel: 1 / (unit * (Window.window ? Window.window.devicePixelRatio : 1))

    fragmentShader: Qt.resolvedUrl("shaders/cockpit.frag.qsb")
}
