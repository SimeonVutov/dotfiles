pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Notifications

// Owns the freedesktop notification service and groups active duplicates.
Singleton {
    id: root

    // State refreshes after a client closes a duplicate are not new arrivals.
    signal received(var message, string screenName, bool arrival)
    signal removed(int id)
    property var sources: ({})
    property var groups: ({})
    property var groupForId: ({})

    function screenName() {
        return Hyprland.focusedMonitor?.name || Quickshell.screens[0]?.name || "";
    }

    function progressFrom(hints) {
        const value = hints?.value;
        if (value === undefined || value === null || !Number.isFinite(Number(value)))
            return null;
        return Math.max(0, Math.min(100, Number(value)));
    }

    function stackTag(hints) {
        return hints?.["x-dunst-stack-tag"] || hints?.["x-canonical-private-synchronous"] || hints?.["private-synchronous"] || hints?.synchronous || "";
    }

    function snapshot(notification) {
        const actions = [];
        for (let i = 0; i < notification.actions.length; i++) {
            const action = notification.actions[i];
            actions.push({
                identifier: action.identifier,
                text: action.text
            });
        }
        return {
            id: notification.id,
            sender: notification.appName || "",
            title: notification.summary || "",
            body: notification.body || "",
            image: notification.image || "",
            icon: notification.appIcon || "",
            urgency: notification.urgency === NotificationUrgency.Critical ? "critical" : notification.urgency === NotificationUrgency.Low ? "low" : "normal",
            progress: progressFrom(notification.hints),
            actions: actions,
            timeout: notification.expireTimeout,
            resident: notification.resident,
            count: 1
        };
    }

    function duplicateKey(message) {
        return JSON.stringify([message.sender, message.title, message.body, message.image, message.icon, message.urgency]);
    }

    function activeFor(screenName) {
        const messages = [];
        for (const primary in groups) {
            const group = groups[primary];
            if (!group.screenName || group.screenName === screenName)
                messages.push(group.message);
        }
        return messages;
    }

    function detach(id, notification) {
        if (sources[id] !== notification)
            return;
        delete sources[id];
        const primary = groupForId[id];
        delete groupForId[id];
        const group = groups[primary];
        if (!group)
            return;
        group.ids = group.ids.filter(item => item !== id);
        if (!group.ids.length) {
            delete groups[primary];
            removed(primary);
        } else {
            group.message = snapshot(sources[group.ids[group.ids.length - 1]]);
            group.message.id = primary;
            group.message.count = group.ids.length;
            received(group.message, group.screenName, false);
        }
    }

    function accept(notification) {
        notification.tracked = true;
        const id = notification.id;
        const message = snapshot(notification);
        const tag = stackTag(notification.hints);
        const key = duplicateKey(message);
        let primary = groupForId[id];
        let replacement = primary !== undefined;
        if (!replacement) {
            for (const candidate in groups) {
                const group = groups[candidate];
                if (tag && group.tag === tag && group.message.sender === message.sender) {
                    primary = Number(candidate);
                    replacement = true;
                    break;
                }
                if (!tag && !group.tag && group.key === key) {
                    primary = Number(candidate);
                    break;
                }
            }
        }
        if (primary === undefined)
            primary = id;
        let group = groups[primary];
        if (!group) {
            group = {
                ids: [],
                message: message,
                key: key,
                tag: tag,
                screenName: screenName()
            };
            groups[primary] = group;
        }
        if (replacement) {
            for (const oldId of group.ids) {
                if (oldId === id)
                    continue;
                const oldSource = sources[oldId];
                delete sources[oldId];
                delete groupForId[oldId];
                oldSource?.dismiss();
            }
            group.ids = [];
            group.message = message;
            group.key = key;
            group.tag = tag;
        }
        if (!group.ids.includes(id))
            group.ids.push(id);
        if (!replacement)
            group.message = message;
        sources[id] = notification;
        groupForId[id] = primary;
        notification.closed.connect(() => detach(id, notification));
        group.message.id = primary;
        group.message.count = group.ids.length;
        received(group.message, group.screenName, true);
    }

    function dismiss(primary, expired = false) {
        const group = groups[primary];
        if (!group)
            return;
        delete groups[primary];
        const ids = group.ids.slice();
        for (const id of ids) {
            const source = sources[id];
            delete sources[id];
            delete groupForId[id];
            if (expired)
                source?.expire();
            else
                source?.dismiss();
        }
        removed(primary);
    }

    function invoke(primary, identifier) {
        const group = groups[primary];
        if (!group)
            return;
        const source = sources[group.ids[group.ids.length - 1]];
        if (!source)
            return;
        for (let i = 0; i < source.actions.length; i++) {
            const action = source.actions[i];
            if (action.identifier === identifier) {
                const resident = source.resident;
                action.invoke();
                if (!resident)
                    dismiss(primary);
                return;
            }
        }
    }

    NotificationServer {
        actionsSupported: true
        bodySupported: true
        bodyMarkupSupported: true
        bodyHyperlinksSupported: true
        imageSupported: true
        persistenceSupported: false
        keepOnReload: true
        onNotification: notification => root.accept(notification)
    }
}
