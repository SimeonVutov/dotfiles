#version 440
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 shake;          // camera shake, in screen heights
    vec4 pane;           // cockpit window: centre (xy) and half size (zw)
    float aspect;
    float clock;         // seconds
    float pad;           // smoke on the launch pad
    float padRise;       // how high it has billowed, in screen heights
    float padDrop;       // how far the ground has fallen away
    float fire;          // exhaust light from below the view
    float plasma;        // re-entry plasma around the window
};

// Everything soft in the flight, rendered at reduced resolution and scaled up:
// fire, smoke and the exhaust's light at lift-off, and the re-entry plasma.
// The output is premultiplied; glowing parts add more light than they cover.
//
// Positions are in screen heights, with y pointing down. The launch pad's
// ground line sits at y = 1 plus the distance the ground has dropped.

// The three colours of fire, from white-hot to cooling embers.
const vec3 CORE = vec3(1.0, .93, .78);
const vec3 FLAME = vec3(1.0, .56, .2);
const vec3 EMBER = vec3(.85, .24, .06);

// Pad smoke, flow: the clouds swell outward from the pad, so the noise is
// scaled about the centre and both sides stay one continuous cloud. How far
// the noise is stretched across and down, how fast the clouds swell, and how
// fast they roll upward.
const float SMOKE_FLOW_ACROSS = 1.7;
const float SMOKE_SWELL_RATE = .55;
const float SMOKE_FLOW_DOWN = 2.2;
const float SMOKE_ROLL_SPEED = .45;

// Pad smoke, shape: the cloud top is highest over the pad and lower to the
// sides (the share that is always present, the share that peaks over the pad,
// and how narrow that peak is), and billows up and down with the noise (its
// base level and variation).
const float CLOUD_BASE_SHARE = .45;
const float CLOUD_CENTRE_SHARE = .55;
const float CLOUD_CENTRE_NARROWNESS = .6;
const float BILLOW_BASE = .55;
const float BILLOW_VARIATION = .9;

// Pad smoke, density: how softly the top edge fades in (above and below the
// cloud top), the overall density, the scale and offset of the finer noise
// layered on top, and how much that detail varies the density.
const vec2 SMOKE_EDGE_SOFTNESS = vec2(.03, .07);
const float SMOKE_DENSITY = 1.25;
const float DETAIL_SCALE = 2.3;
const float DETAIL_OFFSET = 7.3;
const float DETAIL_DENSITY_BASE = .65;
const float DETAIL_DENSITY_DEPTH = .5;

// Pad smoke, colour: sunlit white billows with shaded folds. The shaded and
// sunlit colours, how deep below the cloud top the sunlight reaches, and how
// much sunlight and detail brighten the smoke.
const vec3 SMOKE_SHADE = vec3(.52, .53, .56);
const vec3 SMOKE_SUNLIT = vec3(.98, .97, .95);
const vec2 SMOKE_SUNLIT_RANGE = vec2(.16, -.01);
const float SUNLIGHT_WEIGHT = .6;
const float DETAIL_WEIGHT = .55;

// Pad smoke, firelight: the flame lights the smoke orange only close to the
// pad. The lit colour (a boost of the flame plus an offset), how far the
// light reaches across and down, and how quickly it fades.
const float FIRELIGHT_BOOST = 1.2;
const vec3 FIRELIGHT_OFFSET = vec3(.15, .07, 0.0);
const float FIRELIGHT_REACH_ACROSS = 1.3;
const float FIRELIGHT_REACH_DOWN = 2.2;
const float FIRELIGHT_FALLOFF = 3.6;

// Re-entry plasma, streaks: it streams out from the middle of the view in
// streaks around the window. How many streaks go around, how stretched they
// are along the stream, and how fast they stream.
const float PLASMA_STREAK_COUNT = 14.0;
const float PLASMA_STREAK_STRETCH = 2.0;
const float PLASMA_STREAM_SPEED = 5.5;

// Re-entry plasma, sheet: where the plasma wraps the window's edges (the
// range of edge distance over which it fades in), how ragged the streaks make
// that boundary, and the glow's base level and streak variation.
const vec2 SHEET_RANGE = vec2(.45, 1.1);
const float SHEET_RAGGEDNESS = .35;
const float PLASMA_GLOW_BASE = .5;
const float PLASMA_GLOW_STREAKS = .6;

// Re-entry plasma, sparks of burning material: how many go around, how
// stretched they are along the stream, how fast they stream, the noise level
// that becomes a spark, how far from the window they appear, and how bright
// they are.
const float SPARK_COUNT = 380.0;
const float SPARK_STRETCH = 14.0;
const float SPARK_SPEED = 20.0;
const vec2 SPARK_THRESHOLD = vec2(.93, .99);
const vec2 SPARK_EDGE_RANGE = vec2(.3, .8);
const float SPARK_BRIGHTNESS = 2.0;

