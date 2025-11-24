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

float softStars(vec2 uv) {
    float n = fbm(uv * 18.0, 3);
    float s = smoothstep(0.90, 0.999, n);
    float flicker = 0.85 + 0.15 * sin(time * 0.8 + n * 24.0);
    return s * flicker;
}

// -----------------------------------------------------------------------------
// Density & shape helpers
// -----------------------------------------------------------------------------
float nebulaRadialMask(vec2 rel) {
    float r = length(rel);
    float inner = mix(0.20, 0.55, coverage);
    float outer = mix(0.75, 1.40, coverage);
    return smoothstep(outer, inner, r);
}

float nebulaShapeMask(vec2 ncoord) {
    float l1 = fbm(ncoord * 0.33 + vec2(13.7, -8.3), 4);
    float l2 = fbm(ncoord * 0.21 + vec2(-21.3, 4.9), 3);
    float l3 = fbm(ncoord * 0.27 + vec2(7.1, 18.7), 3);
    float l4 = fbm(ncoord * 0.18 + vec2(-5.4, -17.6), 3);

    float shape = l1 * 0.40 + l2 * 0.25 + l3 * 0.20 + l4 * 0.15;
    shape = smoothstep(0.22, 0.82, shape);

    float gapNoise = fbm(ncoord * 2.75 + 27.3, 3);
    float gapMask  = smoothstep(0.15, 0.65, gapNoise);

    return shape * gapMask;
}

float computeDensity(vec2 ncoord, vec2 rel, float t) {
    vec2 flowOffset = flow * 1500.0;

    vec2 dcoord = ncoord;
    dcoord += vec2(
        sin(dcoord.y * 4.0 + t * 0.13),
        cos(dcoord.x * 3.7 + t * 0.11)
    ) * distortion;
    dcoord += flowOffset;

    float base   = fbm(dcoord * 0.65, 6);
    float detail = fbm(dcoord * 3.1 + vec2(t * 0.11, -t * 0.08), 5);
    float wisps  = fbm(dcoord * 1.9 + vec2(-t * 0.05, t * 0.035), 4);
    float turb   = fbm(dcoord * 1.05 + vec2(t * 0.025, -t * 0.015), 3);

    float density = 0.0;
    density += base   * 0.55;
    density += detail * 0.32;
    density += wisps  * 0.28;
    density += turb   * 0.18;

    density *= nebulaRadialMask(rel);
    density = pow(max(density, 0.0), 1.65);
    density *= nebulaShapeMask(dcoord) * densityScale;

    float slowPulse   = 0.18 * sin(t * 0.18 + 1.7) + 0.82;
    float ripplePulse = 0.05 * sin(t * 0.8 + fbm(dcoord * 4.0, 2) * 6.2831) + 0.95;

    return density * slowPulse * ripplePulse;
}

// -----------------------------------------------------------------------------
// Color helpers
// -----------------------------------------------------------------------------
vec3 computeBaseColors(vec2 ncoord, vec2 rel, float t, float density) {
    float tShift = 0.5 + 0.5 * sin(t * 0.045);
    float spatialShift = fbm(ncoord * 1.5 + rel * 0.8, 3);
    spatialShift = mix(-0.35, 0.35, spatialShift);

    float totalShift = clamp(tShift + spatialShift * colorVariation, 0.0, 1.0);

    vec3 midColor = normalize(colorA + colorB) * 0.8;
    vec3 ca = mix(colorA, midColor, 0.35 + 0.35 * totalShift);
    vec3 cb = mix(colorB, midColor, 0.25 + 0.45 * (1.0 - totalShift));

    float mixFactor = clamp(density * 1.18, 0.0, 1.0);
    vec3 col = mix(ca, cb, mixFactor);

    float angle = atan(rel.y, rel.x);
    float warmCool = 0.5 + 0.5 * sin(angle * 2.0 + t * 0.12);
    vec3 warmTint = vec3(1.05, 0.95, 0.90);
    vec3 coolTint = vec3(0.90, 0.98, 1.05);
    col *= mix(coolTint, warmTint, warmCool);

    float glow       = smoothstep(0.40, 0.85, density);
    float highlights = smoothstep(0.78, 1.00, density);
    vec3 midGlowColor = mix(ca, cb, 0.5);

    col += glow * midGlowColor * 0.58;
    col += highlights * vec3(1.0, 0.99, 0.98) * 0.42;

    float coreRad = length(rel);
    float coreMask = smoothstep(0.55, 0.0, coreRad);
    col += coreMask * 0.12 * midGlowColor;

    return col;
}

vec3 applyStars(vec3 baseColor, vec2 uv, vec2 rel, float density) {
    float tinyStars  = starfield(uv + offset * 0.00002);
    float largeStars = softStars(uv * 0.8 + 0.13 * rel);
    float starMask   = smoothstep(0.1, 0.8, density);
    vec3 starColor   = vec3(1.0, 0.98, 0.94);

    baseColor += tinyStars  * starColor * 0.20 * (0.3 + 0.7 * starMask);
    baseColor += largeStars * starColor * 0.30 * (0.5 + 0.5 * starMask);

    return baseColor;
}

vec3 gradeColor(vec3 color) {
    color = clamp(color, 0.0, 1.0);

    float luma = dot(color, vec3(0.299, 0.587, 0.114));
    color = mix(vec3(luma), color, 1.28);
    color = pow(color, vec3(0.95));

    return mix(vec3(0.0, 0.0, 0.025), color, 1.06);
}

// -----------------------------------------------------------------------------
// Main
// -----------------------------------------------------------------------------
vec4 effect(vec4 vcolor, Image tex, vec2 texcoord, vec2 screen_coords) {
    vec2 uv = screen_coords / resolution;
    float t = 0.0; // local time factor for nebula animation

    vec2 centered = (uv - 0.5) * 2.0;
    vec2 rel = centered - centerOffset;

    vec2 ncoord = (uv + centerOffset * 0.25) * noiseScale + offset * 0.00005;

    float density = computeDensity(ncoord, rel, t);
    vec3 color    = computeBaseColors(ncoord, rel, t, density);
    color         = applyStars(color, uv, rel, density);
    color         = gradeColor(color);

    float alpha = clamp(density * alphaScale * 0.97, 0.0, 1.0);

    return vec4(color, alpha) * vcolor;
}
