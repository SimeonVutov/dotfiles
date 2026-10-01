import QtQuick
import Quickshell
import qs.Common
import qs.Ui

// Power button. Draws bare on the bar with no pill behind it.
BarModule {
    id: root

    IconButton {
        icon: Icons.power
        size: Theme.powerFontSize
        color: Theme.powerButton
        onClicked: Quickshell.execDetached(Config.power.onClick)
    }
}
