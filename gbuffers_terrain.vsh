/* NaturalShaders v4.2 — gbuffers_terrain.vsh
   - Foliage swaying: natural, stabil, tidak bug
   - Rain: angin directional saat hujan & petir
   - Thunder: tanaman miring ke bawah angin (dramatic)
   - Entity ID diteruskan ke fragment shader untuk colored lights
*/
#version 120

#define SHADOW_MAP_BIAS 0.85
#define WAVE_SPEED      1.0

uniform mat4  gbufferModelViewInverse;
uniform mat4  gbufferPreviousModelView;
uniform mat4  gbufferPreviousProjection;
uniform mat4  shadowModelView;
uniform mat4  shadowProjection;
uniform vec3  cameraPosition;
uniform vec3  previousCameraPosition;
uniform float frameTimeCounter;
uniform float rainStrength;
uniform float thunderStrength;

attribute vec4 mc_Entity;
attribute vec4 mc_midTexCoord;

varying vec2  vTexCoord;
varying vec2  vLightCoord;
varying vec4  vColor;
varying vec3  vNormal;
varying vec4  vMotion;
varying vec4  vShadowPos;
varying vec3  vWorldPos;
varying float vIsWater;
varying float vEntityId;

/* ── Hash per tanaman — HANYA xz agar stabil di tanaman tinggi ─
   Jika menggunakan xyz, vertex atas dan bawah mungkin dapat hash
   berbeda → tanaman "merobekan" / bug visual.
   ─────────────────────────────────────────────────────────────── */
float hashPos(vec3 p) {
    // Snap ke blok terdekat, hanya xz — stabil untuk semua tinggi
    vec2 ip = floor(p.xz);
    return fract(sin(dot(ip, vec2(127.1, 311.7))) * 43758.5453);
}

/* ── Wind direction: arah angin konsisten (sedikit diagonal) ─── */
vec2 windDir() {
    // Arah angin statis tapi diagonal agar natural
    return normalize(vec2(1.0, 0.62));
}

/* ── Foliage swaying — natural multi-frequency ──────────────── */
vec2 plantSway(vec3 wp, float t, float rainFactor, float thunder) {
    float h  = hashPos(wp);
    float h2 = fract(h * 17.3 + 0.3);
    float h3 = fract(h * 31.7 + 0.6);

    // Kecepatan naik saat hujan, jauh lebih kencang saat petir
    float windMult = 1.0 + rainFactor * 1.8 + thunder * 4.5;
    float t2 = t * windMult;

    // Frekuensi unik per tanaman — range lebih ketat agar lebih smooth
    float freqX = 0.50 + h  * 0.55;
    float freqZ = 0.50 + h2 * 0.55;

    float phaseX  = h  * 6.2832;
    float phaseZ  = h2 * 6.2832;
    float phaseX2 = h3 * 6.2832;

    // Amplitudo normal kecil, lebih besar saat hujan/petir
    float amp = mix(0.038, 0.085, rainFactor) + thunder * 0.12;

    // Primary sway + harmonic untuk naturalness
    float wx = sin(t2*freqX + phaseX)*amp
             + sin(t2*freqX*1.87 + phaseX2)*amp*0.18;
    float wz = sin(t2*freqZ + phaseZ)*amp
             + sin(t2*freqZ*1.53 + phaseX )*amp*0.14;

    // ── Directional lean: saat hujan/petir tanaman miring ke arah angin
    vec2 wd = windDir();
    // Lean = fungsi waktu lambat — tanaman MIRING bukan hanya bergoyang
    float leanAmount = rainFactor * 0.055 + thunder * 0.18;
    // Saat petir: gust yang mendadak kuat lalu pelan
    float gustPhase = sin(t * (0.8 + h * 0.4) + h2 * 3.14);
    leanAmount *= (0.6 + gustPhase * 0.4);

    wx += wd.x * leanAmount;
    wz += wd.y * leanAmount;

    return vec2(wx, wz);
}

float waterWave(vec3 wp, float t) {
    return (sin(wp.x*1.1+t*1.6)*sin(wp.z*1.3+t)
          + sin((wp.x+wp.z)*0.85+t*1.3)*0.45)*0.028;
}

void main() {
    vTexCoord   = (gl_TextureMatrix[0]*gl_MultiTexCoord0).xy;
    vLightCoord = (gl_TextureMatrix[1]*gl_MultiTexCoord1).xy;
    vColor      = gl_Color;
    vNormal     = normalize(gl_NormalMatrix*gl_Normal);
    vEntityId   = mc_Entity.x;

    float eid    = mc_Entity.x;
    bool isPlant = (eid==6.0||eid==31.0||eid==37.0||eid==38.0||eid==39.0||eid==40.0
                 ||eid==59.0||eid==83.0||eid==106.0||eid==111.0||eid==175.0
                 ||eid==18.0||eid==161.0);
    vIsWater     = (eid==8.0||eid==9.0) ? 1.0 : 0.0;

    vec4 viewPos   = gl_ModelViewMatrix*gl_Vertex;
    vec4 worldPos4 = gbufferModelViewInverse*viewPos;
    vWorldPos      = worldPos4.xyz + cameraPosition;

    vec4 animPos = gl_Vertex;
    float t      = frameTimeCounter*WAVE_SPEED;

    if (isPlant && gl_MultiTexCoord0.t < mc_midTexCoord.t) {
        // Hanya vertex bagian atas yang bergerak (bagian bawah terkunci tanah)
        vec2 w = plantSway(vWorldPos, t, rainStrength, thunderStrength);
        animPos.x += w.x;
        animPos.z += w.y;

        // Daun pohon: tambah sedikit gerak vertikal
        if (eid==18.0||eid==161.0) {
            float h = hashPos(vWorldPos);
            float vertAmp = 0.015 + rainStrength * 0.020 + thunderStrength * 0.035;
            animPos.y += sin(t*(0.6+h*0.5) + h*6.2832)*vertAmp;
        }

        // Thunder: lean lebih ekstrem ke bawah arah angin (dramatis)
        if (thunderStrength > 0.1) {
            float h = hashPos(vWorldPos);
            float gust = sin(t * 5.5 + h * 3.14) * thunderStrength * 0.5;
            animPos.y -= thunderStrength * (0.06 + gust * 0.04);
        }
    }
    if (vIsWater > 0.5) animPos.y += waterWave(vWorldPos, t);

    vec4 currClip = gl_ProjectionMatrix*gl_ModelViewMatrix*animPos;
    gl_Position   = currClip;

    vec3 prevWorld = vWorldPos - cameraPosition + previousCameraPosition;
    vec4 prevClip  = gbufferPreviousProjection*gbufferPreviousModelView*vec4(prevWorld,1.0);
    vMotion = vec4((currClip.xy/currClip.w)*0.5+0.5, (prevClip.xy/prevClip.w)*0.5+0.5);

    vec4 shadowView = shadowModelView*worldPos4;
    vec4 shadowClip = shadowProjection*shadowView;
    float posLen    = length(shadowClip.xy);
    float distort   = (1.0-SHADOW_MAP_BIAS)+posLen*SHADOW_MAP_BIAS;
    shadowClip.xy  /= distort;
    vShadowPos      = vec4(shadowClip.xyz*0.5+0.5, distort);
}
