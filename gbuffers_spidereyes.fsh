/* Steable-DFX — gbuffers_spidereyes.fsh
   Glowing mob eyes — additive blended, bright emission.
   Red spider eyes, white enderman eyes, etc.
   The bloom system in composite will pick these up (they are bright)
   and add a glow halo around them automatically.
   ============================================================= */
#version 120
/* DRAWBUFFERS:0 */
uniform sampler2D texture;
varying vec2 vTexCoord;
varying vec4 vColor;
void main() {
    vec4 c = texture2D(texture, vTexCoord) * vColor;
    if (c.a < 0.05) discard;
    // Boost emissive brightness so bloom picks it up
    c.rgb *= 1.8;
    gl_FragData[0] = c;
}
