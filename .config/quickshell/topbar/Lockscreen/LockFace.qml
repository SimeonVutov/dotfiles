import QtQuick
import "WidgetCatalog.js" as Catalog
// Register dependencies before the catalog loads this widget by URL.
import "widgets/music"

LockTransition {
    id: root
    required property var controller
    required property var store
    settings: store.layout.animation
    ready: background.ready
    fallbackSource: background.imageSource

    CachedBackground {
        id: background
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
            Loader {
                anchors.fill: parent
                active: cell.modelData.type !== "authentication" && !!cell.definition?.component
                source: active ? Qt.resolvedUrl(cell.definition.component) : ""
                onLoaded: {
                    item.widgetSettings = Qt.binding(() => cell.widgetSettings);
                    item.referenceSize = Qt.binding(() => Qt.size(root.width, root.height));
                }
            }
            Loader {
                anchors.fill: parent
                active: cell.modelData.type !== "authentication" && !cell.definition?.component
                sourceComponent: Component {
                    Widget {
                        widgetType: cell.modelData.type
                        widgetSettings: cell.widgetSettings
                        referenceSize: Qt.size(root.width, root.height)

                        Text {
                            anchors.fill: parent
                            anchors.margins: 6
                            text: cell.definition?.name || ""
                            color: cell.widgetSettings.textColor
                            font.family: "SF Pro Display"
                            font.pixelSize: 20
                            minimumPixelSize: 8
                            fontSizeMode: Text.Fit
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                    }
                }
            }
            Loader {
                anchors.fill: parent
                active: cell.modelData.type === "authentication"
                sourceComponent: Component {
                    PasswordWidget {
                        controller: root.controller
                        widgetSettings: cell.widgetSettings
                        referenceSize: Qt.size(root.width, root.height)
                    }
                }
            }
        }
    }
}
