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
    vec2 pos = (vTexCoord + seed * 13.7) * 8.0;
    
    // Large-scale rocky structure
    float structure = fbm(pos * 0.8, 5);
    
    // Medium-scale surface detail
    float surface = fbm(pos * 2.5 + vec2(structure * 0.3), 4);
    
    // Fine grain and micro-details
    float grain = fbm(pos * 8.0 + vec2(surface * 0.2), 3);
    
    // Voronoi pattern for chunky rock segments
    float chunks = voronoi(pos * 1.2 + seed * 7.3);
    chunks = smoothstep(0.15, 0.45, chunks);
    
    // Deep craters and impact marks
    float craters = fbm(pos * 1.8 + vec2(11.3, 7.9), 4);
    craters = smoothstep(0.35, 0.55, craters);
    float craterDepth = (1.0 - craters) * 0.35;
    
    // Bright mineral veins
    float veins = fbm(pos * 4.5 + vec2(23.1, 17.6), 3);
    veins = smoothstep(0.65, 0.75, veins);
    float veinBrightness = veins * 0.25;
    
    // Subtle color variation
    float colorShift = fbm(pos * 1.2 + vec2(31.4, 19.2), 3) * 0.15;
    
    // Build final color
    vec3 baseColor = color.rgb;
    
    // Apply structure variation
    baseColor = baseColor * (0.85 + structure * 0.3);
    
    // Add chunky rock segments
    baseColor = baseColor * (0.92 + chunks * 0.16);
    
    // Apply craters (darkening)
    baseColor = baseColor * (1.0 - craterDepth);
    
    // Add mineral veins (brightening)
    baseColor = baseColor + baseColor * veinBrightness;
    
    // Surface detail and grain
    baseColor = baseColor * (0.88 + surface * 0.18 + grain * 0.06);
    
    // Color variation for interest
    baseColor = mix(baseColor, baseColor * vec3(1.05, 0.98, 0.95), colorShift);
    
    // Slight contrast boost
    baseColor = pow(baseColor, vec3(0.92));
    
    return vec4(baseColor, color.a);
}
#endif
