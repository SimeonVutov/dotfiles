import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import Quickshell
import qs.Common
import qs.Ui
import "../../Lockscreen/Grid.js" as Grid

ColumnLayout {
    id: root

    property bool active: false
    readonly property alias controller: layoutController
    property int previewScreen: 0
    readonly property var screen: Quickshell.screens[previewScreen]
    signal closeRequested
    spacing: 16

    LayoutController {
        id: layoutController
    }

    Keys.onEscapePressed: event => {
        if (layoutController.moving) {
            layoutController.cancelMove();
        } else {
            root.closeRequested();
        }

        event.accepted = true;
    }

    onActiveChanged: {
        if (active)
            forceActiveFocus();
        else
            layoutController.cancelMove();
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 16

        Item {
            Layout.fillWidth: true
        }

        SettingsChoice {
            id: gridSize

            label: "Grid"
            enabled: layoutController.ready && !layoutController.moving
            model: Grid.resolutions.map(size => size.columns + " × " + size.rows)
            currentIndex: Grid.resolutions.findIndex(size => size.columns === layoutController.layout.columns)
            onChosen: index => {
                const size = Grid.resolutions[index];
                layoutController.resizeGrid(size.columns, size.rows);
                currentIndex = Qt.binding(() => Grid.resolutions.findIndex(size => size.columns === layoutController.layout.columns));
            }
        }

        SettingsChoice {
            label: "Preview display"
            model: Quickshell.screens.map(screen => screen.name)
            onChosen: index => root.previewScreen = index
        }

        ConnectionButton {
            visible: !!layoutController.moving
            text: "Cancel move"
            onClicked: layoutController.cancelMove()
        }
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: 18

        WidgetInspector {
            Layout.preferredWidth: 250
            Layout.fillHeight: true
            controller: layoutController
        }

        GridCanvas {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumWidth: 340
            controller: layoutController
            aspectRatio: root.screen ? root.screen.width / root.screen.height : 16 / 9
        }

        WidgetLibrary {
            Layout.preferredWidth: 200
            Layout.fillHeight: true
            controller: layoutController
        }
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.preferredHeight: 28
        spacing: 16

        SaveIndicator {
            store: layoutController.store
        }

        BarText {
            Layout.fillWidth: true
            text: layoutController.status
            color: Theme.criticalBackground
            font.pixelSize: Theme.fontSizeCaption
            wrapMode: Text.Wrap
        }
    }
}
