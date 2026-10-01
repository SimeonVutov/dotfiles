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
    return {
        points: [],
        scale: scale
    };
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

            if (points.length === count) {
                return {
                    points: points,
                    scale: scale
                };
            }
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
    // Spatial hash keyed by the spacing itself, so a candidate only ever has to
    // be compared against the nine buckets surrounding it.
    const buckets = {};
    const candidateLimit = count * options.candidatesPerItem;
    const point = { x: 0, y: 0 };

    for (let candidate = 0; candidate < candidateLimit && points.length < count; candidate++) {
        point.x = (Math.random() * 2 - 1) * field.rangeX;
        point.y = (Math.random() * 2 - 1) * field.rangeY;

        if (overlapsCenter(point, field, options.centerRadius))
            continue;

        const bucketX = Math.floor(point.x / field.spacingX);
        const bucketY = Math.floor(point.y / field.spacingY);

        if (overlapsNeighbour(point, bucketX, bucketY, field, buckets))
            continue;

        const accepted = { x: point.x, y: point.y };
        points.push(accepted);
        addToBucket(buckets, bucketX, bucketY, accepted);
    }

    return points;
}

function overlapsCenter(point, field, centerRadius) {
    const distanceX = Math.max(0, Math.abs(point.x) - field.halfWidth);
    const distanceY = Math.max(0, Math.abs(point.y) - field.halfHeight);
    return Math.hypot(distanceX, distanceY) < centerRadius;
}

function overlapsNeighbour(point, bucketX, bucketY, field, buckets) {
    for (let offsetX = -1; offsetX <= 1; offsetX++) {
        for (let offsetY = -1; offsetY <= 1; offsetY++) {
            const nearby = buckets[bucketKey(bucketX + offsetX, bucketY + offsetY)];
            if (!nearby)
                continue;

            for (let i = 0; i < nearby.length; i++) {
                const other = nearby[i];
                if (Math.abs(other.x - point.x) < field.spacingX && Math.abs(other.y - point.y) < field.spacingY)
                    return true;
            }
        }
    }

    return false;
}

function addToBucket(buckets, bucketX, bucketY, point) {
    const key = bucketKey(bucketX, bucketY);

    if (!buckets[key])
        buckets[key] = [];

    buckets[key].push(point);
}

function bucketKey(x, y) {
    return x + ":" + y;
}
