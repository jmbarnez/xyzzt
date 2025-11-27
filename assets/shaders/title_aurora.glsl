// Aurora effect shader for title text
// Creates a flowing, colorful aurora effect with green and purple tones

extern number time;

const float PI = 3.14159265359;

float hash(vec2 p) {
    p = fract(p * vec2(127.1, 311.7));
    p += dot(p, p + 34.123);
    return fract(p.x * p.y);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);

    float a = hash(i);
    float b = hash(i + vec2(1.0, 0.0));
    float c = hash(i + vec2(0.0, 1.0));
    float d = hash(i + vec2(1.0, 1.0));

    vec2 u = f * f * (3.0 - 2.0 * f);

    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float fbm(vec2 p) {
    float v = 0.0;
    float a = 0.5;

    for (int i = 0; i < 4; i++) {
        v += a * noise(p);
        p *= 2.1;
        a *= 0.5;
    }
    return v;
}

vec3 gradeAurora(vec3 col) {
    col = clamp(col, 0.0, 1.0);
    float luma = dot(col, vec3(0.299, 0.587, 0.114));
    col = mix(vec3(luma), col, 1.20);
    col = pow(col, vec3(0.9));
    return col;
}

vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 pixel_coords) {
    vec4 tex = Texel(texture, texture_coords) * color;
    if (tex.a <= 0.001) return tex;

    // Normalized coordinates for stable, resolution-independent motion
    vec2 uv = pixel_coords * 0.0025;
    float t  = time * 0.4;

    // Base scrolling bands
    float bandPhase = uv.y * 4.0 + t * 1.7;
    float band      = sin(bandPhase) * 0.5 + 0.5;

    // Flowing distortion using fbm
    vec2 flowDir = vec2(0.35, 0.9);
    vec2 warpUV  = uv + flowDir * t * 0.15;
    float warp1  = fbm(warpUV * 1.6 + vec2(0.0, t * 0.3));
    float warp2  = fbm(warpUV * 3.4 + vec2(t * 0.17, -t * 0.12));
    float warp   = mix(warp1, warp2, 0.6);

    // Vertical wisps, slightly offset per x to avoid repetition
    float wispMask   = smoothstep(0.15, 0.85, warp);
    float wispDetail = fbm(vec2(uv.y * 2.4 - t * 0.5, uv.x * 0.9 + t * 0.25));
    float wisps      = smoothstep(0.3, 0.95, wispDetail * wispMask);

    // Combine motion + bands into intensity
    float baseIntensity = band * 0.35 + warp * 0.25 + wisps * 0.30;

    // Mild temporal pulsing
    float slowPulse   = 0.05 * sin(t * 0.8 + 1.3) + 0.95;
    float ripplePulse = 0.03 * sin(t * 2.5 + warp * 8.0) + 0.97;
    float intensity   = clamp(baseIntensity * slowPulse * ripplePulse, 0.0, 1.0);

    // Add a faster-varying hue modulation so colors change more often
    float hueMod = 0.5 + 0.5 * sin(t * 1.5 + uv.x * 2.5 + uv.y * 1.5);

    // Core palette: cool base with teal, blue, lavender and pink highlights
    vec3 baseColor       = vec3(0.02, 0.18, 0.32);
    vec3 tealHighlight   = vec3(0.18, 0.85, 0.80);
    vec3 blueHighlight   = vec3(0.30, 0.65, 0.98);
    vec3 lavenderHighlight = vec3(0.78, 0.62, 0.96);
    vec3 pinkHighlight   = vec3(0.98, 0.55, 0.78);

    float palettePhase   = fract(0.5 * hueMod + 0.5 * sin(t * 0.3 + uv.x * 0.4 + uv.y * 0.2));
    float coolMixFactor  = smoothstep(0.0, 0.5, palettePhase);
    float warmMixFactor  = smoothstep(0.3, 1.0, palettePhase);
    vec3 coolMix         = mix(tealHighlight, blueHighlight, coolMixFactor);
    vec3 warmMixColors   = mix(lavenderHighlight, pinkHighlight, warmMixFactor);
    vec3 dynamicHighlight = mix(coolMix, warmMixColors, palettePhase);

    vec3 aurora          = mix(baseColor, dynamicHighlight, intensity);

    // Purple / magenta accents near bright areas, with faster variation
    float phaseShift   = t * 0.9 + uv.x * 1.8 + uv.y * 1.1;
    float colorLFO     = 0.5 + 0.5 * sin(phaseShift);
    float brightMask   = smoothstep(0.35, 0.9, intensity);

    vec3 purpleTint    = vec3(0.65, 0.40, 0.95); // violet / purple
    vec3 pinkTint      = vec3(0.98, 0.55, 0.78);
    vec3 yellowTint    = vec3(1.00, 0.90, 0.45);

    vec3 purplePink    = mix(purpleTint, pinkTint, colorLFO);
    float yellowLFO    = 0.5 + 0.5 * sin(t * 0.6 + warp * 3.0);
    vec3 accentTint    = mix(purplePink, yellowTint, 0.3 * yellowLFO);

    float accentAmount = brightMask * 0.25;
    aurora = mix(aurora, accentTint, accentAmount);

    // Subtle top–bottom gradient so the top is brighter
    float verticalFade = smoothstep(-0.5, 0.8, uv.y + warp * 0.15);
    aurora *= mix(0.85, 1.15, verticalFade);

    // Final grading
    aurora = gradeAurora(aurora);

    // Preserve readability: modulate but do not completely darken
    float baseBrightness  = 0.75;
    float effectStrength  = 0.40;
    vec3 litAurora        = mix(vec3(baseBrightness), aurora, effectStrength);

    return tex * vec4(litAurora, 1.0);
}
