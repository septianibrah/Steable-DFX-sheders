/* Steable-DFX — gbuffers_textured.vsh
   Thrown items, particles, item frames — now with proper lighting.
   ============================================================= */
#version 120

#define SHADOW_MAP_BIAS 0.85

uniform mat4  gbufferModelViewInverse;
uniform mat4  shadowModelView;
uniform mat4  shadowProjection;
uniform vec3  cameraPosition;

attribute vec4 mc_Entity;

varying vec2  vTexCoord;
varying vec2  vLightCoord;
varying vec4  vColor;
varying vec4  vShadowPos;

void main() {
    vTexCoord   = (gl_TextureMatrix[0]*gl_MultiTexCoord0).xy;
    vLightCoord = (gl_TextureMatrix[1]*gl_MultiTexCoord1).xy;
    vColor      = gl_Color;

    vec4 viewPos   = gl_ModelViewMatrix*gl_Vertex;
    vec4 worldPos4 = gbufferModelViewInverse*viewPos;

    gl_Position = gl_ProjectionMatrix*viewPos;

    vec4 shadowView = shadowModelView*worldPos4;
    vec4 shadowClip = shadowProjection*shadowView;
    float posLen    = length(shadowClip.xy);
    float distort   = (1.0-SHADOW_MAP_BIAS)+posLen*SHADOW_MAP_BIAS;
    shadowClip.xy  /= distort;
    vShadowPos      = vec4(shadowClip.xyz*0.5+0.5, distort);
}
