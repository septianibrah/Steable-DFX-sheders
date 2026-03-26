# Steable-DFX
**Iris Shaders · Fabric 1.21.1**

## Water System
- **Surface**: Crystal-clear transparent water (`WATER_ALPHA=0.06`)
- **Normals**: Kuda finite-difference wave algorithm (noisetex + 6 sine)
- **Reflections**: Screen-space raytrace with sky/sun fallback
- **Caustics**: Multi-frequency noise interference on underwater surfaces
- **Underwater**: Kuda fog overlay + caustic patterns
- **Water Entry/Exit**: Splash drip effect from top to bottom

## Shadow System
- **PCSS**: Percentage Closer Soft Shadows — hard near caster, soft far
- **Normal-offset bias**: No peter-panning, tight to geometry
- **16-sample Vogel disk** + **Interleaved Gradient Noise** rotation
- **4096×4096** shadow map, 16-chunk distance

## Lighting
- Torch: warm amber-orange 4000K boost with tight falloff
- **Held torch glow**: Torch lights up in hand without placing
- **Light fade in/out**: Smooth fade when placing/removing light blocks
- Night ambient: moonlight blue — not pitch black
- **Smooth Lightning**: Natural lightning flash with fade

## Post-Processing
- **God Rays**: 140-step screen-space radial blur
- **Bloom**: 2-pass dual-radius Gaussian blur
- **TAA**: Temporal Anti-Aliasing with AABB ghost clamp
- **Biome Fog**: Per-biome color (desert, jungle, ocean, taiga)
- **Wet Screen**: Rain droplet distortion + streaks + edge blur
- **Water Splash**: Drip effect when entering/exiting water

## Rain Effects
- Screen wetness with UV distortion
- Edge blur during rain
- Rain atmosphere: subtle darkening (not too faded)
- Water splash drip effect on water entry/exit

## Shader Options
`Options → Video Settings → Shader Options`
- Shadow Darkness, Softness
- Torch Brightness
- Bloom Strength
- God Ray Strength
- Biome Fog Density
