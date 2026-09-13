import QtQuick
import Quickshell
import qs.Common
import qs.Ui
import qs.Services
import qs.Popups

// CPU, memory and temperature share one sampler.
BarModule {
    id: root

    // The sampler only runs while at least one of these is on screen.
    Subscriber {
        active: root.visible
        onToggled: enabled => SysMon.subscribe(enabled)
    }

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
                text: Icons.temperature + "   " + (isFinite(SysMon.temperature) ? Math.round(SysMon.temperature) + "°C" : "—")
            }
        }
    }

    HardwarePopup {
        id: hardwarePopup
        anchorItem: pill
    }

    MouseArea {
        anchors.fill: pill
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: mouse => {
            if (mouse.button === Qt.RightButton)
                Quickshell.execDetached(Config.hardware.onRightClick);
            else
                hardwarePopup.toggle();
        }
    }
}
