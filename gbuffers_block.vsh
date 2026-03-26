/* Steable-DFX — gbuffers_block.vsh
   Animated chest, door, piston, etc.
   Same shadow + TAA system as terrain.
   ============================================================= */
#version 120
#define SHADOW_MAP_BIAS 0.85
uniform mat4  gbufferModelViewInverse;
uniform mat4  gbufferPreviousModelView;
uniform mat4  gbufferPreviousProjection;
uniform mat4  shadowModelView;
uniform mat4  shadowProjection;
uniform vec3  cameraPosition;
uniform vec3  previousCameraPosition;
varying vec2  vTexCoord;
varying vec2  vLightCoord;
varying vec4  vColor;
varying vec3  vNormal;
varying vec4  vMotion;
varying vec4  vShadowPos;
varying vec3  vWorldPos;
void main() {
    vTexCoord   = (gl_TextureMatrix[0]*gl_MultiTexCoord0).xy;
    vLightCoord = (gl_TextureMatrix[1]*gl_MultiTexCoord1).xy;
    vColor      = gl_Color;
    vNormal     = normalize(gl_NormalMatrix*gl_Normal);
    vec4 viewPos   = gl_ModelViewMatrix*gl_Vertex;
    vec4 worldPos4 = gbufferModelViewInverse*viewPos;
    vWorldPos      = worldPos4.xyz+cameraPosition;
    vec4 currClip  = gl_ProjectionMatrix*gl_ModelViewMatrix*gl_Vertex;
    gl_Position    = currClip;
    vec3 prevWorld = vWorldPos-cameraPosition+previousCameraPosition;
    vec4 prevClip  = gbufferPreviousProjection*gbufferPreviousModelView*vec4(prevWorld-cameraPosition,1.0);
    vMotion = vec4((currClip.xy/currClip.w)*0.5+0.5,(prevClip.xy/prevClip.w)*0.5+0.5);
    vec4 sv=shadowModelView*worldPos4;
    vec4 sc=shadowProjection*sv;
    float pL=length(sc.xy);
    float d=(1.0-SHADOW_MAP_BIAS)+pL*SHADOW_MAP_BIAS;
    sc.xy/=d;
    vShadowPos=vec4(sc.xyz*0.5+0.5,d);
}
