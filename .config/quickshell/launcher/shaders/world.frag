#version 440
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec4 viewport;      // this item's rectangle, in screen heights
    vec2 centre;        // sphere centre, in screen heights with y down
    vec2 arcScale;      // 1 / (curvature * the arc length the desktop covers)
    vec2 shake;         // camera shake, in screen heights
    float aspect;
    float curvature;    // 1 / sphere radius
    float horizonDrop;  // sin(-cover.y * curvature / 2) / curvature: the horizon above the centre
    float capTop;       // 0: sky above the desktop's top edge (the horizon); 1: more ground
    float ball;         // globe lighting
    float sky;          // sky opacity above the horizon
    float space;        // 0 daylight blue .. 1 black
    float rim;          // atmosphere along the horizon or around the limb
    float streak;       // vertical speed blur, in desktop heights
    float sharp;        // 1 while the desktop is near full size: sample without mipmaps
    float haze;         // heat shimmer
    float hazeEdges;    // 0: rising from the engines below; 1: around the window's edges
    float clock;        // seconds, for the shimmer
    float impact;       // touchdown shock
    float shockRadius;  // in screen heights
    float hasSurface;
    float pixel;        // one device pixel, in screen heights
};
layout(binding = 1) uniform sampler2D source;

// The desktop is a sheet laid over a sphere seen from the front. Longitude is
// arc length across, latitude arc length down, so rows bend into arcs while
// columns stay upright: a tiny curvature leaves the desktop untouched, a larger
// one curves its top edge into a horizon, and a curvature of pi / cover wraps
// it around the whole visible face of a globe. Past the desktop's edges the
// ground continues as its mirror image, so the globe has no seams.
//
// This pass covers the whole screen during lift-off and landing, so every
// feature is behind a test of its uniform and nothing unused is computed.

// The atmosphere's colour, the sky from low to high altitude, and the
// direction of the sun (towards the viewer, up and to the left) used to light
// the globe and its halo.
const vec3 AIR = vec3(.45, .72, 1.0);
const vec3 SKY_LOW = vec3(.42, .64, .9);
const vec3 SKY_HIGH = vec3(.12, .26, .52);
const vec3 SUN = vec3(-.5, -.56, .66);
const vec2 SUN_SIDE = vec2(-.666, -.746);

// Per-pixel jitter for the speed blur (interleaved gradient noise), so the
// blur reads as motion and not as banding: its scale and direction.
const float JITTER_SCALE = 52.9829189;
const vec2 JITTER_DIRECTION = vec2(.06711056, .00583715);

// Speed blur: how far, as a share of the streak, the two extra taps reach
// either side of the middle one.
const float STREAK_TAP_REACH = .5;

// Heat shimmer: where it is strongest. Rising from the engines it grows
// towards the bottom of the view; around the window's edges it grows with
// distance from the middle (a base level plus a share that ramps up).
const vec2 SHIMMER_ENGINE_RANGE = vec2(.55, 1.05);
const float SHIMMER_EDGE_BASE = .35;
const float SHIMMER_EDGE_SHARE = .65;
const vec2 SHIMMER_EDGE_RANGE = vec2(.02, .55);

// Heat shimmer waves: the spatial frequency and speed along each axis, and
// how far they displace the picture, in screen heights.
const vec2 SHIMMER_FREQUENCY = vec2(64.0, 57.0);
const vec2 SHIMMER_SPEED = vec2(29.0, 23.0);
const float SHIMMER_STRENGTH = .0022;

// Touchdown shock: how sharply the pressure ring is confined, how far it
// pushes the picture, over what distance from the middle it starts to act,
// and how far it splits the colour channels.
const float SHOCK_SHARPNESS = 5.0;
const float SHOCK_PUSH = .03;
const vec2 SHOCK_CENTRE_RANGE = vec2(0.0, .25);
const float SHOCK_COLOUR_SPLIT = .005;

// The ground colours (low and high) when there is no desktop to draw.
const vec3 BARE_GROUND_LOW = vec3(.05, .16, .3);
const vec3 BARE_GROUND_HIGH = vec3(.1, .36, .55);

// A lit globe: how the day side ramps in, how much light the ground keeps at
// night and how much more the day adds, and the atmosphere at the globe's edge
// (how bright it is, how much of it shows on the night side and how much more
// the day adds).
const vec2 DAY_RANGE = vec2(-.35, .75);
const float NIGHT_LIGHT = .2;
const float DAY_LIGHT = .8;
const float EDGE_ATMOSPHERE_BRIGHTNESS = .7;
const float EDGE_ATMOSPHERE_NIGHT_SHARE = .25;
const float EDGE_ATMOSPHERE_DAY_SHARE = .75;

