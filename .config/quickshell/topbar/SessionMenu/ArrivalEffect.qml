import QtQuick
import qs.Common as Shared

Item {
    id: root
    property real progress: 0
    property string source: ""
    // Raised once the capture is decoded and safe to paint, not merely fetched.
    signal ready
    visible: progress < 1

    readonly property int shockwaveCount: 3
    readonly property real shockwaveStagger: 0.08
    // Shared by the shockwave phase and both ends of the event horizon's growth
    // so the two effects can't be pulled out of sync by editing only one.
    readonly property real growthWindow: 0.6
    readonly property real shockwaveBaseSize: 30
    readonly property real shockwaveSpread: 1.15
    readonly property real shockwaveShrinkPower: 1.6
    readonly property real shockwaveOpacity: 0.45

    readonly property real eventHorizonMaxDiameter: 300
    readonly property real eventHorizonFadeWindow: 0.4

    Image {
        id: snapshot
        anchors.fill: parent
        source: root.source
        visible: false
        cache: false
        asynchronous: false
        onStatusChanged: if (status === Image.Ready)
            root.ready()
    }
    // Void behind the vortex: whatever the hole has already eaten stays black
    // instead of showing the live desktop through the drained pixels.
    Rectangle {
        anchors.fill: parent
        color: Shared.Theme.overlayAbyss
    }
    ShaderEffect {
        anchors.fill: parent
        visible: snapshot.status === Image.Ready
        property variant source: snapshot
        property real progress: root.progress
        property real aspect: width / Math.max(1, height)
        fragmentShader: Qt.resolvedUrl("shaders/arrival.frag.qsb")
    }

    // Collapsing shockwaves. Also the whole effect when no capture is available.
    Repeater {
        model: root.shockwaveCount
        Rectangle {
            required property int index
            readonly property real phase: Math.max(0, Math.min(1, (root.progress - index * root.shockwaveStagger) / root.growthWindow))
            anchors.centerIn: parent
            width: root.shockwaveBaseSize + Math.max(root.width, root.height) * root.shockwaveSpread * Math.pow(1 - phase, root.shockwaveShrinkPower)
            height: width
            radius: width / 2
            color: "transparent"
            border.width: index === 0 ? 2 : 1
            border.color: Shared.Theme.overlayMuted
            opacity: Math.sin(phase * Math.PI) * root.shockwaveOpacity
        }
    }
    // Event horizon growing at the centre.
    Rectangle {
        anchors.centerIn: parent
        readonly property real phase: Math.min(1, root.progress / root.growthWindow)
        width: root.eventHorizonMaxDiameter * phase * (1 - Math.max(0, (root.progress - root.growthWindow) / root.eventHorizonFadeWindow))
        height: width
        radius: width / 2
        color: Shared.Theme.overlayAbyss
        border.width: 1
        border.color: Shared.Theme.overlayBorder
    }
}
