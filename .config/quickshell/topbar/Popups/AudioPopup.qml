pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Ui
import qs.Services

PopupPanel {
    id: root

    property bool subscribed: false
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

    function syncSubscription() {
        if (subscribed === open)
            return;
        subscribed = open;
        AudioDevices.subscribe(open);
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

    onOpenChanged: {
        syncSubscription();
        if (!open)
            closeProfiles();
    }
    Component.onCompleted: syncSubscription()
    Component.onDestruction: if (subscribed)
        AudioDevices.subscribe(false)

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
            font.pixelSize: 14
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
            font.pixelSize: 12
        }
    }

    AudioDeviceList {
        Layout.fillWidth: true
        mode: root.selectedTab
        onProfilesRequested: device => root.showProfiles(device)
    }

    BarText {
        Layout.fillWidth: true
        Layout.preferredHeight: text === "" ? 0 : 24
        visible: Layout.preferredHeight > 0
        text: AudioDevices.error
        color: Theme.graphTemperature
        font.pixelSize: 11
        wrapMode: Text.WordWrap
        maximumLineCount: 2
        elide: Text.ElideRight
    }
}
