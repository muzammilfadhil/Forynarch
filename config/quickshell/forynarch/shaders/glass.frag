#version 440
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 extent;
    float frost;
    float cornerRadius;
};
layout(binding = 1) uniform sampler2D source;
void main() {
    vec2 uv = qt_TexCoord0;
    vec2 stepSize = vec2(clamp(frost, 0.0, 6.0)) / max(extent, vec2(1.0));
    vec3 image = texture(source, uv).rgb * 0.25;
    image += texture(source, uv + vec2(stepSize.x, 0.0)).rgb * 0.125;
    image += texture(source, uv - vec2(stepSize.x, 0.0)).rgb * 0.125;
    image += texture(source, uv + vec2(0.0, stepSize.y)).rgb * 0.125;
    image += texture(source, uv - vec2(0.0, stepSize.y)).rgb * 0.125;
    image += texture(source, uv + stepSize).rgb * 0.0625;
    image += texture(source, uv - stepSize).rgb * 0.0625;
    image += texture(source, uv + vec2(stepSize.x, -stepSize.y)).rgb * 0.0625;
    image += texture(source, uv + vec2(-stepSize.x, stepSize.y)).rgb * 0.0625;
    float grain = fract(sin(dot(floor(uv * extent), vec2(12.9898, 78.233))) * 43758.5453) - 0.5;
    vec3 navy = vec3(0.063, 0.110, 0.188);
    vec3 color = mix(image, navy, 0.84) + grain * 0.009;
    color += vec3(0.020, 0.036, 0.050) * pow(1.0 - uv.y, 3.0);
    vec2 p = abs(uv * extent - extent * 0.5) - extent * 0.5 + vec2(cornerRadius);
    float distance = length(max(p, vec2(0.0))) + min(max(p.x, p.y), 0.0) - cornerRadius;
    float alpha = (1.0 - smoothstep(-1.0, 0.0, distance)) * 0.72 * qt_Opacity;
    fragColor = vec4(color * alpha, alpha);
}
