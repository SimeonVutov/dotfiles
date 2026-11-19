#version 440
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float progress;
    float aspect;
};
layout(binding = 1) uniform sampler2D source;

// The session menu's opening: the desktop is drawn into a black hole that
// swirls it inward, tears it into shearing bands, splits its colours and
// finally swallows it, leaving the void the menu appears on.

const float PI = 3.14159265;

// Infall: the progress at which it reaches full strength and how sharply it
// accelerates. Slow to start, then it runs away; it does not ease out.
const float INFALL_RAMP_END = 0.9;
const float INFALL_POWER = 2.3;

// Glass bending peaks mid-animation: the exponent shapes how early it builds.
const float BEND_POWER = 0.8;

// The hole itself drifts while it feeds: oscillation speeds and amplitude.
const vec2 WOBBLE_SPEED = vec2(6.0, 4.5);
const float WOBBLE_AMPLITUDE = 0.02;

// A shifting quadrupole keeps the well from reading as a static circle.
const float LOBE_STRENGTH = 0.11;
const float LOBE_COUNT = 2.0;
const float LOBE_SPIN = 5.0;

// How strongly material is pulled inward, linearly and quadratically with the
// infall strength.
const float INFLOW_LINEAR = 4.2;
const float INFLOW_QUADRATIC = 0.6;

// The lens riding on top of the inflow, strongest at the core: how quickly it
// fades with radius and how much it magnifies.
const float LENS_FALLOFF = 2.8;
const float LENS_MAGNIFICATION = 2.6;

// Differential rotation: its strength, the radius offset that keeps it finite
// at the core, and the extra twist light picks up through the lens.
const float SWIRL_STRENGTH = 4.6;
const float SWIRL_CORE_OFFSET = 0.16;
const float LENS_TWIST = 2.4;

// The shockwave crest running outward through the bent glass: its speed,
// sharpness and how far it pushes the material.
const float CREST_SPEED = 0.85;
const float CREST_SHARPNESS = 8.0;
const float CREST_PUSH = 0.16;

// Tear bands: the image shears in blocks that re-roll a couple dozen times a
// second. How fast they re-roll, how many bands there are, how fast the bands
// drift, and how often a band is torn once the bend is strong enough.
const float TEAR_ROLLS_PER_PROGRESS = 26.0;
const float TEAR_BAND_COUNT = 38.0;
const float TEAR_BAND_DRIFT = 0.7;
const float TEAR_SEED_STEP = 17.0;
const float TEAR_CHANCE_THRESHOLD = 0.6;
const vec2 TEAR_BEND_RANGE = vec2(0.12, 0.5);

// How far a torn band shifts sideways and vertically.
const float TEAR_SHIFT_X = 0.3;
const float TEAR_SHIFT_Y = 0.02;

// Five samples of the same material staggered in time smear it into streaks
// along its own path, which is what makes the swirl read as motion. How many
// samples there are, how far each lags the previous one, and how much less
// each counts.
const int SAMPLE_COUNT = 5;
const float SAMPLE_LAG = 0.038;
const float SAMPLE_WEIGHT_STEP = 0.15;

// Chromatic split: the lens no longer agrees with itself across wavelengths.
// The split grows with the bend and the infall, and jumps in torn bands. The
// mix is how much of the shifted red and blue replaces the original.
const float SPLIT_BASE = 0.005;
const float SPLIT_BEND = 0.02;
const float SPLIT_INFALL_BASE = 0.35;
const float SPLIT_GLITCH = 0.01;
const float SPLIT_MIX = 0.7;

// The event horizon opens up and keeps every photon that crosses it: its
// radius at the start and how much it grows, when it stops growing, and how
// quickly it grows.
const float HORIZON_START = 0.018;
const float HORIZON_GROWTH = 0.12;
const float HORIZON_RAMP_END = 0.92;
const float HORIZON_POWER = 1.6;

// How far past the horizon the darkening fades out, as a multiple of it.
const float HORIZON_FADE_SPAN = 2.3;

// The last light bending around the edge: where the ring sits relative to the
// horizon, how wide it is, the smallest width allowed, and its brightness.
const float RING_POSITION = 1.3;
const float RING_WIDTH = 0.34;
const float RING_MIN_WIDTH = 0.001;
const float RING_BRIGHTNESS = 0.9;
const float RING_STRENGTH = 0.4;

// The animation progress over which nothing survives the collapse, so the
// frame is empty before the menu settles.
const float COLLAPSE_START = 0.74;
const float COLLAPSE_END = 1.0;

float hash(float n) {
    return fract(sin(n * 127.1) * 43758.5453);
}

