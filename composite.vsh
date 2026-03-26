/* =============================================================
   Steable-DFX — composite.vsh

   shadowLightPosition is VIEW-SPACE and updated every frame.
   We project it to screen UV here (vertex shader = 4× per frame,
   not per-pixel) and pass to fragment shader.

   Using shadowLightPosition instead of sunPosition means
   god rays automatically switch to the moon at night.
   ============================================================= */
#version 120

uniform mat4 gbufferProjection;
uniform vec3 shadowLightPosition;   // view-space, realtime, auto sun/moon

varying vec2  vUV;
varying vec2  vLightScreenUV;   // projected light source [0,1]
varying float vLightFacing;     // 1.0 = light is in front of camera

void main() {
    gl_Position = ftransform();
    vUV = gl_MultiTexCoord0.xy;

    // Project the shadow-casting light (sun or moon) to screen
    vec4 lightClip = gbufferProjection * vec4(shadowLightPosition * 100.0, 1.0);

    // Light is in front of camera when view-space z < 0
    vLightFacing = (shadowLightPosition.z < 0.0 && lightClip.w > 0.001) ? 1.0 : 0.0;

    if (lightClip.w > 0.001) {
        vLightScreenUV = (lightClip.xy / lightClip.w) * 0.5 + 0.5;
    } else {
        vLightScreenUV = vec2(-10.0);
    }
}
