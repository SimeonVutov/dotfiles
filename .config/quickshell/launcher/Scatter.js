.pragma library

// Rejection sampling keeps the layout scattered rather than snapping to a grid.
const DEFAULTS = {
    cellPadding: 3,
    viewportPadding: 8,
    itemGap: 5,
    // Reserve more area than the items strictly occupy; packing random points
    // into an exactly-sized field almost never succeeds.
    densityFactor: 1.7,
    maxScaleAttempts: 32,
    candidatesPerItem: 120,
    scaleDecay: .88
};

function emptyLayout(scale) {
    return { points: [], scale: scale };
}

function create(count, width, height, settings) {
    if (count === 0 || width < 2 || height < 2)
        return emptyLayout(1);

    const options = Object.assign({}, DEFAULTS, settings);
    let scale = estimateScale(count, width, height, options);

    // The area estimate is optimistic, so shrink until a full pack succeeds.
    for (let attempt = 0; attempt < options.maxScaleAttempts; attempt++) {
        const field = measureField(scale, width, height, options);

        if (field.rangeX > 0 && field.rangeY > 0) {
            const points = scatter(count, field, options);
            if (points.length === count)
                return { points: points, scale: scale };
        }

        scale *= options.scaleDecay;
    }

    return emptyLayout(scale);
}

function estimateScale(count, width, height, options) {
    const itemArea = 4 * options.itemHalfWidth * options.itemHalfHeight;
    return Math.min(1, Math.sqrt(width * height / (count * itemArea * options.densityFactor)));
}

// One item's half-extents at this scale, the minimum centre-to-centre spacing
// that keeps two of them apart, and how far a centre may stray from the middle.
function measureField(scale, width, height, options) {
    const halfWidth = options.itemHalfWidth * scale + options.cellPadding;
    const halfHeight = options.itemHalfHeight * scale + options.cellPadding;

    return {
        halfWidth: halfWidth,
        halfHeight: halfHeight,
        spacingX: 2 * halfWidth + options.itemGap,
        spacingY: 2 * halfHeight + options.itemGap,
        rangeX: width / 2 - halfWidth - options.viewportPadding,
        rangeY: height / 2 - halfHeight - options.viewportPadding
    };
}

function scatter(count, field, options) {
    const points = [];
    const spacingX = field.spacingX;
    const spacingY = field.spacingY;
    const rangeX = field.rangeX;
    const rangeY = field.rangeY;
    const centerRadius = options.centerRadius;
    const centerRadiusSquared = centerRadius * centerRadius;
    // A grid of cells as large as the spacing, so a candidate only ever has to be
    // compared against the nine cells around it. Cells hold indices into xs and ys.
    // Plain numbers index it: building string keys here made the layout slow.
    const columns = Math.ceil(2 * rangeX / spacingX) + 3;
    const rows = Math.ceil(2 * rangeY / spacingY) + 3;
    const cells = new Array(columns * rows);
    const xs = [];
    const ys = [];
    const candidateLimit = count * options.candidatesPerItem;

    for (let candidate = 0; candidate < candidateLimit && xs.length < count; candidate++) {
        const x = (Math.random() * 2 - 1) * rangeX;
        const y = (Math.random() * 2 - 1) * rangeY;

        const distanceX = Math.max(0, Math.abs(x) - field.halfWidth);
        const distanceY = Math.max(0, Math.abs(y) - field.halfHeight);
        if (distanceX * distanceX + distanceY * distanceY < centerRadiusSquared)
            continue;

        const column = Math.floor((x + rangeX) / spacingX) + 1;
        const row = Math.floor((y + rangeY) / spacingY) + 1;
        let blocked = false;

        for (let c = column - 1; c <= column + 1 && !blocked; c++) {
            for (let r = row - 1; r <= row + 1; r++) {
                const nearby = cells[c * rows + r];
                if (!nearby)
                    continue;

                for (let i = 0; i < nearby.length; i++) {
                    const other = nearby[i];
                    if (Math.abs(xs[other] - x) < spacingX && Math.abs(ys[other] - y) < spacingY) {
                        blocked = true;
                        break;
                    }
                }
                if (blocked)
                    break;
            }
        }

        if (blocked)
            continue;

        const index = xs.length;
        xs.push(x);
        ys.push(y);
        const key = column * rows + row;
        if (cells[key])
            cells[key].push(index);
        else
            cells[key] = [index];
        points.push({ x: x, y: y });
    }

    return points;
}