// The desktop at uv. Anything dragged in from beyond the frame is void, not
// edge-clamped smear.
vec3 fetch(vec2 uv) {
    float inside = step(0.0, uv.x) * step(uv.x, 1.0) * step(0.0, uv.y) * step(uv.y, 1.0);
    return texture(source, clamp(uv, 0.0, 1.0)).rgb * inside;
}

// Inverse flow map. Material spirals inward, so whatever sits at radius r now
// started further out: sampling outward along the spiral drags the desktop in.
vec2 warp(vec2 position, float infall, float bend) {
    float radius = length(position);
    float angle = atan(position.y, position.x);

    float lobe = 1.0 + LOBE_STRENGTH * sin(angle * LOBE_COUNT - progress * LOBE_SPIN) * infall;
    float sourceRadius = (radius * (1.0 + infall * INFLOW_LINEAR) + infall * infall * INFLOW_QUADRATIC) * lobe;

    // Glass bending: a lens riding on top of the inflow, strongest at the core.
    float glass = exp(-sourceRadius * LENS_FALLOFF) * bend;
    sourceRadius *= 1.0 + glass * LENS_MAGNIFICATION;

    // Differential rotation, plus the extra twist light picks up through the lens.
    float sourceAngle = angle - infall * SWIRL_STRENGTH / (sourceRadius + SWIRL_CORE_OFFSET) - glass * LENS_TWIST;

    // Shockwave crest running outward through the bent glass.
    sourceRadius += exp(-pow((sourceRadius - progress * CREST_SPEED) * CREST_SHARPNESS, 2.0)) * bend * CREST_PUSH;

    return vec2(cos(sourceAngle), sin(sourceAngle)) * sourceRadius / vec2(aspect, 1.0) + 0.5;
}

void main() {
    float infall = pow(clamp(progress / INFALL_RAMP_END, 0.0, 1.0), INFALL_POWER);
    float bend = sin(pow(progress, BEND_POWER) * PI);

    vec2 wobble = vec2(sin(progress * WOBBLE_SPEED.x), cos(progress * WOBBLE_SPEED.y)) * WOBBLE_AMPLITUDE * infall;
    vec2 position = (qt_TexCoord0 - 0.5) * vec2(aspect, 1.0) - wobble;
    float radius = length(position);

    // Bands shear in blocks that re-roll a couple dozen times a second, so the
    // desktop looks like it is coming apart, not just bending.
    float rollIndex = floor(progress * TEAR_ROLLS_PER_PROGRESS);
    float band = floor(qt_TexCoord0.y * TEAR_BAND_COUNT + rollIndex * TEAR_BAND_DRIFT);
    float bandRandom = hash(band + rollIndex * TEAR_SEED_STEP);
    float glitch = smoothstep(TEAR_BEND_RANGE.x, TEAR_BEND_RANGE.y, bend) * step(TEAR_CHANCE_THRESHOLD, bandRandom);
    vec2 tear = vec2((bandRandom - 0.5) * glitch * TEAR_SHIFT_X, (hash(band) - 0.5) * glitch * TEAR_SHIFT_Y);

    // The first sample's position is kept for the chromatic split below.
    vec2 firstSampleUv = vec2(0.0);
    vec3 accumulated = vec3(0.0);
    float weightSum = 0.0;
    for (int i = 0; i < SAMPLE_COUNT; i++) {
        float sampleInfall = infall * (1.0 - float(i) * SAMPLE_LAG);
        vec2 uv = warp(position, sampleInfall, bend) + tear;
        if (i == 0)
            firstSampleUv = uv;

        float weight = 1.0 - float(i) * SAMPLE_WEIGHT_STEP;
        accumulated += fetch(uv) * weight;
        weightSum += weight;
    }
    vec3 color = accumulated / weightSum;

    float split = (SPLIT_BASE + bend * SPLIT_BEND) * (SPLIT_INFALL_BASE + infall) + glitch * SPLIT_GLITCH;
    color.r = mix(color.r, fetch(firstSampleUv + vec2(split, 0.0)).r, SPLIT_MIX);
    color.b = mix(color.b, fetch(firstSampleUv - vec2(split, 0.0)).b, SPLIT_MIX);

    float horizon = HORIZON_START + HORIZON_GROWTH * pow(clamp(progress / HORIZON_RAMP_END, 0.0, 1.0), HORIZON_POWER);
    color *= smoothstep(horizon, horizon * HORIZON_FADE_SPAN, radius);

    float ring = exp(-pow((radius - horizon * RING_POSITION) / max(horizon * RING_WIDTH, RING_MIN_WIDTH), 2.0));
    color += vec3(RING_BRIGHTNESS) * ring * bend * RING_STRENGTH;

    color *= 1.0 - smoothstep(COLLAPSE_START, COLLAPSE_END, progress);

    // Opaque throughout, so drained areas read as void and not as the live desktop.
    fragColor = vec4(color * qt_Opacity, qt_Opacity);
}
