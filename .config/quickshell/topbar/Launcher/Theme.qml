pragma Singleton

import QtQuick
import Quickshell
import qs.Common as Shared

Singleton {
    readonly property color background: Shared.Theme.overlayBackground
    readonly property color surface: Shared.Theme.overlaySurface
    readonly property color surfaceHover: Shared.Theme.overlaySurfaceHover
    readonly property color border: Shared.Theme.overlayBorder
    readonly property color borderBright: Shared.Theme.overlayBorderBright
    readonly property color text: Shared.Theme.overlayText
    readonly property color muted: Shared.Theme.overlayMuted
    readonly property color selection: Shared.Theme.overlaySelection

    // The atmosphere colour the beams and the search capsule share with the planet.
    readonly property color atmosphere: "#73b8ff"
    // The search capsule's glass in front of the planet.
    readonly property color glass: "#d9070b14"

    readonly property string font: Shared.Theme.fontFamily
    readonly property int fontQuery: 24
    readonly property int fontSearch: 17
    readonly property int fontGlyph: 30
    readonly property int fontLabel: 14
    readonly property int fontHeading: 13
    readonly property int fontCaption: 12

    readonly property int motion: Shared.Theme.overlayMotion
    // Lift-off, the horizon curving into the globe, and the launcher deploying
    // around it (Flight.js holds the timeline).
    readonly property int entranceDuration: 1300
    // Cancelled in orbit: the capsule falls back, re-enters and touches down.
    readonly property int landingDuration: 660
    // Cancelled during lift-off: the flight settles straight back onto the pad.
    readonly property int abortDuration: 420
    readonly property real abortBefore: .42
    // A second cancel skips the rest of a landing (after the first moments, so
    // one key press reaching two handlers counts once).
    readonly property real skipAfter: .08
    readonly property int skipDuration: 160
    // An app was chosen: its icon flies down the beam, then the globe swells
    // back into the desktop the app opens on.
    readonly property int deliveryDuration: 250
    readonly property int exitDuration: 520

    // Entrance progress over which everything shown later is drawn once,
    // invisibly, to warm up its shaders and textures.
    readonly property real warmFrom: .03
    readonly property real warmUntil: .09

    // Deep space behind the flight.
    readonly property color space: "#020307"
    // Smoke, plume and plasma render at this fraction of the screen's resolution.
    readonly property real smokeResolution: .34
    // The capsule's window during a landing, as fractions of the screen, and
    // its corner radius in screen heights.
    readonly property real paneWidth: .86
    readonly property real paneHeight: .82
    readonly property real paneCorner: .1
    // The touchdown's flash.
    readonly property color flash: "#fff1dc"
    // Room around the view so camera shake never uncovers an edge.
    readonly property real shakeMargin: 16

    readonly property int fadeDuration: 170
    // A satellite's radio link comes up when it matches the search; it fades
    // out with the satellite (fadeDuration) when the search drops it.
    readonly property int linkRiseDuration: 280

    // Keeps the settled closing frame visible before the overlay unmaps.
    readonly property int settleDelay: 32

    readonly property real globeRadius: 145
    readonly property real iconSize: 48

    // One satellite's craft, and the box it drifts through. Shared because the
    // scatter layout has to reserve this footprint before any craft exists.
    readonly property real craftWidth: 186
    readonly property real craftHeight: 106
    readonly property real craftDriftX: 64
    readonly property real craftDriftY: 52
    readonly property real craftHoverScale: 1.055

    // Slack beyond the drift box for the name label under the craft and the
    // hover scale-up, so neighbours never overlap.
    readonly property real craftClearanceX: 47
    readonly property real craftClearanceY: 21
}
