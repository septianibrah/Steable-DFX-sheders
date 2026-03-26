/* Steable-DFX — gbuffers_block.fsh
   Animated blocks — same lighting as terrain.
   Chests, doors, pistons, etc. all lit correctly.
   ============================================================= */
#version 120
/* DRAWBUFFERS:0123 */
#define SHADOW_DARKNESS  0.32
#define PCF_RADIUS       1.0
#define TORCH_BRIGHTNESS 2.0
#define LIGHT_SIZE       0.10
#define CAUSTIC_SCALE    0.13
#define CAUSTIC_SPEED    0.22
#define CAUSTIC_STRENGTH 0.85
uniform sampler2D texture;
uniform sampler2D lightmap;
uniform sampler2D noisetex;
uniform sampler2D shadowtex0;
uniform sampler2D shadowtex1;
uniform sampler2D shadowcolor0;
uniform vec3  shadowLightPosition;
uniform mat4  gbufferModelViewInverse;
uniform mat4  shadowModelView;
uniform float rainStrength;
uniform float frameTimeCounter;
uniform float screenBrightness;
uniform int   isEyeInWater;
varying vec2  vTexCoord;
varying vec2  vLightCoord;
varying vec4  vColor;
varying vec3  vNormal;
varying vec4  vMotion;
varying vec4  vShadowPos;
varying vec3  vWorldPos;
float ign(vec2 fc){return fract(52.9829189*fract(0.06711056*fc.x+0.00583715*fc.y));}
vec2 vogel(int i,int n,float r){float a=float(i)*2.3998+r;return vec2(cos(a),sin(a))*sqrt((float(i)+0.5)/float(n));}
float findB(vec2 uv,float rz,float sr){float s=0.0;int c=0;float rot=ign(gl_FragCoord.xy)*6.28318;for(int i=0;i<8;i++){float d=texture2D(shadowtex0,uv+vogel(i,8,rot)*sr).r;if(rz>d){s+=d;c++;}}return(c==0)?-1.0:s/float(c);}
float getShadow(vec3 sc,float dist){
    float edgeX=min(sc.x,1.0-sc.x);float edgeY=min(sc.y,1.0-sc.y);
    float edgeFade=smoothstep(0.0,0.10,min(edgeX,edgeY));
    if(sc.x<0.001||sc.x>0.999||sc.y<0.001||sc.y>0.999)return 1.0;
    vec3 oc=clamp(sc+mat3(shadowModelView)*vNormal*0.0018*dist*dist,0.001,0.999);oc.z-=0.00008;
    float tb=1.0/4096.0,rot=ign(gl_FragCoord.xy)*6.28318;
    float ab=findB(oc.xy,oc.z,tb*8.0/dist);if(ab<0.0)return 1.0;
    float pr=clamp(max((oc.z-ab)/ab*LIGHT_SIZE,0.0),tb*1.0,tb*10.0)*PCF_RADIUS/dist;
    float s=0.0;for(int i=0;i<16;i++)s+=float(oc.z<texture2D(shadowtex0,oc.xy+vogel(i,16,rot)*pr).r);
    return mix(1.0,s/16.0,edgeFade);
}
float causticP(vec3 wp,float t){
    float cs=CAUSTIC_SCALE,spd=CAUSTIC_SPEED;
    float n1=texture2D(noisetex,wp.xz*cs+vec2(t*spd,t*spd*0.7)).x;
    float n2=texture2D(noisetex,wp.xz*cs+vec2(-t*spd*0.8,t*spd*0.5)).x;
    float c1=n1*n2;
    float n3=texture2D(noisetex,wp.xz*cs*2.5+vec2(t*spd*1.3,-t*spd)).x;
    float n4=texture2D(noisetex,wp.xz*cs*2.5+vec2(-t*spd*0.9,t*spd*1.1)).x;
    float combined=c1*0.6+(n3*n4)*0.4;
    return clamp(pow(combined,1.8)*0.6+pow(max(combined-0.4,0.0)/0.6,2.0)*1.2,0.0,1.0);
}
vec3 torchL(vec2 lc){
    vec3 raw=texture2D(lightmap,lc).rgb;float bl=lc.x;
    float falloff=bl*bl*(3.0-2.0*bl);
    float haloInner=pow(bl,5.0);float haloMid=pow(bl,2.8)*0.4;
    vec3 innerColor=vec3(1.00,0.80,0.50)*TORCH_BRIGHTNESS;
    vec3 outerColor=vec3(0.95,0.55,0.18)*TORCH_BRIGHTNESS;
    vec3 torchColor=mix(outerColor,innerColor,pow(bl,3.0));
    vec3 result=mix(raw,raw*torchColor,falloff*0.90);
    result+=innerColor*haloInner*0.35+vec3(0.80,0.35,0.08)*haloMid*0.18;
    float flicker=1.0+sin(frameTimeCounter*7.3)*0.020+sin(frameTimeCounter*13.1+1.2)*0.012;
    return result*flicker;
}

void main(){
    vec4 albedo=texture2D(texture,vTexCoord)*vColor;
    if(albedo.a<0.1)discard;
    vec3 lit=albedo.rgb*torchL(vLightCoord);
    if(isEyeInWater==1){
        float skyL=vLightCoord.y,t=frameTimeCounter;
        float caust=causticP(vWorldPos,t);
        lit+=lit*mix(vec3(0.80,1.0,0.85),vec3(0.95,1.0,0.90),caust)*caust*CAUSTIC_STRENGTH*smoothstep(0.30,0.85,skyL);
        lit+=vec3(1.0,1.0,0.95)*pow(caust,3.5)*smoothstep(0.30,0.85,skyL)*0.65;
        lit=mix(lit,lit*vec3(0.55,0.85,0.78),0.22);
    } else {
        vec3 ld=normalize(mat3(gbufferModelViewInverse)*shadowLightPosition);
        float day=smoothstep(-0.08,0.18,ld.y);
        float nightAmb=0.22;
        float amb=mix(nightAmb,1.0,day);
        float sh=getShadow(vShadowPos.xyz,vShadowPos.w);
        lit*=mix(amb,mix(SHADOW_DARKNESS,1.0,sh),day);
        lit=mix(lit+lit*vec3(0.52,0.62,0.95)*nightAmb*1.5*(1.0-day),lit,day);
        vec3 stint=vec3(1.0);
        float op=texture2D(shadowtex1,vShadowPos.xy).r,fu=texture2D(shadowtex0,vShadowPos.xy).r;
        if(vShadowPos.z-0.0002>fu&&vShadowPos.z-0.0002<=op)stint=texture2D(shadowcolor0,vShadowPos.xy).rgb*1.3;
        lit=mix(lit,lit*stint,day*(1.0-sh)*0.75);
        lit*=mix(1.0,0.91,rainStrength*day);

        // minLighting floor (Rethinking Voxels)
        float vsBrightness=clamp(screenBrightness,0.0,1.0);
        float skyYM=vLightCoord.y*vLightCoord.y*(3.0-2.0*vLightCoord.y);
        vec3 minLight=vec3(0.005625+vsBrightness*0.043)*vec3(0.45,0.475,0.60);
        lit+=albedo.rgb*minLight*(1.0-skyYM);
    }
    vec2 vel=vMotion.xy-vMotion.zw;
    gl_FragData[0]=vec4(lit,albedo.a);
    gl_FragData[1]=vec4(vLightCoord,0.0,1.0);
    gl_FragData[2]=vec4(vel*0.5+0.5,0.0,1.0);
    gl_FragData[3]=vec4(vNormal*0.5+0.5,1.0);
}
