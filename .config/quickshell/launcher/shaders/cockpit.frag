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
//
// All distances are in screen heights. `d` is the signed distance to the
// pane's edge: negative on the glass, positive on the metal.

// Re-entry light on the frame.
const vec3 HEAT = vec3(1.0, .45, .16);

// Flicker of the re-entry light: its base level, depth, rate and noise seed.
const float FLICKER_BASE = .8;
const float FLICKER_DEPTH = .2;
const float FLICKER_RATE = 23.0;
const float FLICKER_SEED = 4.1;

// Glass reflections: two diagonal sheen bands (their offset along the
// diagonal, width and brightness), the soft rim at the glass edge, and the
// tint of all of it.
const float SHEEN_SLANT = .5;
const float SHEEN_ANCHOR = .55;
const float BROAD_SHEEN_WIDTH = .05;
const float BROAD_SHEEN_BRIGHTNESS = .045;
const float NARROW_SHEEN_OFFSET = .09;
const float NARROW_SHEEN_WIDTH = .015;
const float NARROW_SHEEN_BRIGHTNESS = .025;
const float GLASS_RIM_FALLOFF = .04;
const float GLASS_RIM_BRIGHTNESS = .04;
const vec3 GLASS_TINT = vec3(.6, .78, .92);

// How strongly the heat lights the glass, in colour and in opacity, and how
// strongly the sheen and rim make the glass opaque.
const float GLASS_HEAT_LIGHT = .5;
const float GLASS_HEAT_OPACITY = .12;
const float GLASS_SHEEN_OPACITY = .6;

// Brushed metal: the base colour, the two noise layers that brush it (their
// frequencies across and along the grain), how much the brushing varies the
// shade, and how far the metal darkens away from the pane.
const vec3 METAL = vec3(.115, .125, .14);
const vec2 BRUSH_FINE_FREQUENCY = vec2(420.0, 9.0);
const vec2 BRUSH_COARSE_FREQUENCY = vec2(37.0, 61.0);
const float BRUSH_BASE_SHADE = .8;
const float BRUSH_VARIATION = .35;
const float METAL_DARKENING = .45;
const vec2 METAL_DARKENING_RANGE = vec2(.05, .3);

// The bevel around the pane catches light from above left: the direction of
// the light, how far the bevel reaches, its range of visibility and colour,
// and how strongly the light shades it.
const vec2 LIGHT_DIRECTION = vec2(-.55, -.85);
const vec2 BEVEL_REACH = vec2(.006, .026);
const vec2 BEVEL_INNER_EDGE = vec2(.004, .008);
const vec3 BEVEL_COLOR = vec3(.32, .34, .37);
const float BEVEL_BASE_SHADE = .65;
const float BEVEL_LIGHT_SHADE = .55;

// The rubber seal against the glass: its range and colour.
const vec2 SEAL_RANGE = vec2(.003, .006);
const vec3 SEAL_COLOR = vec3(.02);

// A ring of bolts around the pane: its distance from the pane, the spacing of
// the bolts, their radius, and their colour and light shading.
const float BOLT_RING_OFFSET = .045;
const float BOLT_SPACING = .085;
const float BOLT_RADIUS = .0055;
const vec3 BOLT_COLOR = vec3(.45, .47, .5);
const float BOLT_BASE_SHADE = .7;
const float BOLT_LIGHT_SHADE = .5;

// Status lights and a placard under the pane: how far below the pane they
// sit, where the first light sits across the pane, their radius and spacing.
const float PANEL_OFFSET_BELOW_PANE = .045;
const float LAMP_POSITION = .78;
const float LAMP_RADIUS = .004;
const float LAMP_SPACING = .025;
const vec3 GREEN_LAMP = vec3(.2, 1.0, .45);
const vec3 AMBER_LAMP = vec3(1.0, .7, .15);
const float GREEN_LAMP_BRIGHTNESS = .9;
const float AMBER_LAMP_BASE = .6;
const float AMBER_LAMP_FLICKER = .4;

// The placard: its half size, corner radius and colour, and the engraved
// lines on it (their density, share of each period that is drawn, half width
// and half height, and how much they darken the plate).
const vec2 PLACARD_HALF_SIZE = vec2(.06, .011);
const float PLACARD_CORNER = .003;
const vec3 PLACARD_COLOR = vec3(.2, .21, .22);
const float ENGRAVING_DENSITY = 180.0;
const float ENGRAVING_START = .6;
const vec2 ENGRAVING_HALF_SIZE = vec2(.05, .006);
const float ENGRAVING_DARKNESS = .08;

// Re-entry light pouring through the glass onto the frame: how far it spreads
// and how strong it is.
const float FRAME_HEAT_FALLOFF = .05;
const float FRAME_HEAT_BRIGHTNESS = .55;

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

// The glass: a soft reflected sheen, and the frame's warm light at its edge.
vec4 glassLayer(vec2 fromPaneCentre, float d, float flicker) {
    float diagonal = fromPaneCentre.x * SHEEN_SLANT + fromPaneCentre.y + pane.w * SHEEN_ANCHOR;
    float sheen = exp(-pow(diagonal / BROAD_SHEEN_WIDTH, 2.0)) * BROAD_SHEEN_BRIGHTNESS
        + exp(-pow((diagonal - NARROW_SHEEN_OFFSET) / NARROW_SHEEN_WIDTH, 2.0)) * NARROW_SHEEN_BRIGHTNESS;
    float rim = exp(min(d, 0.0) / GLASS_RIM_FALLOFF);

    vec3 glass = GLASS_TINT * (sheen + rim * GLASS_RIM_BRIGHTNESS) + HEAT * heat * flicker * rim * GLASS_HEAT_LIGHT;
    return vec4(glass, (sheen + rim * GLASS_RIM_BRIGHTNESS) * GLASS_SHEEN_OPACITY + heat * rim * GLASS_HEAT_OPACITY);
}

