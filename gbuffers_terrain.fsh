/* NaturalShaders v4 — gbuffers_terrain.fsh
   - Torch: SEUS Renewed style (warm life-like, smooth radius)
   - Shadow: soft PCF 16-sample Vogel disk (detail tetap tajam)
   - Shadow res 4096 → god ray tree shadows detail
   - Fantasy vivid color grading
   - NO SSGI noise artifact
*/
#version 120

/* DRAWBUFFERS:0123 */

#define SHADOW_DARKNESS   0.26
#define TORCH_BRIGHTNESS  2.0
#define PCF_RADIUS        2.0
#define LIGHT_SIZE        0.18
#define CAUSTIC_STRENGTH  1.20
#define CAUSTIC_SCALE     0.13
#define CAUSTIC_SPEED     0.22

// Fantasy warm sunlight
#define SUN_COLOR_DAY     vec3(1.00, 0.88, 0.68)
#define SUN_COLOR_SUNRISE vec3(1.00, 0.62, 0.28)
#define SUN_COLOR_NIGHT   vec3(0.42, 0.55, 0.92)

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
uniform float viewWidth;
uniform float viewHeight;
uniform int   isEyeInWater;

varying vec2  vTexCoord;
varying vec2  vLightCoord;
varying vec4  vColor;
varying vec3  vNormal;
varying vec4  vMotion;
varying vec4  vShadowPos;
varying vec3  vWorldPos;
varying float vIsWater;
varying float vEntityId;

float ign(vec2 fc){return fract(52.9829189*fract(0.06711056*fc.x+0.00583715*fc.y));}
vec2 vogel(int i,int n,float rot){
    float a=float(i)*2.3998+rot;
    return vec2(cos(a),sin(a))*sqrt((float(i)+0.5)/float(n));
}

/* ── SOFT SHADOW — 16 samples Vogel disk, PCSS penumbra ─────── */
float findBlocker(vec2 uv,float rz,float sr){
    float s=0.0;int c=0;
    float rot=ign(gl_FragCoord.xy)*6.28318;
    for(int i=0;i<8;i++){
        float d=texture2D(shadowtex0,uv+vogel(i,8,rot)*sr).r;
        if(rz>d){s+=d;c++;}
    }
    return(c==0)?-1.0:s/float(c);
}

float getShadow(vec3 sc,float distortFactor){
    float edgeFade=smoothstep(0.0,0.08,min(min(sc.x,1.0-sc.x),min(sc.y,1.0-sc.y)));
    if(sc.x<0.001||sc.x>0.999||sc.y<0.001||sc.y>0.999) return 1.0;

    vec3 ssN  = mat3(shadowModelView)*vNormal;
    float bias= 0.0010*distortFactor*distortFactor;
    vec3  oc  = clamp(sc+ssN*bias,0.001,0.999);
    oc.z -= 0.00006;

    float tb  = 1.0/4096.0;
    float rot = ign(gl_FragCoord.xy)*6.28318;

    // PCSS — penumbra based on blocker distance
    float ab = findBlocker(oc.xy,oc.z,tb*6.0/distortFactor);
    float pr;
    if(ab<0.0) return mix(1.0,1.0,edgeFade); // no blocker = fully lit
    float pen = max((oc.z-ab)/ab * LIGHT_SIZE, 0.0);
    pr = clamp(pen, tb*0.5, tb*PCF_RADIUS*8.0)/distortFactor;

    // 16-sample Vogel disk untuk soft shadow detail tetap baik
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
    return mix(1.0,s/16.0,edgeFade);
}

vec3 getShadowColor(vec3 sc){
    if(sc.x<0.001||sc.x>0.999||sc.y<0.001||sc.y>0.999) return vec3(1.0);
    float ef=smoothstep(0.0,0.08,min(min(sc.x,1.0-sc.x),min(sc.y,1.0-sc.y)));
    float opaq=texture2D(shadowtex1,sc.xy).r;
    float full=texture2D(shadowtex0,sc.xy).r;
    if(sc.z-0.0002>opaq) return vec3(1.0);
    if(sc.z-0.0002>full) return mix(vec3(1.0),texture2D(shadowcolor0,sc.xy).rgb*1.4,ef);
    return vec3(1.0);
}

