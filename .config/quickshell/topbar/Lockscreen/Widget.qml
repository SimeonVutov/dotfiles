import QtQuick
import "WidgetCatalog.js" as Catalog

FocusScope {
    id: root

    default property alias content: body.data
    property string widgetType: ""
    property var widgetSettings: ({})
    property size referenceSize: Qt.size(1920, 1080)
    property real designWidth: width
    property real designHeight: height
    readonly property var definition: Catalog.find(widgetType)
    readonly property var settings: definition ? definition.resolve(widgetSettings) : widgetSettings
    readonly property real contentScale: Math.max(.01, Math.min(1, width / Math.max(1, designWidth), height / Math.max(1, designHeight)))
    clip: true

    Rectangle {
        anchors.fill: parent
        anchors.margins: 5
        radius: root.settings.cornerRadius || 0
        color: root.settings.backgroundColor || "transparent"
        opacity: root.settings.backgroundOpacity || 0
    }

    Item {
        id: body
        anchors.centerIn: parent
        width: root.designWidth
        height: root.designHeight
        scale: root.contentScale
    }
}
