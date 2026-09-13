pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire

Singleton {
    id: root

    readonly property var nodes: Pipewire.nodes.values.filter(node => !node.isStream && (node.type & PwNodeType.Audio) !== 0)
    readonly property var outputs: nodes.filter(node => node.isSink)
    readonly property var inputs: nodes.filter(node => !node.isSink)
    readonly property var defaultOutput: Pipewire.defaultAudioSink
    readonly property var defaultInput: Pipewire.defaultAudioSource

    property var cards: []
    property string error: ""
    property int viewers: 0
    readonly property bool profileBusy: loadCards.running || setProfileProcess.running

    PwObjectTracker {
        objects: root.nodes
    }

    function subscribe(enabled) {
        viewers = Math.max(0, viewers + (enabled ? 1 : -1));
        if (enabled && viewers === 1)
            refreshProfiles();
        else if (viewers === 0)
            profileRefreshDelay.stop();
    }

    function labelFor(node) {
        if (!node)
            return "Unknown device";
        return node.description || node.nickname || node.name || "Unknown device";
    }

    function selectNode(node, mode) {
        if (!node)
            return;
        error = "";
        if (mode === "output")
            Pipewire.preferredDefaultAudioSink = node;
        else
            Pipewire.preferredDefaultAudioSource = node;
    }

    function parseCards(text) {
        try {
            const parsed = JSON.parse(text);
            cards = parsed.filter(object => object.type === "PipeWire:Interface:Device").map(object => {
                const info = object.info || {};
                const properties = info.props || {};
                const parameters = info.params || {};
                const activeProfile = (parameters.Profile || [])[0] || {};
                const profiles = (parameters.EnumProfile || []).map(profile => ({
                            index: Number(profile.index),
                            name: profile.name || "",
                            description: profile.description || profile.name || "Unknown profile",
                            available: profile.available || "unknown"
                        }));
                return {
                    id: Number(object.id),
                    name: properties["device.name"] || "",
                    description: properties["device.description"] || properties["device.name"] || "Audio device",
                    activeProfile: activeProfile.name || "",
                    activeProfileIndex: Number(activeProfile.index),
                    profiles: profiles
                };
            });
            error = "";
        } catch (_) {
            cards = [];
            error = "Audio profiles could not be read.";
        }
    }

    function cardFor(node) {
        if (!node)
            return null;
        const properties = node.properties || {};
        const deviceName = properties["device.name"] || "";
        const deviceId = String(properties["device.id"] ?? "");
        let card = cards.find(candidate => candidate.name === deviceName);
        if (!card && deviceId !== "")
            card = cards.find(candidate => String(candidate.id) === deviceId);
        if (!card) {
            const nodeName = node.name || "";
            card = cards.find(candidate => {
                const marker = candidate.name.indexOf("_card.");
                const identifier = marker >= 0 ? candidate.name.substring(marker + 6) : candidate.name;
                return identifier !== "" && nodeName.indexOf(identifier) !== -1;
            });
        }
        return card ?? null;
    }

    function cardById(id) {
        return cards.find(card => card.id === id) ?? null;
    }

    function profilesForCard(card) {
        if (!card)
            return [];
        return card.profiles.filter(profile => String(profile.name).trim().toLowerCase() !== "off").sort((a, b) => {
            if (a.name === card.activeProfile)
                return -1;
            if (b.name === card.activeProfile)
                return 1;
            if (a.available !== b.available)
                return a.available === "no" ? 1 : -1;
            return a.description.localeCompare(b.description);
        });
    }

    function refreshProfiles() {
        if (!profileBusy) {
            error = "";
            loadCards.running = true;
        }
    }

    function setProfile(card, profile) {
        if (!card || !profile || profileBusy || String(profile.name).trim().toLowerCase() === "off")
            return;
        error = "";
        setProfileProcess.command = ["wpctl", "set-profile", String(card.id), String(profile.index)];
        setProfileProcess.running = true;
    }

    onNodesChanged: {
        if (viewers > 0)
            profileRefreshDelay.restart();
    }

    Timer {
        id: profileRefreshDelay
        interval: 200
        onTriggered: if (root.viewers > 0)
            root.refreshProfiles()
    }

    Process {
        id: loadCards
        command: ["pw-dump", "-N"]
        stdout: StdioCollector {
            onStreamFinished: root.parseCards(text)
        }
        onExited: code => {
            if (code !== 0)
                root.error = "Audio profiles could not be read from PipeWire.";
        }
    }

    Process {
        id: setProfileProcess
        onExited: code => {
            if (code !== 0) {
                root.error = "The audio profile could not be changed.";
                return;
            }
            if (root.viewers > 0)
                loadCards.running = true;
        }
    }
}
