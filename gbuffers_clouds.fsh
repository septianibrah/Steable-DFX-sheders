#version 120
/* DRAWBUFFERS:0 */
/* NaturalShaders v5 — gbuffers_clouds.fsh
   Awan lebih natural: tidak terlalu terang/putih, ada gradasi bayangan
   Sesuai dengan pengurangan brightness matahari v5.1
*/
uniform sampler2D texture;
varying vec4 vColor; varying vec2 vTexCoord;
void main() {
    vec4 c = texture2D(texture, vTexCoord) * vColor;
    if (c.a < 0.01) discard;
    // v5.1: contrast normal, tidak over-boost
    // Awan vanilla sudah punya shading sendiri, kita jaga tetap terlihat
    c.rgb = clamp(mix(vec3(0.65), c.rgb, 1.15), 0.0, 1.0);
    c.a   = min(c.a * 1.20, 1.0);
    gl_FragData[0] = c;
}
