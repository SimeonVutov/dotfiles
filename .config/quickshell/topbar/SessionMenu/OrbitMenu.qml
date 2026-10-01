pragma ComponentBehavior: Bound
import QtQuick
import qs.Common as Shared

Item {
    id: root
    signal dismissed
    signal actionRequested(string action)
    property string error: ""
    property bool busy: false
    property int highlighted: -1
    // Keyboard actions require two presses; mouse clicks execute immediately.
    property string armedAction: ""
    // Mouse movement must not hide an armed keyboard action.
    readonly property int displayHighlighted: armedAction ? actions.findIndex(a => a.name === armedAction) : highlighted
    property string backdrop: ""
    property bool presenting: true
    property real arrival: 0

    readonly property color sectorFill: "#141414"
    readonly property color orbitDotHalo: "#353535"

    readonly property int departureDuration: 400
    readonly property int arrivalDuration: 700

    // The reveal only starts in the last stretch of the arrival animation,
    // then the blast (departure) reverses scale and opacity on its own curve.
    readonly property real revealStartFraction: 0.72
    readonly property real revealWindowFraction: 1 - revealStartFraction
    readonly property real revealOpacityRate: 8
    readonly property real expansionEasePower: 3
    readonly property real expansionScaleFloor: 0.015
    readonly property real expansionScaleRange: 1 - expansionScaleFloor
    readonly property real departureScaleBoost: 5.0
    readonly property real departureScalePower: 0.7
    readonly property real departureOpacityPower: 0.55
    readonly property real departureOpacityRate: 2.6

    readonly property real sceneWidth: 600
    readonly property real sceneHeight: 630
    readonly property real sceneScreenMargin: 24

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

    readonly property real orbitRingDiameter: 406
    readonly property real orbitDotHaloPadding: 6
    readonly property real orbitDotHaloMinSize: 6

    readonly property real hubDiameter: 230
    readonly property real hubContentWidth: 190
    readonly property real hubContentSpacing: 10

    readonly property real planetBoxWidth: 104
    readonly property real planetBoxHeight: 108
    readonly property real planetButtonDiameter: 72
    readonly property real planetOrbitRadius: orbitRingDiameter / 2
    readonly property real planetVerticalAnchor: planetButtonDiameter / 2
    readonly property real planetLabelGap: 10
    readonly property real planetLabelY: planetButtonDiameter + planetLabelGap
    readonly property real planetHoverScale: 1.09
    readonly property real planetPressScale: 0.94

    readonly property int promptFontSize: 20
    readonly property int captionFontSize: 11
    readonly property int planetGlyphFontSize: 24
    readonly property int planetLabelFontSize: 12

    // Map only after decoding the capture to avoid black flashes and self-capture.
    property bool armed: false
    visible: armed

    function arm() {
        if (root.armed || !root.presenting)
            return;
        root.armed = true;
        arrivalAnimation.restart();
    }
    function reset() {
        root.error = "";
        root.highlighted = -1;
        root.armedAction = "";
    }
    onPresentingChanged: {
        arrivalAnimation.stop();
        departureAnimation.stop();
        root.armed = false;
        root.arrival = 0;
        root.departure = 0;
    }

    // Keep the surface mapped until the departure animation finishes.
    property real departure: 0
    readonly property bool departing: departureAnimation.running

    function dismiss() {
        if (root.departing)
            return;
        // During arrival the vortex covers the departure effect, so abort directly.
        if (root.arrival < 1) {
            root.dismissed();
            return;
        }
        departureAnimation.restart();
    }

    NumberAnimation {
        id: departureAnimation
        target: root
        property: "departure"
        from: 0
        to: 1
        duration: root.departureDuration
        // The shader owns the easing curve.
        easing.type: Easing.Linear
        onFinished: root.dismissed()
    }
    NumberAnimation {
        id: arrivalAnimation
        target: root
        property: "arrival"
        from: 0
        to: 1
        duration: root.arrivalDuration
        easing.type: Easing.Linear
        onFinished: root.backdrop = ""
    }
    // Coordinates are in the scene's local space, including on scaled displays.
    function sectorAt(x, y) {
        const dx = x - scene.width / 2;
        const dy = y - scene.height / 2;
        const radius = Math.sqrt(dx * dx + dy * dy);
        if (radius < root.sectorInnerRadius)
            return -1;
        const angle = Math.atan2(dy, dx) * 180 / Math.PI;
        return Math.floor(((angle + root.sectorHitAngleOffset + 360) % 360) / root.sectorAngleStep);
    }
    readonly property var actions: [
        {
            name: "lock",
            label: "Lock",
            key: "L",
            glyph: "\uf023",
            angle: -90
        },
        {
            name: "suspend",
            label: "Sleep",
            key: "U",
            glyph: "\uf186",
            angle: -30
        },
        {
            name: "hibernate",
            label: "Hibernate",
            key: "H",
            glyph: "\uf2dc",
            angle: 30
        },
        {
            name: "shutdown",
            label: "Shutdown",
            key: "S",
            glyph: "\uf011",
            angle: 90
        },
        {
            name: "reboot",
            label: "Restart",
            key: "R",
            glyph: "\uf021",
            angle: 150
        },
        {
            name: "exit",
            label: "Log out",
            key: "E",
            glyph: "\uf08b",
            angle: 210
        }
    ]
    function choose(action) {
        if (busy)
            return;
        error = "";
        actionRequested(action);
    }
    // Keyboard entry point: arms an action on first press, fires it on a
    // repeated press of the same shortcut.
    function keyboardChoose(action, index) {
        if (root.armedAction === action) {
            root.armedAction = "";
            choose(action);
        } else {
            root.armedAction = action;
            root.highlighted = index;
        }
    }
    focus: true
    Keys.onPressed: event => {
        if (root.busy || root.departing) {
            event.accepted = true;
            return;
        }

        if (event.key === Qt.Key_Escape) {
            if (root.armedAction)
                root.armedAction = "";
            else
                dismiss();
        } else {
            const index = actions.findIndex(a => a.key === event.text.toUpperCase());
            if (index < 0)
                return;
            keyboardChoose(actions[index].name, index);
        }
        event.accepted = true;
    }

    Rectangle {
        anchors.fill: parent
        color: Shared.Theme.overlayAbyss
        // Handing over to the blast is seamless: at progress 0 the shader is
        // opaque black too. Keeping the shader mounted instead of swapping
        // costs a wasted full-screen pass under the vortex every frame, which
        // is enough to make the open animation stutter.
        visible: root.departure === 0
    }
    ShaderEffect {
        anchors.fill: parent
        visible: root.departure > 0
        property real progress: root.departure
        property real aspect: width / Math.max(1, height)
        fragmentShader: Qt.resolvedUrl("shaders/bigbang.frag.qsb")
    }
    ArrivalEffect {
        anchors.fill: parent
        progress: root.arrival
        source: root.backdrop
        onReady: root.arm()
    }
    MouseArea {
        id: sectors
        anchors.fill: parent
        hoverEnabled: true
        enabled: root.arrival >= 1 && !root.busy && !root.departing
        function indexAt(x, y) {
            const point = mapToItem(scene, x, y);
            return root.sectorAt(point.x, point.y);
        }
        onEntered: root.highlighted = indexAt(mouseX, mouseY)
        onPositionChanged: mouse => root.highlighted = indexAt(mouse.x, mouse.y)
        onExited: root.highlighted = -1
        cursorShape: root.highlighted >= 0 ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: mouse => {
            const index = indexAt(mouse.x, mouse.y);
            if (index >= 0)
                root.choose(root.actions[index].name);
        }
    }

    Item {
        id: scene
        anchors.centerIn: parent
        width: root.sceneWidth
        height: root.sceneHeight
        readonly property real reveal: Math.max(0, Math.min(1, (root.arrival - root.revealStartFraction) / root.revealWindowFraction))
        // Expand concentrically from the core; keep every action at its final angle.
        readonly property real expansion: 1 - Math.pow(1 - reveal, root.expansionEasePower)
        // The blast throws the menu outward with everything else. It goes with
        // the leading edge, so it is gone before the front clears the corners.
        scale: Math.min(1, (root.width - root.sceneScreenMargin) / width, (root.height - root.sceneScreenMargin) / height) * (root.expansionScaleFloor + root.expansionScaleRange * expansion) * (1 + root.departureScaleBoost * Math.pow(root.departure, root.departureScalePower))
        opacity: Math.min(1, reveal * root.revealOpacityRate) * (1 - Math.min(1, Math.pow(root.departure, root.departureOpacityPower) * root.departureOpacityRate))
        layer.enabled: root.presenting && root.arrival < 1
        layer.effect: ShaderEffect {
            property real progress: scene.reveal
            fragmentShader: Qt.resolvedUrl("shaders/ejection.frag.qsb")
        }

        // Paint each sector once; only its opacity animates on hover.
        Repeater {
            model: 6
            Canvas {
                required property int index
                anchors.fill: parent
                opacity: root.displayHighlighted === index ? 1 : 0
                Behavior on opacity {
                    NumberAnimation {
                        duration: Shared.Theme.overlayMotion
                    }
                }
                onPaint: {
                    const ctx = getContext("2d");
                    ctx.reset();
                    const start = (index * root.sectorAngleStep + root.sectorAngleOffset - root.sectorHalfSpanDegrees) * Math.PI / 180;
                    const end = (index * root.sectorAngleStep + root.sectorAngleOffset + root.sectorHalfSpanDegrees) * Math.PI / 180;
                    ctx.beginPath();
                    ctx.arc(width / 2, height / 2, root.sectorOuterRadius, start, end);
                    ctx.arc(width / 2, height / 2, root.sectorInnerRadius, end, start, true);
                    ctx.closePath();
                    ctx.fillStyle = root.sectorFill;
                    ctx.fill();
                    ctx.beginPath();
                    ctx.arc(width / 2, height / 2, root.sectorStrokeRadius, start, end);
                    ctx.strokeStyle = Shared.Theme.overlayMuted;
                    ctx.lineWidth = root.sectorStrokeWidth;
                    ctx.stroke();
                }
            }
        }

        Rectangle {
            anchors.centerIn: parent
            width: root.orbitRingDiameter
            height: width
            radius: width / 2
            color: "transparent"
            border.color: Shared.Theme.overlayBorder
        }
        Repeater {
            model: [
                {
                    diameter: 268,
                    size: 5,
                    period: 18000,
                    phase: 20
                },
                {
                    diameter: 314,
                    size: 8,
                    period: 29000,
                    phase: 155
                },
                {
                    diameter: 358,
                    size: 4,
                    period: 41000,
                    phase: 260
                },
                {
                    diameter: 520,
                    size: 7,
                    period: 63000,
                    phase: 75
                }
            ]
            Item {
                id: orbit
                required property var modelData
                anchors.centerIn: parent
                width: modelData.diameter
                height: width
                NumberAnimation on rotation {
                    from: orbit.modelData.phase
                    to: orbit.modelData.phase + 360
                    duration: orbit.modelData.period
                    loops: Animation.Infinite
                    running: root.presenting && root.armed && root.visible
                    paused: root.busy
                }
                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: "transparent"
                    border.color: Shared.Theme.overlayOrbit
                }
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: -height / 2
                    width: orbit.modelData.size
                    height: width
                    radius: width / 2
                    color: Shared.Theme.overlayMuted
                    Rectangle {
                        anchors.centerIn: parent
                        width: parent.width + root.orbitDotHaloPadding
                        height: width
                        radius: width / 2
                        color: "transparent"
                        border.color: root.orbitDotHalo
                        visible: orbit.modelData.size > root.orbitDotHaloMinSize
                    }
                }
            }
        }

        Rectangle {
            anchors.centerIn: parent
            width: root.hubDiameter
            height: width
            radius: width / 2
            color: Shared.Theme.overlayBackground
            border.color: Shared.Theme.overlayBorder
            Column {
                anchors.centerIn: parent
                width: root.hubContentWidth
                spacing: root.hubContentSpacing
                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: root.busy ? "Please wait" : root.armedAction ? root.actions.find(a => a.name === root.armedAction).label + "?" : root.highlighted >= 0 ? root.actions[root.highlighted].label : "Take a pause"
                    font {
                        family: Shared.Theme.fontFamily
                        pixelSize: root.promptFontSize
                    }
                    color: Shared.Theme.overlayText
                }
                Text {
                    width: parent.width
                    text: root.error || (root.armedAction ? "Press " + root.actions.find(a => a.name === root.armedAction).key + " again to confirm" : "Choose your next destination")
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    font {
                        family: Shared.Theme.fontFamily
                        pixelSize: root.captionFontSize
                    }
                    color: Shared.Theme.overlayMuted
                }
            }
        }

        Repeater {
            model: root.actions
            delegate: Item {
                id: planet
                required property var modelData
                required property int index
                width: root.planetBoxWidth
                height: root.planetBoxHeight
                x: scene.width / 2 + Math.cos(modelData.angle * Math.PI / 180) * root.planetOrbitRadius - width / 2
                y: scene.height / 2 + Math.sin(modelData.angle * Math.PI / 180) * root.planetOrbitRadius - root.planetVerticalAnchor
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: root.planetButtonDiameter
                    height: width
                    radius: width / 2
                    color: root.displayHighlighted === planet.index || planet.activeFocus ? Shared.Theme.overlayText : Shared.Theme.overlaySurface
                    border.color: Shared.Theme.overlayBorder
                    scale: root.displayHighlighted === planet.index ? (sectors.pressed ? root.planetPressScale : root.planetHoverScale) : 1
                    Behavior on color {
                        ColorAnimation {
                            duration: Shared.Theme.overlayMotion
                        }
                    }
                    Behavior on scale {
                        NumberAnimation {
                            duration: Shared.Theme.overlayMotion
                        }
                    }
                    Text {
                        anchors.centerIn: parent
                        text: planet.modelData.glyph
                        color: root.displayHighlighted === planet.index || planet.activeFocus ? Shared.Theme.overlayBackground : Shared.Theme.overlayText
                        font {
                            family: Shared.Theme.fontFamily
                            pixelSize: root.planetGlyphFontSize
                        }
                    }
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: root.planetLabelY
                    text: planet.modelData.label + "  ·  " + planet.modelData.key
                    color: Shared.Theme.overlayText
                    font {
                        family: Shared.Theme.fontFamily
                        pixelSize: root.planetLabelFontSize
                    }
                }
                activeFocusOnTab: true
                enabled: !root.busy && !root.departing
                Keys.onSpacePressed: root.keyboardChoose(modelData.name, planet.index)
                Keys.onReturnPressed: root.keyboardChoose(modelData.name, planet.index)
            }
        }
    }
}
