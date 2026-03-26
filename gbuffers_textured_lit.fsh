/* NaturalShaders v4 — gbuffers_textured_lit.fsh
   Emissive geometry: fire, glowing squid, emissive particles
   ============================================================= */
#version 120
/* DRAWBUFFERS:0 */
#define TORCH_BRIGHTNESS 2.2
uniform sampler2D texture;
uniform sampler2D lightmap;
varying vec2 vTexCoord;
varying vec2 vLightCoord;
varying vec4 vColor;
void main(){
    vec4 a=texture2D(texture,vTexCoord)*vColor;
    if(a.a<0.02) discard;
    vec3 raw=texture2D(lightmap,vLightCoord).rgb;
    float bl=vLightCoord.x;
    float falloff=bl*bl*(3.0-2.0*bl);
    vec3 torchColor=vec3(1.00,0.58,0.20)*TORCH_BRIGHTNESS;
    vec3 mapLight=mix(raw,raw*torchColor,falloff*0.85);
    mapLight+=vec3(0.95,0.40,0.08)*pow(bl,3.5)*TORCH_BRIGHTNESS*0.22;
    // Emissive self-lit
    vec3 lit=a.rgb*max(mapLight,a.rgb*0.5);
    gl_FragData[0]=vec4(lit,a.a);
}
