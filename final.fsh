/* NaturalShaders v4 — final.fsh
   - Wet screen: kaca basah berkilau, tetesan meluncur, tanpa RGB
   - Rain streak animasi: lapisan hujan jatuh di screen
   - ACES + fantasy color grading
   - NO vignette, NO chromatic aberration
*/
#version 120

#define RAIN_WET_STRENGTH  1.0

uniform sampler2D colortex0;
uniform mat4      gbufferProjection;
uniform vec3      shadowLightPosition;
uniform float     rainStrength;
uniform float     thunderStrength;
uniform float     frameTimeCounter;
uniform float     screenBrightness;
uniform float     viewWidth;
uniform float     viewHeight;
uniform int       isEyeInWater;

varying vec2 vUV;

float hash21(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float vnoise(vec2 p){
    vec2 i=floor(p);vec2 f=fract(p);f=f*f*(3.0-2.0*f);
    return mix(mix(hash21(i),hash21(i+vec2(1,0)),f.x),
               mix(hash21(i+vec2(0,1)),hash21(i+vec2(1,1)),f.x),f.y);
}

/* ── ACES Tone Mapping ──────────────────────────────────────── */
vec3 ACESToneMap(vec3 x){
    const float a=2.51,b=0.03,c=2.43,d=0.59,e=0.14;
    return clamp((x*(a*x+b))/(x*(c*x+d)+e),0.0,1.0);
}

/* ── Fantasy Color Grading ──────────────────────────────────── */
vec3 fantasyGrade(vec3 c){
    // Contrast
    c=mix(c,c*c*(3.0-2.0*c),0.20);
    // Saturasi — v5: dikurangi agar tidak kartun
    float lum=dot(c,vec3(0.2126,0.7152,0.0722));
    c=mix(vec3(lum),c,1.14);
    // Shadow-highlight split
    float l=dot(c,vec3(0.333));
    c*=mix(vec3(0.96,0.98,1.04),vec3(1.03,1.01,0.96),smoothstep(0.3,0.9,l));
    return clamp(c,0.0,1.0);
}

/* ── WET SCREEN — kaca basah berkilau, tetesan meluncur ────────
   NO chromatic aberration — tidak ada RGB split
   ─────────────────────────────────────────────────────────── */
vec3 wetScreen(vec2 uv,float rain,float t){
    if(rain<0.02) return texture2D(colortex0,uv).rgb;

    float strength=rain*RAIN_WET_STRENGTH;

    // Lapisan distorsi: kaca basah bergelombang
    float l1=vnoise(uv*6.0 +vec2(t*0.12, t*0.06));
    float l2=vnoise(uv*12.0+vec2(-t*0.07,t*0.10));
    float l3=vnoise(uv*3.5 +vec2(t*0.04,-t*0.04));
    float dx=(l1-0.5)*0.008+(l2-0.5)*0.003;
    float dy=(l1-0.5)*0.006+(l3-0.5)*0.004;

    // Tetesan meluncur vertikal — sliding down screen
    float dropX=floor(uv.x*32.0);
    float dropRng=hash21(vec2(dropX,floor(t*0.3)));
    float dropPhase=fract(fract(dropRng*7.3)+t*0.18);
    float dropY=1.0-dropPhase; // meluncur dari atas ke bawah
    float dropDist=abs(uv.y-dropY);
    float trail=smoothstep(0.0,0.08,dropDist)*smoothstep(0.18,0.0,dropDist);
    float dropMask=smoothstep(0.48,0.50,0.5-abs(fract(uv.x*32.0)-0.5));
    float dropStrength=trail*dropMask*strength;

    // Distorsi tetesan (refraksi kecil)
    dy+=dropStrength*0.012;
    dx+=(vnoise(uv*20.0+t*0.3)-0.5)*dropStrength*0.008;

    vec2 distUV=clamp(uv+vec2(dx,dy)*strength,0.0,1.0);
    return texture2D(colortex0,distUV).rgb;
}

/* ── RAIN STREAKS di screen ──────────────────────────────────── */
vec3 rainStreaks(vec2 uv,float rain,float t){
    if(rain<0.04) return vec3(0.0);
    float aspect=viewWidth/viewHeight;
    float s=0.0;

    // 3 lapisan — jauh, tengah, dekat
    // Lapisan 1: hujan jauh (halus, banyak)
    float c1=floor(uv.x*60.0*aspect);
    float r1=fract(uv.y*40.0+t*2.2+hash21(vec2(c1,0.0))*10.0);
    float len1=0.015+hash21(vec2(c1,1.0))*0.025;
    float fx1=abs(fract(uv.x*60.0*aspect)-0.5);
    s+=smoothstep(0.97,1.0,1.0-abs(r1-0.5)/len1)*smoothstep(0.46,0.50,0.5-fx1)*0.45;

    // Lapisan 2: hujan tengah
    float c2=floor(uv.x*32.0*aspect);
    float r2=fract(uv.y*24.0+t*2.6+hash21(vec2(c2,2.0))*8.0);
    float len2=0.022+hash21(vec2(c2,3.0))*0.040;
    float fx2=abs(fract(uv.x*32.0*aspect)-0.5);
    s+=smoothstep(0.95,1.0,1.0-abs(r2-0.5)/len2)*smoothstep(0.43,0.48,0.5-fx2)*0.60;

    // Lapisan 3: hujan dekat (besar, jelas)
    float c3=floor(uv.x*16.0*aspect);
    float r3=fract(uv.y*14.0+t*3.0+hash21(vec2(c3,4.0))*6.0);
    float len3=0.035+hash21(vec2(c3,5.0))*0.055;
    float fx3=abs(fract(uv.x*16.0*aspect)-0.5);
    s+=smoothstep(0.93,1.0,1.0-abs(r3-0.5)/len3)*smoothstep(0.40,0.46,0.5-fx3)*0.40;

    // Warna rain streak: biru-putih tipis
    return vec3(0.75,0.85,0.98)*clamp(s,0.0,1.0)*rain*0.32;
}

/* ── WET SCREEN EDGE GLEAM ───────────────────────────────────── */
vec3 wetEdgeGleam(vec3 color,vec2 uv,float rain,float t){
    if(rain<0.05) return color;
    // Kilap air di pinggir kaca — bukan penggelapan, tapi kilap tipis
    float ex=abs(uv.x-0.5)*2.0,ey=abs(uv.y-0.5)*2.0;
    float edge=smoothstep(0.65,1.0,max(ex,ey));
    float gleam=vnoise(uv*vec2(14.0,8.0)+vec2(0.0,t*0.12))*rain;
    // Tambah highlight putih tipis di pinggir (bukan gelap)
    color=mix(color,color+vec3(0.06,0.08,0.12)*gleam,edge*rain*0.5);
    return color;
}

void main(){
    float t=frameTimeCounter;
    float rain=rainStrength;

    // Underwater
    if(isEyeInWater==1){
        vec3 c=texture2D(colortex0,vUV).rgb;
        // Distorsi air bergerak
        float l1=vnoise(vUV*5.0+vec2(t*0.09,t*0.05));
        float l2=vnoise(vUV*10.0+vec2(-t*0.06,t*0.08));
        c=texture2D(colortex0,vUV+vec2((l1-0.5)*0.005,(l2-0.5)*0.004)).rgb;
        c=ACESToneMap(c);
        c=fantasyGrade(c);
        c+=vec3(screenBrightness*0.07)*(1.0-c);
        gl_FragColor=vec4(clamp(c,0.0,1.0),1.0);
        return;
    }

    // Wet screen — kaca basah beranimasi
    vec3 color=wetScreen(vUV,rain,t);

    // Rain color grading: langit lebih kelabu, dunia lebih redup
    if(rain>0.02){
        float grey=dot(color,vec3(0.299,0.587,0.114));
        color=mix(color,vec3(grey),rain*0.10);
        color=mix(color,color*vec3(0.91,0.94,1.02),rain*0.12);
        color*=mix(1.0,0.91,rain*0.22);
    }

    // Rain streaks animasi
    color+=rainStreaks(vUV,rain,t);

    // Wet edge gleam (kilap, bukan gelap)
    color=wetEdgeGleam(color,vUV,rain,t);

    // Lightning flash
    if(thunderStrength>0.0){
        float flash=thunderStrength*thunderStrength;
        float flicker=0.7+0.3*sin(t*25.0);
        color+=vec3(0.85,0.88,1.0)*flash*flicker*0.15;
    }

    // ACES
    color=ACESToneMap(color);
    // Fantasy grade
    color=fantasyGrade(color);
    // Brightness
    color+=vec3(screenBrightness*0.07)*(1.0-color);

    gl_FragColor=vec4(clamp(color,0.0,1.0),1.0);
}
