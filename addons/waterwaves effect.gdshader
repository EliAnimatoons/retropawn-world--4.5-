shader_type canvas_item;

// Parámetros ajustables desde el Inspector de Godot
uniform float speed : hint_range(0.1, 5.0) = 1.2;
uniform float frequency : hint_range(1.0, 30.0) = 10.0;
uniform float amplitude : hint_range(0.001, 0.1) = 0.015;

// Margen de los bordes donde el agua se desvanece (0.0 a 0.5)
uniform float edge_fade : hint_range(0.0, 0.5) = 0.05;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

void fragment() {
    vec2 uv = SCREEN_UV;

    // Creamos una máscara basada en las coordenadas locales (UV del ColorRect)
    // Esto asegura que en los 4 bordes la distorsión sea 0
    float mask_x = smoothstep(0.0, edge_fade, UV.x) * smoothstep(1.0, 1.0 - edge_fade, UV.x);
    float mask_y = smoothstep(0.0, edge_fade, UV.y) * smoothstep(1.0, 1.0 - edge_fade, UV.y);
    float edge_mask = mask_x * mask_y;

    // Creamos las ondas de agua habituales
    float wave_x = sin(uv.y * frequency + TIME * speed) + cos(uv.x * (frequency * 0.8) - TIME * (speed * 0.7));
    float wave_y = cos(uv.x * frequency - TIME * speed) + sin(uv.y * (frequency * 0.8) + TIME * (speed * 0.9));

    // Multiplicamos la amplitud por la máscara para anular el movimiento en los bordes
    vec2 water_uv = uv + vec2(wave_x, wave_y) * amplitude * edge_mask;

    // Obtenemos el color final distorsionado
    vec4 final_color = texture(SCREEN_TEXTURE, water_uv);

    COLOR = final_color;
}