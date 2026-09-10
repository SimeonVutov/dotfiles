#version 440
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float progress;
    float aspect;
};
layout(binding = 1) uniform sampler2D source;

const float PI = 3.14159265;

float hash(float n) {
    return fract(sin(n * 127.1) * 43758.5453);
}

vec3 fetch(vec2 uv) {
    // Anything dragged in from beyond the frame is void, not edge-clamped smear.
    float inside = step(0.0, uv.x) * step(uv.x, 1.0) * step(0.0, uv.y) * step(uv.y, 1.0);
    return texture(source, clamp(uv, 0.0, 1.0)).rgb * inside;
}

// Inverse flow map. Material spirals inward, so whatever sits at radius r now
// started further out: sampling outward along the spiral drags the desktop in.
vec2 warp(vec2 p, float k, float bend) {
    float r = length(p);
    float a = atan(p.y, p.x);
    // A shifting quadrupole keeps the well from reading as a static circle.
    float lobe = 1.0 + 0.11 * sin(a * 2.0 - progress * 5.0) * k;
    float rs = (r * (1.0 + k * 4.2) + k * k * 0.6) * lobe;
    // Glass bending: a lens riding on top of the inflow, strongest at the core.
    float glass = exp(-rs * 2.8) * bend;
    rs *= 1.0 + glass * 2.6;
    // Differential rotation, plus the extra twist light picks up through the lens.
    float as = a - k * 4.6 / (rs + 0.16) - glass * 2.4;
    // Shockwave crest running outward through the bent glass.
    rs += exp(-pow((rs - progress * 0.85) * 8.0, 2.0)) * bend * 0.16;
    return vec2(cos(as), sin(as)) * rs / vec2(aspect, 1.0) + 0.5;
}

void main() {
    // Slow to start, then it runs away: infall accelerates, it doesn't ease out.
    float pull = pow(clamp(progress / 0.9, 0.0, 1.0), 2.3);
    float bend = sin(pow(progress, 0.8) * PI);
    // The hole itself drifts while it feeds.
    vec2 wobble = vec2(sin(progress * 6.0), cos(progress * 4.5)) * 0.02 * pull;
    vec2 p = (qt_TexCoord0 - 0.5) * vec2(aspect, 1.0) - wobble;
    float r = length(p);

    // Tear bands: the image shears in blocks that re-roll a couple dozen times
    // a second, so the desktop looks like it is coming apart, not just bending.
    float tick = floor(progress * 26.0);
    float band = floor(qt_TexCoord0.y * 38.0 + tick * 0.7);
    float n = hash(band + tick * 17.0);
    float glitch = smoothstep(0.12, 0.5, bend) * step(0.6, n);
    vec2 tear = vec2((n - 0.5) * glitch * 0.3, (hash(band) - 0.5) * glitch * 0.02);

    // Five samples of the same material staggered in time smear it into streaks
    // along its own path, which is what makes the swirl read as motion.
    vec2 uv0 = vec2(0.0);
    vec3 acc = vec3(0.0);
    float wsum = 0.0;
    for (int i = 0; i < 5; i++) {
        float k = pull * (1.0 - float(i) * 0.038);
        vec2 uv = warp(p, k, bend) + tear;
        if (i == 0)
            uv0 = uv;
        float w = 1.0 - float(i) * 0.15;
        acc += fetch(uv) * w;
        wsum += w;
    }
    vec3 color = acc / wsum;

    // Chromatic split: the lens no longer agrees with itself across wavelengths.
    float split = (0.005 + bend * 0.02) * (0.35 + pull) + glitch * 0.01;
    color.r = mix(color.r, fetch(uv0 + vec2(split, 0.0)).r, 0.7);
    color.b = mix(color.b, fetch(uv0 - vec2(split, 0.0)).b, 0.7);

    // The horizon opens up and keeps every photon that crosses it.
    float horizon = 0.018 + 0.12 * pow(clamp(progress / 0.92, 0.0, 1.0), 1.6);
    color *= smoothstep(horizon, horizon * 2.3, r);
    // Last light bending around the edge.
    float ring = exp(-pow((r - horizon * 1.3) / max(horizon * 0.34, 0.001), 2.0));
    color += vec3(0.9) * ring * bend * 0.4;
    // Nothing survives the collapse: the frame is empty before the menu settles.
    color *= 1.0 - smoothstep(0.74, 1.0, progress);

    // Opaque throughout, so drained areas read as void and not as the live desktop.
    fragColor = vec4(color * qt_Opacity, qt_Opacity);
}
