/* NaturalShaders v5 — composite.fsh
   FIXES:
   - God rays / volumetrik: SELALU aktif dari semua arah kamera
   - Underwater: fog lebih dalam + volumetrik god rays bawah air
   - Rain ripple: transparan seperti asli, fresnel realistis
   - atmosphericScatter lebih kuat & stabil
   v5.1 FIX:
   - God rays tipis & stabil (anti-flicker dither temporal)
   - Sky tidak lagi di-brighten oleh scatter/god rays
   - Kekuatan god rays dikurangi signifikan
*/
#version 120

/* DRAWBUFFERS:045 */

#define GODRAY_STEPS      60
#define GODRAY_DECAY      0.978
#define GODRAY_WEIGHT     0.22
#define GODRAY_EXPOSURE   0.85
#define GODRAY_STRENGTH   0.20
#define GODRAY_THRESHOLD  0.07
#define BLOOM_THRESHOLD   0.72
#define BLOOM_STRENGTH    0.20
#define BIOME_FOG_DENSITY 1.0
#define TAA_BLEND         0.10

uniform sampler2D colortex0;
uniform sampler2D colortex2;
uniform sampler2D colortex3;
uniform sampler2D colortex4;
uniform sampler2D depthtex0;
uniform sampler2D noisetex;

uniform vec3  shadowLightPosition;
uniform mat4  gbufferProjectionInverse;
uniform mat4  gbufferModelViewInverse;
uniform vec3  cameraPosition;
uniform vec3  fogColor;
uniform float fogStart;
uniform float fogEnd;
uniform float rainStrength;
uniform float frameTimeCounter;
uniform float viewWidth;
uniform float viewHeight;
uniform float far;
uniform float near;
uniform int   isEyeInWater;
uniform float worldTime;

varying vec2  vUV;
varying vec2  vLightScreenUV;
varying float vLightFacing;

float luma(vec3 c){return dot(c,vec3(0.2126,0.7152,0.0722));}
float linearizeDepth(float d){return(2.0*near)/(far+near-d*(far-near));}

void getAABB(vec2 uv,vec2 ts,out vec3 mn,out vec3 mx){
    mn=vec3(1.0);mx=vec3(0.0);vec3 s;
    s=texture2D(colortex0,uv+ts*vec2(-1,-1)).rgb;mn=min(mn,s);mx=max(mx,s);
    s=texture2D(colortex0,uv+ts*vec2( 0,-1)).rgb;mn=min(mn,s);mx=max(mx,s);
    s=texture2D(colortex0,uv+ts*vec2( 1,-1)).rgb;mn=min(mn,s);mx=max(mx,s);
    s=texture2D(colortex0,uv+ts*vec2(-1, 0)).rgb;mn=min(mn,s);mx=max(mx,s);
    s=texture2D(colortex0,uv             ).rgb;mn=min(mn,s);mx=max(mx,s);
    s=texture2D(colortex0,uv+ts*vec2( 1, 0)).rgb;mn=min(mn,s);mx=max(mx,s);
    s=texture2D(colortex0,uv+ts*vec2(-1, 1)).rgb;mn=min(mn,s);mx=max(mx,s);
    s=texture2D(colortex0,uv+ts*vec2( 0, 1)).rgb;mn=min(mn,s);mx=max(mx,s);
    s=texture2D(colortex0,uv+ts*vec2( 1, 1)).rgb;mn=min(mn,s);mx=max(mx,s);
    vec3 c=(mn+mx)*0.5;vec3 e=(mx-mn)*0.575;mn=c-e;mx=c+e;
}

