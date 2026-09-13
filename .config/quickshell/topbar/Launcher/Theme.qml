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

    readonly property string font: Shared.Theme.fontFamily
    readonly property int fontQuery: 24
    readonly property int fontGlyph: 30
    readonly property int fontLabel: 14
    readonly property int fontHeading: 13
    readonly property int fontCaption: 12

    readonly property int motion: Shared.Theme.overlayMotion
    readonly property int entranceDuration: 620
    readonly property int deliveryDuration: 250
    readonly property int fadeDuration: 170
    readonly property int beamExtendDuration: 340
    readonly property int beamBurstDuration: 180

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
