shader_type canvas_item;

// Parámetros de control desde el HUD (0.0 a 1.0)
uniform float height = 1.0; 

// Configuración de la Onda/Superficie
uniform float wave_speed = 5.0;
uniform float wave_frequency = 10.0;
uniform float wave_amplitude = 0.03; // Qué tan alta es la ola

// Configuración de las Burbujas Internas
uniform float bubble_speed = 2.0;
uniform float bubble_density = 20.0;

// Colores del Elíxir (El color base lo sobreescribe tu HUD por código)
uniform vec4 water_color: source_color = vec4(0.2, 0.6, 1.0, 1.0);
uniform vec4 foam_color: source_color = vec4(1.0, 1.0, 1.0, 1.0); // Color de la espuma de la ola
uniform vec4 bg_color: source_color = vec4(0.05, 0.05, 0.1, 0.6);   // Fondo del frasco vacío

// Función matemática simple de ruido para generar burbujas
float pseudo_noise(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

void fragment() {
    vec2 uv = UV;
    
    // 1. COMPENSACIÓN DE ALERTA (Si está lleno, el líquido tiembla de poder)
    if (height >= 0.99) {
        uv.x += sin(TIME * 60.0) * 0.005;
        uv.y += cos(TIME * 50.0) * 0.005;
    }

    // 2. CÁLCULO DE LA ONDA HORIZONTAL (Superficie del líquido)
    // Esto crea el oleaje usando el seno del tiempo y la posición X
    float wave = sin(uv.x * wave_frequency + TIME * wave_speed) * wave_amplitude;
    
    // La "línea de llenado" final se calcula de abajo (1.0) hacia arriba (0.0)
    float fill_line = 1.0 - height + wave;
    
    // Color base inicial: el fondo del frasco vacío
    vec4 final_color = bg_color;

    // 3. DIBUJAR EL LÍQUIDO
    if (uv.y >= fill_line) {
        // Estamos dentro del líquido
        final_color = water_color;
        
        // Generar burbujas flotantes usando ruido puramente matemático
        vec2 bubble_uv = uv * bubble_density;
        bubble_uv.y += TIME * bubble_speed; // Hace que suban
        
        float noise_val = pseudo_noise(floor(bubble_uv));
        if (noise_val > 0.92) { // Densidad de las burbujas
            // Añadimos un destello blanco texturizado
            float bubble_shape = sin(fract(bubble_uv.x) * PI) * sin(fract(bubble_uv.y) * PI);
            final_color += vec4(vec3(bubble_shape * 0.4), 0.0);
        }
        
        // Si el poder está al máximo, hacemos que el líquido brille intensamente (Glow)
        if (height >= 0.99) {
            float pulse = sin(TIME * 15.0) * 0.2 + 0.8;
            final_color.rgb += water_color.rgb * pulse * 0.5;
        }
        
    } 
    // 4. DIBUJAR LA ESPUMA (La línea brillante justo en la superficie de la ola)
    else if (uv.y >= fill_line - 0.015) {
        // Genera un borde iluminado muy estético en la punta de la ola
        final_color = mix(foam_color, water_color, (fill_line - uv.y) / 0.015);
        
        if (height >= 0.99) {
            // Destello extra en la espuma si está lleno
            final_color += vec4(1.0, 1.0, 1.0, 1.0) * (sin(TIME * 20.0) * 0.5 + 0.5);
        }
    }

    COLOR = final_color;
}