/* NaturalShaders v4.2 — gbuffers_skytextured.fsh
   Sun/Moon: bulat sempurna, tidak terlalu silau
   Corona lembut di sekitar matahari
   Bulan: keperakan dingin, bukan putih buta
*/
#version 120
/* DRAWBUFFERS:0 */
uniform sampler2D texture;
uniform vec3 shadowLightPosition;
varying vec4 vColor;
varying vec2 vTexCoord;

void main() {
    vec4 base = texture2D(texture, vTexCoord) * vColor;

    /* ── Circular disk mask ─────────────────────────────────────────
       Vanilla sun/moon quad UV goes 0..1. Center = (0.5, 0.5).
       distance * 2 → 1.0 at quad edge.
       Hard disk at 0.82, soft edge 0.82-0.92.
    ─────────────────────────────────────────────────────────────── */
    vec2  centered  = vTexCoord - 0.5;
    float dist      = length(centered) * 2.0;

    // Core disk
    float diskCore  = 1.0 - smoothstep(0.78, 0.88, dist);
    // Soft corona / limb darkening (wider than core, faint)
    float corona    = (1.0 - smoothstep(0.88, 1.40, dist)) * 0.22;

    float mask = diskCore + corona * (1.0 - diskCore);
    if (mask < 0.005) discard;

    /* ── Detect sun vs moon by vColor warmth ─────────────────────── */
    bool isSun = (vColor.r + vColor.g) > (vColor.b * 2.2);

    vec3 color;
    if (isSun) {
        // Sun: warm gold, dimmer at edge (limb darkening)
        float limb   = 1.0 - dist * 0.28;
        vec3  sunCore = vec3(1.00, 0.96, 0.82) * 0.95;      // warm center, tidak silau langit
        vec3  sunLimb = vec3(1.00, 0.72, 0.28) * 0.70;      // orange edge lembut
        color = mix(sunLimb, sunCore, smoothstep(0.0, 0.7, limb)) * diskCore;
        // Corona lebih halus agar tidak menutupi awan
        color += vec3(1.00, 0.70, 0.30) * corona * 0.30;
    } else {
        // Moon: cool silver-white, subtle craters from texture
        vec3 texDetails = base.rgb;                          // keep vanilla surface
        vec3 moonBase   = vec3(0.88, 0.92, 1.00) * 0.95;   // pale silver
        color = mix(moonBase, moonBase * texDetails * 1.1, 0.55) * diskCore;
        // Moon corona: very faint blue-white halo
        color += vec3(0.70, 0.82, 1.00) * corona * 0.30;
    }

    // v5.1: cap sangat rendah — matahari tidak terlalu terang, awan tetap terlihat
    color = min(color, vec3(1.10));

    gl_FragData[0] = vec4(color, base.a * mask);
}
