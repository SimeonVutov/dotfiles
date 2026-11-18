import QtQuick

// A satellite's radio link to the planet (shaders/link.frag): arcs of signal
// rippling between the satellite's dish and a ground station on the planet.
// It comes up while the satellite matches the search, and fades out with the
// satellite when the search drops it.
ShaderEffect {
    id: root

    // The ground station on the planet (start) and the satellite (end).
    property real startX: 0
    property real startY: 0
    property real endX: 0
    property real endY: 0
    property bool connected: false
    property bool highlighted: false
    // 0..1, brighter when only a few satellites are linked.
    property real strength: 1
    // Seconds, shared by every link.
    property real clock: 0
    // 0..1, so neighbouring links do not ripple in step.
    property real seed: 0

    // Shader inputs.
    property color colour: Theme.atmosphere
    property real span: Math.max(1, Math.hypot(endX - startX, endY - startY))
    property real breadth: Math.min(70, 11 + span * .25)
    property real link: 0
    property real selected: highlighted ? 1 : 0
    // When the satellite became, and stopped being, the active one on the
    // shared clock, for the current and the two previous selections. Arcs sent
    // in those periods are the active stream, so arcs already on their way
    // finish their trip whatever is selected later; only new arcs follow the
    // current selection. The clock starts over each time the launcher opens,
    // so times from an earlier opening are dropped here.
    property real selectedSince: 1e9
    property real selectedUntil: -1
    property real previousSince: 1e9
    property real previousUntil: -1
    property real olderSince: 1e9
    property real olderUntil: -1
    property real activeSince: selectedSince > clock + 1 ? (highlighted ? 0 : 1e9) : selectedSince
    property real activeUntil: selectedUntil > clock + 1 && !highlighted ? -1 : selectedUntil
    property vector4d earlier: Qt.vector4d(
        previousSince > clock + 1 ? 1e9 : previousSince, previousSince > clock + 1 ? -1 : previousUntil,
        olderSince > clock + 1 ? 1e9 : olderSince, olderSince > clock + 1 ? -1 : olderUntil)

    // Bumped each time the launcher opens: the clock starts over then, so
    // every earlier selection is forgotten.
    property int epoch: 0

    onEpochChanged: {
        previousSince = 1e9;
        previousUntil = -1;
        olderSince = 1e9;
        olderUntil = -1;
        selectedSince = highlighted ? 0 : 1e9;
        selectedUntil = highlighted ? 1e9 : -1;
    }

    onHighlightedChanged: {
        if (highlighted) {
            olderSince = previousSince;
            olderUntil = previousUntil;
            previousSince = selectedSince;
            previousUntil = selectedUntil;
            selectedSince = clock;
            selectedUntil = 1e9;
        } else {
            selectedUntil = clock;
        }
    }
    Component.onCompleted: if (highlighted) {
        selectedSince = 0;
        selectedUntil = 1e9;
    }

    Behavior on selected {
        NumberAnimation {
            duration: Theme.motion
            easing.type: Easing.OutCubic
        }
    }

    x: startX
    y: startY - breadth / 2
    width: span
    height: breadth
    transformOrigin: Item.Left
    rotation: Math.atan2(endY - startY, endX - startX) * 180 / Math.PI
    visible: link > 0

    onConnectedChanged: {
        if (connected) {
            fade.stop();
            rise.restart();
        } else if (link > 0) {
            rise.stop();
            fade.restart();
        }
    }

    NumberAnimation {
        id: rise

        target: root
        property: "link"
        to: 1
        duration: Theme.linkRiseDuration
        easing.type: Easing.OutCubic
    }

    // Same timing as the satellite's own fade, so they leave together.
    NumberAnimation {
        id: fade

        target: root
        property: "link"
        to: 0
        duration: Theme.fadeDuration
        easing.type: Easing.InCubic
    }

    fragmentShader: Qt.resolvedUrl("shaders/link.frag.qsb")
}
