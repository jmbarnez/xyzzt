// Enhanced multi-lobe nebula shader with offset core, varied coverage, and richer coloring

extern number time;
extern vec2 offset;
extern vec2 resolution;
extern number noiseScale;
extern vec2 flow;
extern number alphaScale;
extern vec3 colorA;
extern vec3 colorB;
extern number distortion;
extern number densityScale;

// How much to offset the main nebula center from screen center (in [-1,1] space)
extern vec2 centerOffset;

// Controls how much of the screen the nebula tends to occupy (0 = small, 1 = wide)
extern number coverage;

// Slight hue shift over time and spatially for more color variation
extern number colorVariation;

// -----------------------------------------------------------------------------
// Utility noise / fbm
// -----------------------------------------------------------------------------
float hash(vec2 p) {
    p = vec2(dot(p, vec2(137.1, 311.7)), dot(p, vec2(269.5, 183.3)));
    return fract(sin(p.x + p.y) * 43758.5453123);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);

    float n = mix(
        mix(hash(i),                 hash(i + vec2(1.0, 0.0)), f.x),
        mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x),
        f.y
    );
    return n;
}

float fbm(vec2 p, int octaves) {
    float value = 0.0;
    float amplitude = 0.6;
    float frequency = 1.0;

    for (int i = 0; i < 8; i++) {
        if (i >= octaves) break;
        value += amplitude * noise(p * frequency);
        frequency *= 2.0;
        amplitude *= 0.5;
    }
    return value;
}

// -----------------------------------------------------------------------------
// Stars
// -----------------------------------------------------------------------------
float starfield(vec2 uv) {
    vec2 grid = floor(uv * 180.0);
    float h = hash(grid);
    float star = smoothstep(0.996, 1.0, h);
    float twinkle = 0.80 + 0.20 * sin(time * (1.5 + h * 3.5) + h * 6.2831);
    return star * twinkle;
}

// Slightly bigger, softer stars concentrated in higher-density regions
float softStars(vec2 uv) {
    float n = fbm(uv * 18.0, 3);
    float s = smoothstep(0.90, 0.999, n);
    float flicker = 0.85 + 0.15 * sin(time * 0.8 + n * 24.0);
    return s * flicker;
}

