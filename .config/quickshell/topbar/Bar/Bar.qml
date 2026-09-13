import QtQuick
import Quickshell
import qs.Common

// One bar window per monitor.
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

    // Left/right clearance from the screen edge; the asymmetry predates this
    // refactor and its original rationale is undocumented.
    readonly property int edgeMarginLeft: 5
    readonly property int edgeMarginRight: 20

    Section {
        id: leftSection
        anchors.left: parent.left
        anchors.leftMargin: root.edgeMarginLeft
        anchors.verticalCenter: parent.verticalCenter
        height: parent.height
        screen: root.screen
        moduleIds: Config.modulesLeft
    }

    Section {
        id: centerSection
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        height: parent.height
        screen: root.screen
        moduleIds: Config.modulesCenter
    }

    Section {
        id: rightSection
        anchors.right: parent.right
        anchors.rightMargin: root.edgeMarginRight
        anchors.verticalCenter: parent.verticalCenter
        height: parent.height
        screen: root.screen
        moduleIds: Config.modulesRight
    }
}
