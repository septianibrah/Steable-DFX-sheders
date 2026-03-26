/* NaturalShaders v5 — gbuffers_water.fsh
   WATER WAVES: Ported from SEUS PTGI E12 (GetWaves + GetWavesNormal)
   UNDERWATER  : Caustics + light shafts dari NaturalShaders
   SHADOW/LIGHT: PCF PCSS sistem NaturalShaders
   Hanya bagian air & underwater — tidak ada perubahan lain.
*/
#version 120

/* DRAWBUFFERS:01236 */

#define SHADOW_DARKNESS  0.26
#define TORCH_BRIGHTNESS 2.0
#define PCF_RADIUS       2.0
#define LIGHT_SIZE       0.18

/* ── SEUS PTGI E12 Water Parameters ────────────────────────── */
#define WATER_WAVE_HEIGHT   0.20
#define WATER_ALPHA         0.06
#define WATER_BRIGHTNESS    0.85
/* Warna air jernih biru-putih kristal */
#define WATER_R  0.48
#define WATER_G  0.78
#define WATER_B  1.00

#define CAUSTIC_STRENGTH 1.40
#define CAUSTIC_SCALE    0.12
#define CAUSTIC_SPEED    0.20

uniform sampler2D texture;
uniform sampler2D lightmap;
uniform sampler2D noisetex;
uniform sampler2D shadowtex0;
uniform sampler2D shadowtex1;
uniform sampler2D shadowcolor0;

uniform vec3  shadowLightPosition;
uniform mat4  gbufferModelViewInverse;
uniform mat4  gbufferModelView;
uniform mat4  shadowModelView;
uniform float rainStrength;
uniform float frameTimeCounter;
uniform float screenBrightness;
uniform int   isEyeInWater;

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

/* ═══════════════════════════════════════════════════════════════
   SEUS PTGI E12 — WAVE SYSTEM (ported to GLSL 120)
   Semua fungsi di bawah ini berasal dari SEUS PTGI E12
   ═══════════════════════════════════════════════════════════════ */

/* textureSmooth: bicubic smooth sampling (dari SEUS gbuffers_water.fsh) */
vec4 textureSmooth(sampler2D tex, vec2 coord) {
    vec2 res = vec2(64.0, 64.0);
    coord *= res;
    coord += 0.5;
    vec2 whole = floor(coord);
    vec2 part  = fract(coord);
    part.x = part.x * part.x * (3.0 - 2.0 * part.x);
    part.y = part.y * part.y * (3.0 - 2.0 * part.y);
    coord = whole + part;
    coord -= 0.5;
    coord /= res;
    return texture2D(tex, coord);
}

/* AlmostIdentity: memperhalus wave shape (dari SEUS) */
float AlmostIdentity(float x, float m, float n) {
    if (x > m) return x;
    float a = 2.0 * n - m;
    float b = 2.0 * m - 3.0 * n;
    float t = x / m;
    return (a * t + b) * t * t + n;
}

