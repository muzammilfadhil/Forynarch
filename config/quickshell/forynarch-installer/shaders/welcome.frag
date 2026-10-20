#version 440
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 extent;
    float reveal;
};
void main() {
    vec2 uv = qt_TexCoord0;
    // Soft, overlapping blue folds: analytic light, no texture/blur sampling.
    float right = smoothstep(0.38, 0.95, uv.x);
    float curve = 0.80 - uv.x * 0.54 + sin(uv.x * 5.0) * 0.14;
    float distanceToFold = uv.y - curve - (1.0 - reveal) * 0.10;
    float fold = exp(-abs(distanceToFold) * 15.0) * right;
    float edge = exp(-abs(distanceToFold) * 150.0) * right;
    float second = exp(-abs(distanceToFold - 0.14) * 45.0) * right;
    vec3 navy = mix(vec3(0.071, 0.137, 0.220), vec3(0.060, 0.110, 0.185), uv.y);
    vec3 color = navy + vec3(0.035, 0.090, 0.160) * fold;
    color += vec3(0.16, 0.29, 0.44) * (edge * 0.70 + second * 0.28) * reveal;
    // Bound light behind all text, including during arrival and at narrow sizes.
    color = min(color, vec3(0.16, 0.28, 0.42));
    vec2 p = abs(uv * extent - extent * 0.5) - extent * 0.5 + vec2(18.0);
    float d = length(max(p, vec2(0.0))) + min(max(p.x, p.y), 0.0) - 18.0;
    float alpha = (1.0 - smoothstep(-1.0, 0.0, d)) * qt_Opacity;
    fragColor = vec4(color * alpha, alpha);
}
