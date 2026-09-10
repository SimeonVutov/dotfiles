#version 440
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float progress;
};
layout(binding = 1) uniform sampler2D source;
void main() {
    vec2 p = qt_TexCoord0 - 0.5;
    float r = length(p);
    float envelope = pow(1.0 - smoothstep(0.0, 0.82, progress), 2.0);
    // Magnify near the core and relax outward, so the menu unfolds out of the
    // well rather than fading in. Purely radial: every action keeps its angle.
    vec4 acc = vec4(0.0);
    float wsum = 0.0;
    for (int i = 0; i < 4; i++) {
        float lens = exp(-r * 3.2) * envelope * (1.8 - float(i) * 0.24);
        vec2 uv = 0.5 + p / (1.0 + lens);
        float inside = step(0.0, uv.x) * step(uv.x, 1.0) * step(0.0, uv.y) * step(uv.y, 1.0);
        float w = 1.0 - float(i) * 0.18;
        acc += texture(source, clamp(uv, 0.0, 1.0)) * inside * w;
        wsum += w;
    }
    fragColor = acc / wsum * qt_Opacity;
}
