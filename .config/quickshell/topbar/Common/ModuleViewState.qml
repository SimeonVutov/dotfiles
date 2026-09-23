pragma Singleton

import Quickshell
import Quickshell.Io

Singleton {
    id: root

    function definition(moduleId) {
        return Config.moduleViews[moduleId] || null;
    }

    function selection(moduleId) {
        const view = definition(moduleId);
        if (!view)
            return [];
        const stored = file.adapter.selections?.[moduleId];
        if (!view.multiple)
            return view.items.some(item => item.value === stored) ? stored : view.defaults;
        const source = Array.isArray(stored) ? stored : view.defaults;
        const selected = view.items.filter(item => source.includes(item.value) || view.required?.includes(item.value)).map(item => item.value);
        return selected.length > 0 ? selected : view.defaults.slice();
    }

    function enabled(moduleId, value) {
        const selected = selection(moduleId);
        return Array.isArray(selected) && selected.includes(value);
    }

    function setChoice(moduleId, value) {
        const view = definition(moduleId);
        if (!view || view.multiple || !view.items.some(item => item.value === value))
            return;
        const next = Object.assign({}, file.adapter.selections);
        next[moduleId] = value;
        file.adapter.selections = next;
    }

    function toggleItem(moduleId, value) {
        const view = definition(moduleId);
        if (!view || !view.multiple || !view.items.some(item => item.value === value))
            return;
        if (view.required?.includes(value))
            return;
        const selected = selection(moduleId).slice();
        if (selected.includes(value)) {
            if (selected.length === 1)
                return;
            selected.splice(selected.indexOf(value), 1);
        } else {
            selected.push(value);
        }
        const next = Object.assign({}, file.adapter.selections);
        next[moduleId] = selected;
        file.adapter.selections = next;
    }

    FileView {
        id: file
        path: Quickshell.stateDir + "/topbar-module-views.json"
        onAdapterUpdated: writeAdapter()

        JsonAdapter {
            property var selections: ({})
        }
    }
}
