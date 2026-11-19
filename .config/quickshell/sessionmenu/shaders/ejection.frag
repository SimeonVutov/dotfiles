#version 440
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float progress;
};
layout(binding = 1) uniform sampler2D source;

// The session menu's reveal: the menu unfolds out of a magnifying well at the
// centre of the screen instead of fading in.

// The animation progress at which the lens has fully relaxed.
const float LENS_RELAX_END = 0.82;

// How quickly the magnification falls off with distance from the centre.
const float LENS_FALLOFF = 3.2;

// Number of samples, each taken through a slightly different lens, that are
// averaged to smear the motion.
const int SAMPLE_COUNT = 4;

// Magnification at the core for the first sample.
const float LENS_STRENGTH = 1.8;

// How much weaker each later sample's lens is.
const float LENS_STRENGTH_STEP = 0.24;

// How much less each later sample counts in the average.
const float SAMPLE_WEIGHT_STEP = 0.18;

// 1 inside the source texture and 0 outside, so nothing is dragged in from
// beyond its edges.
float insideFrame(vec2 uv) {
    return step(0.0, uv.x) * step(uv.x, 1.0) * step(0.0, uv.y) * step(uv.y, 1.0);
}

void main() {
    vec2 fromCenter = qt_TexCoord0 - 0.5;
    float radius = length(fromCenter);
    float relaxation = pow(1.0 - smoothstep(0.0, LENS_RELAX_END, progress), 2.0);

    // Magnify near the core and relax outward, so the menu unfolds out of the
    // well rather than fading in. Purely radial: every action keeps its angle.
    vec4 accumulated = vec4(0.0);
    float weightSum = 0.0;
    for (int i = 0; i < SAMPLE_COUNT; i++) {
        float lens = exp(-radius * LENS_FALLOFF) * relaxation * (LENS_STRENGTH - float(i) * LENS_STRENGTH_STEP);
        vec2 uv = 0.5 + fromCenter / (1.0 + lens);
        float weight = 1.0 - float(i) * SAMPLE_WEIGHT_STEP;

        accumulated += texture(source, clamp(uv, 0.0, 1.0)) * insideFrame(uv) * weight;
        weightSum += weight;
    }

    fragColor = accumulated / weightSum * qt_Opacity;
}