// Re-entry plasma, colour: the streak level at which the plasma turns from
// flame to white-hot, how brightly the plasma lights, the faint tint over the
// whole window, and how much glow and tint make the plasma opaque.
const vec2 WHITE_HOT_RANGE = vec2(.75, 1.0);
const float PLASMA_LIGHT = 1.3;
const float PLASMA_TINT = .1;
const float PLASMA_GLOW_OPACITY = .7;
const float PLASMA_TINT_OPACITY = .6;

// Flame tongues licking up from the pad, white-hot at their roots: how much
// the noise is stretched across and up, how fast it rises, the tongues' base
// height and turbulence, how tall they are away from and over the pad (and how
// narrow that peak is), how much of the root stays flame coloured, and where
// the white-hot part begins.
const vec2 FLAME_FLOW = vec2(7.0, 5.0);
const float FLAME_RISE_SPEED = 6.0;
const float TONGUE_BASE_HEIGHT = .07;
const float TONGUE_TURBULENCE = .16;
const float TONGUE_EDGE_SHARE = .4;
const float TONGUE_CENTRE_SHARE = .6;
const float TONGUE_CENTRE_NARROWNESS = 3.0;
const float TONGUE_SOFT_ROOT = .35;
const float WHITE_HOT_ROOT = .5;
const float FLAME_BRIGHTNESS = 1.3;
const float FLAME_OPACITY = .85;

// The exhaust's light rising over the whole bottom of the view: how quickly it
// fades upward, its strength away from and over the pad (and how narrow that
// peak is), how bright and how opaque it is, and its flicker (base level,
// depth, rate and noise seed).
const float EXHAUST_FALLOFF = 3.2;
const float EXHAUST_EDGE_SHARE = .55;
const float EXHAUST_CENTRE_SHARE = .45;
const float EXHAUST_CENTRE_NARROWNESS = 2.0;
const float EXHAUST_BRIGHTNESS = .6;
const float EXHAUST_OPACITY = .1;
const float EXHAUST_FLICKER_BASE = .85;
const float EXHAUST_FLICKER_DEPTH = .15;
const float EXHAUST_FLICKER_RATE = 27.0;
const float EXHAUST_FLICKER_SEED = 3.3;

float hash(vec2 p) {
    vec3 h = fract(vec3(p.xyx) * vec3(.1031, .1103, .0973));
    h += dot(h, h.yzx + 33.33);
    return fract((h.x + h.y) * h.z);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

// Value noise repeating every `period` cells along x, for patterns that go
// around a circle without a seam.
float noiseAround(vec2 p, float period) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    float x0 = mod(i.x, period);
    float x1 = mod(i.x + 1.0, period);
    return mix(mix(hash(vec2(x0, i.y)), hash(vec2(x1, i.y)), f.x),
               mix(hash(vec2(x0, i.y + 1.0)), hash(vec2(x1, i.y + 1.0)), f.x), f.y);
}

// Four octaves of seamless noise around a circle; each octave doubles the
// period so the seam stays hidden.
float fbmAround(vec2 p, float period) {
    float sum = 0.0;
    float amplitude = .5;
    for (int i = 0; i < 4; ++i) {
        sum += amplitude * noiseAround(p, period);
        p = p * 2.0 + vec2(0.0, 9.4);
        period *= 2.0;
        amplitude *= .5;
    }
    return sum;
}

// Four octaves of noise.
float fbm(vec2 p) {
    float sum = 0.0;
    float amplitude = .5;
    for (int i = 0; i < 4; ++i) {
        sum += amplitude * noise(p);
        p = p * 2.03 + vec2(17.1, 9.4);
        amplitude *= .5;
    }
    return sum;
}

// Composite a premultiplied layer under the ones already accumulated.
void under(inout vec4 acc, vec4 layer) {
    acc += layer * (1.0 - acc.a);
}

// Exhaust clouds rolling out from the pad, lit by the fire from below.
vec4 padSmoke(vec2 p) {
    float base = 1.0 + padDrop;
    float dx = p.x - aspect * .5;

    // The clouds swell outward from the pad: the noise is scaled about the
    // centre, so both sides stay one continuous cloud.
    vec2 flow = vec2(dx * SMOKE_FLOW_ACROSS / (1.0 + clock * SMOKE_SWELL_RATE), (p.y - base) * SMOKE_FLOW_DOWN + clock * SMOKE_ROLL_SPEED);
    float billow = fbm(flow);
    float height = padRise * (CLOUD_BASE_SHARE + CLOUD_CENTRE_SHARE * exp(-dx * dx * CLOUD_CENTRE_NARROWNESS)) * (BILLOW_BASE + BILLOW_VARIATION * billow);
    float top = base - height;
    float density = smoothstep(top - SMOKE_EDGE_SOFTNESS.x, top + SMOKE_EDGE_SOFTNESS.y, p.y) * pad * SMOKE_DENSITY;
    if (density <= 0.0)
        return vec4(0.0);

    float detail = fbm(flow * DETAIL_SCALE + DETAIL_OFFSET);
    density *= DETAIL_DENSITY_BASE + DETAIL_DENSITY_DEPTH * detail;

    // Sunlit white billows with shaded folds; the flame lights them orange
    // only close to the pad.
    float lit = smoothstep(top + SMOKE_SUNLIT_RANGE.x, top + SMOKE_SUNLIT_RANGE.y, p.y);
    vec3 colour = mix(SMOKE_SHADE, SMOKE_SUNLIT, clamp(lit * SUNLIGHT_WEIGHT + detail * DETAIL_WEIGHT, 0.0, 1.0));
    float toFire = length(vec2(dx * FIRELIGHT_REACH_ACROSS, (p.y - base) * FIRELIGHT_REACH_DOWN));
    colour = mix(colour, FLAME * FIRELIGHT_BOOST + FIRELIGHT_OFFSET, exp(-toFire * FIRELIGHT_FALLOFF) * fire);
    return vec4(colour, 1.0) * clamp(density, 0.0, 1.0);
}

