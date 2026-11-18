.pragma library

// The launcher's flight as pure functions of animation progress. Lengths are in
// screen heights with y pointing down, so one flight fits every screen; the QML
// side multiplies by the window height.
//
// The desktop is drawn on a sphere seen from the front (shaders/world.frag):
// ox, oy is the sphere's centre, k its curvature (1 / radius) and wx, wy the
// arc length the desktop covers. A tiny curvature with the desktop's own size
// is the untouched desktop; a curvature of pi / w is a globe the desktop wraps.

function clamp01(x) {
    return x < 0 ? 0 : x > 1 ? 1 : x;
}

function span(start, end, x) {
    return clamp01((x - start) / (end - start));
}

function smooth(start, end, x) {
    const t = span(start, end, x);
    return t * t * (3 - 2 * t);
}

function mix(a, b, t) {
    return a + (b - a) * t;
}

function easeOut(t) {
    return 1 - Math.pow(1 - t, 3);
}

function easeInOut(t) {
    return t < .5 ? 4 * t * t * t : 1 - Math.pow(2 - 2 * t, 3) / 2;
}

// Monotone cubic through keyframes (Fritsch-Butland tangents), flat at both
// ends, so motion starts and stops gently and never overshoots a keyframe.
function curve(xs, ys, x) {
    const last = xs.length - 1;
    if (x <= xs[0])
        return ys[0];
    if (x >= xs[last])
        return ys[last];

    let i = 0;
    while (x > xs[i + 1])
        i++;

    const slope = j => (ys[j + 1] - ys[j]) / (xs[j + 1] - xs[j]);
    const tangent = j => {
        if (j === 0 || j === last)
            return 0;
        const a = slope(j - 1);
        const b = slope(j);
        if (a * b <= 0)
            return 0;
        const h0 = xs[j] - xs[j - 1];
        const h1 = xs[j + 1] - xs[j];
        return 3 * (h0 + h1) / ((2 * h1 + h0) / a + (h1 + 2 * h0) / b);
    };

    const h = xs[i + 1] - xs[i];
    const t = (x - xs[i]) / h;
    const t2 = t * t;
    const t3 = t2 * t;
    return (2 * t3 - 3 * t2 + 1) * ys[i] + (t3 - 2 * t2 + t) * h * tangent(i)
        + (3 * t2 - 2 * t3) * ys[i + 1] + (t3 - t2) * h * tangent(i + 1);
}

// Everything at rest: the plain desktop, nothing else on screen.
function rest(aspect) {
    return {
        ox: aspect / 2, oy: .5, k: 1e-4, wx: aspect, wy: 1,
        capTop: 1, ball: 0, sky: 0, space: 1, rim: 0, streak: 0, haze: 0,
        impact: 0, shockRadius: 0, flash: 0, hazeEdges: 0,
        stars: 0, starsShift: 0, starsStreak: 0, starsZoom: 1, shake: 0,
        pad: 0, padRise: 0, padDrop: 0, fire: 0, plasma: 0,
        frame: 0, frameZoom: 1,
        ui: 0, reveal: 0
    };
}

// The final orbit: the globe at the centre, the launcher around it.
function orbit(aspect, radius) {
    const f = rest(aspect);
    f.k = 1 / radius;
    f.wx = Math.PI * radius;
    f.wy = f.wx;
    f.capTop = 0;
    f.ball = 1;
    f.rim = 1;
    f.stars = 1;
    f.ui = 1;
    f.reveal = 1;
    return f;
}

// Lift-off from the desktop, the horizon curving away into a globe that
// recedes into the middle of the view, then the launcher deploying around it.
// The phase boundaries are fractions of Theme.entranceDuration.
function entrance(p, aspect, radius) {
    const f = rest(aspect);
    f.ox = aspect / 2;

    // One continuous move: the sphere's radius shrinks along a single curve
    // whose pace only ever slows, spread so the visible part of the change
    // (the horizon curving, the globe closing and receding) takes most of the
    // entrance instead of happening in a burst. Radii are in log space.
    const end = Math.log(radius);
    f.k = Math.exp(-curve([0, .1, .2, .3, .4, .5, .6, .7, .8, .9],
        [Math.log(1e4), 5.5, 2.5, 1, .2, -.5, end + 1.2, end + .7, end + .3, end], p));

    // The desktop shrinks a little while it is still the ground, then wraps the
    // whole globe (pi / k of arc each way) as the globe closes.
    const formed = smooth(.26, .64, p);
    const ground = 1 - .08 * smooth(0, .36, p);
    f.wx = mix(aspect * ground, Math.PI / f.k, formed);
    f.wy = mix(ground, Math.PI / f.k, formed);
    f.capTop = 0;

    // The horizon (the desktop's top edge) sinks as the climb begins and
    // eases to its final height; the sphere's centre follows from it and the
    // curvature, oy = horizon + sin(wy k / 2) / k, so the globe recedes
    // without wobbling.
    const horizon = .4 * easeInOut(span(0, .5, p));
    f.oy = horizon + Math.sin(f.wy * f.k / 2) / f.k;

    f.ball = smooth(.28, .64, p);
    f.sky = 1 - smooth(.16, .46, p);
    f.space = smooth(.04, .4, p);
    f.rim = .6 * smooth(.04, .16, p) * (1 - f.ball) + f.ball;
    f.streak = .03 * smooth(.06, .24, p) * (1 - smooth(.28, .46, p));
    f.haze = 1.5 * smooth(0, .03, p) * (1 - smooth(.14, .3, p));

    f.stars = smooth(.15, .42, p);
    f.starsShift = (f.oy - .5) * .3;
    f.starsStreak = f.streak / .03;

    // Ignition hits hard, the climb keeps rattling, and it fades as the air thins.
    const kick = smooth(0, .015, p) * (1 - smooth(.015, .07, p));
    f.shake = (.009 + .008 * kick) * smooth(0, .012, p) * (1 - .55 * smooth(.12, .34, p)) * (1 - smooth(.34, .46, p));

    // Fire and smoke roll out from the pad at ignition and are left below.
    f.pad = smooth(0, .03, p) * (1 - smooth(.28, .42, p));
    f.padRise = .2 + .5 * smooth(0, .18, p);
    f.padDrop = f.oy - .5;
    f.fire = smooth(0, .02, p) * (1 - smooth(.24, .38, p));

    // The satellites deploy while the globe is still settling, so the two
    // movements overlap instead of following one another.
    f.ui = 1;
    f.reveal = span(.62, 1, p);
    return f;
}

