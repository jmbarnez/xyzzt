// Refactored multi-lobe nebula shader with clearer structure and naming

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
extern vec2 centerOffset;
extern number coverage;
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
    float amplitude = 0.5;
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
    float star = smoothstep(0.997, 1.0, h);
    float twinkle = 0.75 + 0.25 * sin(time * (1.5 + h * 3.5) + h * 6.2831);
    return star * twinkle * 0.6;
}

float softStars(vec2 uv) {
    float n = fbm(uv * 18.0, 3);
    float s = smoothstep(0.92, 0.999, n);
    float flicker = 0.80 + 0.20 * sin(time * 0.8 + n * 24.0);
    return s * flicker * 0.5;
}

// -----------------------------------------------------------------------------
// Density & shape helpers
// -----------------------------------------------------------------------------
float nebulaRadialMask(vec2 rel) {
    float r = length(rel);
    float inner = mix(0.25, 0.60, coverage);
    float outer = mix(0.85, 1.50, coverage);
    return smoothstep(outer, inner, r) * 0.75;
}

float nebulaShapeMask(vec2 ncoord) {
    float l1 = fbm(ncoord * 0.33 + vec2(13.7, -8.3), 4);
    float l2 = fbm(ncoord * 0.21 + vec2(-21.3, 4.9), 3);
    float l3 = fbm(ncoord * 0.27 + vec2(7.1, 18.7), 3);
    float l4 = fbm(ncoord * 0.18 + vec2(-5.4, -17.6), 3);

    float shape = l1 * 0.35 + l2 * 0.25 + l3 * 0.20 + l4 * 0.20;
    shape = smoothstep(0.28, 0.78, shape);

    float gapNoise = fbm(ncoord * 2.75 + 27.3, 3);
    float gapMask  = smoothstep(0.20, 0.70, gapNoise);

    return shape * gapMask * 0.85;
}

float computeDensity(vec2 ncoord, vec2 rel, float t) {
    vec2 flowOffset = flow * 1500.0;

    vec2 dcoord = ncoord;
    dcoord += vec2(
        sin(dcoord.y * 4.0 + t * 0.13),
        cos(dcoord.x * 3.7 + t * 0.11)
    ) * distortion * 0.8;
    dcoord += flowOffset;

    float base   = fbm(dcoord * 0.65, 5);
    float detail = fbm(dcoord * 3.1 + vec2(t * 0.11, -t * 0.08), 4);
    float wisps  = fbm(dcoord * 1.9 + vec2(-t * 0.05, t * 0.035), 3);
    float turb   = fbm(dcoord * 1.05 + vec2(t * 0.025, -t * 0.015), 3);

    float density = 0.0;
    density += base   * 0.45;
    density += detail * 0.28;
    density += wisps  * 0.22;
    density += turb   * 0.15;

    density *= nebulaRadialMask(rel);
    density = pow(max(density, 0.0), 1.85);
    density *= nebulaShapeMask(dcoord) * densityScale * 0.7;

    float slowPulse   = 0.12 * sin(t * 0.18 + 1.7) + 0.88;
    float ripplePulse = 0.03 * sin(t * 0.8 + fbm(dcoord * 4.0, 2) * 6.2831) + 0.97;

    return density * slowPulse * ripplePulse;
}

// -----------------------------------------------------------------------------
// Color helpers
// -----------------------------------------------------------------------------
vec3 computeBaseColors(vec2 ncoord, vec2 rel, float t, float density) {
    float tShift = 0.5 + 0.5 * sin(t * 0.045);
    float spatialShift = fbm(ncoord * 1.5 + rel * 0.8, 3);
    spatialShift = mix(-0.30, 0.30, spatialShift);

    float totalShift = clamp(tShift + spatialShift * colorVariation, 0.0, 1.0);

    vec3 midColor = normalize(colorA + colorB) * 0.7;
    vec3 ca = mix(colorA, midColor, 0.30 + 0.30 * totalShift) * 0.8;
    vec3 cb = mix(colorB, midColor, 0.20 + 0.40 * (1.0 - totalShift)) * 0.8;

    float mixFactor = clamp(density * 1.10, 0.0, 1.0);
    vec3 col = mix(ca, cb, mixFactor);

    float angle = atan(rel.y, rel.x);
    float warmCool = 0.5 + 0.5 * sin(angle * 2.0 + t * 0.12);
    vec3 warmTint = vec3(1.02, 0.97, 0.93);
    vec3 coolTint = vec3(0.93, 0.97, 1.02);
    col *= mix(coolTint, warmTint, warmCool);

    float glow       = smoothstep(0.45, 0.80, density);
    float highlights = smoothstep(0.82, 1.00, density);
    vec3 midGlowColor = mix(ca, cb, 0.5);

    col += glow * midGlowColor * 0.35;
    col += highlights * vec3(0.95, 0.94, 0.93) * 0.25;

    float coreRad = length(rel);
    float coreMask = smoothstep(0.60, 0.0, coreRad);
    col += coreMask * 0.08 * midGlowColor;

    return col * 0.75;
}

vec3 applyStars(vec3 baseColor, vec2 uv, vec2 rel, float density) {
    float tinyStars  = starfield(uv + offset * 0.00002);
    float largeStars = softStars(uv * 0.8 + 0.13 * rel);
    float starMask   = smoothstep(0.15, 0.85, density);
    vec3 starColor   = vec3(0.95, 0.93, 0.89);

    baseColor += tinyStars  * starColor * 0.12 * (0.4 + 0.6 * starMask);
    baseColor += largeStars * starColor * 0.18 * (0.5 + 0.5 * starMask);

    return baseColor;
}

vec3 gradeColor(vec3 color) {
    color = clamp(color, 0.0, 1.0);

    float luma = dot(color, vec3(0.299, 0.587, 0.114));
    color = mix(vec3(luma), color, 1.18);
    color = pow(color, vec3(1.05));

    return mix(vec3(0.0, 0.0, 0.015), color, 0.98);
}

// -----------------------------------------------------------------------------
// Main
// -----------------------------------------------------------------------------
vec4 effect(vec4 vcolor, Image tex, vec2 texcoord, vec2 screen_coords) {
    vec2 uv = screen_coords / resolution;

    vec2 centered = (uv - 0.5) * 2.0;
    vec2 rel = centered - centerOffset;

    uv += offset * 0.00003;
    uv += flow * 300.0;

    float r = length(rel);

    float inner = mix(0.22, 0.65, coverage);
    float outer = mix(1.05, 1.85, coverage);
    float baseRadial = smoothstep(outer, inner, r) * 0.65;

    float angle = atan(rel.y, rel.x);
    float swirl = sin(angle * 1.7 + time * 0.12) * 0.5 + 0.5;

    float bands = sin((rel.x * 2.1 + rel.y * 2.7) + time * 0.07) * 0.5 + 0.5;

    float variation = mix(swirl, bands, clamp(colorVariation, 0.0, 1.0));

    float density = baseRadial * (0.50 + 0.40 * variation) * densityScale * 0.6;

    float slowPulse = 0.95 + 0.05 * sin(time * 0.16);
    density *= slowPulse;

    density = clamp(density, 0.0, 1.0);

    float vignette = smoothstep(1.7, 0.5, length(centered));
    density *= vignette;

    float mixFactor = clamp(density * 0.85 + variation * 0.15, 0.0, 1.0);
    vec3 color = mix(colorA * 0.7, colorB * 0.7, mixFactor);

    float alpha = clamp(density * alphaScale * 0.75, 0.0, 1.0);

    return vec4(color, alpha) * vcolor;
}
