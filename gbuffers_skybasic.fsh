#version 120
/* DRAWBUFFERS:0 */
varying vec4 vColor;
uniform float frameTimeCounter;

void main() {
    vec4 col = vColor;

    /* ── Stars: detect by high luminance (stars = near-white bright) ──
       Sky geometry at night is nearly black (luma < 0.05)
       Stars are white-ish specks (luma > 0.25)
    ────────────────────────────────────────────────────────────────── */
    float luma = dot(col.rgb, vec3(0.2126, 0.7152, 0.0722));

    if (luma > 0.15) {
        // Per-star unique hash (based on color)
        float h1 = fract(col.r * 127.1 + col.g * 311.7 + col.b * 74.7);
        float h2 = fract(h1 * 17.3 + col.b * 52.9);
        float h3 = fract(h2 * 31.7 + col.r * 127.1);

        // Twinkle: multi-frequency oscillation per star
        float twinkle = 1.0
            + sin(frameTimeCounter * (1.2 + h1 * 2.5)  + h2 * 6.2832) * 0.28
            + sin(frameTimeCounter * (2.9 + h2 * 1.8)  + h3 * 9.4248) * 0.12
            + sin(frameTimeCounter * (0.7 + h3 * 0.9)  + h1 * 3.1416) * 0.08;

        // Bintang bersinar natural, tidak terlalu silau
        col.rgb *= 1.9 * twinkle;

        // Subtle color hue variation (bintang punya warna berbeda)
        // Biru keputihan untuk bintang panas, kekuningan untuk bintang dingin
        col.rgb *= mix(
            vec3(0.88 + h1*0.14, 0.90 + h2*0.12, 1.00),  // biru-putih (panas)
            vec3(1.00, 0.95 + h3*0.08, 0.72 + h2*0.20),  // kuning-putih (dingin)
            step(0.5, h3)
        );
    }

    gl_FragData[0] = col;
}