// Blue haze over the far ground below the horizon: how quickly it fades down
// the desktop, how strong it is, and its tint in daylight and in space.
const float FAR_HAZE_FALLOFF = 9.0;
const float FAR_HAZE_STRENGTH = .45;
const vec2 FAR_HAZE_TINT = vec2(.85, .45);

// The atmosphere's glow above the horizon: a tight bright band and a wide
// faint one (their falloff and weight).
const vec2 HORIZON_BAND_FALLOFF = vec2(40.0, 9.0);
const vec2 HORIZON_BAND_WEIGHT = vec2(.55, .2);

// The halo around the globe: a tight and a wide ring (falloff and weight), and
// how much brighter it is on the sun side (the dimmest level and the share
// that ramps up towards the sun).
const vec2 HALO_FALLOFF = vec2(9.0, 2.4);
const vec2 HALO_WEIGHT = vec2(.55, .12);
const float HALO_DIM_SIDE = .35;
const float HALO_SUN_SHARE = .65;

// How high above the horizon the sky reaches full altitude colour, and how
// much of the glow counts towards opacity.
const float SKY_ALTITUDE_RANGE = .55;
const float GLOW_OPACITY = .5;

float mirrored(float x) {
    return 1.0 - abs(mod(x, 2.0) - 1.0);
}

vec3 desktop(vec2 uv) {
    vec2 st = vec2(mirrored(uv.x), mirrored(uv.y));
    if (streak > 0.0) {
        // Three taps, jittered per pixel so the blur reads as motion.
        float jitter = fract(JITTER_SCALE * fract(dot(gl_FragCoord.xy, JITTER_DIRECTION))) - .5;
        vec3 sum = textureLod(source, st, 0.0).rgb;
        sum += textureLod(source, vec2(st.x, mirrored(uv.y + streak * (jitter + .5) * STREAK_TAP_REACH)), 0.0).rgb;
        sum += textureLod(source, vec2(st.x, mirrored(uv.y - streak * (.5 - jitter) * STREAK_TAP_REACH)), 0.0).rgb;
        return sum / 3.0;
    }
    return sharp > .5 ? textureLod(source, st, 0.0).rgb : texture(source, st).rgb;
}

// Heat shimmer: rising from the engines at lift-off, around the window on
// re-entry. How far to displace the picture at `position`.
vec2 shimmerOffset(vec2 position) {
    vec2 fromMiddle = position - vec2(aspect * .5, .5);
    float where = mix(smoothstep(SHIMMER_ENGINE_RANGE.x, SHIMMER_ENGINE_RANGE.y, position.y),
                      SHIMMER_EDGE_BASE + SHIMMER_EDGE_SHARE * smoothstep(SHIMMER_EDGE_RANGE.x, SHIMMER_EDGE_RANGE.y, dot(fromMiddle, fromMiddle)),
                      hazeEdges);
    return vec2(sin(position.y * SHIMMER_FREQUENCY.x + clock * SHIMMER_SPEED.x), sin(position.x * SHIMMER_FREQUENCY.y - clock * SHIMMER_SPEED.y)) * haze * SHIMMER_STRENGTH * where;
}

// Touchdown: a pressure ring races out from the middle of the view. It pushes
// `position` outward and returns how far to split the colour channels.
vec2 applyShockwave(inout vec2 position) {
    vec2 fromMiddle = position - vec2(aspect * .5, .5);
    float middle = length(fromMiddle);
    vec2 outward = fromMiddle / max(middle, 1e-3);
    float ring = (middle - shockRadius) * SHOCK_SHARPNESS;

    position -= outward * impact * SHOCK_PUSH * exp(-ring * ring) * smoothstep(SHOCK_CENTRE_RANGE.x, SHOCK_CENTRE_RANGE.y, middle);
    return outward * impact * SHOCK_COLOUR_SPLIT;
}

// A lit globe: day side, night side and the atmosphere at its edge.
vec3 lightGlobe(vec3 ground, vec2 offsetOnSphere, float radiusSquared) {
    vec3 normal = vec3(offsetOnSphere, sqrt(max(0.0, 1.0 - radiusSquared)));
    float day = smoothstep(DAY_RANGE.x, DAY_RANGE.y, dot(normal, SUN));
    float side = 1.0 - normal.z;
    float fresnel = side * side * sqrt(side);
    return ground * mix(1.0, NIGHT_LIGHT + DAY_LIGHT * day, ball)
        + AIR * fresnel * ball * (EDGE_ATMOSPHERE_NIGHT_SHARE + EDGE_ATMOSPHERE_DAY_SHARE * day) * EDGE_ATMOSPHERE_BRIGHTNESS;
}

