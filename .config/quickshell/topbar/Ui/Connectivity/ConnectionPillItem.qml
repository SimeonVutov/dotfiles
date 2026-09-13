import QtQuick
import qs.Ui
import qs.Common

Rectangle {
    id: root

    property string icon: ""
    property string label: ""
    property var rotatingLabels: []
    property int minimumWidth: 72
    property int maximumLabelWidth: 140
    signal clicked

    readonly property bool rotates: rotatingLabels.length > 1
    readonly property string displayedLabel: rotatingLabels.length === 1 ? rotatingLabels[0] : label
    readonly property int labelWidth: rotates ? maximumLabelWidth : displayedLabel === "" ? 0 : Math.min(Math.ceil(measure.implicitWidth), maximumLabelWidth)
    readonly property int textWidth: labelWidth > 0 ? Math.max(labelWidth, width - 36) : 0

    implicitWidth: Math.max(minimumWidth, 28 + labelWidth + (labelWidth > 0 ? 8 : 0))
    implicitHeight: 25
    radius: 8
    color: "transparent"
    Behavior on width {
        NumberAnimation {
            duration: Theme.durationFast
            easing.type: Theme.easingEmphasized
        }
    }

    BarText {
        id: glyph
        x: root.labelWidth > 0 ? 6 : Math.round((root.width - implicitWidth) / 2)
        anchors.verticalCenter: parent.verticalCenter
        text: root.icon
        font.pixelSize: Theme.fontSizeSmall

        Behavior on x {
            NumberAnimation {
                duration: Theme.durationFast
                easing.type: Theme.easingEmphasized
            }
        }
    }

    MarqueeText {
        anchors.left: glyph.right
        anchors.leftMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        width: root.textWidth
        visible: root.labelWidth > 0 && !root.rotates
        text: root.displayedLabel
        restartKey: root.displayedLabel
        fontSize: Theme.fontSizeSmall
        pixelsPerSecond: Config.media.scrollPixelsPerSecond
        startPause: Config.media.scrollStartPause
        endPause: 0
    }

    RotatingMarqueeText {
        anchors.left: glyph.right
        anchors.leftMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        width: root.textWidth
        visible: root.rotates
        texts: root.rotatingLabels
        fontSize: Theme.fontSizeSmall
        endPause: 0
    }

    BarText {
        id: measure
        visible: false
        text: root.displayedLabel
        font.pixelSize: Theme.fontSizeSmall
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
