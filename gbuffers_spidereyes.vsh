/* Steable-DFX — gbuffers_spidereyes.vsh
   Mob glowing eyes (spider, enderman, etc.)
   These are rendered with additive blending in Minecraft.
   ============================================================= */
#version 120
varying vec2 vTexCoord;
varying vec4 vColor;
void main() {
    vTexCoord   = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    vColor      = gl_Color;
    gl_Position = ftransform();
}
