// Enhanced multi-lobe nebula shader with subtle star glow
// Creates procedural nebula clouds with dynamic color mixing and embedded sparkles

extern number time;
extern vec2 offset;
extern vec2 resolution;
extern number noiseScale;
extern vec2 flow;
extern number alphaScale;
extern vec3 colorA;
extern vec3 colorB;

float hash(vec2 p) {
    p = vec2(dot(p, vec2(137.1, 311.7)), dot(p, vec2(269.5, 183.3)));
    return fract(sin(p.x + p.y) * 43758.5453123);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);

    float n = mix(
        mix(hash(i),             hash(i + vec2(1.0, 0.0)), f.x),
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

// Soft star-ish glints in the nebula
float starfield(vec2 uv) {
    vec2 grid = floor(uv * 160.0);
    float h = hash(grid);
    float star = smoothstep(0.995, 1.0, h);
    float flicker = 0.85 + 0.15 * sin(time * (1.5 + h * 3.0) + h * 6.28);
    return star * flicker;
}

vec4 effect(vec4 vcolor, Image tex, vec2 texcoord, vec2 screen_coords) {
    vec2 uv = screen_coords / resolution;
    vec2 centered = (uv - 0.5) * 2.0;

    vec2 ncoord = uv * noiseScale + offset * 0.00005;
    ncoord += flow * time * 0.8;

    // Multiple fbm layers with different scales and motion
    float base   = fbm(ncoord * 0.7, 6);
    float detail = fbm(ncoord * 3.2 + vec2(time * 0.10, -time * 0.07), 5);
    float wisps  = fbm(ncoord * 1.8 + vec2(-time * 0.04, time * 0.03), 4);
    float turb   = fbm(ncoord * 0.9 + vec2(time * 0.02), 3);

    float density = 0.0;
    density += base   * 0.55;
    density += detail * 0.30;
    density += wisps  * 0.25;
    density += turb   * 0.15;

    // Radial falloff so nebula doesn't fill entire screen uniformly
    float r = length(centered);
    float radialMask = smoothstep(1.2, 0.25, r);
    density *= radialMask;

    // Additional shape mask – multiple broad "cloud lobes"
    float mask1 = fbm(ncoord * 0.35 + vec2(13.7, -8.3), 4);
    float mask2 = fbm(ncoord * 0.20 + vec2(-21.3, 4.9), 3);
    float mask3 = fbm(ncoord * 0.28 + vec2(7.1, 18.7), 3);
    float mask  = (mask1 * 0.5 + mask2 * 0.3 + mask3 * 0.2);
    mask = smoothstep(0.25, 0.80, mask);

    density = pow(max(density, 0.0), 1.6);
    density *= mask;

    // Subtle temporal pulsing in brightness
    float pulse = 0.15 * sin(time * 0.25) + 0.85;
    density *= pulse;

    // Slight color shift over time to keep nebula lively
    float tShift = 0.5 + 0.5 * sin(time * 0.05);
    vec3 ca = mix(colorA, colorB, 0.25 + 0.25 * tShift);
    vec3 cb = mix(colorB, colorA, 0.25 + 0.25 * (1.0 - tShift));

    vec3 color = mix(ca, cb, clamp(density * 1.15, 0.0, 1.0));

    // Glow and edge highlights
    float glow      = smoothstep(0.45, 0.85, density);
    float highlights = smoothstep(0.80, 1.00, density);

    vec3 midGlowColor = mix(ca, cb, 0.5);
    color += glow * midGlowColor * 0.55;

    vec3 highlightTint = vec3(0.95, 0.98, 1.0);
    color += highlights * highlightTint * 0.38;

    // Embedded tiny star glints to add sparkle
    float stars = starfield(uv + offset * 0.00002);
    color += stars * vec3(1.0, 0.98, 0.9) * 0.22;

    // Final alpha and color grading
    float alpha = density * alphaScale * 0.95;
    alpha = clamp(alpha, 0.0, 1.0);

    // Slight contrast & saturation boost
    color = clamp(color, 0.0, 1.0);
    float luma = dot(color, vec3(0.299, 0.587, 0.114));
    color = mix(vec3(luma), color, 1.25);   // saturation
    color = mix(vec3(0.04, 0.05, 0.10), color, 1.05); // mix with deep space tint

    return vec4(color, alpha) * vcolor;
}
