pragma ComponentBehavior: Bound

import QtQuick

// The bar above the wallpapers: the filter buttons, a hint, and the palette
// swatches of the wallpaper in focus. It flashes red to warn that a colour must
// be chosen first.
Rectangle {
    id: root

    required property MatugenColors theme
    property string filter: "All"
    property bool loading: false
    property var colors: []
    property string selectedColor: ""
    // Whether the palette, rather than the wallpapers, has the keyboard focus,
    // and which swatch it is on.
    property bool paletteFocused: false
    property int focusedIndex: -1
    property real warningFlash: 0.0

    signal filterChosen(string name)
    signal colorChosen(string color)

    z: 20
    height: 58
    width: row.width + 26
    radius: 16
    color: Qt.rgba(theme.mantle.r, theme.mantle.g, theme.mantle.b, 0.94)

    border.color: warningFlash > 0 ? Qt.rgba(1.0, 0.25, 0.25, 0.95) : Qt.rgba(theme.surface2.r, theme.surface2.g, theme.surface2.b, 0.75)
    border.width: warningFlash > 0 ? 2 : 1

    Rectangle {
        anchors.fill: parent
        radius: parent.radius
        color: Qt.rgba(1.0, 0.15, 0.15, 0.16 * root.warningFlash)
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 10

        FilterButton {
            theme: root.theme
            icon: "all"
            active: root.filter === "All"
            onClicked: root.filterChosen("All")
        }

        FilterButton {
            theme: root.theme
            icon: "video"
            active: root.filter === "Video"
            onClicked: root.filterChosen("Video")
        }

        Item {
            width: 8
            height: 1
        }

        Text {
            visible: root.loading || root.colors.length === 0 || root.selectedColor !== ""
            anchors.verticalCenter: parent.verticalCenter
            text: root.loading ? "Loading palette..." : (root.paletteFocused ? "Choose color → Enter to apply" : "Press Enter")
            color: root.theme.text
            font.pixelSize: 14
            font.bold: true
        }

        Repeater {
            model: root.colors

            delegate: PaletteSwatch {
                required property int index
                required property var modelData

                swatchColor: modelData
                focused: root.paletteFocused && root.focusedIndex === index
                selected: root.selectedColor === modelData
                autoPrimary: index === 0 && root.selectedColor === modelData
                onClicked: root.colorChosen(modelData)
            }
        }
    }
}