// Re-entry: plasma streaming out from the middle of the view and wrapping the
// edges of the window, flickering, with sparks of burning material.
vec4 reentry(vec2 p) {
    vec2 q = (p - pane.xy) / pane.zw;
    float edge = max(abs(q.x), abs(q.y));
    float radial = length(q);
    float around = atan(q.y, q.x) / 6.2831853 + .5;

    float streaks = fbmAround(vec2(around * PLASMA_STREAK_COUNT, radial * PLASMA_STREAK_STRETCH - clock * PLASMA_STREAM_SPEED), PLASMA_STREAK_COUNT);
    float sheet = smoothstep(SHEET_RANGE.x, SHEET_RANGE.y, edge + (streaks - .5) * SHEET_RAGGEDNESS);
    float glow = sheet * (PLASMA_GLOW_BASE + PLASMA_GLOW_STREAKS * streaks) * plasma;

    float sparkField = noiseAround(vec2(around * SPARK_COUNT, radial * SPARK_STRETCH - clock * SPARK_SPEED), SPARK_COUNT);
    float sparks = smoothstep(SPARK_THRESHOLD.x, SPARK_THRESHOLD.y, sparkField) * smoothstep(SPARK_EDGE_RANGE.x, SPARK_EDGE_RANGE.y, edge) * plasma;

    vec3 colour = mix(EMBER, mix(FLAME, CORE, smoothstep(WHITE_HOT_RANGE.x, WHITE_HOT_RANGE.y, streaks)), clamp(sheet, 0.0, 1.0));
    float tint = PLASMA_TINT * plasma;
    vec3 light = colour * (glow * PLASMA_LIGHT + tint) + CORE * sparks * SPARK_BRIGHTNESS;
    return vec4(light, clamp(glow * PLASMA_GLOW_OPACITY + tint * PLASMA_TINT_OPACITY, 0.0, 1.0));
}

// Flame tongues licking up from the pad in front of the smoke, white-hot at
// their roots, and the exhaust's light rising over the whole bottom of the
// view. Drawn over the layers accumulated so far.
vec4 padFire(vec2 q, vec4 acc) {
    float base = 1.0 + padDrop;
    float dx = q.x - aspect * .5;

    float turbulence = fbm(vec2(dx * FLAME_FLOW.x, (q.y - base) * FLAME_FLOW.y + clock * FLAME_RISE_SPEED));
    float tongue = (TONGUE_BASE_HEIGHT + TONGUE_TURBULENCE * turbulence) * (TONGUE_EDGE_SHARE + TONGUE_CENTRE_SHARE * exp(-dx * dx * TONGUE_CENTRE_NARROWNESS));
    float flame = smoothstep(base - tongue, base - tongue * TONGUE_SOFT_ROOT, q.y) * fire;
    vec3 flameColour = mix(FLAME, CORE, smoothstep(base - tongue * WHITE_HOT_ROOT, base, q.y));
    acc = vec4(flameColour * flame * FLAME_BRIGHTNESS, flame * FLAME_OPACITY) + acc * (1.0 - flame * FLAME_OPACITY);

    float rise = exp(-(base - q.y) * EXHAUST_FALLOFF) * (EXHAUST_EDGE_SHARE + EXHAUST_CENTRE_SHARE * exp(-dx * dx * EXHAUST_CENTRE_NARROWNESS));
    float flicker = EXHAUST_FLICKER_BASE + EXHAUST_FLICKER_DEPTH * noise(vec2(clock * EXHAUST_FLICKER_RATE, EXHAUST_FLICKER_SEED));
    acc.rgb += FLAME * rise * fire * EXHAUST_BRIGHTNESS * flicker;
    acc.a = min(1.0, acc.a + rise * fire * EXHAUST_OPACITY);
    return acc;
}

void main() {
    vec2 p = qt_TexCoord0 * vec2(aspect, 1.0);
    vec4 acc = vec4(0.0);

    // The shake is subtracted at each call rather than once: sharing the
    // result changes how the compiler fuses the arithmetic and moves the
    // noise cells' edges by a pixel.
    if (plasma > 0.0)
        under(acc, reentry(p - shake));
    if (pad > 0.0)
        under(acc, padSmoke(p - shake));
    if (fire > 0.0)
        acc = padFire(p - shake, acc);

    fragColor = acc * qt_Opacity;
}
