import QtQuick
import QtTest
import Quickshell
import qs.Launcher

ShellRoot {
    FloatingWindow {
        implicitWidth: 1280
        implicitHeight: 900

        Launcher {
            id: menu

            anchors.fill: parent
            property int launches: 0
            property int closes: 0
            applications: [
                {
                    name: "Alpha",
                    genericName: "",
                    comment: "",
                    icon: "",
                    noDisplay: false
                },
                {
                    name: "Beta",
                    genericName: "",
                    comment: "",
                    icon: "",
                    noDisplay: false
                }
            ]
            onLaunchRequested: launches++
            onDismissed: closes++
        }

        Beam {
            id: testBeam

            visible: false
            startX: 100
            startY: 100
            endX: 500
            endY: 300
        }

        TestCase {
            id: tests

            name: "ProximityLaunch"
            when: false

            function find(item, name) {
                if (item.objectName === name)
                    return item;
                for (const child of item.children) {
                    const found = find(child, name);
                    if (found)
                        return found;
                }
                return null;
            }
            function runChecks() {
                const area = find(menu, "proximityArea");
                // A point just outside the satellite's hit rectangle.
                const craft = find(menu, "satelliteHitTarget");
                const point = craft.mapToItem(area, craft.width + 8, 38);
                mouseMove(area, point.x, point.y);
                verify(menu.pointerApp !== null);
                const selected = menu.pointerApp;
                mouseClick(area, point.x, point.y);
                compare(menu.pendingLaunch, selected);
                compare(menu.launches, 0);
                verify(menu.closing);
                wait(480);
                verify(menu.progress < 1);
                compare(menu.launches, 0);
                wait(1200);
                compare(menu.launches, 1);
                compare(menu.progress, 0);
                menu.launchFailed("");
                menu.activate(menu.results[0]);
                wait(100);
                menu.cancel();
                menu.cancel();
                wait(1250);
                compare(menu.launches, 1);
                compare(menu.closes, 1);
                menu.launchFailed("");
                menu.pickNearest(menu.width / 2, menu.height / 2);
                verify(menu.pointerApp !== null);
            }

            function verifySelectionControls() {
                menu.prepare();
                menu.progress = 1;
                menu.layout = {
                    points: [Qt.point(-300, 0), Qt.point(300, 0)],
                    scale: 1
                };
                wait(30);
                compare(menu.mouseSelection, false);
                compare(menu.highlightedApp, menu.results[0]);

                menu.focusSearch();
                keyClick(Qt.Key_Right);
                compare(menu.highlightedApp, menu.results[1]);
                compare(menu.mouseSelection, false);
                keyClick(Qt.Key_Left);
                compare(menu.highlightedApp, menu.results[0]);

                const area = find(menu, "proximityArea");
                mouseMove(area, menu.width - 1, menu.height / 2);
                compare(menu.highlightedApp, menu.results[1]);
                compare(menu.mouseSelection, true);
                keyClick(Qt.Key_Left);
                compare(menu.highlightedApp, menu.results[0]);
                compare(menu.mouseSelection, false);
                keyClick(Qt.Key_Up);
                keyClick(Qt.Key_Down);
                compare(menu.mouseSelection, false);

                mouseMove(area, menu.width / 2, menu.height / 2);
                verify(menu.highlightedApp !== null);
                compare(menu.mouseSelection, true);
                menu.query = "no-match";
                menu.pickNearest(0, 0);
                compare(menu.highlightedApp, null);
            }

            function verifyRapidBeamToggle() {
                testBeam.connected = true;
                wait(50);
                verify(testBeam.reach > 0 && testBeam.reach < 1);

                testBeam.connected = false;
                compare(testBeam.reach, 0);
                testBeam.connected = true;
                wait(50);
                verify(testBeam.reach > 0);

                testBeam.connected = false;
                compare(testBeam.reach, 0);
                testBeam.connected = true;
                tryCompare(testBeam, "reach", 1, Theme.beamExtendDuration + 100);
            }
        }

        Timer {
            interval: 1700
            running: true
            onTriggered: {
                try {
                    tests.runChecks();
                    tests.verifySelectionControls();
                    tests.verifyRapidBeamToggle();
                    console.log("PASS nearest mouse selection, directional keyboard takeover, delayed launch, Escape cancellation, rapid beam toggle");
                } catch (error) {
                    console.error("FAIL", error);
                }
                Qt.quit();
            }
        }
    }
}
