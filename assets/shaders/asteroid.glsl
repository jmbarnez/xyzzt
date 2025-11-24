// Satisfying asteroid shader with smooth, organic rocky surfaces
// Designed for visually pleasing 2D space aesthetics

uniform float seed;
varying vec2 vTexCoord;

#ifdef VERTEX
vec4 position(mat4 transform_projection, vec4 vertex_position)
{
    vTexCoord = VertexTexCoord.xy;
    return transform_projection * vertex_position;
}
#endif

#ifdef PIXEL
// Smooth hash function
float hash(vec2 p)
{
    p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
    return fract(sin(p.x + p.y) * 43758.5453123);
}

// Smooth value noise
float noise(vec2 p)
{
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f); // Smoothstep interpolation
    
    float a = hash(i);
    float b = hash(i + vec2(1.0, 0.0));
    float c = hash(i + vec2(0.0, 1.0));
    float d = hash(i + vec2(1.0, 1.0));
    
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// Fractal Brownian Motion for organic patterns
float fbm(vec2 p)
{
    float value = 0.0;
    float amplitude = 0.5;
    
    for(int i = 0; i < 4; i++)
    {
        value += amplitude * noise(p);
        p *= 2.3;
        amplitude *= 0.5;
    }
    
    return value;
}

// Ridged noise for crater-like features
float ridged(vec2 p)
{
    return 1.0 - abs(noise(p) * 2.0 - 1.0);
}

vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords)
{
    // Unique seed-based position for each asteroid
    vec2 pos = (vTexCoord + seed * 7.531) * 3.0;
    
    // Organic rocky base structure
    float base = fbm(pos);
    
    // Add subtle crater-like features
    float craters = ridged(pos * 1.5 + base * 0.3) * 0.3;
    
    // Fine surface detail
    float detail = noise(pos * 8.0) * 0.15;
    
    // Combine layers for depth
    float combined = base * 0.6 + craters + detail;
    
    // Color variation with smooth gradients
    vec3 darkTone = color.rgb * 0.7;
    vec3 lightTone = color.rgb * 1.2;
    vec3 finalColor = mix(darkTone, lightTone, combined);
    
    // Subtle edge darkening for depth
    float edge = smoothstep(0.0, 0.3, length(vTexCoord - 0.5) * 2.0);
    finalColor = mix(finalColor, finalColor * 0.8, edge * 0.3);
    
    // Soft contrast for a polished look
    finalColor = pow(finalColor, vec3(0.95));
    
    return vec4(finalColor, color.a);
}
#endif
