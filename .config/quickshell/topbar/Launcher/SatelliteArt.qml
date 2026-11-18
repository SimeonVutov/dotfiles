import QtQuick

// Vector art of one satellite without its app icon: a foil-wrapped bus with an
// instrument face, a dish antenna, and two solar arrays on booms. The launcher
// renders it once per foil into a shared texture, so every satellite draws a
// single textured quad and its icon on top.
Item {
    id: root

    // Gold or silver insulation foil.
    property bool silver: false

    // Bus (hull) placement inside the art; the icon is centred on it.
    readonly property real hullSize: 76
    readonly property real hullX: 83
    readonly property real hullY: 12
    readonly property real faceInset: 9

    readonly property real wingWidth: 71
    readonly property real wingHeight: 48
    readonly property real wingGap: 12
    readonly property real wingY: hullY + 16
    readonly property real tiltDegrees: 4

    readonly property color foilLight: silver ? "#f4f6fa" : "#f7cf63"
    readonly property color foilMid: silver ? "#b9c2cf" : "#d0912c"
    readonly property color foilDark: silver ? "#6c7686" : "#8a5414"
    readonly property color foilEdge: silver ? "#4a5361" : "#5a3509"
    readonly property color metal: "#c7ced9"
    readonly property color metalDark: "#7d8796"
    readonly property color cellLight: "#3a6fd8"
    readonly property color cellDark: "#11296a"
    readonly property color cellGap: "#0a1533"

    width: hullX * 2 + hullSize
    height: hullY + hullSize + 4

    // Booms from the bus to each array, with a yoke at the array's edge.
    Repeater {
        model: 2

        Item {
            required property int index
            readonly property bool onRight: index === 1

            x: onRight ? root.hullX + root.hullSize - 2 : root.hullX - root.wingGap + 2
            y: root.wingY + root.wingHeight / 2 - 2
            width: root.wingGap
            height: 4

            Rectangle {
                anchors.fill: parent
                color: root.metal
                border.color: root.metalDark
                border.width: .5
            }

            Rectangle {
                x: parent.onRight ? parent.width - 3 : 0
                y: -5
                width: 3
                height: 14
                radius: 1
                color: root.metalDark
            }
        }
    }

    // Solar arrays: deep blue cells in a silver frame, tilted slightly.
    Repeater {
        model: 2

        Rectangle {
            id: wing

            required property int index
            readonly property bool onRight: index === 1

            x: onRight ? root.hullX + root.hullSize + root.wingGap : root.hullX - root.wingGap - width
            y: root.wingY
            width: root.wingWidth
            height: root.wingHeight
            radius: 2
            rotation: onRight ? root.tiltDegrees : -root.tiltDegrees
            antialiasing: true
            color: root.cellGap
            border.color: root.metal
            border.width: 1.5

            Grid {
                anchors.fill: parent
                anchors.margins: 3.5
                columns: 4
                spacing: 1.5

                Repeater {
                    model: 12

                    Rectangle {
                        width: (wing.width - 7 - 3 * 1.5) / 4
                        height: (wing.height - 7 - 2 * 1.5) / 3
                        gradient: Gradient {
                            GradientStop { position: 0; color: root.cellLight }
                            GradientStop { position: .55; color: root.cellDark }
                            GradientStop { position: 1; color: Qt.darker(root.cellDark, 1.3) }
                        }

                        // Fine busbar across each cell.
                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width
                            height: .6
                            color: Qt.alpha("#9fb8ff", .35)
                        }
                    }
                }
            }
        }
    }

    // Dish antenna on a short mast above the bus.
    Rectangle {
        x: root.hullX + root.hullSize * .68 - width / 2
        y: root.hullY - 5
        width: 2
        height: 7
        color: root.metalDark
    }

    Rectangle {
        x: root.hullX + root.hullSize * .68 - width / 2
        y: 1
        width: 24
        height: 8
        radius: height / 2
        border.color: root.metalDark
        border.width: .5
        gradient: Gradient {
            GradientStop { position: 0; color: "#ffffff" }
            GradientStop { position: 1; color: "#aeb7c4" }
        }
    }

    // The bus, wrapped in crinkled insulation foil.
    Rectangle {
        id: hull

        x: root.hullX
        y: root.hullY
        width: root.hullSize
        height: root.hullSize
        radius: 10
        clip: true
        border.color: root.foilEdge
        border.width: 1
        gradient: Gradient {
            GradientStop { position: 0; color: root.foilLight }
            GradientStop { position: .45; color: root.foilMid }
            GradientStop { position: 1; color: root.foilDark }
        }

        // Crinkles: soft light and dark streaks across the foil.
        Repeater {
            model: [
                { x: -10, y: 8, w: 110, angle: 24, light: true },
                { x: -20, y: 30, w: 120, angle: -18, light: false },
                { x: -5, y: 52, w: 100, angle: 31, light: true },
                { x: -15, y: 66, w: 110, angle: -9, light: false }
            ]

            Rectangle {
                required property var modelData

                x: modelData.x
                y: modelData.y
                width: modelData.w
                height: 3
                rotation: modelData.angle
                antialiasing: true
                color: modelData.light ? Qt.alpha("#ffffff", .22) : Qt.alpha("#000000", .16)
            }
        }

        // Instrument face that carries the app icon.
        Rectangle {
            anchors.fill: parent
            anchors.margins: root.faceInset
            radius: 12
            color: "#0b111c"
            border.color: Qt.alpha(Theme.atmosphere, .35)
            border.width: 1
        }
    }

    // Thruster nozzle under the bus.
    Rectangle {
        x: root.hullX + root.hullSize * .3 - width / 2
        y: root.hullY + root.hullSize - 1
        width: 8
        height: 4
        radius: 1
        color: root.metalDark
    }
}
