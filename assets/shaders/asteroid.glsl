// Asteroid surface shader with procedural noise-based texture
// Uses UV texture coordinates for stable, painted-on appearance

uniform float seed;
varying vec2 vTexCoord;

#ifdef VERTEX
vec4 position(mat4 transform_projection, vec4 vertex_position)
{
    // Pass through texture coordinates from vertex attributes
    vTexCoord = VertexTexCoord.xy;
    return transform_projection * vertex_position;
}
#endif

#ifdef PIXEL
// Simple hash function for noise generation
float hash(vec2 p)
{
    p = 50.0 * fract(p * 0.3183099 + vec2(0.71, 0.113));
    return -1.0 + 2.0 * fract(p.x * p.y * (p.x + p.y));
}

// 2D noise function
float noise(vec2 p)
{
    vec2 i = floor(p);
    vec2 f = fract(p);
    
    vec2 u = f * f * (3.0 - 2.0 * f);
    
    return mix(mix(hash(i + vec2(0.0, 0.0)), 
                   hash(i + vec2(1.0, 0.0)), u.x),
               mix(hash(i + vec2(0.0, 1.0)), 
                   hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

// Fractal Brownian Motion for complex noise
float fbm(vec2 p)
{
    float f = 0.0;
    float amplitude = 0.5;
    float frequency = 1.0;
    
    for(int i = 0; i < 3; i++)
    {
        f += amplitude * noise(p * frequency);
        amplitude *= 0.5;
        frequency *= 2.0;
    }
    
    return f;
}

vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords)
{
    // Use UV coordinates with seed offset to make texture unique per asteroid
    // Scale UV to create appropriate noise frequency
    vec2 pos = (vTexCoord * 100.0 + seed * 100.0) * 0.06;
    
    // Generate multiple noise layers at different scales
    float n1 = fbm(pos);
    float n2 = fbm(pos * 2.5 + vec2(1.3, 2.7));
    float n3 = fbm(pos * 6.0 + vec2(5.1, 3.4));
    
    // Base texture variation
    float baseVariation = n1 * 0.2;
    
    // Dark spots (craters/shadows)
    float spots = smoothstep(0.3, 0.6, n2) * 0.25;
    
    // Bright highlights (mineral deposits)
    float highlights = smoothstep(0.6, 0.8, n3) * 0.15;
    
    // Fine grain texture
    float grain = n3 * 0.1;
    
    // Combine all texture layers
    vec3 finalColor = color.rgb;
    finalColor = finalColor * (1.0 - spots);  // Apply dark spots
    finalColor = finalColor + finalColor * highlights;  // Apply highlights
    finalColor = finalColor * (0.92 + baseVariation * 0.16 + grain * 0.08);
    
    return vec4(finalColor, color.a);
}
#endif
