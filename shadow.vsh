/* =============================================================
   Steable-DFX — shadow.vsh   CRITICAL: must apply IDENTICAL
   BSL distortion as gbuffers_terrain.vsh so shadow map coords
   match lookup coords exactly.
   #define SHADOW_MAP_BIAS must be 0.85 in BOTH files.
   ============================================================= */
#version 120

#define SHADOW_MAP_BIAS 0.85

attribute vec4 mc_Entity;
attribute vec4 at_tangent;

varying vec2  vTexCoord;
varying float vAlphaTest;
varying float vWater;

void main() {
    vTexCoord  = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;

    float eid = mc_Entity.x;
    // Alpha-tested blocks: glass, leaves, plants, water surface
    vAlphaTest = 0.0;
    if (eid == 8.0  || eid == 9.0  || eid == 18.0 ||
        eid == 31.0 || eid == 37.0 || eid == 38.0 ||
        eid == 39.0 || eid == 40.0 || eid == 59.0 ||
        eid == 83.0 || eid == 106.0|| eid == 111.0||
        eid == 161.0|| eid == 175.0|| eid == 20.0 ||
        eid == 95.0 || eid == 102.0|| eid == 160.0)
        vAlphaTest = 1.0;

    vWater = (eid == 8.0 || eid == 9.0) ? 1.0 : 0.0;

    // BSL distortion — MUST match terrain exactly
    vec4 pos    = ftransform();
    float posLen= length(pos.xy);
    float distort=(1.0-SHADOW_MAP_BIAS)+posLen*SHADOW_MAP_BIAS;
    pos.xy      /= distort;
    gl_Position  = pos;
}