// Brushed, slightly worn metal, darker away from the pane.
vec3 brushedMetal(vec2 p, float d) {
    float brushed = noise(vec2(p.x * BRUSH_FINE_FREQUENCY.x, p.y * BRUSH_FINE_FREQUENCY.y)) * .5
        + noise(vec2(p.x * BRUSH_COARSE_FREQUENCY.x, p.y * BRUSH_COARSE_FREQUENCY.y)) * .5;
    return METAL * (BRUSH_BASE_SHADE + BRUSH_VARIATION * brushed)
        * (1.0 - METAL_DARKENING * smoothstep(METAL_DARKENING_RANGE.x, METAL_DARKENING_RANGE.y, d));
}

// How directly the pane's edge faces the light, from -1 to 1.
float edgeFacing(float d) {
    vec2 grad = normalize(vec2(dFdx(d), dFdy(d)) + 1e-6);
    return dot(-grad, normalize(LIGHT_DIRECTION));
}

// A ring of bolts on the pane's straight sides: 1 on a bolt, else 0.
float boltRing(vec2 fromPaneCentre, float d) {
    float outer = d - BOLT_RING_OFFSET;
    bool onSides = abs(fromPaneCentre.x) / pane.z > abs(fromPaneCentre.y) / pane.w;
    float along = onSides ? fromPaneCentre.y : fromPaneCentre.x;
    float limit = (onSides ? pane.w : pane.z) - corner;

    float boltShape = 1.0 - smoothstep(BOLT_RADIUS, BOLT_RADIUS + pixel * 1.5,
        length(vec2(outer, (fract(along / BOLT_SPACING + .5) - .5) * BOLT_SPACING)));
    return boltShape * step(abs(along), limit);
}

// The two status lights and the placard under the pane, drawn onto `metal`.
vec3 statusPanel(vec3 metal, vec2 p, float flicker) {
    vec2 lamps = p - vec2(pane.x - pane.z * LAMP_POSITION, pane.y + pane.w + PANEL_OFFSET_BELOW_PANE);
    float green = 1.0 - smoothstep(LAMP_RADIUS, LAMP_RADIUS + pixel * 2.0, length(lamps));
    float amber = 1.0 - smoothstep(LAMP_RADIUS, LAMP_RADIUS + pixel * 2.0, length(lamps - vec2(LAMP_SPACING, 0.0)));

    vec2 plate = p - vec2(pane.x, pane.y + pane.w + PANEL_OFFSET_BELOW_PANE);
    float placard = 1.0 - smoothstep(0.0, pixel * 1.5, roundedBox(plate, PLACARD_HALF_SIZE, PLACARD_CORNER));
    float lines = step(ENGRAVING_START, fract(plate.y * ENGRAVING_DENSITY)) * step(abs(plate.x), ENGRAVING_HALF_SIZE.x) * step(abs(plate.y), ENGRAVING_HALF_SIZE.y);

    metal = mix(metal, PLACARD_COLOR - lines * ENGRAVING_DARKNESS, placard);
    return metal + (GREEN_LAMP * green * GREEN_LAMP_BRIGHTNESS + AMBER_LAMP * amber * (AMBER_LAMP_BASE + AMBER_LAMP_FLICKER * flicker));
}

void main() {
    vec2 p = qt_TexCoord0 * vec2(aspect, 1.0);
    vec2 fromPaneCentre = p - pane.xy;
    float d = roundedBox(fromPaneCentre, pane.zw, corner);
    float flicker = FLICKER_BASE + FLICKER_DEPTH * noise(vec2(clock * FLICKER_RATE, FLICKER_SEED));

    vec4 colour = glassLayer(fromPaneCentre, d, flicker);

    float cover = smoothstep(-pixel, pixel, d);
    if (cover > 0.0) {
        vec3 metal = brushedMetal(p, d);

        // The bevel catches light from above left.
        float facing = edgeFacing(d);
        float bevel = 1.0 - smoothstep(BEVEL_REACH.x, BEVEL_REACH.y, d);
        metal = mix(metal, BEVEL_COLOR * (BEVEL_BASE_SHADE + BEVEL_LIGHT_SHADE * facing), bevel * smoothstep(BEVEL_INNER_EDGE.x, BEVEL_INNER_EDGE.y, d));

        // Rubber seal against the glass.
        metal = mix(metal, SEAL_COLOR, 1.0 - smoothstep(SEAL_RANGE.x, SEAL_RANGE.y, d));

        float bolt = boltRing(fromPaneCentre, d);
        metal = mix(metal, BOLT_COLOR * (BOLT_BASE_SHADE + BOLT_LIGHT_SHADE * facing), bolt);

        metal = statusPanel(metal, p, flicker);

        // Re-entry light pouring through the glass onto the frame.
        metal += HEAT * heat * flicker * exp(-d / FRAME_HEAT_FALLOFF) * FRAME_HEAT_BRIGHTNESS;

        colour = mix(colour, vec4(metal, 1.0), cover);
    }

    fragColor = colour * qt_Opacity;
}