void main() {
    vec2 position = viewport.xy + qt_TexCoord0 * viewport.zw - shake;

    if (haze > 0.0)
        position += shimmerOffset(position);

    vec2 channelSplit = vec2(0.0);
    if (impact > 0.0)
        channelSplit = applyShockwave(position);

    // Position on the sphere, as a fraction of its radius from its centre.
    float sphereCurvature = max(curvature, 1e-4);
    vec2 offsetOnSphere = (position - centre) * sphereCurvature;
    float radiusSquared = dot(offsetOnSphere, offsetOnSphere);
    float limbWidth = pixel * sphereCurvature;
    float sinLongitude = clamp(offsetOnSphere.x, -1.0, 1.0);
    float cosLongitude = sqrt(max(1.0 - sinLongitude * sinLongitude, 1e-6));

    // The ground: the desktop wrapped over the sphere's visible face.
    vec3 ground = vec3(0.0);
    float groundCover = 0.0;
    float limit = 1.0 + limbWidth;
    if (radiusSquared < limit * limit) {
        float radius = sqrt(radiusSquared);
        vec2 uv = vec2(asin(sinLongitude), asin(clamp(offsetOnSphere.y / cosLongitude, -1.0, 1.0))) * arcScale + .5;
        groundCover = 1.0 - smoothstep(1.0 - limbWidth, limit, radius);

        if (hasSurface > .5) {
            ground = desktop(uv);
            if (impact > 0.0) {
                vec2 offset = channelSplit * arcScale * sphereCurvature;
                ground.r = desktop(uv + offset).r;
                ground.b = desktop(uv - offset).b;
            }
        } else {
            ground = mix(BARE_GROUND_LOW, BARE_GROUND_HIGH, mirrored(uv.y));
        }

        if (ball > 0.0)
            ground = lightGlobe(ground, offsetOnSphere, radiusSquared);

        // The horizon is the desktop's top edge; blue haze over the far ground below it.
        if (capTop < 1.0) {
            float width = fwidth(uv.y) + 1e-6;
            groundCover *= mix(smoothstep(-width, 0.0, uv.y), 1.0, capTop);
            float far = (1.0 - capTop) * (1.0 - ball) * rim;
            if (far > 0.0)
                ground = mix(ground, AIR * mix(FAR_HAZE_TINT.x, FAR_HAZE_TINT.y, space), exp(-max(uv.y, 0.0) * FAR_HAZE_FALLOFF) * far * FAR_HAZE_STRENGTH);
        }
    }

    vec3 colour = ground * groundCover;
    float alpha = groundCover;
    float open = 1.0 - groundCover;

    // Sky above the horizon, and the atmosphere's glow: a thin bright band on
    // the horizon, or a halo around the globe.
    if (open > 0.0 && (sky > 0.0 || rim > 0.0)) {
        float radius = sqrt(radiusSquared);
        float above = max(abs(offsetOnSphere.x) < 1.0 ? centre.y + cosLongitude * horizonDrop - position.y : (radius - 1.0) / sphereCurvature, 0.0);

        float glow = 0.0;
        if (capTop < 1.0 && ball < 1.0)
            glow += (exp(-above * HORIZON_BAND_FALLOFF.x) * HORIZON_BAND_WEIGHT.x + exp(-above * HORIZON_BAND_FALLOFF.y) * HORIZON_BAND_WEIGHT.y) * (1.0 - ball) * (1.0 - capTop);
        if (ball > 0.0) {
            float outside = max(radius - 1.0, 0.0);
            float sunSide = HALO_DIM_SIDE + HALO_SUN_SHARE * smoothstep(-.7, .7, dot(offsetOnSphere / max(radius, 1e-4), SUN_SIDE));
            glow += (exp(-outside * HALO_FALLOFF.x) * HALO_WEIGHT.x + exp(-outside * HALO_FALLOFF.y) * HALO_WEIGHT.y) * sunSide * ball;
        }
        glow *= rim * open;

        float skyCover = sky * open;
        if (skyCover > 0.0)
            colour += mix(SKY_LOW, SKY_HIGH, smoothstep(0.0, SKY_ALTITUDE_RANGE, above)) * (1.0 - space) * skyCover;
        colour += AIR * glow;
        alpha = min(1.0, alpha + skyCover + glow * GLOW_OPACITY);
    }

    fragColor = vec4(colour, alpha) * qt_Opacity;
}
