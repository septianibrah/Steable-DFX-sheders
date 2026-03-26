/* =============================================================
   Steable-DFX — gbuffers_water.vsh
   Water / ice / glass / translucent geometry.

   Features:
   - Kuda TBN (at_tangent) for normal mapping
   - worldPosition for wave sampling
   - position2 (view-space) for NdotE scaling
   - Our BSL shadow distortion system
   - TAA motion vectors
   ============================================================= */
#version 120

#define SHADOW_MAP_BIAS 0.85

uniform mat4  gbufferModelView;
uniform mat4  gbufferModelViewInverse;
uniform mat4  gbufferPreviousModelView;
uniform mat4  gbufferPreviousProjection;
uniform mat4  shadowModelView;
uniform mat4  shadowProjection;
uniform vec3  cameraPosition;
uniform vec3  previousCameraPosition;
uniform float frameTimeCounter;
uniform int   isEyeInWater;

attribute vec4 mc_Entity;
attribute vec4 at_tangent;

varying vec4  vColor;
varying vec4  vPosition2;
varying vec4  vWorldPos;
varying vec3  vTangent;
varying vec3  vNormal;
varying vec3  vBinormal;
varying vec2  vTexCoord;
varying vec2  vLightCoord;
varying float vWater;
varying float vIce;
varying float vStainedGlass;
varying float vStainedGlassPane;
varying float vUnderwater;
varying vec4  vMotion;
varying vec4  vShadowPos;

void main() {
    vTexCoord        = gl_MultiTexCoord0.st;
    vLightCoord      = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
    vNormal          = normalize(gl_NormalMatrix * gl_Normal);
    vColor           = gl_Color;
    vWater = 0.0; vIce = 0.0;
    vStainedGlass = 0.0; vStainedGlassPane = 0.0;
    vUnderwater = float(isEyeInWater == 1);

    vPosition2  = gl_ModelViewMatrix * gl_Vertex;
    vec4 position  = gbufferModelViewInverse * gl_ModelViewMatrix * gl_Vertex;
    vWorldPos      = position + vec4(cameraPosition, 0.0);

    float eid = mc_Entity.x;
    if (eid == 8.0 || eid == 9.0)  vWater          = 1.0;
    if (eid == 79.0)                vIce            = 1.0;
    if (eid == 95.0)                vStainedGlass   = 1.0;
    if (eid == 160.0)               vStainedGlassPane = 1.0;

    vTangent  = normalize(gl_NormalMatrix * at_tangent.xyz);
    vBinormal = normalize(gl_NormalMatrix * -cross(gl_Normal, at_tangent.xyz));

    vec4 finalPos = gl_ProjectionMatrix * gbufferModelView * position;
    gl_Position   = finalPos;

    // TAA motion vector
    vec3 prevWorld = vWorldPos.xyz - cameraPosition + previousCameraPosition;
    vec4 prevClip  = gbufferPreviousProjection
                   * gbufferPreviousModelView * vec4(prevWorld - cameraPosition, 1.0);
    vMotion = vec4(
        (finalPos.xy / finalPos.w) * 0.5 + 0.5,
        (prevClip.xy / prevClip.w) * 0.5 + 0.5
    );

    // BSL shadow distortion — identical to terrain
    vec4 sv     = shadowModelView * position;
    vec4 sc     = shadowProjection * sv;
    float pLen  = length(sc.xy);
    float dist  = (1.0 - SHADOW_MAP_BIAS) + pLen * SHADOW_MAP_BIAS;
    sc.xy      /= dist;
    vShadowPos  = vec4(sc.xyz * 0.5 + 0.5, dist);
}
