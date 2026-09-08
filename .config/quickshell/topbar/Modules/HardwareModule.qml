import QtQuick
import Quickshell
import qs.Common
import qs.Ui
import qs.Services

// CPU, memory and temperature in one pill. Right click opens btop, same as the
// old waybar group binding.
BarModule {
    id: root

    // The sampler only runs while at least one of these is on screen.
    Component.onCompleted: SysMon.subscribe(true)
    Component.onDestruction: SysMon.subscribe(false)

    Pill {
        id: pill

        // Each reading carries its own 5px side padding, which is what puts
        // 10px between them and 5px inside the pill's edges.
        Row {
            spacing: 0

            BarText {
                leftPadding: Theme.groupItemPaddingH
                rightPadding: Theme.groupItemPaddingH
                font.pixelSize: Theme.fontSizeSmall
                text: Icons.cpu + "   " + Math.round(SysMon.cpuUsage) + "%"
            }

            BarText {
                leftPadding: Theme.groupItemPaddingH
                rightPadding: Theme.groupItemPaddingH
                font.pixelSize: Theme.fontSizeSmall
                text: Icons.memory + "   " + SysMon.memoryUsed.toFixed(2) + "GB"
            }

            BarText {
                leftPadding: Theme.groupItemPaddingH
                rightPadding: Theme.groupItemPaddingH
                font.pixelSize: Theme.fontSizeSmall
                text: Icons.temperature + "   " + Math.round(SysMon.temperature) + "°C"
            }
        }
    }

    MouseArea {
        anchors.fill: pill
        acceptedButtons: Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: Quickshell.execDetached(Config.hardware.onRightClick)
    }
}
