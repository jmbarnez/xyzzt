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
    float baseIntensity = band * 0.55 + warp * 0.30 + wisps * 0.40;

    // Mild temporal pulsing
    float slowPulse   = 0.14 * sin(t * 0.8 + 1.3) + 0.86;
    float ripplePulse = 0.08 * sin(t * 2.5 + warp * 8.0) + 0.96;
    float intensity   = clamp(baseIntensity * slowPulse * ripplePulse, 0.0, 1.0);

    // Add a faster-varying hue modulation so colors change more often
    float hueMod = 0.5 + 0.5 * sin(t * 3.0 + uv.x * 4.0 + uv.y * 2.0);

    // Core palette: deep green -> bright teal, modulated by hueMod
    vec3 baseColor      = vec3(0.02, 0.35, 0.20);
    vec3 highlightColor = vec3(0.24, 0.95, 0.75);
    vec3 altHighlight   = vec3(0.30, 0.90, 0.35);
    vec3 dynamicHighlight = mix(highlightColor, altHighlight, hueMod);
    vec3 aurora         = mix(baseColor, dynamicHighlight, intensity);

    // Purple / magenta accents near bright areas, with faster variation
    float phaseShift   = t * 1.1 + uv.x * 2.4 + uv.y * 1.3;
    float colorLFO     = 0.5 + 0.5 * sin(phaseShift);
    float purpleAmount = smoothstep(0.45, 1.0, intensity) * (0.22 + 0.48 * colorLFO);
    vec3 purpleTint    = vec3(0.55, 0.28, 0.74);

    // Extra warm accent that alternates quickly with purple
    float warmPhase    = t * 2.2 + warp * 5.0;
    float warmMix      = 0.5 + 0.5 * sin(warmPhase);
    vec3 warmTint      = vec3(0.90, 0.65, 0.25);
    vec3 accentTint    = mix(purpleTint, warmTint, warmMix);

    aurora = mix(aurora, accentTint, purpleAmount);

    // Subtle top–bottom gradient so the top is brighter
    float verticalFade = smoothstep(-0.5, 0.8, uv.y + warp * 0.15);
    aurora *= mix(0.7, 1.3, verticalFade);

    // Final grading
    aurora = gradeAurora(aurora);

    // Preserve readability: modulate but do not completely darken
    float baseBrightness  = 0.55;
    float effectStrength  = 0.65;
    vec3 litAurora        = mix(vec3(baseBrightness), aurora, effectStrength);

    return tex * vec4(litAurora, 1.0);
}
