/* NaturalShaders v5 — gbuffers_weather.fsh
   Rain/snow particles: lebih transparan, biru-putih jernih seperti asli
*/
#version 120
/* DRAWBUFFERS:0 */
uniform sampler2D texture;
uniform sampler2D lightmap;
uniform float rainStrength;
varying vec2 vTexCoord;
varying vec4 vColor;
varying vec2 vLightCoord;
void main() {
    vec4 a = texture2D(texture, vTexCoord) * vColor;
    if (a.a < 0.02) discard;
    vec3 light = texture2D(lightmap, vLightCoord).rgb;
    // v5: Hujan biru-putih, lebih transparan (0.65→0.38), lebih jernih
    vec3 rainTint = mix(vec3(1.0), vec3(0.78, 0.88, 1.00), 0.45);
    // Alpha lebih rendah → tetesan lebih transparan seperti asli
    float finalAlpha = a.a * 0.38;
    gl_FragData[0] = vec4(a.rgb * light * rainTint, finalAlpha);
}
