pragma ComponentBehavior: Bound
import QtQuick

Item {
    id: root
    signal dismissed
    signal actionRequested(string action)
    property string error: ""
    property bool busy: false
    property int highlighted: -1
    // Keyboard safety net, for every action: a first press of the shortcut
    // arms it (highlights only), a second press of the *same* key fires it.
    // Any other key re-arms instead of firing, so there is no way to trigger
    // an action by typing past it. The mouse never arms — clicking a sector
    // always fires immediately, per root.choose().
    property string armedAction: ""
    // What should actually look highlighted: an armed action stays pinned
    // there even if the mouse then wanders elsewhere, since arming it is a
    // keyboard commitment that a stray mouse move shouldn't visually undo.
    readonly property int displayHighlighted: armedAction ? actions.findIndex(a => a.name === armedAction) : highlighted
    property string backdrop: ""
    property bool presenting: true
    property real arrival: 0

    // Nothing is painted until there is something to distort. A mapped but
    // empty surface is indistinguishable from having no overlay at all, so
    // opening never flashes black while grim is still running, and the capture
    // stays clean because the menu is not in it yet. The first painted frame
    // is the undistorted snapshot, which matches what was already on screen.
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
        root.armed = false;
        root.arrival = 0;
    }
    // No capture means nothing to swirl: fall back to the rings rather than
    // holding an invisible window open forever.
    Timer {
        interval: 500
        running: root.presenting && !root.armed
        onTriggered: root.arm()
    }
    NumberAnimation {
        id: arrivalAnimation
        target: root
        property: "arrival"
        from: 0
        to: 1
        duration: 1000
        easing.type: Easing.Linear
        onFinished: root.backdrop = ""
    }
    // Coordinates are in the scene's local space, including on scaled displays.
    function sectorAt(x, y) {
        const dx = x - scene.width / 2;
        const dy = y - scene.height / 2;
        const radius = Math.sqrt(dx * dx + dy * dy);
        if (radius < 122)
            return -1;
        const angle = Math.atan2(dy, dx) * 180 / Math.PI;
        return Math.floor(((angle + 120 + 360) % 360) / 60);
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
        if (event.key === Qt.Key_Escape) {
            if (root.armedAction)
                root.armedAction = "";
            else
                dismissed();
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
        color: Theme.abyss
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
        enabled: root.arrival >= 1 && !root.busy
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
        width: 600
        height: 630
        readonly property real reveal: Math.max(0, Math.min(1, (root.arrival - 0.72) / 0.28))
        // Expand concentrically from the core; keep every action at its final angle.
        readonly property real expansion: 1 - Math.pow(1 - reveal, 3)
        scale: Math.min(1, (root.width - 24) / width, (root.height - 24) / height) * (0.015 + 0.985 * expansion)
        opacity: Math.min(1, reveal * 8)
        layer.enabled: root.arrival < 1
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
                        duration: Theme.motion
                    }
                }
                onPaint: {
                    const ctx = getContext("2d");
                    ctx.reset();
                    const start = (index * 60 - 119) * Math.PI / 180;
                    const end = (index * 60 - 61) * Math.PI / 180;
                    ctx.beginPath();
                    ctx.arc(width / 2, height / 2, 282, start, end);
                    ctx.arc(width / 2, height / 2, 122, end, start, true);
                    ctx.closePath();
                    ctx.fillStyle = "#141414";
                    ctx.fill();
                    ctx.beginPath();
                    ctx.arc(width / 2, height / 2, 281, start, end);
                    ctx.strokeStyle = Theme.muted;
                    ctx.lineWidth = 1;
                    ctx.stroke();
                }
            }
        }

        Rectangle {
            anchors.centerIn: parent
            width: 406
            height: width
            radius: width / 2
            color: "transparent"
            border.color: Theme.border
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
                    running: root.visible
                    paused: root.busy
                }
                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: "transparent"
                    border.color: "#232323"
                }
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: -height / 2
                    width: orbit.modelData.size
                    height: width
                    radius: width / 2
                    color: Theme.muted
                    Rectangle {
                        anchors.centerIn: parent
                        width: parent.width + 6
                        height: width
                        radius: width / 2
                        color: "transparent"
                        border.color: "#353535"
                        visible: orbit.modelData.size > 6
                    }
                }
            }
        }

        Rectangle {
            anchors.centerIn: parent
            width: 230
            height: width
            radius: width / 2
            color: Theme.background
            border.color: Theme.border
            Column {
                anchors.centerIn: parent
                width: 190
                spacing: 10
                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: root.busy ? "Please wait" : root.armedAction ? root.actions.find(a => a.name === root.armedAction).label + "?" : root.highlighted >= 0 ? root.actions[root.highlighted].label : "Take a pause"
                    font {
                        family: Theme.font
                        pixelSize: 20
                    }
                    color: Theme.text
                }
                Text {
                    width: parent.width
                    text: root.error || (root.armedAction ? "Press " + root.actions.find(a => a.name === root.armedAction).key + " again to confirm" : "Choose your next destination")
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    font {
                        family: Theme.font
                        pixelSize: 11
                    }
                    color: Theme.muted
                }
            }
        }

        Repeater {
            model: root.actions
            delegate: Item {
                id: planet
                required property var modelData
                required property int index
                width: 104
                height: 108
                x: scene.width / 2 + Math.cos(modelData.angle * Math.PI / 180) * 203 - width / 2
                y: scene.height / 2 + Math.sin(modelData.angle * Math.PI / 180) * 203 - 36
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 72
                    height: width
                    radius: width / 2
                    color: root.displayHighlighted === planet.index || planet.activeFocus ? Theme.text : Theme.surface
                    border.color: Theme.border
                    scale: root.displayHighlighted === planet.index ? (sectors.pressed ? 0.94 : 1.09) : 1
                    Behavior on color {
                        ColorAnimation {
                            duration: Theme.motion
                        }
                    }
                    Behavior on scale {
                        NumberAnimation {
                            duration: Theme.motion
                        }
                    }
                    Text {
                        anchors.centerIn: parent
                        text: planet.modelData.glyph
                        color: root.displayHighlighted === planet.index || planet.activeFocus ? Theme.background : Theme.text
                        font {
                            family: Theme.font
                            pixelSize: 24
                        }
                    }
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 82
                    text: planet.modelData.label + "  ·  " + planet.modelData.key
                    color: Theme.text
                    font {
                        family: Theme.font
                        pixelSize: 12
                    }
                }
                activeFocusOnTab: true
                enabled: !root.busy
                Keys.onSpacePressed: root.keyboardChoose(modelData.name, planet.index)
                Keys.onReturnPressed: root.keyboardChoose(modelData.name, planet.index)
            }
        }
    }
}
