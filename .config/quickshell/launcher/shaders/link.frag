#version 440
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec4 colour;      // the atmosphere colour
    float span;       // link length, in pixels
    float breadth;    // this item's height, in pixels
    float link;       // 0..1 as the link comes up
    float selected;   // 0..1, the highlighted satellite's link
    float strength;   // brighter when few satellites share the planet's attention
    float clock;      // seconds
    float seed;       // per satellite, so the links do not pulse in step
    float activeSince; // clock time the satellite became the active one
    float activeUntil; // clock time it stopped being active (far future while it is)
    vec4 earlier;      // the two previous active periods: since, until, since, until
};

// One satellite's radio link, drawn in the link's own frame: the planet's
// ground station at the left end, the satellite at the right. There is no
// line: the satellite's dish sends arcs of signal rippling down towards the
// planet, and the ground station answers with fainter, warmer arcs rippling
// up. The active satellite sends a dense, fast, bright stream instead. A
// dropped link fades out with its satellite.

const vec3 REPLY = vec3(1.0, .9, .74);
const float PI = 3.14159265;

// The signal's arcs are sent on a fixed beat and keep the pace they were sent
// at, so an arc already on its way never changes; only arcs sent from now on
// do. Normal traffic and the active satellite's stream are separate families.
const float PACE = 100.0;          // normal arcs, pixels per second
const float BEAT = .26;            // seconds between normal arcs
const float ACTIVE_PACE = 190.0;   // the active satellite's arcs
const float ACTIVE_BEAT = .087;    // three times as often
const float BEND = .004;           // how much each arc bows forward
const float THICKNESS = 1.6;       // normal arcs, pixels
const float ACTIVE_THICKNESS = 2.3;

// Normal traffic comes in short bursts of a few arcs, then quiet.
float burst(float sent, float phase) {
    float f = fract(sent * .7 + phase);
    return smoothstep(.45, .6, f) * (1.0 - smoothstep(.85, 1.0, f));
}

// Whether the satellite was the active one when an arc was sent, in the
// current or one of the two previous selections.
float activeAt(float sent) {
    return max(step(activeSince, sent) * step(sent, activeUntil),
               max(step(earlier.x, sent) * step(sent, earlier.y), step(earlier.z, sent) * step(sent, earlier.w)));
}

// One family of arcs from an emitter at `from` towards the far end, kept to a
// beam around the link and bowed forward the way they travel. `stream` 1 is
// the active satellite's stream, sent only while it is active; 0 is normal
// traffic in bursts, paused while the stream runs.
float ripples(vec2 p, vec2 from, float pace, float beat, float thickness, float phase, float stream) {
    vec2 d = p - from;
    float r = length(d);
    float front = r + BEND * d.y * d.y;
    float sent = clock - front / pace;
    float at = floor(sent / beat + .5) * beat;
    float talking = activeAt(at);
    float exists = stream > .5 ? talking : burst(at, phase) * (1.0 - talking);
    float arc = exp(-pow((sent - at) * pace / thickness, 2.0));

    float beam = exp(-pow(abs(d.y) / (1.6 + r * .11), 2.0));
    // Arcs grow fainter as they travel and vanish before the far end.
    float reach = 1.0 - smoothstep(.7, .98, r / span);
    float start = smoothstep(2.0, 8.0, r);
    return arc * exists * beam * reach * start;
}

void main() {
    vec2 p = vec2(qt_TexCoord0.x * span, (qt_TexCoord0.y - .5) * breadth);

    float down = ripples(p, vec2(span, 0.0), PACE, BEAT, THICKNESS, seed, 0.0);
    float stream = ripples(p, vec2(span, 0.0), ACTIVE_PACE, ACTIVE_BEAT, ACTIVE_THICKNESS, seed, 1.0);
    // The ground station's answers, always normal traffic.
    float up = ripples(vec2(span - p.x, p.y), vec2(span, 0.0), PACE * .7, BEAT * 1.6, THICKNESS, seed * 2.3, 0.0);

    // Faint along their way, bright near where they were sent.
    float downFade = mix(.25, 1.0, smoothstep(0.0, 1.0, p.x / span));
    float upFade = mix(.25, 1.0, smoothstep(1.0, 0.0, p.x / span));

    // The dish and the ground station glow while they talk.
    float dish = exp(-pow(length(p - vec2(span, 0.0)) / 5.0, 2.0));
    float station = exp(-pow(length(p) / mix(2.5, 4.0, selected), 2.0));
    float pulse = .75 + .25 * sin(clock * mix(5.0, 11.0, selected) + seed * 6.28);

    float power = mix(.42, .84, strength);
    float glows = (dish * .35 + station * .8) * pulse * power * mix(1.0, 2.0, selected);
    // The active stream is bright and nearly solid, so it stands out at once.
    vec3 rgb = colour.rgb * (down * downFade * power + stream * mix(.6, 1.0, downFade) * 1.9 + glows)
        + REPLY * up * upFade * power * .5;

    rgb *= link;

    float alpha = clamp(max(max(rgb.r, rgb.g), rgb.b), 0.0, 1.0);
    fragColor = vec4(rgb, alpha) * qt_Opacity;
}
