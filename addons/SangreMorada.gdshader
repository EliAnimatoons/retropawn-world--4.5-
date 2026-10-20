shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_opaque, cull_back;

uniform vec4 color_sangre : source_color = vec4(0.5, 0.0, 0.5, 1.0); // Morado

void fragment() {
    // Calculamos la distancia al centro para hacer un círculo
    float dist = distance(UV, vec2(0.5));
    
    // Si la distancia es mayor a 0.5, lo borramos (hace la gota circular)
    if (dist > 0.5) {
        discard;
    }
    
    // Un pequeño brillo en el borde para que parezca líquido
    float brillo = smoothstep(0.45, 0.2, dist);
    ALBEDO = color_sangre.rgb + (brillo * 0.2);
    ALPHA = color_sangre.a;
}