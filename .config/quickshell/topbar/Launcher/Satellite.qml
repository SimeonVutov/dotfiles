import QtQuick
import Quickshell

Item {
    id: root

    required property int slot

    property point basePosition: Qt.point(0, 0)
    property real visualScale: 1
    property real globeRadius: Theme.globeRadius
    property var entry: null

    property bool active: false
    property real arrival: 1
    property bool tracking: false
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

    readonly property real entranceLift: 65
    readonly property int entranceStaggerSlots: 8
    readonly property real entranceStaggerStep: 3
    readonly property real entranceRise: entranceLift + slot % entranceStaggerSlots * entranceStaggerStep

    readonly property real centerOffsetX: basePosition.x + drift
    readonly property real centerOffsetY: basePosition.y + bob

    readonly property real bankScaleFloor: .01
    readonly property real bankPerDrift: .15
    readonly property real bankAngle: drift / Math.max(bankScaleFloor, visualScale) * bankPerDrift

    function iconPosition() {
        const offsetX = hull.x + hull.width / 2 - craft.width / 2;
        const offsetY = hull.y + hull.height / 2 - craft.height / 2;
        return Qt.point(craft.x + craft.width / 2 + offsetX * craft.scale, craft.y + craft.height / 2 + offsetY * craft.scale);
    }

    function beamOrigin() {
        const icon = iconPosition();
        const toIconX = icon.x - width / 2;
        const toIconY = icon.y - height / 2;
        const length = Math.max(1, Math.hypot(toIconX, toIconY));
        return Qt.point(width / 2 + toIconX / length * globeRadius, height / 2 + toIconY / length * globeRadius);
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
        startX: root.beamOrigin().x
        startY: root.beamOrigin().y
        endX: root.iconPosition().x
        endY: root.iconPosition().y
        connected: root.beaming
    }

    Item {
        id: craft

        objectName: "satelliteHitTarget"

        readonly property real hullSize: 76
        readonly property real hullRadius: 18
        readonly property real hullOutlineInset: 4
        readonly property real iconSourceSize: 64
        readonly property real arrayInsetX: 4
        readonly property real arrayInsetY: 16
        readonly property real labelGap: 10
        readonly property bool highlighted: root.selected

        width: Theme.craftWidth
        height: Theme.craftHeight
        x: root.width / 2 + root.centerOffsetX - width / 2
        y: root.height / 2 + root.centerOffsetY - height / 2 + (1 - root.arrival) * root.entranceRise
        scale: root.visualScale * (highlighted ? Theme.craftHoverScale : 1)
        opacity: root.presence * root.arrival
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

            SolarArray {
                x: craft.arrayInsetX
                y: craft.arrayInsetY
            }
            SolarArray {
                x: body.width - craft.arrayInsetX - width
                y: craft.arrayInsetY
                mirrored: true
            }

            Rectangle {
                id: hull

                x: (body.width - width) / 2
                width: craft.hullSize
                height: craft.hullSize
                radius: craft.hullRadius
                color: craft.highlighted ? Theme.surfaceHover : Theme.surface
                border.color: root.selected ? Theme.text : Theme.borderBright

                Behavior on color {
                    ColorAnimation {
                        duration: Theme.motion
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: craft.hullOutlineInset
                    radius: parent.radius - anchors.margins
                    color: "transparent"
                    border.color: Theme.border
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
