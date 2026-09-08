import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.Common

// Shared plumbing for anything that drops down from the bar: window placement,
// the open/close animation, and dismissing on a click elsewhere. Panels put
// their content inside and set panelWidth/panelHeight.
PopupWindow {
    id: root

    property Item anchorItem: null
    property bool open: false
    property int panelWidth: 320
    property int panelHeight: 200
    property int gap: 6

    default property alias content: panel.data

    function toggle() {
        open = !open;
    }

    function close() {
        open = false;
    }

    anchor.item: anchorItem
    anchor.rect.y: anchorItem ? anchorItem.height + gap : 0

    implicitWidth: panelWidth
    implicitHeight: panelHeight
    color: "transparent"

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

        opacity: root.open ? Theme.popupOpacity : 0
        scale: root.open ? 1 : 0.96
        y: root.open ? 0 : -10
        transformOrigin: Item.Top

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