// -----------------------------------------------------------------------------
// Main
// -----------------------------------------------------------------------------
vec4 effect(vec4 vcolor, Image tex, vec2 texcoord, vec2 screen_coords) {
    vec2 uv = screen_coords / resolution;
    float nebulaTime = 0.0;

    // Re-center to [-1,1] and allow shifting the nebula's core
    vec2 centered = (uv - 0.5) * 2.0;
    vec2 nebulaCenter = centerOffset; // user controls offset; e.g., vec2(0.2, -0.1)
    vec2 rel = centered - nebulaCenter;

    vec2 ncoord = (uv + centerOffset * 0.25) * noiseScale + offset * 0.00005;

    // Flowing distortion
    ncoord += vec2(
        sin(ncoord.y * 4.0 + nebulaTime * 0.13),
        cos(ncoord.x * 3.7 + nebulaTime * 0.11)
    ) * distortion;

    ncoord += flow * 1500.0;

    // Multiple fbm layers with different scales and motion
    float base   = fbm(ncoord * 0.65, 6);
    float detail = fbm(ncoord * 3.1 + vec2(nebulaTime * 0.11, -nebulaTime * 0.08), 5);
    float wisps  = fbm(ncoord * 1.9 + vec2(-nebulaTime * 0.05, nebulaTime * 0.035), 4);
    float turb   = fbm(ncoord * 1.05 + vec2(nebulaTime * 0.025, -nebulaTime * 0.015), 3);

    float density = 0.0;
    density += base   * 0.55;
    density += detail * 0.32;
    density += wisps  * 0.28;
    density += turb   * 0.18;

    // -------------------------------------------------------------------------
    // Radial / falloff mask with variable coverage and off-center core
    // coverage in [0,1]: 0 small tight core, 1 very broad nebula
    // -------------------------------------------------------------------------
    float r = length(rel);
    float baseInner = mix(0.20, 0.55, coverage);
    float baseOuter = mix(0.75, 1.40, coverage);
    float radialMask = smoothstep(baseOuter, baseInner, r);

    density *= radialMask;

    // -------------------------------------------------------------------------
    // Multiple broad lobe masks to vary coverage and shape
    // -------------------------------------------------------------------------
    float lobe1 = fbm(ncoord * 0.33 + vec2(13.7, -8.3), 4);
    float lobe2 = fbm(ncoord * 0.21 + vec2(-21.3, 4.9), 3);
    float lobe3 = fbm(ncoord * 0.27 + vec2(7.1, 18.7), 3);
    float lobe4 = fbm(ncoord * 0.18 + vec2(-5.4, -17.6), 3);

    float shape = (lobe1 * 0.40 + lobe2 * 0.25 + lobe3 * 0.20 + lobe4 * 0.15);
    shape = smoothstep(0.22, 0.82, shape);

    // Extra spatial variation in coverage – small local gaps in nebula
    float gapNoise = fbm(ncoord * 2.75 + 27.3, 3);
    float gapMask  = smoothstep(0.15, 0.65, gapNoise);
    shape *= gapMask;

    density = pow(max(density, 0.0), 1.65);
    density *= shape * densityScale;

    // -------------------------------------------------------------------------
    // Temporal pulsing & breathing
    // -------------------------------------------------------------------------
    float slowPulse  = 0.18 * sin(nebulaTime * 0.18 + 1.7) + 0.82;
    float ripplePulse = 0.05 * sin(nebulaTime * 0.8 + fbm(ncoord * 4.0, 2) * 6.2831) + 0.95;
    density *= slowPulse * ripplePulse;

    // -------------------------------------------------------------------------
    // Color: richer gradients, spatial variation, and slight hue shift
    // -------------------------------------------------------------------------
    // base shift over time
    float tShift = 0.5 + 0.5 * sin(nebulaTime * 0.045);
    // spatial term to vary color across the nebula
    float spatialShift = fbm(ncoord * 1.5 + rel * 0.8, 3);
    spatialShift = mix(-0.35, 0.35, spatialShift);

    float totalShift = clamp(tShift + spatialShift * colorVariation, 0.0, 1.0);

    // blend endpoints and introduce a mid color
    vec3 midColor = normalize(colorA + colorB) * 0.8;
    vec3 ca = mix(colorA, midColor, 0.35 + 0.35 * totalShift);
    vec3 cb = mix(colorB, midColor, 0.25 + 0.45 * (1.0 - totalShift));

    float mixFactor = clamp(density * 1.18, 0.0, 1.0);
    vec3 color = mix(ca, cb, mixFactor);

    // Slight cool/warm bias based on angle from nebula center
    float angle = atan(rel.y, rel.x);
    float warmCool = 0.5 + 0.5 * sin(angle * 2.0 + nebulaTime * 0.12);
    vec3 warmTint = vec3(1.05, 0.95, 0.90);
    vec3 coolTint = vec3(0.90, 0.98, 1.05);
    color *= mix(coolTint, warmTint, warmCool);

    // -------------------------------------------------------------------------
    // Glow and highlights
    // -------------------------------------------------------------------------
    float glow       = smoothstep(0.40, 0.85, density);
    float highlights = smoothstep(0.78, 1.00, density);

    vec3 midGlowColor = mix(ca, cb, 0.5);
    color += glow * midGlowColor * 0.58;

    vec3 highlightTint = vec3(1.0, 0.99, 0.98);
    color += highlights * highlightTint * 0.42;

    // Soft inner core emphasis slightly near the offset center
    float coreRad = length(rel);
    float coreMask = smoothstep(0.55, 0.0, coreRad);
    color += coreMask * 0.12 * midGlowColor;

    // -------------------------------------------------------------------------
    // Stars
    // -------------------------------------------------------------------------
    float tinyStars = starfield(uv + offset * 0.00002);
    float largeStars = softStars(uv * 0.8 + 0.13 * rel);
    float starMaskByDensity = smoothstep(0.1, 0.8, density);

    vec3 starColor = vec3(1.0, 0.98, 0.94);
    color += tinyStars * starColor * 0.20 * (0.3 + 0.7 * starMaskByDensity);
    color += largeStars * starColor * 0.30 * (0.5 + 0.5 * starMaskByDensity);

    // -------------------------------------------------------------------------
    // Final alpha and grading
    // -------------------------------------------------------------------------
    float alpha = density * alphaScale * 0.97;
    alpha = clamp(alpha, 0.0, 1.0);

    color = clamp(color, 0.0, 1.0);

    // Slight contrast & saturation boost
    float luma = dot(color, vec3(0.299, 0.587, 0.114));
    // saturation
    color = mix(vec3(luma), color, 1.28);
    // gentle contrast curve
    color = pow(color, vec3(0.95));

    // Dark background tending to neutral/very slight deep blue
    color = mix(vec3(0.0, 0.0, 0.025), color, 1.06);

    return vec4(color, alpha) * vcolor;
}
