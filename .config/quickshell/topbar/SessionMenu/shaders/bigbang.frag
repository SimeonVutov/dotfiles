#version 440
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float progress;
    float aspect;
};

// The void the menu sits on, and — once progress leaves 0 — the Big Bang that
// tears it open and hands the desktop back. At progress 0 this is a plain
// opaque black fill, so it can stay mounted the whole time: no swapping a
// Rectangle out for a ShaderEffect mid-cancel, and no first-use pipeline
// build in the middle of the animation.
void main() {
    vec2 p = (qt_TexCoord0 - 0.5) * vec2(aspect, 1.0);
    float r = length(p);
    float a = atan(p.y, p.x);
    float t = progress;

    // Detonation front. Clears the far corner around t=0.45, leaving the rest
    // of the animation for the debris shells and the burn-down.
    float front = pow(t, 0.5) * 1.5;
    // Torn, not a clean circle — three harmonics beating against each other.
    front *= 1.0 + 0.09 * sin(a * 5.0 + t * 7.0) + 0.05 * sin(a * 11.0 - t * 13.0) + 0.03 * sin(a * 23.0 + t * 5.0);

    float edge = 0.05 + 0.16 * t;
    // Void survives only outside the front; inside it the desktop is back.
    float voidAlpha = smoothstep(front - edge, front, r);

    // Hot leading edge, plus two trailing debris shells chasing it out.
    float rim = exp(-pow((r - front) / (edge * 0.75), 2.0));
    float shell1 = exp(-pow((r - front * 0.72) / (edge * 0.6), 2.0)) * 0.45;
    float shell2 = exp(-pow((r - front * 0.45) / (edge * 0.5), 2.0)) * 0.25;

    // Hard-edged spokes so the blast throws shrapnel instead of glowing evenly.
    float spokes = pow(0.5 + 0.5 * sin(a * 17.0 + t * 3.0), 2.0);
    spokes = mix(0.5, 1.5, spokes);

    // The initial flash, gone almost immediately.
    float flash = exp(-t * 20.0);
    float core = exp(-r * 5.0) * flash * 1.8;

    float burn = 1.0 - smoothstep(0.6, 1.0, t);
    float glow = (rim * spokes + shell1 + shell2) * burn + core;

    float fade = 1.0 - smoothstep(0.85, 1.0, t);
    voidAlpha *= fade;
    glow = clamp(glow * fade, 0.0, 1.6);

    // White-hot at the front, cooling to embers behind it.
    vec3 tint = mix(vec3(1.0, 0.82, 0.60), vec3(1.0, 0.98, 0.94), clamp(rim + core, 0.0, 1.0));

    float alpha = clamp(voidAlpha + glow, 0.0, 1.0);
    // Premultiplied: the void carries no colour of its own, only the glow does.
    fragColor = vec4(tint * glow, alpha) * qt_Opacity;
}
