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

// The ground station's answers are warmer than the satellite's signal.
const vec3 REPLY = vec3(1.0, .9, .74);

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

// The ground station's answers relative to normal traffic: slower, less
// frequent, and out of step with the satellite's own arcs.
const float REPLY_PACE_SCALE = .7;
const float REPLY_BEAT_SCALE = 1.6;
const float REPLY_SEED_SCALE = 2.3;

// Normal traffic comes in short bursts of a few arcs, then quiet: how often
// bursts come, and where within each cycle they switch on and off.
const float BURST_RATE = .7;
const vec2 BURST_ON_RANGE = vec2(.45, .6);
const vec2 BURST_OFF_RANGE = vec2(.85, 1.0);

// The beam arcs are kept to: its width at the emitter and how much it
// spreads with distance.
const float BEAM_BASE_WIDTH = 1.6;
const float BEAM_SPREAD = .11;

// Arcs vanish before the far end, as a fraction of the link length, and fade
// in just after leaving the emitter, in pixels.
const vec2 REACH_FADE_RANGE = vec2(.7, .98);
const vec2 EMERGE_RANGE = vec2(2.0, 8.0);

// Arcs are faint along their way and bright near where they were sent: the
// faintest level, as a fraction of full brightness.
const float FAR_END_BRIGHTNESS = .25;

// The dish and the ground station glow while they talk: the dish's radius,
// the station's radius when idle and when selected, their weights, and the
// pulse's base level, depth, and its rate when idle and when selected.
const float DISH_RADIUS = 5.0;
const vec2 STATION_RADIUS = vec2(2.5, 4.0);
const float DISH_GLOW = .35;
const float STATION_GLOW = .8;
const float PULSE_BASE = .75;
const float PULSE_DEPTH = .25;
const vec2 PULSE_RATE = vec2(5.0, 11.0);
const float PULSE_SEED_SCALE = 6.28;

// How bright the link is overall, from the weakest to the strongest
// attention, and how much brighter the glows get when the link is selected.
const vec2 POWER_RANGE = vec2(.42, .84);
const float SELECTED_GLOW_BOOST = 2.0;

// The active stream is bright and nearly solid, so it stands out at once: its
// weight, and how much of it survives at the far end.
const float STREAM_BRIGHTNESS = 1.9;
const float STREAM_FAR_END_BRIGHTNESS = .6;

// How strongly the ground station's answers show.
const float REPLY_BRIGHTNESS = .5;

// Normal traffic comes in short bursts of a few arcs, then quiet.
float burst(float sent, float phase) {
    float cycle = fract(sent * BURST_RATE + phase);
    return smoothstep(BURST_ON_RANGE.x, BURST_ON_RANGE.y, cycle) * (1.0 - smoothstep(BURST_OFF_RANGE.x, BURST_OFF_RANGE.y, cycle));
}

// Whether the satellite was the active one when an arc was sent, in the
// current or one of the two previous selections.
float activeAt(float sent) {
    return max(step(activeSince, sent) * step(sent, activeUntil),
               max(step(earlier.x, sent) * step(sent, earlier.y), step(earlier.z, sent) * step(sent, earlier.w)));
}

// One family of arcs from an emitter at `emitter` towards the far end, kept to
// a beam around the link and bowed forward the way they travel. `activeStream`
// 1 is the active satellite's stream, sent only while it is active; 0 is
// normal traffic in bursts, paused while the stream runs.
float ripples(vec2 p, vec2 emitter, float pace, float beat, float thickness, float phase, float activeStream) {
    vec2 offset = p - emitter;
    float emitterDistance = length(offset);

    // Which arc passes this pixel, and whether that arc was actually sent.
    float front = emitterDistance + BEND * offset.y * offset.y;
    float sent = clock - front / pace;
    float sentAt = floor(sent / beat + .5) * beat;
    float talking = activeAt(sentAt);
    float exists = activeStream > .5 ? talking : burst(sentAt, phase) * (1.0 - talking);
    float arc = exp(-pow((sent - sentAt) * pace / thickness, 2.0));

    float beam = exp(-pow(abs(offset.y) / (BEAM_BASE_WIDTH + emitterDistance * BEAM_SPREAD), 2.0));
    // Arcs grow fainter as they travel and vanish before the far end.
    float reach = 1.0 - smoothstep(REACH_FADE_RANGE.x, REACH_FADE_RANGE.y, emitterDistance / span);
    float emerge = smoothstep(EMERGE_RANGE.x, EMERGE_RANGE.y, emitterDistance);
    return arc * exists * beam * reach * emerge;
}

void main() {
    vec2 p = vec2(qt_TexCoord0.x * span, (qt_TexCoord0.y - .5) * breadth);
    vec2 dish = vec2(span, 0.0);

    float down = ripples(p, dish, PACE, BEAT, THICKNESS, seed, 0.0);
    float stream = ripples(p, dish, ACTIVE_PACE, ACTIVE_BEAT, ACTIVE_THICKNESS, seed, 1.0);
    // The ground station's answers, always normal traffic.
    float up = ripples(vec2(span - p.x, p.y), dish, PACE * REPLY_PACE_SCALE, BEAT * REPLY_BEAT_SCALE, THICKNESS, seed * REPLY_SEED_SCALE, 0.0);

    // Faint along their way, bright near where they were sent.
    float downFade = mix(FAR_END_BRIGHTNESS, 1.0, smoothstep(0.0, 1.0, p.x / span));
    float upFade = mix(FAR_END_BRIGHTNESS, 1.0, smoothstep(1.0, 0.0, p.x / span));

    // The dish and the ground station glow while they talk.
    float dishLight = exp(-pow(length(p - dish) / DISH_RADIUS, 2.0));
    float stationLight = exp(-pow(length(p) / mix(STATION_RADIUS.x, STATION_RADIUS.y, selected), 2.0));
    float pulse = PULSE_BASE + PULSE_DEPTH * sin(clock * mix(PULSE_RATE.x, PULSE_RATE.y, selected) + seed * PULSE_SEED_SCALE);

    float power = mix(POWER_RANGE.x, POWER_RANGE.y, strength);
    float glows = (dishLight * DISH_GLOW + stationLight * STATION_GLOW) * pulse * power * mix(1.0, SELECTED_GLOW_BOOST, selected);

    // The active stream is bright and nearly solid, so it stands out at once.
    vec3 rgb = colour.rgb * (down * downFade * power + stream * mix(STREAM_FAR_END_BRIGHTNESS, 1.0, downFade) * STREAM_BRIGHTNESS + glows)
        + REPLY * up * upFade * power * REPLY_BRIGHTNESS;

    rgb *= link;

    float alpha = clamp(max(max(rgb.r, rgb.g), rgb.b), 0.0, 1.0);
    fragColor = vec4(rgb, alpha) * qt_Opacity;
}
