.pragma library

// Whether a wallpaper of `type` is listed under the filter named `filterName`.
function matches(type, filterName) {
    if (filterName === "All")
        return true;
    if (filterName === "Video")
        return type === "video";
    return true;
}

function firstMatchingIndex(model, filterName) {
    for (let i = 0; i < model.count; ++i) {
        if (matches(model.get(i).type, filterName))
            return i;
    }
    return -1;
}

// The listed wallpaper closest to `fromIndex`; the first one when there is no
// current wallpaper.
function nearestMatchingIndex(model, filterName, fromIndex) {
    if (model.count === 0)
        return -1;
    if (fromIndex < 0)
        return firstMatchingIndex(model, filterName);

    let best = -1;
    let bestDistance = Number.POSITIVE_INFINITY;
    for (let i = 0; i < model.count; ++i) {
        if (!matches(model.get(i).type, filterName))
            continue;

        const distance = Math.abs(i - fromIndex);
        if (distance < bestDistance) {
            bestDistance = distance;
            best = i;
        }
    }
    return best;
}

// The next listed wallpaper after `fromIndex` in `direction` (1 or -1),
// wrapping around, or -1 when none is listed.
function nextMatchingIndex(model, filterName, fromIndex, direction) {
    if (model.count === 0)
        return -1;

    let index = fromIndex < 0 ? firstMatchingIndex(model, filterName) : fromIndex;
    for (let step = 0; step < model.count; ++step) {
        index = (index + direction + model.count) % model.count;
        if (matches(model.get(index).type, filterName))
            return index;
    }
    return -1;
}
