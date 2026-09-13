import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import qs.Common

// Shared chrome, content grid, and floating-menu layer for every panel.
PopupWindow {
    id: root

    // A footer error line, styled identically wherever a popup shows one.
    component ErrorBanner: BarText {
        Layout.fillWidth: true
        Layout.preferredHeight: visible ? implicitHeight : 0
        visible: text !== ""
        color: Theme.graphTemperature
        font.pixelSize: Theme.fontSizeTiny
        wrapMode: Text.WordWrap
        maximumLineCount: 2
        elide: Text.ElideRight
    }

    property Item anchorItem: null
    property bool open: false
    property int panelWidth: 320
    property int minimumPanelHeight: 0
    property int panelHeight: Math.max(minimumPanelHeight, layout.implicitHeight + contentPadding * 2)
    property bool animateHeight: false
    property bool smoothAnchorMovement: false
    property real anchorOffsetX: anchorItem ? Math.round((anchorItem.width - panelWidth) / 2) : 0
    property int contentPadding: Theme.popupPadding
    property alias columns: layout.columns
    property alias rowSpacing: layout.rowSpacing
    property alias columnSpacing: layout.columnSpacing
    readonly property alias overlayItem: overlay
    property Component overlayPage: null
    property bool overlayActive: false
    signal overlayDismissed
    property int gap: 6

    default property alias content: layout.data

    function toggle() {
        open = !open;
    }

    function close() {
        open = false;
    }

    Behavior on anchorOffsetX {
        enabled: root.smoothAnchorMovement && root.open
        SmoothedAnimation {
            duration: Theme.durationFast
            easing.type: Theme.easingEmphasized
        }
    }

    anchor.item: anchorItem
    anchor.rect.x: anchorOffsetX
    anchor.rect.y: anchorItem ? anchorItem.height + gap : 0
    anchor.edges: Edges.Top | Edges.Left
    anchor.gravity: Edges.Bottom | Edges.Right
    anchor.adjustment: PopupAdjustment.SlideX | PopupAdjustment.SlideY

    implicitWidth: panelWidth
    implicitHeight: panelHeight
    color: "transparent"

    Behavior on panelHeight {
        enabled: root.animateHeight
        NumberAnimation {
            duration: Theme.durationNormal
            easing.type: Theme.easingEmphasized
        }
    }

    // Stays mapped until the close animation has finished playing out.
    visible: open || panel.opacity > 0.01

    // Hyprland tells us when the user clicked somewhere else.
    HyprlandFocusGrab {
        active: root.open
        windows: [root]
        onCleared: root.open = false
    }

    Rectangle {
        id: panel

        width: root.panelWidth
        height: root.panelHeight
        radius: Theme.popupRadius
        color: Theme.popupBackground
        border.color: Theme.popupBorder
        border.width: 1
        clip: root.animateHeight

        opacity: root.open ? Theme.popupOpacity : 0
        scale: root.open ? 1 : 0.96
        y: root.open ? 0 : -10
        transformOrigin: Item.Top

        GridLayout {
            id: layout

            x: root.contentPadding
            y: root.contentPadding
            width: parent.width - root.contentPadding * 2
            columns: 1
            columnSpacing: Theme.popupSpacing
            rowSpacing: Theme.popupSectionSpacing
            enabled: !root.overlayPage || !root.overlayActive
            opacity: root.overlayPage && root.overlayActive ? 0 : 1

            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.durationFast
                }
            }
        }

        Item {
            id: overlay
            anchors.fill: parent
            z: 10
            MouseArea {
                anchors.fill: parent
                enabled: root.overlayActive
                onClicked: root.overlayDismissed()
            }

            // Content pages share the existing window and never affect its size.
            Loader {
                anchors.fill: parent
                anchors.margins: root.contentPadding
                sourceComponent: root.overlayPage
                active: root.overlayPage !== null
                enabled: root.overlayActive
                visible: opacity > 0
                opacity: root.overlayActive ? 1 : 0
                scale: root.overlayActive ? 1 : 0.985
                transformOrigin: Item.Bottom
                focus: root.overlayActive && active
                Keys.onEscapePressed: root.overlayDismissed()

                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.durationFast
                    }
                }
                Behavior on scale {
                    NumberAnimation {
                        duration: Theme.durationFast
                        easing.type: Theme.easingEmphasized
                    }
                }
            }
        }

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.durationFast
                easing.type: Theme.easing
            }
        }

        Behavior on scale {
            NumberAnimation {
                duration: Theme.durationNormal
                easing.type: Theme.easingEmphasized
            }
        }

        Behavior on y {
            NumberAnimation {
                duration: Theme.durationNormal
                easing.type: Theme.easingEmphasized
            }
        }
    }
}
