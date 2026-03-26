/* Steable-DFX — composite2.fsh
   Bloom Pass: Vertical dual-radius Gaussian + combine with scene.
   Uses screen-blend to avoid overbrightening.
   ============================================================= */
#version 120
/* DRAWBUFFERS:0 */
uniform sampler2D colortex0;
uniform sampler2D colortex5;
uniform float viewHeight;
varying vec2 vUV;
void main() {
    float ty = 1.0 / viewHeight;
    vec3 tight = vec3(0.0);
    tight += texture2D(colortex5, vUV + vec2(0,-4.0*ty)).rgb * 0.0162;
    tight += texture2D(colortex5, vUV + vec2(0,-3.0*ty)).rgb * 0.0540;
    tight += texture2D(colortex5, vUV + vec2(0,-2.0*ty)).rgb * 0.1216;
    tight += texture2D(colortex5, vUV + vec2(0,-1.0*ty)).rgb * 0.1945;
    tight += texture2D(colortex5, vUV                  ).rgb * 0.2270;
    tight += texture2D(colortex5, vUV + vec2(0, 1.0*ty)).rgb * 0.1945;
    tight += texture2D(colortex5, vUV + vec2(0, 2.0*ty)).rgb * 0.1216;
    tight += texture2D(colortex5, vUV + vec2(0, 3.0*ty)).rgb * 0.0540;
    tight += texture2D(colortex5, vUV + vec2(0, 4.0*ty)).rgb * 0.0162;

    vec3 wide = vec3(0.0);
    wide += texture2D(colortex5, vUV + vec2(0,-8.0*ty)).rgb * 0.0093;
    wide += texture2D(colortex5, vUV + vec2(0,-6.0*ty)).rgb * 0.0280;
    wide += texture2D(colortex5, vUV + vec2(0,-4.0*ty)).rgb * 0.0670;
    wide += texture2D(colortex5, vUV + vec2(0,-2.0*ty)).rgb * 0.1240;
    wide += texture2D(colortex5, vUV                  ).rgb * 0.1432;
    wide += texture2D(colortex5, vUV + vec2(0, 2.0*ty)).rgb * 0.1240;
    wide += texture2D(colortex5, vUV + vec2(0, 4.0*ty)).rgb * 0.0670;
    wide += texture2D(colortex5, vUV + vec2(0, 6.0*ty)).rgb * 0.0280;
    wide += texture2D(colortex5, vUV + vec2(0, 8.0*ty)).rgb * 0.0093;

    vec3 bloom = tight * 0.7 + wide * 0.3;
    vec3 scene = texture2D(colortex0, vUV).rgb;
    // v5.1: bloom lebih lemah — awan dan objek cerah tidak hilang
    vec3 combined = scene + bloom * 0.65 - scene * bloom * 0.65;
    gl_FragData[0] = vec4(combined, 1.0);
}
