import qs.Common

TabSwitcher {
    currentTab: "wifi"
    tabs: [
        {
            value: "wifi",
            label: "Wi-Fi",
            icon: Icons.wifi
        },
        {
            value: "bluetooth",
            label: "Bluetooth",
            icon: Icons.bluetooth
        }
    ]
}