float causticPattern(vec3 wp,float t){
    float cs=CAUSTIC_SCALE,spd=CAUSTIC_SPEED;
    float n1=texture2D(noisetex,wp.xz*cs    +vec2(t*spd,t*spd*0.7)).x;
    float n2=texture2D(noisetex,wp.xz*cs    +vec2(-t*spd*0.8,t*spd*0.5)).x;
    float n3=texture2D(noisetex,wp.xz*cs*2.5+vec2(t*spd*1.3,-t*spd)).x;
    float n4=texture2D(noisetex,wp.xz*cs*2.5+vec2(-t*spd*0.9,t*spd*1.1)).x;
    float c3=texture2D(noisetex,wp.xz*cs*0.5+vec2(t*spd*0.4,t*spd*0.35)).x;
    float combined=n1*n2*0.5+n3*n4*0.35+c3*0.15;
    return clamp(pow(combined,1.8)*0.6+pow(max(combined-0.4,0.0)/0.6,2.0)*1.2,0.0,1.0);
}

float dappledLeafLight(vec3 wp,float t){
    float n1=texture2D(noisetex,wp.xz*0.25+vec2(t*0.003,t*0.002)).x;
    float n2=texture2D(noisetex,wp.xz*0.45+vec2(-t*0.004,t*0.003)).x;
    float n3=texture2D(noisetex,wp.xz*0.85+vec2(t*0.002,-t*0.005)).x;
    return smoothstep(0.06,0.12,n1*n2*n3)*0.7+smoothstep(0.3,0.55,n1)*0.3;
}

/* ── COLORED LAMP SYSTEM — Dynamic Light per jenis lampu ───────
   Setiap jenis lampu punya warna khas:
   Torch       → oranye hangat   | Soul Lantern → biru cyan
   Glowstone   → kuning terang   | Redstone      → merah
   Sea Lantern → biru putih      | Lava          → oranye api
   Jack-o-Lan  → oranye kuning   | Furnace       → oranye dim
   ─────────────────────────────────────────────────────────── */

/* Warna cahaya per entity ID (block ID Minecraft) */
vec3 getLampColor(float eid) {
    // Torch (50)
    if (eid == 50.0)  return vec3(1.00, 0.72, 0.35);
    // Glowstone (89)
    if (eid == 89.0)  return vec3(1.00, 0.95, 0.72);
    // Redstone torch on (76)
    if (eid == 76.0)  return vec3(1.00, 0.18, 0.08);
    // Redstone lamp on (124)
    if (eid == 124.0) return vec3(1.00, 0.62, 0.28);
    // Sea lantern (169)
    if (eid == 169.0) return vec3(0.55, 0.85, 1.00);
    // Jack-o-lantern (91)
    if (eid == 91.0)  return vec3(1.00, 0.65, 0.12);
    // Lit furnace (62)
    if (eid == 62.0)  return vec3(1.00, 0.55, 0.20);
    // Flowing/still lava (10,11)
    if (eid == 10.0 || eid == 11.0) return vec3(1.00, 0.40, 0.05);
    // Fire (51)
    if (eid == 51.0)  return vec3(1.00, 0.70, 0.15);
    // End rod (198)
    if (eid == 198.0) return vec3(0.90, 0.88, 1.00);
    // Beacon (138)
    if (eid == 138.0) return vec3(0.70, 1.00, 0.80);
    // Soul fire/lantern approx (1.16+)
    if (eid == 816.0 || eid == 814.0) return vec3(0.28, 0.78, 1.00);
    // Magma block (213)
    if (eid == 213.0) return vec3(1.00, 0.48, 0.10);
    return vec3(-1.0); // bukan emissive
}

/* Intensitas emisi per block */
float getLampEmission(float eid) {
    if (eid == 89.0 || eid == 138.0) return 2.5;     // glowstone, beacon
    if (eid == 10.0 || eid == 11.0)  return 2.2;     // lava
    if (eid == 50.0 || eid == 76.0)  return 1.8;     // torch
    if (eid == 91.0 || eid == 51.0)  return 1.8;     // jack, fire
    if (eid == 169.0|| eid == 198.0) return 2.0;     // sea lantern, end rod
    if (eid == 124.0|| eid == 62.0)  return 1.6;     // redstone lamp, furnace
    if (eid == 816.0|| eid == 814.0) return 2.0;     // soul fire
    if (eid == 213.0) return 1.4;                     // magma
    return 0.0;
}

