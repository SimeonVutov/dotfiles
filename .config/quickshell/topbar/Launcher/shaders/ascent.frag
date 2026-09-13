#version 440
layout(location=0) in vec2 qt_TexCoord0;
layout(location=0) out vec4 fragColor;
layout(std140,binding=0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float progress;
    float hasCapture;
};
layout(binding=1) uniform sampler2D source;

void main() {
    float acceleration=pow(progress,2.8);
    float stretch=1.0+acceleration*9.0;
    float departure=acceleration*2.3;
    vec4 color=vec4(0.0);
    // Temporal samples stretch the desktop DOWN, as the camera rises away.
    // At progress=0 all taps coincide with the untouched desktop pixel.
    for (int i=0;i<9;i++) {
        float lag=float(i)/8.0;
        vec2 uv=qt_TexCoord0;
        uv.y=(uv.y-departure+lag*acceleration*.85)/stretch;
        float inside=step(0.0,uv.y)*step(uv.y,1.0);
        color+=texture(source,clamp(uv,vec2(0.0),vec2(1.0)))*inside/9.0;
    }
    float fade=(1.0-smoothstep(.35,.88,progress))*hasCapture;
    // Premultiplied transparency reveals the accelerating star field below.
    fragColor=vec4(color.rgb*fade,fade)*qt_Opacity;
}
