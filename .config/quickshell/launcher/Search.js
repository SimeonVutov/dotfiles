.pragma library

// Match quality, best first. Every token has to hit somewhere in the name, and
// an entry is ranked by its *worst* token.
const EXACT_MATCH = 0;
const PREFIX_MATCH = 1;
const WORD_MATCH = 2;
const SUBSTRING_MATCH = 3;

const SEPARATORS = " \t-_./\\:+()[]{}@&,";

// Offsets a word may begin at: after a separator, or at a camelCase hump
// (lower-to-upper, and digit-to-upper so "2Go" counts).
function wordStarts(name) {
    const starts = [0];

    for (let i = 1; i < name.length; i++) {
        const previous = name[i - 1];
        const character = name[i];
        const uppercase = character !== character.toLowerCase() && character === character.toUpperCase();
        const previousLowercase = previous === previous.toLowerCase() && previous !== previous.toUpperCase();
        const previousDigit = previous >= "0" && previous <= "9";

        if (SEPARATORS.includes(previous) || (uppercase && (previousLowercase || previousDigit)))
            starts.push(i);
    }

    return starts;
}

function bestMatch(lowerName, starts, token) {
    if (lowerName === token)
        return {
            tier: EXACT_MATCH,
            position: 0
        };

    let position = lowerName.indexOf(token);
    let best = null;

    while (position >= 0) {
        const tier = position === 0 ? PREFIX_MATCH : starts.includes(position) ? WORD_MATCH : SUBSTRING_MATCH;

        if (!best || tier < best.tier)
            best = {
                tier: tier,
                position: position
            };

        if (best.tier <= PREFIX_MATCH)
            break;

        position = lowerName.indexOf(token, position + 1);
    }

    return best;
}

function score(entry, tokens) {
    const name = entry.name || "";
    const lowerName = name.toLowerCase();
    const starts = wordStarts(name);
    let tier = EXACT_MATCH;
    let position = 0;

    for (let i = 0; i < tokens.length; i++) {
        const hit = bestMatch(lowerName, starts, tokens[i]);

        if (!hit)
            return null;

        tier = Math.max(tier, hit.tier);
        position = Math.max(position, hit.position);
    }

    return {
        entry: entry,
        tier: tier,
        position: position,
        nameLength: name.length
    };
}

function rank(catalog, query) {
    const needle = (query || "").trim().toLowerCase();

    if (!needle)
        return catalog;

    const tokens = needle.split(/\s+/).filter(token => token.length);
    const scored = [];

    for (let i = 0; i < catalog.length; i++) {
        const hit = score(catalog[i], tokens);

        if (hit)
            scored.push(hit);
    }

    // Best tier, then the earliest hit, then the shortest name, then A-Z.
    scored.sort((a, b) => a.tier - b.tier || a.position - b.position || a.nameLength - b.nameLength || a.entry.name.localeCompare(b.entry.name));

    return scored.map(hit => hit.entry);
}
