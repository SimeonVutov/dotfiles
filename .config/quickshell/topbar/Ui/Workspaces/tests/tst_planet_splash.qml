import QtQuick
import QtTest
import ".." as Workspaces

TestCase {
    name: "PlanetSplash"
    when: windowShown
    width: 120
    height: 90

    Workspaces.PlanetSplash {
        id: splash
        anchors.centerIn: parent
        width: 44
        height: 34
        expanded: false

        Rectangle {
            anchors.centerIn: parent
            width: 12
            height: 12
            color: "white"
        }
    }

    SignalSpy {
        id: closedSpy
        target: splash
        signalName: "closed"
    }

    function test_revealAndConceal() {
        compare(splash.progress, 0);
        splash.expanded = true;
        tryCompare(splash, "progress", 1, 1500);
        compare(closedSpy.count, 0);

        splash.expanded = false;
        tryCompare(splash, "progress", 0, 1500);
        tryCompare(closedSpy, "count", 1, 500);
    }
}
