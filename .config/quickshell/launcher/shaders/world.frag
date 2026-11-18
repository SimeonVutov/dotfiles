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

const vec3 AIR = vec3(.45, .72, 1.0);
const vec3 SKY_LOW = vec3(.42, .64, .9);
const vec3 SKY_HIGH = vec3(.12, .26, .52);
const vec3 SUN = vec3(-.5, -.56, .66);
const vec2 SUN_SIDE = vec2(-.666, -.746);

float mirrored(float x) {
    return 1.0 - abs(mod(x, 2.0) - 1.0);
}

vec3 desktop(vec2 uv) {
    vec2 st = vec2(mirrored(uv.x), mirrored(uv.y));
    if (streak > 0.0) {
        // Three taps, jittered per pixel so the blur reads as motion.
        float jitter = fract(52.9829189 * fract(dot(gl_FragCoord.xy, vec2(.06711056, .00583715)))) - .5;
        vec3 sum = textureLod(source, st, 0.0).rgb;
        sum += textureLod(source, vec2(st.x, mirrored(uv.y + streak * (jitter + .5) * .5)), 0.0).rgb;
        sum += textureLod(source, vec2(st.x, mirrored(uv.y - streak * (.5 - jitter) * .5)), 0.0).rgb;
        return sum / 3.0;
    }
    return sharp > .5 ? textureLod(source, st, 0.0).rgb : texture(source, st).rgb;
}

void main() {
    vec2 p = viewport.xy + qt_TexCoord0 * viewport.zw - shake;

    // Heat shimmer: rising from the engines at lift-off, around the window on re-entry.
    if (haze > 0.0) {
        vec2 fromMiddle = p - vec2(aspect * .5, .5);
        float where = mix(smoothstep(.55, 1.05, p.y), .35 + .65 * smoothstep(.02, .55, dot(fromMiddle, fromMiddle)), hazeEdges);
        p += vec2(sin(p.y * 64.0 + clock * 29.0), sin(p.x * 57.0 - clock * 23.0)) * haze * .0022 * where;
    }

    // Touchdown: a pressure ring races out from the middle of the view.
    vec2 split = vec2(0.0);
    if (impact > 0.0) {
        vec2 fromMiddle = p - vec2(aspect * .5, .5);
        float middle = length(fromMiddle);
        vec2 outward = fromMiddle / max(middle, 1e-3);
        float ring = (middle - shockRadius) * 5.0;
        p -= outward * impact * .03 * exp(-ring * ring) * smoothstep(0.0, .25, middle);
        split = outward * impact * .005;
    }

    float k = max(curvature, 1e-4);
    vec2 d = (p - centre) * k;
    float r2 = dot(d, d);
    float edge = pixel * k;
    float sinLon = clamp(d.x, -1.0, 1.0);
    float cosLon = sqrt(max(1.0 - sinLon * sinLon, 1e-6));

    vec3 ground = vec3(0.0);
    float groundCover = 0.0;
    float limit = 1.0 + edge;
    if (r2 < limit * limit) {
        float r = sqrt(r2);
        vec2 uv = vec2(asin(sinLon), asin(clamp(d.y / cosLon, -1.0, 1.0))) * arcScale + .5;
        groundCover = 1.0 - smoothstep(1.0 - edge, limit, r);

        if (hasSurface > .5) {
            ground = desktop(uv);
            if (impact > 0.0) {
                vec2 offset = split * arcScale * k;
                ground.r = desktop(uv + offset).r;
                ground.b = desktop(uv - offset).b;
            }
        } else {
            ground = mix(vec3(.05, .16, .3), vec3(.1, .36, .55), mirrored(uv.y));
        }

        // A lit globe: day side, night side and the atmosphere at its edge.
        if (ball > 0.0) {
            vec3 n = vec3(d, sqrt(max(0.0, 1.0 - r2)));
            float day = smoothstep(-.35, .75, dot(n, SUN));
            float side = 1.0 - n.z;
            float fresnel = side * side * sqrt(side);
            ground = ground * mix(1.0, .2 + .8 * day, ball) + AIR * fresnel * ball * (.25 + .75 * day) * .7;
        }

        // The horizon is the desktop's top edge; blue haze over the far ground below it.
        if (capTop < 1.0) {
            float w = fwidth(uv.y) + 1e-6;
            groundCover *= mix(smoothstep(-w, 0.0, uv.y), 1.0, capTop);
            float far = (1.0 - capTop) * (1.0 - ball) * rim;
            if (far > 0.0)
                ground = mix(ground, AIR * mix(.85, .45, space), exp(-max(uv.y, 0.0) * 9.0) * far * .45);
        }
    }

    vec3 colour = ground * groundCover;
    float alpha = groundCover;
    float open = 1.0 - groundCover;

    // Sky above the horizon, and the atmosphere's glow: a thin bright band on
    // the horizon, or a halo around the globe.
    if (open > 0.0 && (sky > 0.0 || rim > 0.0)) {
        float r = sqrt(r2);
        float above = max(abs(d.x) < 1.0 ? centre.y + cosLon * horizonDrop - p.y : (r - 1.0) / k, 0.0);
        float glow = 0.0;
        if (capTop < 1.0 && ball < 1.0)
            glow += (exp(-above * 40.0) * .55 + exp(-above * 9.0) * .2) * (1.0 - ball) * (1.0 - capTop);
        if (ball > 0.0) {
            float outside = max(r - 1.0, 0.0);
            float sunSide = .35 + .65 * smoothstep(-.7, .7, dot(d / max(r, 1e-4), SUN_SIDE));
            glow += (exp(-outside * 9.0) * .55 + exp(-outside * 2.4) * .12) * sunSide * ball;
        }
        glow *= rim * open;

        float skyCover = sky * open;
        if (skyCover > 0.0)
            colour += mix(SKY_LOW, SKY_HIGH, smoothstep(0.0, .55, above)) * (1.0 - space) * skyCover;
        colour += AIR * glow;
        alpha = min(1.0, alpha + skyCover + glow * .5);
    }

    fragColor = vec4(colour, alpha) * qt_Opacity;
}
