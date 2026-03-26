/* Steable-DFX — shadow.fsh
   Depth-only pass with alpha testing for transparent blocks.
   Water is rendered semi-transparent in shadow (tinted shadow).
   ============================================================= */
#version 120

uniform sampler2D texture;

varying vec2  vTexCoord;
varying float vAlphaTest;
varying float vWater;

void main() {
    if (vAlphaTest > 0.5) {
        float alpha = texture2D(texture, vTexCoord).a;
        // Water: semi-transparent in shadow (partial occlusion)
        if (vWater > 0.5) {
            if (alpha < 0.05) discard;
            // Don't write depth — water lets light through
            // (creates colored light effect in conjunction with shadowcolor0)
        } else {
            // Solid alpha-tested (leaves, glass panes, etc.)
            if (alpha < 0.5) discard;
        }
    }
    // Depth written automatically by GL
}
