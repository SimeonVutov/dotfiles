import QtQuick
import QtQuick.Window
import Quickshell
import "Animations.js" as Animations

Rectangle {
    id: root

    default property alias content: scene.data
    property var settings: Animations.defaults()
    property bool presenting: true
    property bool ready: true
    property real progress: 0
    property bool started: false
    property bool exiting: false
    property real exitProgress: 0
    property string snapshot: ""
    property rect snapshotRect: Qt.rect(0, 0, 0, 0)
    property url fallbackSource: ""
    readonly property var renderWindow: root.Window.window
    readonly property var animation: Animations.options.find(option => option.type === settings.type)
    readonly property real easedProgress: exiting ? 1 - exitProgress : (1 - Math.cos(Math.PI * progress)) / 2
    readonly property bool sceneReady: ready && desktop.status !== Image.Loading
    signal finished

    color: "#0a0a0a"
    clip: true

    function requestFrame() {
        if (presenting && sceneReady && progress < 1 && renderWindow)
            renderWindow.update();
    }

    function advance() {
        if (!started) {
            // Begin timing after the first ready frame, including texture upload.
            started = true;
            elapsed.restart();
        } else {
            progress = Math.min(1, elapsed.elapsed() * 1000 / settings.duration);
        }

        if (settings.type === "none")
            progress = 1;

        renderWindow.update();
        if (progress >= 1)
            finished();
    }

    onPresentingChanged: requestFrame()
    onReadyChanged: requestFrame()
    onSceneReadyChanged: requestFrame()
    onRenderWindowChanged: requestFrame()
    Component.onCompleted: requestFrame()

    ElapsedTimer {
        id: elapsed
    }

    Connections {
        target: root.renderWindow
        enabled: root.presenting && root.sceneReady && !root.exiting && root.progress < 1

        function onFrameSwapped() {
            root.advance();
        }
    }

    Item {
        anchors.fill: parent
        z: root.settings.type === "fade" ? 2 : 0
        opacity: root.settings.type === "fade" ? 1 - root.easedProgress : 1
        visible: (root.progress < 1 || root.exiting)

        Image {
            id: desktop
            anchors.fill: parent
            source: (root.progress < 1 || root.exiting) ? root.snapshot || root.fallbackSource : ""
            sourceClipRect: root.snapshot ? root.snapshotRect : Qt.rect(0, 0, 0, 0)
            fillMode: Image.PreserveAspectCrop
            asynchronous: false
            cache: false
        }

        Rectangle {
            anchors.fill: parent
            color: "#000000"
            opacity: root.snapshot ? 0 : .18
        }
    }

    Item {
        id: scene

        anchors.fill: parent
        z: 1
        opacity: root.settings.type === "zoom-in" || (root.exiting && root.settings.type === "fade") ? root.easedProgress : 1
        scale: root.settings.type === "zoom-in" ? .96 + .04 * root.easedProgress : 1
        transform: Translate {
            x: (root.animation?.x || 0) * root.width * (1 - root.easedProgress)
            y: (root.animation?.y || 0) * root.height * (1 - root.easedProgress)
        }
    }
}
