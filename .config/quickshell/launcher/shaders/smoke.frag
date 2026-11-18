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

const vec3 CORE = vec3(1.0, .93, .78);
const vec3 FLAME = vec3(1.0, .56, .2);
const vec3 EMBER = vec3(.85, .24, .06);

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
    vec2 flow = vec2(dx * 1.7 / (1.0 + clock * .55), (p.y - base) * 2.2 + clock * .45);
    float billow = fbm(flow);
    float height = padRise * (.45 + .55 * exp(-dx * dx * .6)) * (.55 + .9 * billow);
    float top = base - height;
    float density = smoothstep(top - .03, top + .07, p.y) * pad * 1.25;
    if (density <= 0.0)
        return vec4(0.0);

    float detail = fbm(flow * 2.3 + 7.3);
    density *= .65 + .5 * detail;
    // Sunlit white billows with shaded folds; the flame lights them orange
    // only close to the pad.
    float lit = smoothstep(top + .16, top - .01, p.y);
    vec3 colour = mix(vec3(.52, .53, .56), vec3(.98, .97, .95), clamp(lit * .6 + detail * .55, 0.0, 1.0));
    float toFire = length(vec2(dx * 1.3, (p.y - base) * 2.2));
    colour = mix(colour, FLAME * 1.2 + vec3(.15, .07, 0.0), exp(-toFire * 3.6) * fire);
    return vec4(colour, 1.0) * clamp(density, 0.0, 1.0);
}

// Re-entry: plasma streaming out from the middle of the view and wrapping the
// edges of the window, flickering, with sparks of burning material.
vec4 reentry(vec2 p) {
    vec2 q = (p - pane.xy) / pane.zw;
    float edge = max(abs(q.x), abs(q.y));
    float radial = length(q);
    float around = atan(q.y, q.x) / 6.2831853 + .5;
    float streaks = fbmAround(vec2(around * 14.0, radial * 2.0 - clock * 5.5), 14.0);
    float sheet = smoothstep(.45, 1.1, edge + (streaks - .5) * .35);
    float glow = sheet * (.5 + .6 * streaks) * plasma;

    float sparkField = noiseAround(vec2(around * 380.0, radial * 14.0 - clock * 20.0), 380.0);
    float sparks = smoothstep(.93, .99, sparkField) * smoothstep(.3, .8, edge) * plasma;

    vec3 colour = mix(EMBER, mix(FLAME, CORE, smoothstep(.75, 1.0, streaks)), clamp(sheet, 0.0, 1.0));
    float tint = .1 * plasma;
    vec3 light = colour * (glow * 1.3 + tint) + CORE * sparks * 2.0;
    return vec4(light, clamp(glow * .7 + tint * .6, 0.0, 1.0));
}

void main() {
    vec2 p = qt_TexCoord0 * vec2(aspect, 1.0);
    vec4 acc = vec4(0.0);

    if (plasma > 0.0)
        under(acc, reentry(p - shake));
    if (pad > 0.0)
        under(acc, padSmoke(p - shake));
    if (fire > 0.0) {
        vec2 q = p - shake;
        float base = 1.0 + padDrop;
        float dx = q.x - aspect * .5;

        // Flame tongues licking up from the pad in front of the smoke,
        // white-hot at their roots.
        float turbulence = fbm(vec2(dx * 7.0, (q.y - base) * 5.0 + clock * 6.0));
        float tongue = (.07 + .16 * turbulence) * (.4 + .6 * exp(-dx * dx * 3.0));
        float flame = smoothstep(base - tongue, base - tongue * .35, q.y) * fire;
        vec3 flameColour = mix(FLAME, CORE, smoothstep(base - tongue * .5, base, q.y));
        acc = vec4(flameColour * flame * 1.3, flame * .85) + acc * (1.0 - flame * .85);

        // The exhaust's light rising over the whole bottom of the view.
        float rise = exp(-(base - q.y) * 3.2) * (.55 + .45 * exp(-dx * dx * 2.0));
        float flicker = .85 + .15 * noise(vec2(clock * 27.0, 3.3));
        acc.rgb += FLAME * rise * fire * .6 * flicker;
        acc.a = min(1.0, acc.a + rise * fire * .1);
    }

    fragColor = acc * qt_Opacity;
}
