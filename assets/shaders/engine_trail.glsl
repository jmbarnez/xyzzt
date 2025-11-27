extern number time;
extern vec3 glow_tint;

vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
    // Texture coords x is along the trail length (0 = head, 1 = tail)
    // Texture coords y is across the trail width (0 = left, 1 = right)
    
    float u = texture_coords.x;
    float v = texture_coords.y;
    
    // Fade out towards the tail
    float alpha = 1.0 - u;
    alpha = pow(alpha, 1.5); // Non-linear fade
    
    // Core brightness (center of the trail)
    float core = 1.0 - abs(v - 0.5) * 2.0;
    core = pow(core, 3.0);
    
    // Cyan glow color
    vec3 glowColor = glow_tint; // Base glow tint (e.g. cyan for player, red for enemies)
    vec3 coreColor = vec3(1.0, 1.0, 1.0); // White core
    
    vec3 finalColor = mix(glowColor, coreColor, core * 0.5);
    
    // Add some noise/fluctuation
    float noise = sin(u * 20.0 - time * 10.0) * 0.1 + 0.9;
    alpha *= noise;
    
    return vec4(finalColor, alpha * color.a);
}
