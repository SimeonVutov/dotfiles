pragma ComponentBehavior: Bound

import QtQuick

Item {
    id: root

    property bool expanded: true
    property bool animateEntry: true
    property real progress: 0
    property bool initialized: false
    readonly property real opening: Math.sin(progress * Math.PI / 2)
    readonly property real flare: Math.sin(progress * Math.PI)
    default property alias content: planet.data
    signal closed()

    Component.onCompleted: {
        if (!animateEntry)
            progress = expanded ? 1 : 0;
        initialized = true;
        progress = Qt.binding(() => expanded ? 1 : 0);
    }

    onProgressChanged: if (initialized && !expanded && progress === 0)
        closed()
    onExpandedChanged: if (initialized && !expanded && progress === 0)
        closed()

    Behavior on progress {
        enabled: root.initialized && root.animateEntry
        NumberAnimation { duration: 300; easing.type: Easing.InOutCubic }
    }

    Item {
        id: planet
        anchors.fill: parent
        visible: root.progress > 0
        scale: 0.08 + 0.92 * root.opening + 0.02 * root.flare
        opacity: Math.min(1, root.progress * 3)
    }

    Item {
        anchors.centerIn: parent
        width: Math.max(0, Math.min(root.width, root.height) - 3) * root.opening
        height: width
        visible: root.animateEntry && root.progress > 0 && root.progress < 1

        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: "transparent"
            border.width: 3
            border.color: "#D8DEE5"
            opacity: root.flare * 0.08
            antialiasing: true
        }

        Rectangle {
            anchors.fill: parent
            anchors.margins: 2
            visible: parent.width > 4
            radius: width / 2
            color: "transparent"
            border.width: 2
            border.color: "#E8EFF8"
            opacity: root.flare * 0.2
            antialiasing: true
        }

        Rectangle {
            anchors.fill: parent
            anchors.margins: 3
            visible: parent.width > 6
            radius: width / 2
            color: "transparent"
            border.width: 1
            border.color: "#FFFFFF"
            opacity: root.flare * 0.65
            antialiasing: true
        }
    }
}
