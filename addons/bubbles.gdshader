shader_type canvas_item;

// --- Parámetros ajustables desde el Inspector ---
// Base: Colores Frutiger Aero Cute (Azul cian a blanco con toque rosa suave)
uniform vec4 color_burbuja_bordes : source_color = vec4(0.4, 0.9, 1.0, 0.6); // Cyan traslúcido
uniform vec4 color_burbuja_centro : source_color = vec4(1.0, 1.0, 1.0, 0.9); // Centro brillante
uniform float tamano_base : hint_range(0.01, 0.2) = 0.05; // Tamaño promedio de burbuja
uniform float velocidad : hint_range(0.1, 2.0) = 0.5;    // Velocidad de subida
uniform float cantidad : hint_range(5.0, 50.0) = 20.0;   // Complejidad visual

// Función pseudo-aleatoria muy simple para que no consuma recursos
float hash(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

void fragment() {
    // Normalizar coordenadas (ajusta según el ratio de aspecto para que no salgan ovaladas)
    vec2 uv = (UV * 2.0 - 1.0);
    uv.x *= (1.0 / TEXTURE_PIXEL_SIZE.y) / (1.0 / TEXTURE_PIXEL_SIZE.x);

    vec3 color_final = vec3(0.0); // Fondo del ColorRect transparente por defecto
    float alpha_final = 0.0;

    // --- Generación de burbujas ---
    // Dividimos la pantalla en "capas" o celdas para distribuir burbujas
    for (float i = 0.0; i < cantidad; i++) {
        // Obtenemos valores "aleatorios" para cada burbuja basados en su índice
        float seed = i + 0.123;
        float randX = hash(vec2(seed, 0.0));
        float randY = hash(vec2(0.0, seed));
        float rand_size = hash(vec2(seed, seed));
        
        // --- Posición con movimiento ---
        // Movimiento X sinusoidal (zig-zag suave cute)
        float offset_x = (randX * 2.0 - 1.0) * 0.8; // Rango horizontal
        float zig_zag = sin(TIME * (0.5 + rand_size) + seed * 10.0) * 0.05;
        
        // Movimiento Y (subida constante con 'mod' para resetear)
        float tiempo_con_offset = TIME * velocidad * (0.7 + rand_size);
        float pos_y_ciclica = mod(randY - tiempo_con_offset, 1.0);
        // Mapeamos pos_y de [0,1] (fuera abajo) a [1,-1] (fuera arriba en coord normalizadas)
        float pos_y_mapeada = pos_y_ciclica * 2.6 - 1.3; 

        vec2 pos_burbuja = vec2(offset_x + zig_zag, pos_y_mapeada);
        
        // --- Cálculo de la forma ---
        float dist = distance(uv, pos_burbuja);
        float radio = tamano_base * (0.5 + rand_size); // Variación de tamaño

        // Suavizado de bordes (antialias) para que no sea pixelado ("choto")
        float borde_suave = 0.005;
        float mascara = smoothstep(radio, radio - borde_suave, dist);

        if (mascara > 0.0) {
            // --- Coloreado Frutiger Aero (Estilo "Brillo de Cristal/Agua") ---
            // Un degradado radial simple: blanco brillante en el centro, cyan traslúcido en borde
            float degradado_radial = smoothstep(radio * 0.9, 0.0, dist);
            vec4 color_actual = mix(color_burbuja_bordes, color_burbuja_centro, degradado_radial);
            
            // Toque de brillo extra descentrado (imitando reflejo de luz)
            vec2 reflejo_pos = pos_burbuja + vec2(-radio*0.3, radio*0.3);
            float dist_reflejo = distance(uv, reflejo_pos);
            float reflejo_cuteness = smoothstep(radio * 0.3, 0.0, dist_reflejo) * 0.8;
            color_actual.rgb = mix(color_actual.rgb, vec3(1.0), reflejo_cuteness);

            // --- Mezcla (Blending) ---
            // Para que las burbujas traslúcidas se vean bien al superponerse
            color_final = mix(color_final, color_actual.rgb, mascara * color_actual.a);
            alpha_final = max(alpha_final, mascara * color_actual.a);
        }
    }

    COLOR = vec4(color_final, alpha_final);
}