import QtQuick

Item {
    id: root
    property real progress: 0
    property string source: ""
    // Raised once the capture is decoded and safe to paint, not merely fetched.
    signal ready
    visible: progress < 1

    Image {
        id: snapshot
        anchors.fill: parent
        source: root.source
        visible: false
        cache: false
        // Local file, loaded synchronously: assigning the source decodes it in
        // the same call stack, so readiness is deterministic and the window can
        // map on an already-populated scene instead of an empty one.
        asynchronous: false
        onStatusChanged: if (status === Image.Ready)
            root.ready()
    }
    // Void behind the vortex: whatever the hole has already eaten stays black
    // instead of showing the live desktop through the drained pixels.
    Rectangle {
        anchors.fill: parent
        color: Theme.abyss
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
        model: 3
        Rectangle {
            required property int index
            readonly property real phase: Math.max(0, Math.min(1, (root.progress - index * 0.08) / 0.6))
            anchors.centerIn: parent
            width: 30 + Math.max(root.width, root.height) * 1.15 * Math.pow(1 - phase, 1.6)
            height: width
            radius: width / 2
            color: "transparent"
            border.width: index === 0 ? 2 : 1
            border.color: Theme.muted
            opacity: Math.sin(phase * Math.PI) * 0.45
        }
    }
    // Event horizon growing at the centre.
    Rectangle {
        anchors.centerIn: parent
        readonly property real phase: Math.min(1, root.progress / 0.6)
        width: 300 * phase * (1 - Math.max(0, (root.progress - 0.6) / 0.4))
        height: width
        radius: width / 2
        color: Theme.abyss
        border.width: 1
        border.color: Theme.border
    }
}
