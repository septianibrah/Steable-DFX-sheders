/* Steable-DFX — gbuffers_hand.fsh
   Items held in hand — includes held torch glow
   Torch lights up when held, without needing to place it.
   Reduced torch brightness and deeper color.
   ============================================================= */
#version 120

/* DRAWBUFFERS:012 */

#define SHADOW_DARKNESS  0.32
#define PCF_RADIUS       1.0
#define TORCH_BRIGHTNESS 2.0
#define LIGHT_SIZE       0.10

uniform sampler2D texture;
uniform sampler2D lightmap;
uniform sampler2D shadowtex0;
uniform sampler2D noisetex;

uniform vec3  shadowLightPosition;
uniform mat4  gbufferModelViewInverse;
uniform mat4  shadowModelView;
uniform float frameTimeCounter;
uniform float screenBrightness;
uniform int   heldItemId;
uniform int   heldItemId2;

varying vec2 vTexCoord;
varying vec2 vLightCoord;
varying vec4 vColor;
varying vec3 vNormal;
varying vec4 vMotion;
varying vec4 vShadowPos;

float ign(vec2 fc) {
    return fract(52.9829189*fract(0.06711056*fc.x+0.00583715*fc.y));
}
vec2 vogel(int i, int n, float rot) {
    float r=sqrt((float(i)+0.5)/float(n)); float a=float(i)*2.3998+rot;
    return vec2(cos(a),sin(a))*r;
}
float getShadow(vec3 sc, float distort) {
    float edgeX=min(sc.x,1.0-sc.x);float edgeY=min(sc.y,1.0-sc.y);
    float edgeFade=smoothstep(0.0,0.10,min(edgeX,edgeY));
    if(sc.x<0.001||sc.x>0.999||sc.y<0.001||sc.y>0.999) return 1.0;
    sc.z -= 0.0002;
    float rot=ign(gl_FragCoord.xy)*6.28318;
    float pr=(1.0/2048.0)*PCF_RADIUS/distort;
    float s=0.0;
    s+=float(sc.z<texture2D(shadowtex0,sc.xy+vogel(0,8,rot)*pr).r);
    s+=float(sc.z<texture2D(shadowtex0,sc.xy+vogel(1,8,rot)*pr).r);
    s+=float(sc.z<texture2D(shadowtex0,sc.xy+vogel(2,8,rot)*pr).r);
    s+=float(sc.z<texture2D(shadowtex0,sc.xy+vogel(3,8,rot)*pr).r);
    s+=float(sc.z<texture2D(shadowtex0,sc.xy+vogel(4,8,rot)*pr).r);
    s+=float(sc.z<texture2D(shadowtex0,sc.xy+vogel(5,8,rot)*pr).r);
    s+=float(sc.z<texture2D(shadowtex0,sc.xy+vogel(6,8,rot)*pr).r);
    s+=float(sc.z<texture2D(shadowtex0,sc.xy+vogel(7,8,rot)*pr).r);
    return mix(1.0, s/8.0, edgeFade);
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

bool isLightItem(int id) {
    return (id==50 || id==76 || id==170 || id==169 ||
            id==89 || id==91 || id==1148 || id==1145 ||
            id==1146 || id==198);
}

void main() {
    vec4 albedo = texture2D(texture, vTexCoord)*vColor;
    if (albedo.a < 0.1) discard;

    vec3 mapLight = torchLightmap(vLightCoord);
    vec3 lit      = albedo.rgb*mapLight;

    vec3  lightDir  = normalize(mat3(gbufferModelViewInverse)*shadowLightPosition);
    float dayFactor = smoothstep(-0.08, 0.18, lightDir.y);
    float shadow    = getShadow(vShadowPos.xyz, vShadowPos.w);
    float nightAmb  = 0.055;
    float amb       = mix(nightAmb, 1.0, dayFactor);
    lit *= mix(amb, mix(amb, mix(SHADOW_DARKNESS,1.0,shadow), dayFactor), 0.9);
    lit = mix(lit + lit*vec3(0.52,0.62,0.95)*nightAmb*1.5*(1.0-dayFactor), lit, dayFactor);

    // Held torch glow — warm amber
    if (isLightItem(heldItemId) || isLightItem(heldItemId2)) {
        vec3 torchGlow = vec3(1.00, 0.80, 0.50) * TORCH_BRIGHTNESS * 0.18;
        lit += torchGlow * albedo.rgb;
        lit += vec3(0.95, 0.40, 0.08) * 0.05;
    }

    vec2 vel = vMotion.xy-vMotion.zw;
    gl_FragData[0] = vec4(lit, albedo.a);
    gl_FragData[1] = vec4(vLightCoord, 0.0, 1.0);
    gl_FragData[2] = vec4(vel*0.5+0.5, 0.0, 1.0);
}
