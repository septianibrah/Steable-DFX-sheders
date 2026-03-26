/* =============================================================
   Steable-DFX — composite3.fsh

   SSR for water and glass reflections.
   MAXIMIZED water reflections — strong, not thin/faint.
   Still water detection: less wave for enclosed water.
   ============================================================= */
#version 120

/* DRAWBUFFERS:0 */

uniform sampler2D colortex0;
uniform sampler2D colortex3;
uniform sampler2D colortex6;
uniform sampler2D depthtex0;
uniform sampler2D depthtex1;

uniform mat4  gbufferProjection;
uniform mat4  gbufferProjectionInverse;
uniform vec3  sunPosition;
uniform vec3  moonPosition;
uniform vec3  fogColor;
uniform float near;
uniform float far;
uniform float rainStrength;
uniform int   isEyeInWater;
uniform float worldTime;

varying vec2 vUV;

float comp = 1.0 - near/far/far;

vec3 viewSpacePos(vec2 uv, sampler2D d){
    vec4 ndc=vec4(uv*2.0-1.0,texture2D(d,uv).r*2.0-1.0,1.0);
    vec4 vp=gbufferProjectionInverse*ndc; return vp.xyz/vp.w;
}
vec3 toScreen(vec3 vp){
    vec4 c=gbufferProjection*vec4(vp,1.0); return(c.xyz/c.w)*0.5+0.5;
}
float screenEdgeFade(vec2 uv){
    vec2 d=min(uv,1.0-uv); return smoothstep(0.0,0.07,min(d.x,d.y));
}

/* ── Raytrace — more steps for better reflections ────────── */
vec4 raytrace(vec3 startPos, vec3 rVec){
    vec3 vector  = 0.08*rVec;  // smaller initial step for precision
    vec3 fragPos = startPos+vector;
    vec3 tvec    = vector;
    int  sr      = 0;
    for(int i=0; i<36; i++){  // more steps for better coverage
        vec3 pos=toScreen(fragPos);
        if(pos.x<0.0||pos.x>1.0||pos.y<0.0||pos.y>1.0||pos.z<0.0||pos.z>1.0) break;
        vec3  sv    = viewSpacePos(pos.xy, depthtex1);
        float err   = distance(fragPos, sv);
        float thresh= pow(length(vector)*1.5, 1.15);
        if(err<thresh){
            sr++;
            if(sr>=6){
                bool  rLand = texture2D(depthtex1,pos.xy).x<comp;
                float border= screenEdgeFade(pos.xy);
                if(!rLand) return vec4(0.0);
                return vec4(texture2D(colortex0,pos.xy).rgb, border);
            }
            tvec   -= vector;
            vector *= 0.07;
        }
        vector *= 2.0;
        tvec   += vector;
        fragPos = startPos+tvec;
    }
    return vec4(0.0);
}

/* =============================================================
   REFLECTED SKY — bright at all angles
   ============================================================= */
vec3 reflectedSky(vec3 rVec){
    float time    =mod(worldTime,24000.0);
    float noon    =clamp(1.0-abs(time/6000.0-1.0),0.0,1.0);
    float sunrise =clamp(1.0-abs(time/3000.0-1.0),0.0,1.0)
                  +clamp(1.0-abs((time-24000.0)/3000.0+1.0),0.0,1.0);
    float sunset  =clamp(1.0-abs(time/3000.0-4.0),0.0,1.0);
    float midnight=clamp(1.0-abs(time/2000.0-8.0),0.0,1.0);
    float isDay   =clamp(noon+sunrise+sunset,0.0,1.0);

    vec3 skyBlue  =vec3(0.42,0.72,1.00)*noon
                  +vec3(0.55,0.70,0.95)*0.8*sunrise
                  +vec3(0.55,0.70,0.95)*0.8*sunset
                  +vec3(0.15,0.20,0.40)*0.1*midnight;
    skyBlue=mix(vec3(0.40,0.48,0.60)*0.4, skyBlue, 1.0-rainStrength*0.7);

    vec3 sunCol=vec3(1.0,0.82,0.55)*sunrise
               +vec3(1.0,1.00,1.00)*noon
               +vec3(1.0,0.82,0.55)*sunset;
    if(dot(sunCol,sunCol)<0.01) sunCol=vec3(0.30,0.40,0.65)*midnight;

    float sunDot =max(dot(normalize(rVec),normalize(sunPosition)),0.0);
    float sunDisc=pow(sunDot,2000.0)*5.5*(1.0-rainStrength);
    float sunGlow=pow(sunDot,15.0)*0.30*(1.0-rainStrength);

    float skyUp  =clamp(rVec.y*0.5+0.5,0.0,1.0);

    vec3 horizon =mix(fogColor*1.2, skyBlue, 0.3);
    vec3 sky     =mix(horizon, skyBlue, pow(skyUp,0.45));

    // Brighter sky for stronger reflections
    sky *= isDay*1.0 + 0.12;

    sky+=sunCol*sunDisc;
    sky+=mix(vec3(1.0,0.85,0.55),vec3(0.9,0.95,1.0),skyUp)*sunGlow;

    return sky;
}

/* ============================================================= */
void main(){
    vec2  uv    = vUV;
    vec3  scene = texture2D(colortex0,uv).rgb;
    vec4  flag  = texture2D(colortex6,uv);
    float fa    = flag.a;
    bool  isWater = (fa>0.3 && fa<0.7);
    bool  isGlass = (fa>0.8);

    if(!isWater && !isGlass){ gl_FragData[0]=vec4(scene,1.0); return; }
    if(isEyeInWater==1 && isWater){ gl_FragData[0]=vec4(scene,1.0); return; }

    vec3 vP  = viewSpacePos(uv, depthtex0);
    vec3 vN  = normalize(texture2D(colortex3,uv).rgb*2.0-1.0);
    vec3 vD  = normalize(vP);
    vec3 rVec= reflect(vD, vN);

    vec3 rSky = reflectedSky(rVec);

    vec4 hit = raytrace(vP, rVec);

    // Blend SSR hit with sky fallback
    vec3 reflColor = mix(rSky, hit.rgb, hit.a);

    vec3 result;
    if(isWater){
        float NdotEye = dot(vN, vD);
        // STRONGER Fresnel — more reflective overall
        float fresnel = clamp(pow(1.0+NdotEye, 1.6), 0.08, 1.0);

        // Sun glint
        float sunRef = pow(max(dot(normalize(rVec),normalize(sunPosition)),0.0), 2000.0)*10.0;
        fresnel = clamp(max(fresnel, min(sunRef, 1.0)), 0.0, 1.0);

        // Minimum fresnel — tetap realistis, bukan terlalu cermin
        fresnel = max(fresnel, 0.18);

        // Bright ambient floor — prevent dark reflections
        vec3 ambientFloor = vec3(0.45, 0.75, 1.00) * 0.28;
        reflColor = max(reflColor, ambientFloor);

        result = mix(scene, reflColor, fresnel);

    } else {
        // Glass: Schlick fresnel
        vec3  gc      = flag.rgb;
        bool  colored = (dot(gc,vec3(1.0))<2.8);
        float cosA    = max(dot(-vD,vN),0.0);
        float fresnel = clamp(0.04+0.96*pow(1.0-cosA,5.0), 0.05, 0.95);
        result = mix(colored?scene*gc:scene, colored?reflColor*gc:reflColor, fresnel);
    }

    gl_FragData[0] = vec4(result, 1.0);
}