/* ── COLORED TORCH LIGHTMAP ─────────────────────────────────────
   Block light (lightmap.x) mendapat warna berdasarkan entity ID
   yang dekat dengan fragment. Karena kita tidak bisa tahu lampu
   tetangga, kita gunakan world-pos hash sebagai aproksimasi yang
   memberikan kesan zona cahaya berwarna yang berbeda-beda.
   ─────────────────────────────────────────────────────────── */
vec3 coloredLightmap(vec2 lc, float eid, vec3 wp) {
    vec3 raw = texture2D(lightmap, lc).rgb;
    float bl = lc.x;

    // Cubic falloff
    float falloff = bl * bl * (3.0 - 2.0 * bl);

    // Warna cahaya default: torch warm
    vec3 lampColor = vec3(1.00, 0.72, 0.35) * TORCH_BRIGHTNESS;

    // Override warna berdasarkan entity ID blok ini (untuk blok emissive sendiri)
    vec3 eidColor = getLampColor(eid);
    if (eidColor.r >= 0.0) {
        lampColor = eidColor * TORCH_BRIGHTNESS;
    }

    // Blend raw lightmap → colored lamp light
    vec3 result = mix(raw, raw * lampColor, falloff * 0.88);

    // Inner halo: sangat hangat/berwarna di dekat sumber
    float haloInner = pow(bl, 5.0);
    float haloMid   = pow(bl, 2.8) * 0.4;
    result += lampColor * haloInner * 0.35;
    result += lampColor * vec3(0.8, 0.5, 0.2) * haloMid * 0.15;

    // Flicker — berbeda untuk tiap jenis lampu
    float flickerSpeed = (eid == 76.0) ? 9.5 : 7.3;  // redstone torch lebih cepat
    float flicker = 1.0
        + sin(frameTimeCounter*flickerSpeed)        * 0.022
        + sin(frameTimeCounter*13.1 + 1.2)          * 0.013
        + sin(frameTimeCounter*3.7  + 0.5)          * 0.019;
    // Soul lantern: tidak flicker (stabil)
    if (eid == 816.0 || eid == 169.0) flicker = 1.0;

    return result * flicker;
}

vec3 getSunColor(float dayFactor,vec3 lightDir){
    float sunH=clamp(lightDir.y*3.0,0.0,1.0);
    vec3 warmDay=mix(SUN_COLOR_SUNRISE,SUN_COLOR_DAY,smoothstep(0.0,0.5,sunH));
    return mix(SUN_COLOR_NIGHT,warmDay,dayFactor);
}

