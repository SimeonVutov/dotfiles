#version 440
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec4 pane;      // the window: centre (xy) and half size (zw), in screen heights
    float aspect;
    float corner;   // the window's corner radius, in screen heights
    float heat;     // re-entry glow reaching the frame
    float clock;    // seconds, for the flicker
    float pixel;    // one device pixel, in screen heights
};

// The capsule's window during the landing: brushed metal around a rounded
// pane, a lit bevel and rubber seal at the glass, a ring of bolts, two status
// lights and a placard; faint reflections on the glass. Re-entry heat lights
// the frame orange from outside.

const vec3 HEAT = vec3(1.0, .45, .16);

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

float roundedBox(vec2 p, vec2 extent, float radius) {
    vec2 q = abs(p) - extent + radius;
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - radius;
}

void main() {
    vec2 p = qt_TexCoord0 * vec2(aspect, 1.0);
    vec2 q = p - pane.xy;
    float d = roundedBox(q, pane.zw, corner);
    float flicker = .8 + .2 * noise(vec2(clock * 23.0, 4.1));

    // Glass: a soft reflected sheen, and the frame's warm light at its edge.
    float diagonal = q.x * .5 + q.y + pane.w * .55;
    float sheen = exp(-pow(diagonal / .05, 2.0)) * .045 + exp(-pow((diagonal - .09) / .015, 2.0)) * .025;
    float rim = exp(min(d, 0.0) / .04);
    vec3 glass = vec3(.6, .78, .92) * (sheen + rim * .04) + HEAT * heat * flicker * rim * .5;
    vec4 colour = vec4(glass, (sheen + rim * .04) * .6 + heat * rim * .12);

    float cover = smoothstep(-pixel, pixel, d);
    if (cover > 0.0) {
        // Brushed, slightly worn metal, darker away from the pane.
        float brushed = noise(vec2(p.x * 420.0, p.y * 9.0)) * .5 + noise(vec2(p.x * 37.0, p.y * 61.0)) * .5;
        vec3 metal = vec3(.115, .125, .14) * (.8 + .35 * brushed) * (1.0 - .45 * smoothstep(.05, .3, d));

        // The bevel around the pane catches light from above left.
        vec2 grad = normalize(vec2(dFdx(d), dFdy(d)) + 1e-6);
        float facing = dot(-grad, normalize(vec2(-.55, -.85)));
        float bevel = 1.0 - smoothstep(.006, .026, d);
        metal = mix(metal, vec3(.32, .34, .37) * (.65 + .55 * facing), bevel * smoothstep(.004, .008, d));
        // Rubber seal against the glass.
        metal = mix(metal, vec3(.02), 1.0 - smoothstep(.003, .006, d));

        // A ring of bolts around the pane, on its straight sides.
        float outer = d - .045;
        bool sides = abs(q.x) / pane.z > abs(q.y) / pane.w;
        float along = sides ? q.y : q.x;
        float limit = (sides ? pane.w : pane.z) - corner;
        float bolt = (1.0 - smoothstep(.0055, .0055 + pixel * 1.5,
            length(vec2(outer, (fract(along / .085 + .5) - .5) * .085)))) * step(abs(along), limit);
        metal = mix(metal, vec3(.45, .47, .5) * (.7 + .5 * facing), bolt);

        // Status lights and a placard under the pane.
        vec2 lamps = p - vec2(pane.x - pane.z * .78, pane.y + pane.w + .045);
        float green = 1.0 - smoothstep(.004, .004 + pixel * 2.0, length(lamps));
        float amber = 1.0 - smoothstep(.004, .004 + pixel * 2.0, length(lamps - vec2(.025, 0.0)));
        vec2 plate = p - vec2(pane.x, pane.y + pane.w + .045);
        float placard = 1.0 - smoothstep(0.0, pixel * 1.5, roundedBox(plate, vec2(.06, .011), .003));
        float lines = step(.6, fract(plate.y * 180.0)) * step(abs(plate.x), .05) * step(abs(plate.y), .006);
        metal = mix(metal, vec3(.2, .21, .22) - lines * .08, placard);
        metal += vec3(.2, 1.0, .45) * green * .9 + vec3(1.0, .7, .15) * amber * (.6 + .4 * flicker);

        // Re-entry light pouring through the glass onto the frame.
        metal += HEAT * heat * flicker * exp(-d / .05) * .55;

        colour = mix(colour, vec4(metal, 1.0), cover);
    }

    fragColor = colour * qt_Opacity;
}
