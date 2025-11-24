// Enhanced asteroid surface shader with rich procedural textures
// Creates varied, visually interesting rocky surfaces

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
// Improved hash for better randomization
float hash(vec2 p)
{
    p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
    return fract(sin(p.x + p.y) * 43758.5453123) * 2.0 - 1.0;
}

// Smooth noise with better interpolation
float noise(vec2 p)
{
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    
    return mix(
        mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
        mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x),
        f.y
    );
}

// Multi-octave fractal noise
float fbm(vec2 p, int octaves)
{
    float value = 0.0;
    float amplitude = 0.5;
    float frequency = 1.0;
    
    for(int i = 0; i < 6; i++)
    {
        if(i >= octaves) break;
        value += amplitude * noise(p * frequency);
        frequency *= 2.1;
        amplitude *= 0.48;
    }
    
    return value;
}

// Voronoi-like cell pattern for rocky chunks
float voronoi(vec2 p)
{
    vec2 i = floor(p);
    vec2 f = fract(p);
    
    float minDist = 1.0;
    for(int y = -1; y <= 1; y++)
    {
        for(int x = -1; x <= 1; x++)
        {
            vec2 neighbor = vec2(float(x), float(y));
            vec2 point = vec2(hash(i + neighbor)) * 0.5 + 0.5;
            float dist = length(neighbor + point - f);
            minDist = min(minDist, dist);
        }
    }
    
    return minDist;
}

vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords)
{
    // Unique position per asteroid using seed
    vec2 pos = (vTexCoord + seed * 13.7) * 4.0;
    
    // Large-scale rocky structure - reduced octaves for smoother look
    float structure = fbm(pos, 3);
    
    // Subtle surface variation
    float surface = fbm(pos * 2.0 + vec2(structure), 2);
    
    // Build final color
    vec3 baseColor = color.rgb;
    
    // Apply structure variation - much softer than before
    baseColor = baseColor * (0.9 + structure * 0.2);
    
    // Add subtle surface detail
    baseColor = baseColor * (0.95 + surface * 0.1);
    
    // Slight contrast adjustment for "solid" feel
    baseColor = pow(baseColor, vec3(1.1));
    
    return vec4(baseColor, color.a);
}
#endif
