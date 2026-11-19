import QtQuick
import qs.Common as Shared

// One action: a round button on the orbit with its label underneath. It lights
// up while highlighted or focused.
Item {
    id: root

    required property var modelData
    required property int index
    required property MenuGeometry geometry
    property bool highlighted: false
    property bool pressed: false

    // The keyboard chose this action (Space or Return while it has the focus).
    signal keyChosen

    readonly property bool lit: highlighted || activeFocus

    readonly property real boxWidth: 104
    readonly property real boxHeight: 108
    readonly property real buttonDiameter: 72
    readonly property real verticalAnchor: buttonDiameter / 2
    readonly property real labelGap: 10
    readonly property real labelY: buttonDiameter + labelGap
    readonly property real hoverScale: 1.09
    readonly property real pressScale: 0.94
    readonly property int glyphFontSize: 24
    readonly property int labelFontSize: 12

    width: boxWidth
    height: boxHeight
    x: parent.width / 2 + Math.cos(modelData.angle * Math.PI / 180) * geometry.planetOrbitRadius - width / 2
    y: parent.height / 2 + Math.sin(modelData.angle * Math.PI / 180) * geometry.planetOrbitRadius - verticalAnchor

    activeFocusOnTab: true
    Keys.onSpacePressed: root.keyChosen()
    Keys.onReturnPressed: root.keyChosen()

    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        width: root.buttonDiameter
        height: width
        radius: width / 2
        color: root.lit ? Shared.Theme.overlayText : Shared.Theme.overlaySurface
        border.color: Shared.Theme.overlayBorder
        scale: root.highlighted ? (root.pressed ? root.pressScale : root.hoverScale) : 1
        Behavior on color {
            ColorAnimation {
                duration: Shared.Theme.overlayMotion
            }
        }
        Behavior on scale {
            NumberAnimation {
                duration: Shared.Theme.overlayMotion
            }
        }

        Text {
            anchors.centerIn: parent
            text: root.modelData.glyph
            color: root.lit ? Shared.Theme.overlayBackground : Shared.Theme.overlayText
            font {
                family: Shared.Theme.fontFamily
                pixelSize: root.glyphFontSize
            }
        }
    }

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.labelY
        text: root.modelData.label + "  ·  " + root.modelData.key
        color: Shared.Theme.overlayText
        font {
            family: Shared.Theme.fontFamily
            pixelSize: root.labelFontSize
        }
    }
}