/* ── UNDERWATER FOG + VOLUMETRIC SHAFTS ──────────────────────── */
vec3 underwaterFog(vec3 clr, vec2 uv){
    if(isEyeInWater != 1) return clr;
    float d = texture2D(depthtex0, uv).r;
    vec4 ndc = vec4(uv*2.0-1.0, d*2.0-1.0, 1.0);
    vec4 vp  = gbufferProjectionInverse * ndc;
    vec3 fragpos = vp.xyz / vp.w;
    float depth  = length(fragpos.xyz);

    // Fog density bawah air — lebih dalam makin biru gelap
    float fogFactor = 1.0 - exp(-pow(depth * 0.060, 1.8));

    float time = mod(worldTime, 24000.0);
    float noon    = 1.0 - abs(time/6000.0 - 1.0);
    float sunrise = clamp(1.0-abs(time/3000.0-1.0),0.0,1.0)+clamp(1.0-abs((time-24000.0)/3000.0+1.0),0.0,1.0);
    float sunset  = clamp(1.0 - abs(time/3000.0 - 4.0), 0.0, 1.0);
    float midnight= clamp(1.0 - abs(time/2000.0 - 8.0), 0.0, 1.0);
    float eyeAdapt= clamp(noon + sunrise*0.6 + sunset*0.6 + midnight*0.06, 0.35, 1.0);

    vec3 uwColor = vec3(0.10, 0.38, 0.68)*(noon+sunrise*0.6+sunset*0.6)
                 + vec3(0.05, 0.15, 0.30)*0.05*midnight;
    if(length(uwColor)<0.01) uwColor = vec3(0.04, 0.13, 0.28)*0.35;

    // ── Volumetric god rays bawah air ──────────────────────────
    // Shaft dari permukaan ke bawah — bergoyang dengan noise
    vec3 lightDir = normalize(mat3(gbufferModelViewInverse)*shadowLightPosition);
    float dayF = smoothstep(-0.05, 0.20, lightDir.y);
    float shaftAmt = 0.0;
    if(dayF > 0.01 && d < 0.9999){
        float n1 = texture2D(noisetex, uv*1.8 + vec2(frameTimeCounter*0.012, 0.0)).x;
        float n2 = texture2D(noisetex, uv*3.2 + vec2(0.0, frameTimeCounter*0.009)).x;
        float n3 = texture2D(noisetex, uv*0.9 + vec2(-frameTimeCounter*0.007, frameTimeCounter*0.006)).x;
        // Shaft pattern: kombinasi noise yang bergerak
        float shaft = pow(n1 * n2, 1.4) * 1.80 + pow(max(n3-0.4,0.0)/0.6, 2.0) * 0.60;
        shaftAmt = clamp(shaft * dayF * (1.0 - fogFactor*0.7), 0.0, 1.0);
    }
    vec3 shaftColor = vec3(0.72, 0.92, 1.00) * 0.18 * shaftAmt * eyeAdapt;

    // Campurkan: fog + shaft + tint air
    vec3 tintedSrc = mix(clr * vec3(0.45, 0.72, 0.95), uwColor*0.10*eyeAdapt, fogFactor);
    return tintedSrc + shaftColor;
}

