import QtQuick
import Quickshell
import Quickshell.Io

Rectangle {
    id: root
    property string cacheDirectory: Quickshell.env("XDG_CACHE_HOME") || Quickshell.env("HOME") + "/.cache"
    property int revision: 0
    color: "#0a0a0a"
    Image {
        anchors.fill: parent
        source: "file://" + root.cacheDirectory + "/blurred_wallpaper.png?revision=" + root.revision
        fillMode: Image.PreserveAspectCrop
        cache: false
        asynchronous: true
    }
    // The blur is baked by wallpaper-apply.sh; no live shader or media capture.
    Rectangle {
        anchors.fill: parent
        color: "#000000"
        opacity: .18
    }
    FileView {
        path: root.cacheDirectory + "/blurred_wallpaper.png"
        preload: false
        watchChanges: true
        printErrors: false
        onFileChanged: root.revision++
    }
}
