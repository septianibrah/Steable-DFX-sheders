/* Steable-DFX — gbuffers_skytextured.vsh : Sun/moon disc */
#version 120
varying vec4 vColor;
varying vec2 vTexCoord;
void main() {
    vTexCoord   = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    vColor      = gl_Color;
    gl_Position = ftransform();
}