/* ── DIRECTIONAL GOD RAYS — tree shadows visible ──────────────*/
vec3 godRays(vec2 uv, vec2 lightUV){
    vec2 dir  = lightUV - uv;
    float dist = length(dir);
    // Dither temporal: stabil per-pixel, berubah antar frame → TAA blend
    vec2 pixelCoord = floor(uv * vec2(viewWidth, viewHeight));
    float ditherOffset = fract(fract(dot(pixelCoord, vec2(127.1, 311.7)) * 0.00392156) + frameTimeCounter * 0.6180339);
    vec2 step_ = dir / float(GODRAY_STEPS);
    float illum = 1.0; vec3 acc = vec3(0.0);
    vec2 pos = uv + step_*ditherOffset;

    for(int i=0; i<GODRAY_STEPS; i++){
        pos += step_;
        vec2 s = clamp(pos, 0.001, 0.999);
        float bright = max(luma(texture2D(colortex0,s).rgb)-GODRAY_THRESHOLD, 0.0);
        acc += vec3(bright)*illum*GODRAY_WEIGHT;
        illum *= GODRAY_DECAY;
    }
    acc *= GODRAY_EXPOSURE / float(GODRAY_STEPS);
    acc  = clamp(acc, 0.0, 1.0);

    float edgeFade = 1.0 - smoothstep(0.45, 1.10, dist);
    float rainDim  = 1.0 - rainStrength*0.55;
    vec3  lightDir = normalize(mat3(gbufferModelViewInverse)*shadowLightPosition);
    float isDay    = smoothstep(-0.08, 0.18, lightDir.y);

    float sunHeight   = clamp((lightUV.y - 0.10)*3.0, 0.0, 1.0);
    vec3  sunriseColor = vec3(1.00, 0.55, 0.18);
    vec3  middayColor  = vec3(1.00, 0.88, 0.65);
    vec3  moonColor    = vec3(0.60, 0.72, 1.00);
    vec3  dayColor = mix(sunriseColor, middayColor, smoothstep(0.0, 0.6, sunHeight));

    // horizonBoost & strengthMult dikurangi agar god rays tipis
    float horizonBoost = 1.0 + smoothstep(0.40, 0.0, sunHeight)*0.35;
    float noonFactor   = pow(max(sunHeight-0.05,0.0)/0.95, 0.6);
    float strengthMult = mix(0.80, 1.20, noonFactor);

    return acc * mix(moonColor,dayColor,isDay) * GODRAY_STRENGTH*strengthMult*edgeFade*rainDim*horizonBoost;
}

/* ── RAIN GROUND RIPPLE — transparan realistis ─────────────────
   v5: Fresnel-based highlight, tidak ada darkening
   Tetesan transparan seperti air sungguhan di aspal/tanah
   ─────────────────────────────────────────────────────────── */
vec3 rainGroundRipple(vec3 color, vec2 uv, float rain, float t){
    if(rain < 0.05 || isEyeInWater == 1) return color;

    float rawD = texture2D(depthtex0, uv).r;
    if(rawD > 0.9999) return color;

    vec4 ndc = vec4(uv*2.0-1.0, rawD*2.0-1.0, 1.0);
    vec4 vp  = gbufferProjectionInverse * ndc;
    vec3 viewPos  = vp.xyz / vp.w;
    vec3 worldPos = (gbufferModelViewInverse * vec4(viewPos, 1.0)).xyz + cameraPosition;

    // Permukaan menghadap ke atas
    vec3 viewNormal  = texture2D(colortex3, uv).rgb * 2.0 - 1.0;
    vec3 worldNormal = normalize(mat3(gbufferModelViewInverse) * viewNormal);
    float upFacing = worldNormal.y;
    if(upFacing < 0.50) return color;

    // Fresnel: semakin grazing angle, semakin reflektif
    vec3 viewDir = normalize(-viewPos);
    float fresnel = pow(1.0 - max(dot(viewDir, worldNormal), 0.0), 3.0);
    fresnel = mix(0.04, 1.0, fresnel); // F0 air ~0.04

    float ripple = 0.0;
    float rippleGlow = 0.0; // untuk highlight specular

    for(int i = 0; i < 12; i++){
        float fi = float(i);
        float cellX = floor(worldPos.x * 0.65 + fi*2.718281);
        float cellZ = floor(worldPos.z * 0.65 + fi*1.618034);

        float rng  = fract(sin(fi*13.7 + cellX*0.1234 + cellZ*0.0712)*4375.8);
        float rng2 = fract(sin(fi*27.3 + cellX*0.0891 + cellZ*0.1567)*8765.4);
        float rng3 = fract(rng*7.31 + rng2*3.17);

        float cx = cellX/0.65 + (rng -0.5)*1.8;
        float cz = cellZ/0.65 + (rng2-0.5)*1.8;

        float phaseSpeed = 1.2 + rng3*0.9;
        float phase = fract(t*phaseSpeed + rng*4.7);
        float radius = phase * 0.75;

        float dx = worldPos.x - cx;
        float dz = worldPos.z - cz;
        float dist = sqrt(dx*dx + dz*dz);

        // Ring tipis memuai
        float ringW = 0.035 + phase*0.018;
        float ring  = 1.0 - smoothstep(0.0, ringW, abs(dist - radius));
        float fade  = smoothstep(0.0, 0.10, phase) * smoothstep(1.0, 0.50, phase);

        // Highlight lebih kuat di tepi depan cincin (air nyata: rim-lit)
        float rimFront = 1.0 - smoothstep(0.0, ringW*0.5, dist - radius);
        rippleGlow += rimFront * fade * rain * 0.5;
        ripple     += ring * fade * rain;
    }

    ripple     = clamp(ripple,     0.0, 1.0);
    rippleGlow = clamp(rippleGlow, 0.0, 1.0);

    if(ripple > 0.003){
        // Highlight air transparan: TIDAK darkening, hanya menambah specular
        // Warna highlight bergantung sky/cahaya
        vec3 skyReflect = mix(vec3(0.80, 0.90, 1.00), vec3(1.00, 0.85, 0.65),
                              rainStrength*0.3);
        // Fresnel highlight di cincin — seperti air menangkap cahaya
        float specAmt = ripple * fresnel * upFacing;
        color += skyReflect * specAmt * 0.28 * rain;
        // Rim glow: titik terang di tepi depan tetesan
        color += vec3(0.90, 0.95, 1.00) * rippleGlow * 0.12 * upFacing;
    }
    return color;
}