// Cancelled: the capsule's window frames the view, the globe grows as the
// capsule falls towards it, plasma wraps the window during re-entry, the
// surface flattens into the desktop and the touchdown shakes everything.
function landing(l, aspect, radius) {
    const f = orbit(aspect, radius);
    const touchdown = .76;

    const approach = Math.pow(span(.04, touchdown, l), 1.6);
    const reach = 1 - approach;
    const grown = Math.pow(approach, 1.3);
    f.k = Math.max(1e-4, Math.pow(reach, 2.6) / radius);
    f.wx = mix(Math.PI * radius, aspect, grown);
    f.wy = mix(Math.PI * radius, 1, grown);
    f.capTop = 1;
    f.ball = 1 - smooth(.5, touchdown, l);
    f.rim = 1 - smooth(.45, .7, l);

    f.plasma = smooth(.26, .5, l) * (1 - smooth(.7, touchdown + .005, l));
    f.haze = f.plasma;
    f.hazeEdges = 1;
    f.impact = smooth(touchdown - .004, touchdown + .012, l) * (1 - smooth(touchdown + .015, touchdown + .2, l));
    f.shockRadius = Math.max(0, l - touchdown) * 11;
    f.flash = smooth(touchdown - .002, touchdown + .008, l) * (1 - smooth(touchdown + .008, touchdown + .07, l));
    f.shake = .0028 * f.plasma + .012 * f.impact;

    f.frame = smooth(.02, .16, l) * (1 - smooth(.84, 1, l));
    f.frameZoom = 1 + .07 * (1 - smooth(.02, .2, l)) + .06 * smooth(.84, 1, l);
    f.stars = 1 - smooth(.3, .62, l);
    f.starsZoom = 1 + 2.5 * approach;
    f.ui = 1 - smooth(0, .1, l);
    return f;
}

// An app was chosen: the globe swells back into the desktop the app opens on.
function exit(x, aspect, radius) {
    const f = orbit(aspect, radius);
    const e = easeInOut(x);
    const grown = Math.pow(e, 1.2);
    f.k = Math.max(1e-4, Math.pow(1 - e, 2.2) / radius);
    f.wx = mix(Math.PI * radius, aspect, grown);
    f.wy = mix(Math.PI * radius, 1, grown);
    f.capTop = 1;
    f.ball = 1 - smooth(.45, .95, x);
    f.rim = 1 - smooth(.3, .8, x);
    f.stars = 1 - smooth(.25, .75, x);
    f.ui = 1 - smooth(0, .3, x);
    return f;
}

// Blend every value of two flight states.
function blend(a, b, t) {
    const f = {};
    for (const key in b)
        f[key] = mix(a[key], b[key], t);
    return f;
}

// Cancelled during lift-off: settle straight back onto the pad. Curvature is
// blended in log space so the horizon unbends at an even pace.
function abort(x, from, aspect) {
    const e = easeOut(x);
    const f = blend(from, rest(aspect), e);
    f.k = Math.exp(mix(Math.log(Math.max(1e-4, from.k)), Math.log(1e-4), e));
    f.capTop = from.capTop;
    // The sky keeps its colour while the horizon sinks back to the top edge.
    f.sky = from.sky;
    f.space = from.space;
    return f;
}

// The state for the launcher's current phase. `from` is the state when closing
// began; a landing or exit started before orbit eases out of it first.
function state(mode, progress, closeProgress, from, aspect, radius) {
    if (mode === "abort")
        return abort(closeProgress, from, aspect);

    if (mode === "landing" || mode === "exit") {
        const target = mode === "landing" ? landing(closeProgress, aspect, radius) : exit(closeProgress, aspect, radius);
        if (!from || from.reveal >= 1)
            return target;
        const settle = smooth(0, mode === "landing" ? .22 : .5, closeProgress);
        const f = blend(from, target, settle);
        f.k = Math.exp(mix(Math.log(Math.max(1e-4, from.k)), Math.log(Math.max(1e-4, target.k)), settle));
        f.capTop = target.capTop;
        return f;
    }

    return entrance(progress, aspect, radius);
}
