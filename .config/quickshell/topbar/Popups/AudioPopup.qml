pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Ui
import qs.Ui.Audio
import qs.Services

PopupPanel {
    id: root

    property string selectedTab: "output"
    property int profileCardId: -1
    property string profileDeviceName: ""
    readonly property var selectedDevice: selectedTab === "output" ? AudioDevices.defaultOutput : AudioDevices.defaultInput

    panelWidth: 380
    minimumPanelHeight: 260
    animateHeight: true
    smoothAnchorMovement: true
    contentPadding: 14
    rowSpacing: 8
    overlayActive: profileCardId >= 0
    onOverlayDismissed: closeProfiles()
    overlayPage: Component {
        AudioProfileMenu {
            cardId: root.profileCardId
            deviceName: root.profileDeviceName
            onDismissed: root.closeProfiles()
        }
    }

    function showTab(tab) {
        const sameOpenTab = open && selectedTab === tab;
        selectedTab = tab;
        open = !sameOpenTab;
    }

    function showProfiles(device) {
        const card = AudioDevices.cardFor(device);
        if (!card)
            return;
        profileCardId = card.id;
        profileDeviceName = AudioDevices.labelFor(device);
    }

    function closeProfiles() {
        profileCardId = -1;
        profileDeviceName = "";
    }

    onOpenChanged: if (!open)
        closeProfiles()

    Subscriber {
        active: root.open
        onToggled: enabled => AudioDevices.subscribe(enabled)
    }

    TabSwitcher {
        Layout.fillWidth: true
        currentTab: root.selectedTab
        tabs: [
            {
                value: "output",
                label: "Output",
                icon: Icons.audioOutput
            },
            {
                value: "input",
                label: "Input",
                icon: Icons.audioInput
            }
        ]
        onSelected: tab => root.selectedTab = tab
    }

    Item {
        Layout.fillWidth: true
        implicitHeight: 32

        BarText {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: root.selectedTab === "output" ? "Output devices" : "Input devices"
            font.pixelSize: Theme.fontSizeSmall
            font.bold: true
        }
        BarText {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: {
                const audio = root.selectedDevice ? root.selectedDevice.audio : null;
                return audio ? Math.round(audio.volume * 100) + "%" + (audio.muted ? " · Muted" : "") : "";
            }
            color: Theme.popupSubtleText
            font.pixelSize: Theme.fontSizeCaption
        }
    }

    AudioDeviceList {
        Layout.fillWidth: true
        mode: root.selectedTab
        onProfilesRequested: device => root.showProfiles(device)
    }

    PopupPanel.ErrorBanner {
        text: AudioDevices.error
    }
}
