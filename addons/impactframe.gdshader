shader_type canvas_item;

// Parámetros ajustables desde el Inspector
uniform float intensity : hint_range(0.0, 1.0) = 0.0; // Controlado por la cámara
uniform vec4 impact_color : source_color = vec4(0.9, 0.1, 0.2, 1.0); // Color del impacto (Rojo violento)
uniform float chromatic_aberration : hint_range(0.0, 0.05) = 0.015; // Distorsión de color
uniform float vignette_sharpness : hint_range(0.1, 5.0) = 2.0;
uniform float vignette_amount : hint_range(0.0, 1.0) = 0.6;
uniform float flash_brightness : hint_range(0.0, 1.0) = 0.2; // Brillo extra de impacto

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

void fragment() {
    vec2 uv = SCREEN_UV;
    
    // 1. Aberración Cromática (desfase RGB impulsado por la intensidad)
    float shift = chromatic_aberration * intensity;
    float r = texture(SCREEN_TEXTURE, uv + vec2(shift, 0.0)).r;
    float g = texture(SCREEN_TEXTURE, uv).g;
    float b = texture(SCREEN_TEXTURE, uv - vec2(shift, 0.0)).b;
    vec3 color_distorsionado = vec3(r, g, b);

    // 2. Efecto Vignette circular desde el centro
    vec2 center_uv = uv - vec2(0.5);
    float dist = length(center_uv);
    float vignette = smoothstep(0.8, 0.2, dist * vignette_amount);
    vignette = pow(vignette, vignette_sharpness);
    
    // 3. Tinta de color estilizada (Blend de impacto)
    vec3 color_impacto = mix(impact_color.rgb, color_distorsionado, vignette);
    
    // 4. Aumento de brillo/flash ligero
    color_impacto += vec3(flash_brightness * (1.0 - vignette));

    // 5. Mezcla final con la pantalla original usando 'intensity'
    vec3 color_final = mix(color_distorsionado, color_impacto, intensity);

    COLOR = vec4(color_final, 1.0);
}