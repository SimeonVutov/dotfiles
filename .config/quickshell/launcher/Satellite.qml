import QtQuick
import Quickshell

Item {
    id: root

    required property int slot

    property point basePosition: Qt.point(0, 0)
    property real visualScale: 1
    property real globeRadius: Theme.globeRadius
    property var entry: null
    // Shared craft texture (a ShaderEffectSource over a SatelliteArt) and the
    // transparent margin it keeps around the art.
    property Item craftTexture: null
    property real craftArtMargin: 0

    property bool active: false
    property real arrival: 1
    property bool warming: false
    property bool tracking: false
    // The radio link's shared clock (seconds) and brightness (0..1).
    property real linkClock: 0
    property real linkStrength: 1
    property int linkEpoch: 0
    property bool selected: false
    property bool departing: false
    property real presence: 0

    readonly property real fadeEpsilon: .001
    readonly property real barelyVisible: .05
    readonly property real nearlySettled: .98

    readonly property bool accepted: active && entry !== null
    readonly property bool showingEntry: presence > fadeEpsilon
    readonly property bool moving: visible && showingEntry && arrival > barelyVisible && !departing
    readonly property bool beaming: tracking && accepted && presence > barelyVisible && arrival > nearlySettled

    // Deployment: each craft flies out from the planet to its orbit, in a few
    // staggered groups, growing to full size on the way.
    readonly property int deployGroups: 6
    readonly property real deployStagger: .32
    readonly property real deployDelay: slot % deployGroups / (deployGroups - 1) * deployStagger
    readonly property real deployed: Math.max(0, Math.min(1, (arrival - deployDelay) / (1 - deployDelay)))
    readonly property real deployReach: .18 + .82 * (1 - Math.pow(1 - deployed, 3))

    readonly property real centerOffsetX: basePosition.x + drift
    readonly property real centerOffsetY: basePosition.y + bob

    readonly property real bankScaleFloor: .01
    readonly property real bankPerDrift: .15
    readonly property real bankAngle: drift / Math.max(bankScaleFloor, visualScale) * bankPerDrift

    readonly property point iconCenter: {
        const offsetX = hull.x + hull.width / 2 - craft.width / 2;
        const offsetY = hull.y + hull.height / 2 - craft.height / 2;
        return Qt.point(craft.x + craft.width / 2 + offsetX * craft.scale, craft.y + craft.height / 2 + offsetY * craft.scale);
    }
    readonly property point beamStart: {
        const toIconX = iconCenter.x - width / 2;
        const toIconY = iconCenter.y - height / 2;
        const length = Math.max(1, Math.hypot(toIconX, toIconY));
        return Qt.point(width / 2 + toIconX / length * globeRadius, height / 2 + toIconY / length * globeRadius);
    }

    function iconPosition() {
        return iconCenter;
    }

    function beamOrigin() {
        return beamStart;
    }

    // The two fades hand off mid-flight: whichever starts stops the other, and a
    // running retire is never restarted so a dimming craft keeps its remaining time.
    function updatePresence() {
        if (active) {
            retire.stop();
            if (presence < 1)
                appear.restart();
        } else if (showingEntry) {
            appear.stop();
            if (!retire.running)
                retire.start();
        }
    }

    onActiveChanged: updatePresence()

    NumberAnimation {
        id: appear

        target: root
        property: "presence"
        to: 1
        duration: Theme.fadeDuration
        easing.type: Easing.OutCubic
    }

    NumberAnimation {
        id: retire

        target: root
        property: "presence"
        to: 0
        duration: Theme.fadeDuration
        easing.type: Easing.InCubic
    }

    readonly property int driftDurationMin: 1200
    readonly property int driftDurationMax: 2500

    property real drift: 0
    property real bob: 0
    property real driftTargetX: 0
    property real driftTargetY: 0
    property int driftDuration: driftDurationMin

    function wander() {
        if (!moving)
            return;
        driftTargetX = (Math.random() - .5) * Theme.craftDriftX * visualScale;
        driftTargetY = (Math.random() - .5) * Theme.craftDriftY * visualScale;
        driftDuration = driftDurationMin + Math.floor(Math.random() * (driftDurationMax - driftDurationMin));
        movement.start();
    }

    onMovingChanged: {
        if (moving)
            wander();
        else
            movement.stop();
    }

    onVisualScaleChanged: {
        movement.stop();
        drift = 0;
        bob = 0;
        Qt.callLater(wander);
    }

    ParallelAnimation {
        id: movement

        NumberAnimation {
            target: root
            property: "drift"
            to: root.driftTargetX
            duration: root.driftDuration
            easing.type: Easing.InOutSine
        }
        NumberAnimation {
            target: root
            property: "bob"
            to: root.driftTargetY
            duration: root.driftDuration
            easing.type: Easing.InOutSine
        }

        onFinished: Qt.callLater(root.wander)
    }

    Beam {
        startX: root.beamStart.x
        startY: root.beamStart.y
        endX: root.iconCenter.x
        endY: root.iconCenter.y
        connected: root.beaming
        highlighted: root.selected
        strength: root.linkStrength
        clock: root.linkClock
        epoch: root.linkEpoch
        seed: root.slot * .618 % 1
    }

    Item {
        id: craft

        objectName: "satelliteHitTarget"

        readonly property real hullSize: 76
        readonly property real iconSourceSize: 64
        readonly property real labelGap: 10
        readonly property Item art: root.craftTexture ? root.craftTexture.sourceItem : null
        readonly property bool highlighted: root.selected

        width: Theme.craftWidth
        height: Theme.craftHeight
        x: root.width / 2 + root.centerOffsetX * root.deployReach - width / 2
        y: root.height / 2 + root.centerOffsetY * root.deployReach - height / 2
        scale: root.visualScale * (highlighted ? Theme.craftHoverScale : 1)
        // While warming up, drawn at an invisible opacity rather than skipped.
        opacity: root.presence * Math.max(root.warming ? .004 : 0, Math.min(1, root.deployed * 3))
        // Growth during deployment, kept apart from the animated hover scale.
        transform: Scale {
            origin.x: craft.width / 2
            origin.y: craft.height / 2
            xScale: .5 + .5 * root.deployReach
            yScale: xScale
        }
        visible: root.entry !== null && opacity > 0

        Behavior on scale {
            NumberAnimation {
                duration: Theme.motion
                easing.type: Easing.OutCubic
            }
        }

        Item {
            id: body

            width: parent.width
            height: craft.hullSize
            rotation: root.bankAngle

            // The whole craft from the shared texture, placed so its bus lines up
            // with the hull below.
            ShaderEffect {
                readonly property real margin: root.craftArtMargin

                visible: craft.art !== null
                x: craft.art ? hull.x - craft.art.hullX - margin : 0
                y: craft.art ? hull.y - craft.art.hullY - margin : 0
                width: craft.art ? craft.art.width + margin * 2 : 0
                height: craft.art ? craft.art.height + margin * 2 : 0
                property variant source: root.craftTexture
            }

            Item {
                id: hull

                x: (body.width - width) / 2
                width: craft.hullSize
                height: craft.hullSize

                // Selection ring in the atmosphere colour, around the instrument face.
                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 6
                    radius: 14
                    color: "transparent"
                    border.color: Theme.atmosphere
                    border.width: 2
                    opacity: craft.highlighted ? 1 : 0
                    visible: opacity > 0

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Theme.motion
                        }
                    }
                }

                Image {
                    anchors.centerIn: parent
                    width: Theme.iconSize
                    height: Theme.iconSize
                    sourceSize.width: craft.iconSourceSize
                    sourceSize.height: craft.iconSourceSize
                    source: root.entry?.icon ? Quickshell.iconPath(root.entry.icon, true) : ""
                    asynchronous: true
                    opacity: root.departing ? 0 : 1

                    Text {
                        anchors.centerIn: parent
                        visible: parent.status !== Image.Ready
                        text: root.entry?.name?.charAt(0) || ""
                        font.family: Theme.font
                        font.pixelSize: Theme.fontGlyph
                        color: Theme.text
                    }
                }
            }
        }

        Text {
            y: body.height + craft.labelGap
            width: parent.width
            text: root.entry?.name || ""
            textFormat: Text.PlainText
            font.family: Theme.font
            font.pixelSize: Theme.fontLabel
            color: craft.highlighted ? Theme.text : Theme.muted
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
        }
    }
}
