#version 440
layout(location=0) in vec2 qt_TexCoord0;
layout(location=0) out vec4 fragColor;
layout(std140,binding=0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 extent;
    float smear;
};
layout(binding=1) uniform sampler2D source;
void main() {
    vec2 stepSize=vec2(0.0,smear/max(extent.y,1.0));
    vec4 color=texture(source,qt_TexCoord0)*0.20;
    color+=texture(source,qt_TexCoord0+stepSize)*0.16;
    color+=texture(source,qt_TexCoord0-stepSize)*0.16;
    color+=texture(source,qt_TexCoord0+stepSize*2.0)*0.12;
    color+=texture(source,qt_TexCoord0-stepSize*2.0)*0.12;
    color+=texture(source,qt_TexCoord0+stepSize*3.0)*0.08;
    color+=texture(source,qt_TexCoord0-stepSize*3.0)*0.08;
    color+=texture(source,qt_TexCoord0+stepSize*4.0)*0.04;
    color+=texture(source,qt_TexCoord0-stepSize*4.0)*0.04;
    fragColor=color*qt_Opacity;
}
