import QtQuick
import QtQuick.Window

// Lift-off fire and smoke, and re-entry plasma (shaders/smoke.frag).
// They are soft, so they render at a fraction of the screen's resolution and
// are scaled up, which keeps the flight light on slower GPUs.
Item {
    id: root

    // A Flight.js state.
    required property var flight
    property real clock: 0
    // Camera shake, in screen heights.
    property point shake: Qt.point(0, 0)
    // The cockpit window (centre and half size, in screen heights) the plasma wraps.
    property rect pane: Qt.rect(0, 0, 1, 1)

    readonly property real unit: Math.max(1, height)
    readonly property real density: (Window.window ? Window.window.devicePixelRatio : 1) * Theme.smokeResolution

    visible: flight.pad > 0 || flight.fire > 0 || flight.plasma > 0
    layer.enabled: visible
    layer.smooth: true
    layer.textureSize: Qt.size(Math.ceil(width * density), Math.ceil(height * density))

    ShaderEffect {
        anchors.fill: parent

        property point shake: root.shake
        property rect pane: root.pane
        property real aspect: root.width / root.unit
        property real clock: root.clock
        property real pad: root.flight.pad
        property real padRise: root.flight.padRise
        property real padDrop: root.flight.padDrop
        property real fire: root.flight.fire
        property real plasma: root.flight.plasma

        fragmentShader: Qt.resolvedUrl("shaders/smoke.frag.qsb")
    }
}
