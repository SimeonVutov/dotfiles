import QtQuick
import Quickshell
import qs.Common

// One bar window, on one monitor. Transparent background — the pills are the
// only thing that paints, same as the old waybar setup.
PanelWindow {
    id: root

    required property var modelData

    screen: modelData
    color: "transparent"

    anchors {
        top: true
        left: true
        right: true
    }

    implicitHeight: Theme.barHeight
    exclusiveZone: Theme.barHeight

    Section {
        id: leftSection
        anchors.left: parent.left
        anchors.leftMargin: 5
        anchors.verticalCenter: parent.verticalCenter
        height: parent.height
        screen: root.screen
        section: "left"
        moduleIds: Config.modulesLeft
    }

    Section {
        id: centerSection
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        height: parent.height
        screen: root.screen
        section: "center"
        moduleIds: Config.modulesCenter
    }

    Section {
        id: rightSection
        anchors.right: parent.right
        anchors.rightMargin: 20
        anchors.verticalCenter: parent.verticalCenter
        height: parent.height
        screen: root.screen
        section: "right"
        moduleIds: Config.modulesRight
    }
}
