/* Steable-DFX — gbuffers_entities.fsh
   Same lighting model as terrain:
   - PCSS shadow (mobs cast and receive proper shadows)
   - torch lightmap enhancement
   - night ambient
   Fixes: mobs/items were white because they had no shadow/env lighting.
   ============================================================= */
#version 120

/* DRAWBUFFERS:0123 */

#define SHADOW_DARKNESS  0.20
#define PCF_RADIUS       1.0
#define TORCH_BRIGHTNESS 2.0
#define LIGHT_SIZE       0.08

uniform sampler2D texture;
uniform sampler2D lightmap;
uniform sampler2D shadowtex0;
uniform sampler2D shadowtex1;
uniform sampler2D shadowcolor0;
uniform sampler2D noisetex;

uniform vec3  shadowLightPosition;
uniform mat4  gbufferModelViewInverse;
uniform mat4  shadowModelView;
uniform float rainStrength;
uniform float frameTimeCounter;
uniform float screenBrightness;

varying vec2  vTexCoord;
varying vec2  vLightCoord;
varying vec4  vColor;
varying vec3  vNormal;
varying vec4  vMotion;
varying vec4  vShadowPos;
varying vec3  vWorldPos;

float ign(vec2 fc) {
    return fract(52.9829189*fract(0.06711056*fc.x+0.00583715*fc.y));
}
vec2 vogel(int i, int n, float rot) {
    float r=sqrt((float(i)+0.5)/float(n)); float a=float(i)*2.3998+rot;
    return vec2(cos(a),sin(a))*r;
}
float findBlocker(vec2 uv, float rz, float sr) {
    float sum=0.0; int cnt=0;
    float rot=ign(gl_FragCoord.xy)*6.28318;
    for(int i=0;i<8;i++){
        float d=texture2D(shadowtex0,uv+vogel(i,8,rot)*sr).r;
        if(rz>d){sum+=d;cnt++;}
    }
    return (cnt==0)?-1.0:sum/float(cnt);
}
float getShadow(vec3 sc, float distort) {
    float edgeX=min(sc.x,1.0-sc.x);float edgeY=min(sc.y,1.0-sc.y);
    float edgeFade=smoothstep(0.0,0.10,min(edgeX,edgeY));
    if(sc.x<0.001||sc.x>0.999||sc.y<0.001||sc.y>0.999) return 1.0;
    vec3 ssN=mat3(shadowModelView)*vNormal;
    vec3 oc=clamp(sc+ssN*0.0018*distort*distort, 0.001, 0.999);
    oc.z-=0.00008;
    float tb=1.0/4096.0;
    float rot=ign(gl_FragCoord.xy)*6.28318;
    float ab=findBlocker(oc.xy,oc.z,tb*8.0/distort);
    if(ab<0.0) return 1.0;
    float pen=max((oc.z-ab)/ab*LIGHT_SIZE,0.0);
    float pr=clamp(pen,tb*1.0,tb*10.0)*PCF_RADIUS/distort;
    float s=0.0;
    s+=float(oc.z<texture2D(shadowtex0,oc.xy+vogel( 0,16,rot)*pr).r);
    s+=float(oc.z<texture2D(shadowtex0,oc.xy+vogel( 1,16,rot)*pr).r);
    s+=float(oc.z<texture2D(shadowtex0,oc.xy+vogel( 2,16,rot)*pr).r);
    s+=float(oc.z<texture2D(shadowtex0,oc.xy+vogel( 3,16,rot)*pr).r);
    s+=float(oc.z<texture2D(shadowtex0,oc.xy+vogel( 4,16,rot)*pr).r);
    s+=float(oc.z<texture2D(shadowtex0,oc.xy+vogel( 5,16,rot)*pr).r);
    s+=float(oc.z<texture2D(shadowtex0,oc.xy+vogel( 6,16,rot)*pr).r);
    s+=float(oc.z<texture2D(shadowtex0,oc.xy+vogel( 7,16,rot)*pr).r);
    s+=float(oc.z<texture2D(shadowtex0,oc.xy+vogel( 8,16,rot)*pr).r);
    s+=float(oc.z<texture2D(shadowtex0,oc.xy+vogel( 9,16,rot)*pr).r);
    s+=float(oc.z<texture2D(shadowtex0,oc.xy+vogel(10,16,rot)*pr).r);
    s+=float(oc.z<texture2D(shadowtex0,oc.xy+vogel(11,16,rot)*pr).r);
    s+=float(oc.z<texture2D(shadowtex0,oc.xy+vogel(12,16,rot)*pr).r);
    s+=float(oc.z<texture2D(shadowtex0,oc.xy+vogel(13,16,rot)*pr).r);
    s+=float(oc.z<texture2D(shadowtex0,oc.xy+vogel(14,16,rot)*pr).r);
    s+=float(oc.z<texture2D(shadowtex0,oc.xy+vogel(15,16,rot)*pr).r);
    return mix(1.0, s/16.0, edgeFade);
}
vec3 torchLightmap(vec2 lc){
    vec3 raw=texture2D(lightmap,lc).rgb; float bl=lc.x;
    float falloff=bl*bl*(3.0-2.0*bl);
    float haloInner=pow(bl,5.0); float haloMid=pow(bl,2.8)*0.4;
    vec3 innerColor=vec3(1.00,0.80,0.50)*TORCH_BRIGHTNESS;
    vec3 outerColor=vec3(0.95,0.55,0.18)*TORCH_BRIGHTNESS;
    vec3 glowColor=vec3(0.80,0.35,0.08);
    vec3 torchColor=mix(outerColor,innerColor,pow(bl,3.0));
    vec3 result=mix(raw,raw*torchColor,falloff*0.90);
    result+=innerColor*haloInner*0.35+glowColor*haloMid*0.18;
    float flicker=1.0+sin(frameTimeCounter*7.3)*0.020+sin(frameTimeCounter*13.1+1.2)*0.012;
    return result*flicker;
}


void main() {
    vec4 albedo = texture2D(texture, vTexCoord)*vColor;
    if (albedo.a < 0.1) discard;

    vec3 mapLight = torchLightmap(vLightCoord);
    vec3 lit      = albedo.rgb*mapLight;

    vec3  lightDir  = normalize(mat3(gbufferModelViewInverse)*shadowLightPosition);
    float dayFactor = smoothstep(-0.08, 0.18, lightDir.y);
    float nightAmb  = 0.30;
    float amb       = mix(nightAmb, 1.0, dayFactor);
    float shadow    = getShadow(vShadowPos.xyz, vShadowPos.w);
    lit *= mix(amb, mix(SHADOW_DARKNESS, 1.0, shadow), dayFactor);
    lit *= mix(1.0, 0.91, rainStrength*dayFactor);

    // minLighting floor (Rethinking Voxels) — cegah entity jadi hitam total
    float vsBrightness = clamp(screenBrightness, 0.0, 1.0);
    float skyYM = vLightCoord.y * vLightCoord.y * (3.0 - 2.0 * vLightCoord.y);
    vec3 minLight = vec3(0.005625 + vsBrightness * 0.043) * vec3(0.45, 0.475, 0.60);
    lit += albedo.rgb * minLight * (1.0 - skyYM);

    vec2 vel = vMotion.xy-vMotion.zw;
    gl_FragData[0] = vec4(lit, albedo.a);
    gl_FragData[1] = vec4(vLightCoord, 0.0, 1.0);
    gl_FragData[2] = vec4(vel*0.5+0.5, 0.0, 1.0);
    gl_FragData[3] = vec4(vNormal*0.5+0.5, 1.0);
}
