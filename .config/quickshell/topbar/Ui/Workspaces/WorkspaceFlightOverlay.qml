pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import "OrbitalMotion.js" as Motion

Scope {
    id: root

    required property var coordinator

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: overlay
            required property var modelData
            screen: modelData
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "quickshell-workspace-flight"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            mask: Region {}

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            Canvas {
                id: trail
                anchors.fill: parent
                opacity: root.coordinator.trailOpacity
                onPaint: {
                    const ctx = getContext("2d");
                    ctx.reset();

                    const points = root.coordinator.trailPoints;
                    if (points.length < 2)
                        return;

                    ctx.lineCap = "round";
                    for (let i = 1; i < points.length; ++i) {
                        const from = points[i - 1];
                        const to = points[i];
                        const strength = Math.max(0, 1 - (root.coordinator.elapsed - to.time) / .65);

                        ctx.beginPath();
                        ctx.moveTo(from.x - overlay.screen.x, from.y - overlay.screen.y);
                        ctx.lineTo(to.x - overlay.screen.x, to.y - overlay.screen.y);
                        ctx.strokeStyle = Qt.rgba(1, .88, .66, .85 * strength);
                        ctx.lineWidth = 2.2 * strength + .3;
                        ctx.stroke();
                    }
                }

                Connections {
                    target: root.coordinator
                    function onTrailRevisionChanged() {
                        trail.requestPaint();
                    }
                }
            }

            OrbitalShip {
                visible: root.coordinator.stage === "transfer" && root.coordinator.pose !== null
                x: root.coordinator.pose ? root.coordinator.pose.p[0] - overlay.screen.x - width / 2 : 0
                y: root.coordinator.pose ? root.coordinator.pose.p[1] - overlay.screen.y - height / 2 : 0
                rotation: root.coordinator.heading * 180 / Math.PI
                scale: root.coordinator.pose ? 1.05 + Math.max(-1, Math.min(1, root.coordinator.pose.p[2] / Motion.radiusZ)) * .04 : 1.05
                throttle: root.coordinator.transfer?.throttle || 0
                braking: root.coordinator.transfer?.braking || 0
                clock: root.coordinator.elapsed
            }
        }
    }
}
