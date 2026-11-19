pragma ComponentBehavior: Bound
import QtQuick
import qs.Common as Shared

Item {
    id: root

    MenuGeometry {
        id: menuGeometry
    }

    signal dismissed
    signal actionRequested(string action)
    property string error: ""
    property bool busy: false
    property int highlighted: -1
    // Keyboard actions require two presses; mouse clicks execute immediately.
    property string armedAction: ""
    // Mouse movement must not hide an armed keyboard action.
    readonly property int displayHighlighted: armedAction ? menuGeometry.actions.findIndex(a => a.name === armedAction) : highlighted
    property string backdrop: ""
    property bool presenting: true
    property real arrival: 0

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
            const index = menuGeometry.actions.findIndex(a => a.key === event.text.toUpperCase());
            if (index < 0)
                return;
            keyboardChoose(menuGeometry.actions[index].name, index);
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
            return menuGeometry.sectorAt(point.x, point.y, scene.width, scene.height);
        }
        onEntered: root.highlighted = indexAt(mouseX, mouseY)
        onPositionChanged: mouse => root.highlighted = indexAt(mouse.x, mouse.y)
        onExited: root.highlighted = -1
        cursorShape: root.highlighted >= 0 ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: mouse => {
            const index = indexAt(mouse.x, mouse.y);
            if (index >= 0)
                root.choose(menuGeometry.actions[index].name);
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

        SectorHighlights {
            geometry: menuGeometry
            highlighted: root.displayHighlighted
        }

        OrbitRings {
            anchors.fill: parent
            geometry: menuGeometry
            running: root.presenting && root.armed && root.visible
            paused: root.busy
        }

        MenuHub {
            anchors.centerIn: parent
            actions: menuGeometry.actions
            busy: root.busy
            highlighted: root.highlighted
            armedAction: root.armedAction
            error: root.error
        }

        Repeater {
            model: menuGeometry.actions

            PlanetButton {
                geometry: menuGeometry
                highlighted: root.displayHighlighted === index
                pressed: sectors.pressed
                enabled: !root.busy && !root.departing
                onKeyChosen: root.keyboardChoose(modelData.name, index)
            }
        }
    }
}