vec3 biomeFog(vec3 color, float worldDist){
    float fe  = max(fogEnd, far*0.75);
    float vT  = clamp((worldDist-fogStart)/max(fe-fogStart,1.0), 0.0, 1.0);
    float warmth   = fogColor.r - fogColor.b;
    float greenish = fogColor.g - (fogColor.r+fogColor.b)*0.5;
    float coldness = fogColor.b - fogColor.r;
    vec3 tint=fogColor; float mult=1.0;
    if(warmth>0.08){float d=sin(worldDist*0.04+frameTimeCounter*0.18)*0.5+0.5;tint=mix(fogColor,vec3(0.82,0.65,0.30)+vec3(0.05,0.03,0.0)*d,0.65);mult=1.0+warmth*2.0*BIOME_FOG_DENSITY;}
    else if(greenish>0.04){tint=mix(fogColor,vec3(0.28,0.44,0.20),0.55);mult=1.0+0.55*BIOME_FOG_DENSITY;}
    else if(coldness>0.05){tint=mix(fogColor,vec3(0.76,0.88,1.00),0.45);mult=1.0+0.28*BIOME_FOG_DENSITY;}
    else{tint=mix(fogColor,fogColor+vec3(0.01,0.02,0.04),0.35);mult=1.0+0.12*BIOME_FOG_DENSITY;}
    tint=mix(tint,tint*0.65,rainStrength*0.5);mult=mix(mult,mult*1.5,rainStrength*0.4);
    return mix(color, tint, clamp(vT*mult, 0.0, 1.0));
}

/* ── ATMOSPHERIC SCATTER — SEMUA ARAH + KAMERA KE BAWAH ─────────
   v5.2 FIX:
   - Sky pixel (rawD >= 0.9999) TIDAK di-scatter → langit tidak cerah berlebihan
   - Hanya terrain/objek yang mendapat haze
   - Ambient haze dikurangi
   ─────────────────────────────────────────────────────────────── */
