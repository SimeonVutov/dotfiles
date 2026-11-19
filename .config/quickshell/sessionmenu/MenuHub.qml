import QtQuick
import qs.Common as Shared

// The disc at the centre: a prompt that names the highlighted or armed action,
// and a line of guidance (or the error from the last action).
Rectangle {
    id: root

    required property var actions
    property bool busy: false
    property int highlighted: -1
    property string armedAction: ""
    property string error: ""

    readonly property real contentWidth: 190
    readonly property real contentSpacing: 10
    readonly property int promptFontSize: 20
    readonly property int captionFontSize: 11

    width: 230
    height: width
    radius: width / 2
    color: Shared.Theme.overlayBackground
    border.color: Shared.Theme.overlayBorder

    Column {
        anchors.centerIn: parent
        width: root.contentWidth
        spacing: root.contentSpacing

        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: root.busy ? "Please wait" : root.armedAction ? root.actions.find(a => a.name === root.armedAction).label + "?" : root.highlighted >= 0 ? root.actions[root.highlighted].label : "Take a pause"
            font {
                family: Shared.Theme.fontFamily
                pixelSize: root.promptFontSize
            }
            color: Shared.Theme.overlayText
        }

        Text {
            width: parent.width
            text: root.error || (root.armedAction ? "Press " + root.actions.find(a => a.name === root.armedAction).key + " again to confirm" : "Choose your next destination")
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            font {
                family: Shared.Theme.fontFamily
                pixelSize: root.captionFontSize
            }
            color: Shared.Theme.overlayMuted
        }
    }
}
