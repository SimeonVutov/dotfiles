pragma Singleton

import QtQuick
import Quickshell

// Nerd Font glyphs, written as codepoints rather than literal characters so
// they survive copy/paste and diffs intact. Values match the old waybar config.
Singleton {
    id: root

    function cp(code) {
        return String.fromCodePoint(code);
    }

    // Hardware
    readonly property string cpu: cp(0xf035b)
    readonly property string memory: cp(0xf0f85)
    readonly property string memoryTooltip: cp(0xe266)
    readonly property string temperature: cp(0xf2c9)

    readonly property string gpu: cp(0xf0253)
    readonly property string rocket: cp(0xf135)
    readonly property string balance: cp(0xf24e)
    readonly property string leaf: cp(0xf06c)
    readonly property string flame: cp(0xf06d)
    readonly property string chevronDown: cp(0xf078)
    readonly property string check: cp(0xf00c)
    readonly property string close: cp(0xf00d)
    readonly property string automatic: cp(0xf021)

    // Battery: index 0 is empty, 4 is full.
    readonly property var batteryLevels: [cp(0xf244), cp(0xf243), cp(0xf242), cp(0xf241), cp(0xf240)]
    readonly property string batteryCharging: cp(0xf492)

    // Network
    readonly property string wifi: cp(0xf1eb)
    readonly property string wifiDisabled: cp(0xf092d)
    readonly property string ethernet: cp(0xf0200)

    // Bluetooth
    readonly property string bluetooth: cp(0xf294)
    readonly property string bluetoothDisabled: cp(0xf00b2)
    readonly property string bluetoothConnected: cp(0xf00b1)
    readonly property string bluetoothBattery: cp(0xf0948)

    // Audio: volume levels are low / medium / high.
    readonly property var volumeLevels: [cp(0xf026), cp(0xf027), cp(0xf028)]
    readonly property string volumeMuted: cp(0xf466)
    readonly property string headphone: cp(0xf025)
    readonly property string handsFree: cp(0xf118f)
    readonly property string phone: cp(0xf095)
    readonly property string car: cp(0xf1b9)
    readonly property string microphone: cp(0xf130)
    readonly property string microphoneMuted: cp(0xf131)

    // Media transport
    readonly property string mediaPrevious: cp(0xf04d5)
    readonly property string mediaNext: cp(0xf04d7)
    readonly property string mediaPlay: cp(0xf040a)
    readonly property string mediaPause: cp(0xf03e4)
    readonly property string music: cp(0xf075a)

    // Misc
    readonly property string power: cp(0xf011)
    readonly property string person: cp(0xf007)
    readonly property string clock: cp(0xf017)
}