/* GetWaves: multi-layer ocean wave height (dari SEUS PTGI E12) */
float GetWaves(vec3 position) {
    float speed = 0.9;
    if (vIce > 0.9) speed = 0.0;

    vec2 p = position.xz / 5.0;
    p.xy -= position.y / 10.0;
    p.x = -p.x;

    /* Animasi menggunakan frameTimeCounter langsung */
    float t = frameTimeCounter;
    p.x += (t / 40.0) * speed;
    p.y -= (t / 40.0) * speed;

    float weight, weights, allwaves, wave;

    /* Layer 1 */
    weight = 1.0; weights = weight;
    wave = textureSmooth(noisetex, (p * vec2(2.0, 1.2)) + vec2(0.0, p.x * 2.1)).x;
    allwaves = wave * 0.5;
    p /= 2.1;
    p.y -= (t / 20.0) * speed;
    p.x -= (t / 30.0) * speed;

    /* Layer 2 */
    weight = 2.1; weights += weight;
    wave = textureSmooth(noisetex, (p * vec2(2.0, 1.4)) + vec2(0.0, -p.x * 2.1)).x;
    wave *= weight;
    allwaves += wave;
    p /= 1.5;
    p.x += (t / 20.0) * speed;

    /* Layer 3 */
    weight = 17.25; weights += weight;
    wave = textureSmooth(noisetex, (p * vec2(1.0, 0.75)) + vec2(0.0, p.x * 1.1)).x;
    wave *= weight;
    allwaves += wave;
    p /= 1.5;
    p.x -= (t / 55.0) * speed;

    /* Layer 4 */
    weight = 15.25; weights += weight;
    wave = textureSmooth(noisetex, (p * vec2(1.0, 0.75)) + vec2(0.0, -p.x * 1.7)).x;
    wave *= weight;
    allwaves += wave;
    p /= 1.9;
    p.x += (t / 155.0) * speed;

    /* Layer 5: abs wave — puncak tajam (crest) */
    weight = 29.25; weights += weight;
    wave = abs(textureSmooth(noisetex, (p * vec2(1.0, 0.8)) + vec2(0.0, -p.x * 1.7)).x * 2.0 - 1.0);
    wave = 1.0 - AlmostIdentity(wave, 0.2, 0.1);
    wave *= weight;
    allwaves += wave;
    p /= 2.0;
    p.x += (t / 155.0) * speed;

    /* Layer 6: abs wave — detil micro-ripple */
    weight = 15.25; weights += weight;
    wave = abs(textureSmooth(noisetex, (p * vec2(1.0, 0.8)) + vec2(0.0, p.x * 1.7)).x * 2.0 - 1.0);
    wave = 1.0 - AlmostIdentity(wave, 0.2, 0.1);
    wave *= weight;
    allwaves += wave;

    /* Tambahan: rain ripple dari SEUS approach */
    if (rainStrength > 0.05) {
        float rn = textureSmooth(noisetex, position.xz * 0.08 + vec2(t * 0.04, 0.0)).x;
        allwaves += rn * rainStrength * weights * 0.04;
    }

    allwaves /= weights;
    return allwaves;
}

/* GetWavesNormal: hitung normal dari gradient wave heights (dari SEUS) */
vec3 GetWavesNormal(vec3 worldPos) {
    const float sampleDist = 4.0;
    float dP = 0.005 * sampleDist;

    vec3 pos = worldPos - vec3(dP, 0.0, dP) * sampleDist;

    float hCenter = GetWaves(pos);
    float hLeft   = GetWaves(pos + vec3(0.01 * sampleDist, 0.0, 0.0));
    float hUp     = GetWaves(pos + vec3(0.0, 0.0, 0.01 * sampleDist));

    vec3 wavesNormal;
    wavesNormal.r = hCenter - hLeft;
    wavesNormal.g = hCenter - hUp;
    wavesNormal.r *= 20.0 * WATER_WAVE_HEIGHT / sampleDist;
    wavesNormal.g *= 20.0 * WATER_WAVE_HEIGHT / sampleDist;
    wavesNormal.b = 1.0;
    wavesNormal = normalize(wavesNormal);

    /* Transform TBN world → view space */
    mat3 tbnMatrix = mat3(vTangent.x, vBinormal.x, vNormal.x,
                          vTangent.y, vBinormal.y, vNormal.y,
                          vTangent.z, vBinormal.z, vNormal.z);
    return normalize(wavesNormal * tbnMatrix);
}

/* ═══════════════════════════════════════════════════════════════
   SHADOW & LIGHTING (NaturalShaders sistem)
   ═══════════════════════════════════════════════════════════════ */

float ign(vec2 fc){ return fract(52.9829189 * fract(0.06711056*fc.x + 0.00583715*fc.y)); }
vec2 vogel(int i, int n, float r){ float a=float(i)*2.3998+r; return vec2(cos(a),sin(a))*sqrt((float(i)+0.5)/float(n)); }

