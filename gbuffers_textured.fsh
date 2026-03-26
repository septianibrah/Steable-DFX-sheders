/* Steable-DFX — gbuffers_textured.fsh
   Thrown items, particles, item frames — proper env lighting.
   ============================================================= */
#version 120

/* DRAWBUFFERS:0 */

#define SHADOW_DARKNESS  0.32
#define TORCH_BRIGHTNESS 2.0

uniform sampler2D texture;
uniform sampler2D lightmap;
uniform sampler2D shadowtex0;
uniform sampler2D noisetex;
uniform vec3  shadowLightPosition;
uniform mat4  gbufferModelViewInverse;
uniform float frameTimeCounter;
uniform float screenBrightness;

varying vec2  vTexCoord;
varying vec2  vLightCoord;
varying vec4  vColor;
varying vec4  vShadowPos;

float ign(vec2 fc) {
    return fract(52.9829189*fract(0.06711056*fc.x+0.00583715*fc.y));
}
vec2 vogel(int i, int n, float rot) {
    float r=sqrt((float(i)+0.5)/float(n));
    return vec2(cos(float(i)*2.3998+rot),sin(float(i)*2.3998+rot))*r;
}
float getShadow(vec3 sc, float dist) {
    if(sc.x<0.001||sc.x>0.999||sc.y<0.001||sc.y>0.999) return 1.0;
    sc.z -= 0.00015;
    float rot=ign(gl_FragCoord.xy)*6.28318;
    float pr=(1.0/4096.0)/dist;
    float s=0.0;
    s+=float(sc.z<texture2D(shadowtex0,sc.xy+vogel(0,8,rot)*pr).r);
    s+=float(sc.z<texture2D(shadowtex0,sc.xy+vogel(1,8,rot)*pr).r);
    s+=float(sc.z<texture2D(shadowtex0,sc.xy+vogel(2,8,rot)*pr).r);
    s+=float(sc.z<texture2D(shadowtex0,sc.xy+vogel(3,8,rot)*pr).r);
    s+=float(sc.z<texture2D(shadowtex0,sc.xy+vogel(4,8,rot)*pr).r);
    s+=float(sc.z<texture2D(shadowtex0,sc.xy+vogel(5,8,rot)*pr).r);
    s+=float(sc.z<texture2D(shadowtex0,sc.xy+vogel(6,8,rot)*pr).r);
    s+=float(sc.z<texture2D(shadowtex0,sc.xy+vogel(7,8,rot)*pr).r);
    return s/8.0;
}

void main() {
    vec4 a = texture2D(texture, vTexCoord)*vColor;
    if (a.a < 0.05) discard;

    float bl=vLightCoord.x;
    vec3 raw=texture2D(lightmap,vLightCoord).rgb;
    float falloff=bl*bl*(3.0-2.0*bl);
    float haloInner=pow(bl,5.0);float haloMid=pow(bl,2.8)*0.4;
    vec3 innerColor=vec3(1.00,0.80,0.50)*TORCH_BRIGHTNESS;
    vec3 outerColor=vec3(0.95,0.55,0.18)*TORCH_BRIGHTNESS;
    vec3 torchColor=mix(outerColor,innerColor,pow(bl,3.0));
    vec3 mapLight=mix(raw,raw*torchColor,falloff*0.90);
    mapLight+=innerColor*haloInner*0.35+vec3(0.80,0.35,0.08)*haloMid*0.18;
    mapLight*=1.0+sin(frameTimeCounter*7.3)*0.020+sin(frameTimeCounter*13.1+1.2)*0.012;
    vec3 lit=a.rgb*mapLight;

    vec3  ld  = normalize(mat3(gbufferModelViewInverse)*shadowLightPosition);
    float day = smoothstep(-0.08,0.18,ld.y);
    float amb = mix(0.38, 1.0, day);
    float sh  = getShadow(vShadowPos.xyz, vShadowPos.w);
    lit *= mix(amb, mix(amb, mix(SHADOW_DARKNESS,1.0,sh), day), 0.9);

    gl_FragData[0] = vec4(lit, a.a);
}
