/* Steable-DFX — composite1.fsh
   Bloom Pass: Horizontal dual-radius Gaussian blur.
   Two radii blended: tight glow + wide soft halo.
   ============================================================= */
#version 120
/* DRAWBUFFERS:5 */
uniform sampler2D colortex5;
uniform float viewWidth;
varying vec2 vUV;
void main() {
    float tx = 1.0 / viewWidth;
    // Tight bloom (radius 1)
    vec3 tight = vec3(0.0);
    tight += texture2D(colortex5, vUV + vec2(-4.0*tx, 0)).rgb * 0.0162;
    tight += texture2D(colortex5, vUV + vec2(-3.0*tx, 0)).rgb * 0.0540;
    tight += texture2D(colortex5, vUV + vec2(-2.0*tx, 0)).rgb * 0.1216;
    tight += texture2D(colortex5, vUV + vec2(-1.0*tx, 0)).rgb * 0.1945;
    tight += texture2D(colortex5, vUV                   ).rgb * 0.2270;
    tight += texture2D(colortex5, vUV + vec2( 1.0*tx, 0)).rgb * 0.1945;
    tight += texture2D(colortex5, vUV + vec2( 2.0*tx, 0)).rgb * 0.1216;
    tight += texture2D(colortex5, vUV + vec2( 3.0*tx, 0)).rgb * 0.0540;
    tight += texture2D(colortex5, vUV + vec2( 4.0*tx, 0)).rgb * 0.0162;
    // Wide bloom (radius 2.5)
    vec3 wide = vec3(0.0);
    wide += texture2D(colortex5, vUV + vec2(-8.0*tx, 0)).rgb * 0.0093;
    wide += texture2D(colortex5, vUV + vec2(-6.0*tx, 0)).rgb * 0.0280;
    wide += texture2D(colortex5, vUV + vec2(-4.0*tx, 0)).rgb * 0.0670;
    wide += texture2D(colortex5, vUV + vec2(-2.0*tx, 0)).rgb * 0.1240;
    wide += texture2D(colortex5, vUV                   ).rgb * 0.1432;
    wide += texture2D(colortex5, vUV + vec2( 2.0*tx, 0)).rgb * 0.1240;
    wide += texture2D(colortex5, vUV + vec2( 4.0*tx, 0)).rgb * 0.0670;
    wide += texture2D(colortex5, vUV + vec2( 6.0*tx, 0)).rgb * 0.0280;
    wide += texture2D(colortex5, vUV + vec2( 8.0*tx, 0)).rgb * 0.0093;
    // Blend tight + wide
    gl_FragData[0] = vec4(tight * 0.7 + wide * 0.3, 1.0);
}
