import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.Common
import qs.Ui

// Workspaces for the monitor this bar is on.
//
// Which workspaces exist on which monitor is Hyprland's business — the monitor
// switcher scripts keep those rules current, and this just renders whatever
// the compositor currently reports. That means layout switches show up here
// immediately, with no bar restart.
//
// Visually this is a fixed row of circular numbers with one accent capsule
// that springs to whichever is active — the capsule's motion is what shows a
// switch, not any per-button resizing, so a click reads as instant and the
// hover state (a plain ring) never fights it for space.
BarModule {
    id: root

    readonly property var hyprMonitor: screen ? Hyprland.monitorFor(screen) : null

    readonly property var workspaces: {
        const all = Hyprland.workspaces.values;
        // Positive ids only: negatives are Hyprland's special/scratchpad workspaces.
        return all.filter(w => w.id > 0 && w.monitor === hyprMonitor).sort((a, b) => a.id - b.id);
    }

    readonly property int activeId: (hyprMonitor && hyprMonitor.activeWorkspace) ? hyprMonitor.activeWorkspace.id : -1
    readonly property int activeIndex: workspaces.findIndex(w => w.id === activeId)

    readonly property real cellSize: Theme.barHeight - Theme.pillMarginV * 2 - 8
    readonly property real cellStride: cellSize + Theme.workspaceSpacing

    Pill {
        id: pill

        paddingH: 4

        Item {
            id: track
            width: Math.max(0, root.workspaces.length * root.cellStride - Theme.workspaceSpacing)
            height: root.cellSize

            // The one thing that actually moves. A spring reacts the instant
            // the active id changes and keeps going after — no fixed duration
            // to wait out, so a switch never feels like it's catching up.
            Rectangle {
                id: indicator
                visible: root.activeIndex >= 0
                width: root.cellSize
                height: root.cellSize
                radius: height / 2
                color: Theme.workspaceActiveBackground
                x: root.activeIndex * root.cellStride

                Behavior on x {
                    SpringAnimation {
                        spring: 3.2
                        damping: 0.32
                        mass: 0.5
                    }
                }
            }

            Row {
                spacing: Theme.workspaceSpacing

                Repeater {
                    model: root.workspaces

                    Item {
                        id: cell

                        required property var modelData

                        readonly property bool isActive: modelData.id === root.activeId

                        width: root.cellSize
                        height: root.cellSize

                        // Hover ring: pure opacity, zero layout impact, so it
                        // can never fight the indicator for space.
                        Rectangle {
                            anchors.fill: parent
                            radius: height / 2
                            color: "transparent"
                            border.width: 1.5
                            border.color: Theme.workspaceActiveBackground
                            opacity: !cell.isActive && hover.containsMouse ? 0.9 : 0

                            Behavior on opacity {
                                NumberAnimation {
                                    duration: Theme.durationFast
                                    easing.type: Theme.easing
                                }
                            }
                        }

                        BarText {
                            anchors.centerIn: parent
                            text: cell.modelData.name
                            font.pixelSize: Theme.fontSizeSmall
                            font.bold: true
                            color: cell.isActive ? Theme.workspaceActiveText : Theme.text

                            Behavior on color {
                                ColorAnimation {
                                    duration: Theme.durationFast
                                }
                            }
                        }

                        MouseArea {
                            id: hover
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: cell.modelData.activate()
                        }
                    }
                }
            }
        }
    }

    MouseArea {
        anchors.fill: pill
        acceptedButtons: Qt.NoButton
        enabled: Config.workspaces.scrollToSwitch
        onWheel: wheel => {
            Hyprland.dispatch(wheel.angleDelta.y > 0 ? "workspace r-1" : "workspace r+1");
        }
    }
}