vec3 atmosphericScatter(vec3 color, vec2 uv){
    vec3  lightDir = normalize(mat3(gbufferModelViewInverse)*shadowLightPosition);
    float sunH     = lightDir.y;

    float dayFactor = smoothstep(-0.15, 0.25, sunH);
    if(dayFactor < 0.005) return color;

    float rawD = texture2D(depthtex0, uv).r;
    float isSky = step(0.9999, rawD);

    // Jika pixel adalah langit murni → kembalikan tanpa perubahan
    // (God rays dari matahari cukup, tidak perlu scatter tambahan di langit)
    if(isSky > 0.5) return color;

    float linD = linearizeDepth(rawD);

    // Depth-based haze: makin jauh makin banyak scatter
    float volDepth = 1.0 - exp(-linD * far * 0.00055);

    // Ambient haze ringan untuk udara di sekitar pemain
    float ambientHaze = dayFactor * 0.008;

    float volAmt = volDepth * 0.75 + ambientHaze;

    // Noise variation
    float nx = texture2D(noisetex, uv*0.35 + vec2(frameTimeCounter*0.004, 0.0)).x;
    float noiseVar = 0.88 + nx * 0.24;

    float normalized = clamp(sunH, 0.0, 1.0);
    vec3  sunriseCol = vec3(1.00, 0.58, 0.22);
    vec3  noonCol    = vec3(0.95, 0.90, 0.78);
    vec3  scatterCol = mix(sunriseCol, noonCol, smoothstep(0.0, 0.50, normalized));

    float rainDim = 1.0 - rainStrength*0.45;

    float intensity = volAmt * dayFactor * 0.038 * rainDim * noiseVar;
    return color + scatterCol * intensity;
}

void main(){
    vec2 uv = vUV;
    vec2 ts = vec2(1.0/viewWidth, 1.0/viewHeight);
    vec3 curr  = texture2D(colortex0, uv).rgb;
    float rawD = texture2D(depthtex0, uv).r;
    float linD = linearizeDepth(rawD);

    if(isEyeInWater == 0) curr = biomeFog(curr, linD*far);

    // ── ATMOSPHERIC SCATTER: selalu aktif, semua arah kamera ──
    if(isEyeInWater == 0) curr = atmosphericScatter(curr, uv);

    // ── DIRECTIONAL GOD RAYS: saat matahari terlihat di layar ──
    if(vLightFacing > 0.5 && isEyeInWater == 0){
        curr += godRays(uv, vLightScreenUV);
    }

    // Rain ground ripple — transparan realistis
    curr = rainGroundRipple(curr, uv, rainStrength, frameTimeCounter);

    // TAA
    vec2 rawVel = texture2D(colortex2, uv).rg;
    vec2 vel    = (rawVel - 0.5)*2.0;
    vec2 prevUV = uv - vel;
    bool inBounds = (prevUV.x>0.001&&prevUV.x<0.999&&prevUV.y>0.001&&prevUV.y<0.999);
    vec3 hist = texture2D(colortex4, prevUV).rgb;
    vec3 mn,mx; getAABB(uv,ts,mn,mx); hist = clamp(hist,mn,mx);
    float prevD  = texture2D(depthtex0, prevUV).r;
    float disoc  = 1.0 - smoothstep(0.0008, 0.006, abs(rawD-prevD));
    vec2 edgeDist= min(uv, 1.0-uv);
    float edgeMask = smoothstep(0.0, 0.06, min(edgeDist.x, edgeDist.y));
    float alpha  = TAA_BLEND*disoc*(inBounds?1.0:0.0)*edgeMask;
    float wC=1.0/(1.0+luma(curr)), wH=1.0/(1.0+luma(hist));
    vec3 blended=(curr*wC*(1.0-alpha)+hist*wH*alpha)/max(wC*(1.0-alpha)+wH*alpha,0.0001);

    blended = underwaterFog(blended, uv);

    float l     = luma(blended);
    vec3 bloom  = blended * smoothstep(BLOOM_THRESHOLD,BLOOM_THRESHOLD+0.20,l) * BLOOM_STRENGTH;

    gl_FragData[0] = vec4(blended, 1.0);
    gl_FragData[1] = vec4(blended, 1.0);
    gl_FragData[2] = vec4(bloom,   1.0);
}
