// Aurora effect shader for title text
// Creates a flowing, colorful aurora effect with green and purple tones

extern number time;

vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 pixel_coords) {
    vec4 tex = Texel(texture, texture_coords) * color;
    if (tex.a <= 0.001) return tex;

    // Parameters for the aurora effect
    float speed = 1.5;
    float wave_frequency_x = 0.03;
    float wave_frequency_y = 0.02;
    float color_frequency = 0.5;
    float color_amplitude = 0.4;
    float base_brightness = 0.6; // Ensure text is visible even in darker parts

    // Calculate wave pattern
    float wave1 = sin(pixel_coords.x * wave_frequency_x + time * speed);
    float wave2 = cos(pixel_coords.y * wave_frequency_y + time * speed * 0.7); // Slightly different speed/frequency

    float combined_wave = (wave1 + wave2) * 0.5; // Combine waves

    // Generate color based on wave and time
    float intensity = combined_wave * 0.5 + 0.5;
    vec3 baseColor = vec3(0.0, 0.45, 0.25);   // deep green
    vec3 highlightColor = vec3(0.2, 0.9, 0.6); // bright teal
    vec3 aurora = mix(baseColor, highlightColor, intensity);

    float subtleShift = smoothstep(0.6, 1.0, intensity) * 0.35 * (sin(time * color_frequency * 0.7) * 0.5 + 0.5);
    vec3 purpleTint = vec3(0.4, 0.2, 0.6);
    aurora = mix(aurora, purpleTint, subtleShift);

    float brightness = base_brightness + color_amplitude * (intensity - 0.5);
    aurora *= brightness;

    // Clamp values to [0, 1]
    aurora = clamp(aurora, 0.0, 1.0);

    return tex * vec4(aurora, 1.0);
}
