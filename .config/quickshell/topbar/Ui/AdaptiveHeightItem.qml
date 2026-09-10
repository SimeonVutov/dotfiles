import QtQuick

Item {
    id: root

    property int targetHeight: 0
    property int collapseDelay: 100
    property int settledHeight: targetHeight

    implicitHeight: settledHeight

    function syncHeight() {
        if (targetHeight >= settledHeight) {
            collapse.stop();
            settledHeight = targetHeight;
        } else {
            collapse.restart();
        }
    }

    onTargetHeightChanged: syncHeight()
    Component.onCompleted: settledHeight = targetHeight

    Timer {
        id: collapse
        interval: root.collapseDelay
        onTriggered: root.settledHeight = root.targetHeight
    }
}
