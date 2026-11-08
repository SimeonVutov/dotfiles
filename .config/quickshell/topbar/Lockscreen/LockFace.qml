import QtQuick
import "WidgetCatalog.js" as Catalog

Item {
    id: root
    required property var controller
    required property var store

    CachedBackground {
        anchors.fill: parent
    }
    Repeater {
        model: root.store.layout.widgets
        delegate: Item {
            id: cell
            required property var modelData
            readonly property var definition: Catalog.find(modelData.type)
            readonly property var widgetSettings: Object.assign(Catalog.defaults(modelData.type), modelData.settings)
            x: modelData.column * root.width / root.store.layout.columns
            y: modelData.row * root.height / root.store.layout.rows
            width: modelData.columns * root.width / root.store.layout.columns
            height: modelData.rows * root.height / root.store.layout.rows
            clip: true
            Rectangle {
                anchors.fill: parent
                anchors.margins: 5
                radius: cell.widgetSettings.cornerRadius
                color: cell.widgetSettings.backgroundColor
                opacity: cell.widgetSettings.backgroundOpacity
            }
            Loader {
                anchors.fill: parent
                active: cell.modelData.type !== "authentication" && !!cell.definition?.component
                source: active ? Qt.resolvedUrl(cell.definition.component) : ""
                onLoaded: item.widgetSettings = Qt.binding(() => cell.widgetSettings)
            }
            Text {
                anchors.centerIn: parent
                width: Math.max(0, parent.width - 12)
                height: Math.max(0, parent.height - 12)
                visible: cell.modelData.type !== "authentication" && !cell.definition?.component
                text: cell.definition?.name || ""
                color: cell.widgetSettings.textColor
                font.family: "SF Pro Display"
                font.pixelSize: 20
                minimumPixelSize: 8
                fontSizeMode: Text.Fit
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
            Loader {
                anchors.fill: parent
                active: cell.modelData.type === "authentication"
                sourceComponent: Component {
                    PasswordWidget {
                        controller: root.controller
                        widgetSettings: cell.widgetSettings
                    }
                }
            }
        }
    }
}
