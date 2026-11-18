#version 440
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float progress;
    float aspect;
};

// The void the menu sits on, and, once progress leaves 0, the Big Bang that
// tears it open and hands the desktop back. At progress 0 this is a plain
// opaque black fill, so it can stay mounted the whole time: no swapping a
// Rectangle out for a ShaderEffect mid-cancel, and no first-use pipeline
// build in the middle of the animation.

// Detonation front: how far it travels, and how its speed eases. It clears the
// far corner around progress 0.45, leaving the rest of the animation for the
// debris shells and the burn-down.
const float FRONT_REACH = 1.5;
const float FRONT_EASE_POWER = 0.5;

// The front is torn rather than a clean circle: three harmonics beating
// against each other. Per harmonic: how far it bends the front, how many lobes
// it has around the circle, and how fast it turns.
const vec3 TEAR_AMPLITUDE = vec3(0.09, 0.05, 0.03);
const vec3 TEAR_LOBES = vec3(5.0, 11.0, 23.0);
const vec3 TEAR_SPEED = vec3(7.0, -13.0, 5.0);

// Softness of the front's edge: its width at the start and how much it grows.
const float EDGE_WIDTH_START = 0.05;
const float EDGE_WIDTH_GROWTH = 0.16;

// The hot leading edge, as a fraction of the edge width.
const float RIM_WIDTH = 0.75;

// Two debris shells chasing the front out: where each sits relative to the
// front, how wide it is relative to the edge, and how bright it is.
const float FIRST_SHELL_POSITION = 0.72;
const float FIRST_SHELL_WIDTH = 0.6;
const float FIRST_SHELL_INTENSITY = 0.45;
const float SECOND_SHELL_POSITION = 0.45;
const float SECOND_SHELL_WIDTH = 0.5;
const float SECOND_SHELL_INTENSITY = 0.25;

// Hard-edged spokes that make the blast throw shrapnel instead of glowing
// evenly: how many there are, how fast they turn, and how much they dim or
// brighten the rim.
const float SPOKE_COUNT = 17.0;
const float SPOKE_SPIN = 3.0;
const float SPOKE_MIN_BRIGHTNESS = 0.5;
const float SPOKE_MAX_BRIGHTNESS = 1.5;

// The initial flash at the centre: how quickly it dies and how bright it is.
const float FLASH_DECAY = 20.0;
const float CORE_FALLOFF = 5.0;
const float CORE_INTENSITY = 1.8;

// The animation progress over which the glow burns down, and over which the
// whole effect fades out.
const float BURN_START = 0.6;
const float BURN_END = 1.0;
const float FADE_START = 0.85;
const float FADE_END = 1.0;

// The brightest the glow may get.
const float GLOW_LIMIT = 1.6;

// White-hot at the front, cooling to embers behind it.
const vec3 EMBER_TINT = vec3(1.0, 0.82, 0.60);
const vec3 WHITE_HOT_TINT = vec3(1.0, 0.98, 0.94);

void main() {
    vec2 position = (qt_TexCoord0 - 0.5) * vec2(aspect, 1.0);
    float radius = length(position);
    float angle = atan(position.y, position.x);

    float front = pow(progress, FRONT_EASE_POWER) * FRONT_REACH;
    front *= 1.0
        + TEAR_AMPLITUDE.x * sin(angle * TEAR_LOBES.x + progress * TEAR_SPEED.x)
        + TEAR_AMPLITUDE.y * sin(angle * TEAR_LOBES.y + progress * TEAR_SPEED.y)
        + TEAR_AMPLITUDE.z * sin(angle * TEAR_LOBES.z + progress * TEAR_SPEED.z);

    // The void survives only outside the front; inside it the desktop is back.
    float edge = EDGE_WIDTH_START + EDGE_WIDTH_GROWTH * progress;
    float voidAlpha = smoothstep(front - edge, front, radius);

    float rim = exp(-pow((radius - front) / (edge * RIM_WIDTH), 2.0));
    float firstShell = exp(-pow((radius - front * FIRST_SHELL_POSITION) / (edge * FIRST_SHELL_WIDTH), 2.0)) * FIRST_SHELL_INTENSITY;
    float secondShell = exp(-pow((radius - front * SECOND_SHELL_POSITION) / (edge * SECOND_SHELL_WIDTH), 2.0)) * SECOND_SHELL_INTENSITY;

    float spokes = pow(0.5 + 0.5 * sin(angle * SPOKE_COUNT + progress * SPOKE_SPIN), 2.0);
    spokes = mix(SPOKE_MIN_BRIGHTNESS, SPOKE_MAX_BRIGHTNESS, spokes);

    float flash = exp(-progress * FLASH_DECAY);
    float core = exp(-radius * CORE_FALLOFF) * flash * CORE_INTENSITY;

    float burn = 1.0 - smoothstep(BURN_START, BURN_END, progress);
    float glow = (rim * spokes + firstShell + secondShell) * burn + core;

    float fade = 1.0 - smoothstep(FADE_START, FADE_END, progress);
    voidAlpha *= fade;
    glow = clamp(glow * fade, 0.0, GLOW_LIMIT);

    vec3 tint = mix(EMBER_TINT, WHITE_HOT_TINT, clamp(rim + core, 0.0, 1.0));
    float alpha = clamp(voidAlpha + glow, 0.0, 1.0);

    // Premultiplied: the void carries no colour of its own, only the glow does.
    fragColor = vec4(tint * glow, alpha) * qt_Opacity;
}
