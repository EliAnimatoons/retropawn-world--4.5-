shader_type canvas_item;

uniform float line_count : hint_range(10.0, 500.0) = 250.0;
uniform float opacity : hint_range(0.0, 1.0) = 0.2;

void fragment() {
    // Esto crea líneas horizontales basadas en la posición de los píxeles
    float s = sin(SCREEN_UV.y * line_count * PI * 2.0);
    s = (s * 0.5 + 0.5); // Normalizar
    s = pow(s, 0.5); // Ajustar grosor
    
    // Solo oscurecemos un poquito donde están las líneas
    COLOR = vec4(0.0, 0.0, 0.0, (1.0 - s) * opacity);
}