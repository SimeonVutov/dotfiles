import QtQuick
import qs.Ui
import qs.Common

Rectangle {
    id: root

    property string icon: ""
    property string label: ""
    property var rotatingLabels: []
    property bool compact: false
    property int minimumWidth: 72
    signal clicked

    readonly property bool rotates: rotatingLabels.length > 1
    readonly property string displayedLabel: rotates ? rotatingLabels[rotatingText.currentIndex] || "" : rotatingLabels.length === 1 ? rotatingLabels[0] : label
    readonly property string longestLabel: rotatingLabels.length > 0 ? rotatingLabels.reduce((longest, value) => value.length > longest.length ? value : longest, "") : label
    readonly property int fullLabelWidth: Math.min(Math.ceil(measure.implicitWidth), Config.connections.maximumLabelWidth)
    readonly property int labelWidth: compact ? 0 : fullLabelWidth
    readonly property int textWidth: labelWidth > 0 ? Math.max(0, width - 36) : 0
    readonly property int expandedWidth: Math.max(minimumWidth, 28 + fullLabelWidth + (fullLabelWidth > 0 ? 8 : 0))

    implicitWidth: compact ? 28 : expandedWidth
    implicitHeight: 25
    radius: 8
    color: "transparent"
    clip: true
    Behavior on width {
        NumberAnimation {
            duration: Theme.durationNormal
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
                duration: Theme.durationNormal
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
        text: root.longestLabel
        restartKey: root.displayedLabel
        fontSize: Theme.fontSizeSmall
        pixelsPerSecond: Config.media.scrollPixelsPerSecond
        startPause: Config.media.scrollStartPause
        endPause: 0
    }

    RotatingMarqueeText {
        id: rotatingText
        anchors.left: glyph.right
        anchors.leftMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        width: root.textWidth
        visible: root.rotates && !root.compact
        texts: root.rotatingLabels
        fontSize: Theme.fontSizeSmall
        endPause: 0
    }

    BarText {
        id: measure
        visible: false
        text: root.longestLabel
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
