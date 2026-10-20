shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back;

uniform vec3 water_color : source_color = vec3(0.02, 0.45, 0.55);
uniform sampler2D wave_bump : hint_normal;
uniform float wave_speed : hint_range(0.0, 0.2) = 0.03;
uniform float uv_scale = 12.0; // Ajusta la repetición para tu plano de 50 metros
uniform float opacity : hint_range(0.0, 1.0) = 0.8;

void vertex() {
    // Elevación suave de las olas en las crestas
    float wave = sin(VERTEX.x * 0.2 + TIME * 1.5) * cos(VERTEX.z * 0.2 + TIME * 1.2) * 0.2;
    VERTEX.y += wave;
}

void fragment() {
    // Escalamiento automático para que la textura no se estire
    vec2 scaled_uv = UV * uv_scale;

    // Dos capas moviéndose en diagonal para que parezca agua viva
    vec2 uv_1 = scaled_uv + vec2(TIME * wave_speed, TIME * wave_speed);
    vec2 uv_2 = scaled_uv + vec2(-TIME * wave_speed * 0.8, TIME * wave_speed * 1.1);

    vec3 n1 = texture(wave_bump, uv_1).rgb;
    vec3 n2 = texture(wave_bump, uv_2).rgb;
    
    // Asignamos la normal mezclada
    NORMAL_MAP = normalize(mix(n1, n2, 0.5));

    ALBEDO = water_color;
    ROUGHNESS = 0.8; // Alto para evitar reflejos de espejo molestos
    METALLIC = 0.0;
    ALPHA = opacity;
}