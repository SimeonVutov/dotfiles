import QtQuick
import QtQuick.Controls.Basic
import qs.Common

Item {
    id: root

    property alias model: list.model
    property alias delegate: list.delegate
    property alias spacing: list.spacing
    property alias addTransition: list.add
    property alias removeTransition: list.remove
    property alias displacedTransition: list.displaced

    property int rowHeight: 52
    property int minimumHeight: 52
    property int scanningHeight: 78
    property int maximumHeight: 196
    property bool scanning: false
    property string emptyText: ""

    readonly property int desiredHeight: list.count > 0 ? Math.min(maximumHeight, list.count * rowHeight + Math.max(0, list.count - 1) * list.spacing) : (scanning ? scanningHeight : minimumHeight)

    property int collapseDelay: 100
    property int settledHeight: desiredHeight
    property alias emptyWrapMode: emptyMessage.wrapMode

    implicitHeight: settledHeight

    function syncHeight() {
        if (desiredHeight >= settledHeight) {
            collapse.stop();
            settledHeight = desiredHeight;
        } else {
            collapse.restart();
        }
    }

    onDesiredHeightChanged: syncHeight()
    Component.onCompleted: settledHeight = desiredHeight

    // Keep departing rows visible until their removal transition settles.
    Timer {
        id: collapse
        interval: root.collapseDelay
        onTriggered: root.settledHeight = root.desiredHeight
    }

    ListView {
        id: list
        anchors.fill: parent
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollBar {}
    }

    BarText {
        id: emptyMessage
        anchors.centerIn: parent
        width: parent.width - 32
        visible: list.count === 0
        text: root.emptyText
        color: Theme.popupSubtleText
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
        font.pixelSize: Theme.fontSizeLabel
    }
}
