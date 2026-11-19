import QtQuick

// The menu's actions and the geometry they share: the six sectors around the
// hub, and the orbit the action buttons sit on. Distances are in the scene's
// own pixels.
QtObject {
    id: root

    readonly property var actions: [
        {
            name: "lock",
            label: "Lock",
            key: "L",
            glyph: "",
            angle: -90
        },
        {
            name: "suspend",
            label: "Sleep",
            key: "U",
            glyph: "",
            angle: -30
        },
        {
            name: "hibernate",
            label: "Hibernate",
            key: "H",
            glyph: "",
            angle: 30
        },
        {
            name: "shutdown",
            label: "Shutdown",
            key: "S",
            glyph: "",
            angle: 90
        },
        {
            name: "reboot",
            label: "Restart",
            key: "R",
            glyph: "",
            angle: 150
        },
        {
            name: "exit",
            label: "Log out",
            key: "E",
            glyph: "",
            angle: 210
        }
    ]

    // A sector spans one action's worth of angle (360 / action count); its arc
    // is drawn a couple of degrees narrower to leave a hairline gap between
    // neighbours. sectorAngleOffset must stay in sync with actions[0].angle.
    readonly property real sectorAngleStep: 60
    readonly property real sectorAngleOffset: -90
    readonly property real sectorGapDegrees: 2
    readonly property real sectorHalfSpanDegrees: sectorAngleStep / 2 - sectorGapDegrees / 2
    readonly property real sectorHitAngleOffset: -sectorAngleOffset + sectorAngleStep / 2
    readonly property real sectorInnerRadius: 122
    readonly property real sectorOuterRadius: 282
    readonly property real sectorStrokeWidth: 1
    readonly property real sectorStrokeRadius: sectorOuterRadius - sectorStrokeWidth

    // The ring the action buttons sit on.
    readonly property real orbitRingDiameter: 406
    readonly property real planetOrbitRadius: orbitRingDiameter / 2

    // The sector under a point of the scene, or -1 over the hub. Coordinates
    // are in the scene's local space, including on scaled displays.
    function sectorAt(x, y, sceneWidth, sceneHeight) {
        const dx = x - sceneWidth / 2;
        const dy = y - sceneHeight / 2;
        const radius = Math.sqrt(dx * dx + dy * dy);
        if (radius < sectorInnerRadius)
            return -1;
        const angle = Math.atan2(dy, dx) * 180 / Math.PI;
        return Math.floor(((angle + sectorHitAngleOffset + 360) % 360) / sectorAngleStep);
    }
}