float findBlocker(vec2 uv, float rz, float sr){
    float s=0.0; int c=0; float rot=ign(gl_FragCoord.xy)*6.28318;
    for(int i=0;i<8;i++){ float d=texture2D(shadowtex0,uv+vogel(i,8,rot)*sr).r; if(rz>d){s+=d;c++;} }
    return(c==0)?-1.0:s/float(c);
}

float getShadow(vec3 sc, float dist, vec3 n){
    if(sc.x<0.001||sc.x>0.999||sc.y<0.001||sc.y>0.999) return 1.0;
    float ef=smoothstep(0.0,0.08,min(min(sc.x,1.0-sc.x),min(sc.y,1.0-sc.y)));
    vec3 oc=clamp(sc+mat3(shadowModelView)*n*0.0012*dist*dist,0.001,0.999); oc.z-=0.00006;
    float tb=1.0/4096.0, rot=ign(gl_FragCoord.xy)*6.28318;
    float ab=findBlocker(oc.xy,oc.z,tb*6.0/dist);
    if(ab<0.0) return 1.0;
    float pen=max((oc.z-ab)/ab*LIGHT_SIZE,0.0);
    float pr=clamp(pen,tb*0.5,tb*PCF_RADIUS*8.0)/dist;
    float s=0.0;
    for(int i=0;i<16;i++) s+=float(oc.z<texture2D(shadowtex0,oc.xy+vogel(i,16,rot)*pr).r);
    return mix(1.0,s/16.0,ef);
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

/* ── Caustics untuk bawah air ── */
float causticPattern(vec3 wp, float t){
    float cs=CAUSTIC_SCALE, spd=CAUSTIC_SPEED;
    float n1=texture2D(noisetex,wp.xz*cs+vec2(t*spd,t*spd*0.7)).x;
    float n2=texture2D(noisetex,wp.xz*cs+vec2(-t*spd*0.8,t*spd*0.5)).x;
    float n3=texture2D(noisetex,wp.xz*cs*2.5+vec2(t*spd*1.3,-t*spd)).x;
    float n4=texture2D(noisetex,wp.xz*cs*2.5+vec2(-t*spd*0.9,t*spd*1.1)).x;
    float c3=texture2D(noisetex,wp.xz*cs*0.5+vec2(t*spd*0.4,t*spd*0.35)).x;
    float combined=n1*n2*0.50+n3*n4*0.35+c3*0.15;
    return clamp(pow(combined,1.6)*0.55+pow(max(combined-0.35,0.0)/0.65,1.8)*1.40,0.0,1.0);
}

float underwaterLightShaft(vec3 wp, float t){
    vec3 ld=normalize(mat3(gbufferModelViewInverse)*shadowLightPosition);
    float dayF=smoothstep(-0.08,0.18,ld.y); if(dayF<0.05) return 0.0;
    float sb=texture2D(noisetex,wp.xz*0.04+vec2(t*0.01,t*0.008)).x;
    float sf=texture2D(noisetex,wp.xz*0.08+vec2(-t*0.015,t*0.012)).x;
    float shaft=pow(sb*sf,1.5)*2.0;
    shaft*=smoothstep(0.2,0.9,vLightCoord.y)*dayF;
    return clamp(shaft,0.0,1.0);
}

void main(){
    vec4 albedo=texture2D(texture,vTexCoord)*vColor;
    if(albedo.a<0.02) discard;

    vec3 mapLight = torchLightmap(vLightCoord);
    vec2 vel = vMotion.xy - vMotion.zw;

    vec3 lightDir=normalize(mat3(gbufferModelViewInverse)*shadowLightPosition);
    float day=smoothstep(-0.08,0.18,lightDir.y);
    float amb=mix(0.28,1.0,day);

    bool isWaterIce    = (vWater>0.9 || vIce>0.9);
    bool isGlass       = (vStainedGlass>0.9 || vStainedGlassPane>0.9);

    /* ── STAINED GLASS ── */
    if(isGlass){
        vec3 lit=albedo.rgb*mapLight;
        float sh=getShadow(vShadowPos.xyz,vShadowPos.w,vNormal);
        lit*=mix(amb,mix(SHADOW_DARKNESS,1.0,sh),day);
        lit+=albedo.rgb*sh*day*0.35*vec3(1.0,0.95,0.85);
        gl_FragData[0]=vec4(lit,albedo.a*0.55);
        gl_FragData[1]=vec4(vLightCoord,0.0,1.0);
        gl_FragData[2]=vec4(vel*0.5+0.5,0.0,1.0);
        gl_FragData[3]=vec4(vNormal*0.5+0.5,1.0);
        gl_FragData[4]=vec4(albedo.rgb,1.0);
        return;
    }

    /* ── UNDERWATER FRAGMENTS ── */
    if(vUnderwater>0.5){
        vec3 lit=albedo.rgb*mapLight;
        if(isWaterIce){
            lit=vec3(WATER_R,WATER_G,WATER_B)*0.12*mapLight;
        } else {
            float t=frameTimeCounter; float skyL=vLightCoord.y;
            float caust=causticPattern(vWorldPos.xyz,t);
            float skyI=smoothstep(0.25,0.80,skyL)*day;
            lit+=lit*mix(vec3(0.92,1.00,0.95),vec3(1.00,1.00,0.98),caust)*caust*CAUSTIC_STRENGTH*skyI;
            lit+=vec3(1.00,1.00,0.96)*pow(caust,3.0)*skyI*0.90;
            lit+=vec3(0.85,0.95,1.00)*underwaterLightShaft(vWorldPos.xyz,t)*0.35*day;
        }
        lit=mix(lit,lit*vec3(0.55,0.82,1.00),0.18);
        lit*=0.94;
        /* Normal: SEUS waves untuk bawah permukaan air juga */
        vec3 wn = isWaterIce ? GetWavesNormal(vWorldPos.xyz) : vNormal;
        gl_FragData[0]=vec4(lit,albedo.a);
        gl_FragData[1]=vec4(vLightCoord,0.0,1.0);
        gl_FragData[2]=vec4(vel*0.5+0.5,0.0,1.0);
        gl_FragData[3]=vec4(wn*0.5+0.5,1.0);
        gl_FragData[4]=vec4(0.0,0.0,0.0,isWaterIce?0.5:0.0);
        return;
    }

    /* ── WATER/ICE SURFACE — SEUS normal + NaturalShaders lighting ── */
    vec3 wn = isWaterIce ? GetWavesNormal(vWorldPos.xyz) : vNormal;
    vec3 lit; float alpha;

    if(isWaterIce){
        /* Warna air murni biru-putih stabil — tidak terpengaruh vColor Minecraft */
        vec3 pureWater = vec3(WATER_R, WATER_G, WATER_B);
        lit = pureWater * mapLight * WATER_BRIGHTNESS;
        float sh=getShadow(vShadowPos.xyz,vShadowPos.w,wn);
        lit*=mix(amb,mix(SHADOW_DARKNESS,1.0,sh),day);
        lit*=mix(1.0,0.82,rainStrength*day);
        alpha=WATER_ALPHA;
    } else {
        lit=albedo.rgb*mapLight;
        float sh=getShadow(vShadowPos.xyz,vShadowPos.w,wn);
        lit*=mix(amb,mix(SHADOW_DARKNESS,1.0,sh),day);
        alpha=albedo.a;
    }

    gl_FragData[0]=vec4(lit,alpha);
    gl_FragData[1]=vec4(vLightCoord,0.0,1.0);
    gl_FragData[2]=vec4(vel*0.5+0.5,0.0,1.0);
    gl_FragData[3]=vec4(wn*0.5+0.5,1.0);
    gl_FragData[4]=vec4(0.0,0.0,0.0,isWaterIce?0.5:0.0);
}