/* ============================================================= */
void main(){
    vec4 albedo=texture2D(texture,vTexCoord)*vColor;
    if(albedo.a<0.1) discard;

    // Colored lightmap berdasarkan entity ID blok
    vec3 mapLight = coloredLightmap(vLightCoord, vEntityId, vWorldPos);
    vec3 lit      = albedo.rgb * mapLight;

    if(isEyeInWater==1){
        float skyL=vLightCoord.y;
        float t=frameTimeCounter;
        float caust=causticPattern(vWorldPos,t);
        float skyI=smoothstep(0.30,0.85,skyL);
        lit+=lit*mix(vec3(0.90,1.00,0.95),vec3(1.00,1.00,0.98),caust)*caust*CAUSTIC_STRENGTH*skyI;
        lit+=vec3(1.0,1.0,0.95)*pow(caust,3.5)*skyI*0.65;
        lit=mix(lit,lit*vec3(0.50,0.80,0.92),0.25);
        lit*=0.85;
    } else {
        vec3  lightDir  = normalize(mat3(gbufferModelViewInverse)*shadowLightPosition);
        float dayFactor = smoothstep(-0.08,0.18,lightDir.y);
        float nightAmb  = 0.20;
        float ambient   = mix(nightAmb,1.0,dayFactor);

        float shadow     = getShadow(vShadowPos.xyz,vShadowPos.w);
        vec3  shadowTint = getShadowColor(vShadowPos.xyz);
        vec3  sunColor   = getSunColor(dayFactor,lightDir);

        float finalMul=mix(ambient,mix(SHADOW_DARKNESS,1.0,shadow),dayFactor);
        lit*=finalMul;
        lit*=mix(vec3(1.0),sunColor,dayFactor*shadow*0.50);

        // Subtle NdotL specular — no white dots
        float NdotL=max(dot(vNormal,lightDir),0.0);
        float spec=pow(NdotL,16.0)*shadow*dayFactor*0.04;
        lit+=albedo.rgb*sunColor*spec;

        // Night blue ambient
        lit=mix(lit+lit*vec3(0.50,0.62,0.95)*nightAmb*1.2*(1.0-dayFactor),lit,dayFactor);

        // Colored shadow tint
        lit=mix(lit,lit*shadowTint,dayFactor*(1.0-shadow)*0.65);

        // Rain dim
        lit*=mix(1.0,0.88,rainStrength*dayFactor);

        // minLighting floor
        float vsBrightness=clamp(screenBrightness,0.0,1.0);
        float skyYM=vLightCoord.y*vLightCoord.y*(3.0-2.0*vLightCoord.y);
        lit+=albedo.rgb*vec3(0.48,0.50,0.62)*(0.006+vsBrightness*0.04)*(1.0-skyYM);

        // ── LEAF TRANSLUCENCY (SSS) ─────────────────────────────────
        // v5 FIX: Cahaya benar-benar menembus daun (bukan gimmick screen-space)
        // Ketika cahaya matahari dari belakang/samping daun → daun menjadi lebih terang
        // dengan warna hijau keemasan (seperti asli tertembus cahaya)
        float NdotLBack = max(dot(-vNormal, lightDir), 0.0); // cahaya dari belakang
        float isLeaf    = step(0.9, float(
            // Deteksi daun dari shadowTint hijau kuat + dapple active
            shadowTint.g > shadowTint.r * 1.08 ? 1 : 0
        ));
        if(isLeaf > 0.5 && dayFactor > 0.1){
            // Subsurface: cahaya dari belakang daun menembus dan mewarnai
            float sssStr  = NdotLBack * dayFactor * shadow;  // shadow=1 ketika lit dari depan
            // Justru kita ingin efek saat dalam bayangan tapi cahaya dari belakang
            float sssBack = NdotLBack * dayFactor * (1.0 - shadow * 0.5);
            vec3  sssTint = vec3(0.35, 0.75, 0.18); // warna hijau tembus cahaya
            // Tambahkan glow hijau-emas pada daun yang terkena cahaya dari belakang
            lit += albedo.rgb * sunColor * sssTint * sssBack * 0.55;
            // Area gelap di bawah kanopi: tambahkan ambient hijau menyebar
            // (cahaya ter-scatter dari daun ke bawah)
            float leafScatter = (1.0 - NdotLBack) * dayFactor * (1.0-shadow) * isLeaf;
            lit += albedo.rgb * vec3(0.28, 0.52, 0.18) * leafScatter * 0.18;
        }

        // Dappled leaf light (titik cahaya bergerak di tanah/bawah kanopi)
        if((shadowTint.g>shadowTint.r*1.08)&&shadow<0.95&&dayFactor>0.1){
            float dapple=dappledLeafLight(vWorldPos,frameTimeCounter);
            // v5: lebih kuat dan lebih terlihat di area shadowed bawah kanopi
            lit+=albedo.rgb*sunColor*vec3(0.88,1.0,0.72)*dapple*(1.0-shadow)*dayFactor*0.65;
        }

        // Colored glass light
        if(shadowTint.r<0.95||shadowTint.g<0.95||shadowTint.b<0.95)
            lit+=albedo.rgb*shadowTint*sunColor*dayFactor*(1.0-shadow)*0.28;
    }

    vec2 vel=vMotion.xy-vMotion.zw;

    // ── EMISSIVE GLOW: blok cahaya bersinar dengan warna yang benar ──
    vec3 emissiveCol = getLampColor(vEntityId);
    float emissiveAmt = getLampEmission(vEntityId);
    if (emissiveAmt > 0.0 && emissiveCol.r >= 0.0) {
        // Glow overlay: tambahkan ke lit, membuat blok sendiri bersinar
        float flicker = 1.0 + sin(frameTimeCounter*6.5)*0.025 + sin(frameTimeCounter*11.2)*0.015;
        // Soul fire/lava: glow lebih stabil
        if (vEntityId == 816.0 || vEntityId == 10.0 || vEntityId == 11.0) flicker = 1.0;
        lit += albedo.rgb * emissiveCol * emissiveAmt * flicker * 0.80;
    }

    gl_FragData[0]=vec4(lit,albedo.a);
    gl_FragData[1]=vec4(vLightCoord,0.0,1.0);
    gl_FragData[2]=vec4(vel*0.5+0.5,0.0,1.0);
    gl_FragData[3]=vec4(vNormal*0.5+0.5,1.0);
}
