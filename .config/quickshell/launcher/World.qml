import QtQuick
import QtQuick.Window

// The desktop as the ground, the curved horizon, the sky and the globe: one
// surface whose curvature grows from flat to a planet (shaders/world.frag).
ShaderEffect {
    id: root

    // A Flight.js state; lengths are in screen heights.
    required property var flight
    // Texture provider holding the desktop capture.
    property Item surface: null
    // 1 once the capture has loaded; otherwise an ocean is drawn.
    property real hasSurface: 0
    property real clock: 0
    // Camera shake, in screen heights.
    property point shake: Qt.point(0, 0)

    readonly property real unit: Math.max(1, parent ? parent.height : 1)
    readonly property real screenWidth: parent ? parent.width : 0
    // Centre to the outer edge of the halo, in screen heights.
    readonly property real reach: 2.6 / Math.max(1e-4, flight.k)
    // Once no sky or ground fills the view, draw only the globe and its halo.
    readonly property rect box: {
        if (flight.sky > .001 || reach > 1.5)
            return Qt.rect(0, 0, screenWidth, unit);
        const left = Math.max(0, (flight.ox - reach) * unit);
        const top = Math.max(0, (flight.oy - reach) * unit);
        const right = Math.min(screenWidth, (flight.ox + reach) * unit);
        const bottom = Math.min(unit, (flight.oy + reach) * unit);
        return Qt.rect(left, top, Math.max(0, right - left), Math.max(0, bottom - top));
    }

    x: box.x
    y: box.y
    width: box.width
    height: box.height

    property variant source: surface
    property rect viewport: Qt.rect(box.x / unit, box.y / unit, box.width / unit, box.height / unit)
    readonly property real bend: Math.max(1e-4, flight.k)

    property point centre: Qt.point(flight.ox, flight.oy)
    // Per-pixel constants, worked out once per frame here.
    property point arcScale: Qt.point(1 / (bend * flight.wx), 1 / (bend * flight.wy))
    property real horizonDrop: Math.sin(-.5 * flight.wy * bend) / bend
    property real sharp: flight.wx >= aspect * .7 ? 1 : 0
    property real aspect: screenWidth / unit
    property real curvature: flight.k
    property real capTop: flight.capTop
    property real ball: flight.ball
    property real sky: flight.sky
    property real space: flight.space
    property real rim: flight.rim
    property real streak: flight.streak
    property real haze: flight.haze
    property real hazeEdges: flight.hazeEdges
    property real impact: flight.impact
    property real shockRadius: flight.shockRadius
    property real pixel: 1 / (unit * (Window.window ? Window.window.devicePixelRatio : 1))

    fragmentShader: Qt.resolvedUrl("shaders/world.frag.qsb")
}
