import QtQuick

Item {
    id: root

    property real progress: 0
    property string snapshot: ""
    signal snapshotReady

    readonly property bool captureReady: capture.status === Image.Ready
    readonly property real groundFade: Math.min(1, progress * 3)
    readonly property real starFade: Math.min(1, progress * 2)

    QtObject {
        id: stars

        readonly property int count: 140
        readonly property real rise: 80
        readonly property real riseStep: 30
        readonly property int riseVariants: 7
        readonly property real streak: 30
        readonly property real streakStep: 18
        readonly property int streakVariants: 6
        readonly property real dimmest: .15
        readonly property real brightStep: .12
        readonly property int brightVariants: 5
        readonly property int brightEvery: 9
    }

    Image {
        id: capture

        anchors.fill: parent
        source: root.snapshot
        visible: false
        cache: false
        // Synchronous: arming waits on Image.Ready, so a background decode would
        // race the open watchdog and drop the capture.
        asynchronous: false
        onStatusChanged: if (root.captureReady)
            root.snapshotReady()
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.background
        opacity: root.captureReady ? 1 : root.groundFade
    }

    Repeater {
        model: stars.count

        Rectangle {
            required property int index

            // Coprime strides distribute stars without storing a position table.
            readonly property real seedX: ((index * 197 + 61) % 997) / 997
            readonly property real seedY: ((index * 109 + 37) % 991) / 991

            readonly property real travel: Math.pow(Math.sin(root.progress * Math.PI), 3)
            readonly property real rise: stars.rise + index % stars.riseVariants * stars.riseStep
            readonly property real streak: stars.streak + index % stars.streakVariants * stars.streakStep

            x: seedX * root.width
            y: (seedY * root.height + travel * rise) % Math.max(1, root.height)
            width: index % stars.brightEvery === 0 ? 2 : 1
            height: width + travel * streak
            radius: width / 2
            color: Theme.text
            opacity: (stars.dimmest + index % stars.brightVariants * stars.brightStep) * root.starFade
        }
    }

    ShaderEffect {
        anchors.fill: parent
        property variant source: capture
        property real progress: root.progress
        property real hasCapture: root.captureReady ? 1 : 0

        fragmentShader: Qt.resolvedUrl("shaders/ascent.frag.qsb")
    }
}
