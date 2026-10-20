shader_type spatial;

// Quitamos 'unshaded' para que el buffer de profundidad lo reconozca mejor
render_mode depth_draw_always, alpha_to_coverage;

// Texturas y control visual
uniform sampler2D foliage_texture : source_color, filter_linear_mipmap;
uniform vec2 texture_scale = vec2(1.0, 1.0);
uniform float alpha_threshold : hint_range(0.0, 1.0) = 0.1;

// Control de Color
uniform vec3 foliage_colour : source_color = vec3(0.13, 0.33, 0.25);
uniform float color_strength : hint_range(0.0, 2.0) = 1.0;

// Brillo en los bordes (Fresnel)
uniform vec3 fresnel_colour : source_color = vec3(0.5, 0.7, 0.4);
uniform float fresnel_strength : hint_range(0.0, 1.0) = 0.3;
uniform float fresnel_power : hint_range(0.1, 5.0) = 1.5;

// Efecto Billboard
uniform float billboard_strength : hint_range(0.0, 1.0) = 1.0;
uniform vec2 vertex_offset_scale = vec2(1.0, 1.0);
uniform bool flip_normal = true;

// Control de Viento
uniform bool use_wind = true;
uniform float wind_strength : hint_range(0.0, 1.0) = 0.1;
uniform float wind_speed : hint_range(0.1, 5.0) = 1.0;
uniform vec3 wind_direction = vec3(1.0, 0.0, 0.0);

void vertex()
{
    if (flip_normal) {
        NORMAL = -NORMAL;
    }

    // Posicionamiento Billboard
    vec2 viewspace_offset = (UV - vec2(0.5)) * vertex_offset_scale;
    vec4 modelspace_offset = inverse(MODELVIEW_MATRIX) * vec4(viewspace_offset, 0.0, 0.0);
    VERTEX += modelspace_offset.xyz * billboard_strength;

    // Movimiento de vaivén (Viento)
    if (use_wind) {
        float sway = sin(TIME * wind_speed + VERTEX.x * 0.5) * wind_strength;
        VERTEX.xyz += wind_direction * sway;
    }
}

void fragment()
{
    vec2 scaled_uv = UV * texture_scale;
    
    // Ahora leemos el alpha real de la textura para que los rayos se filtren
    vec4 tex_color = texture(foliage_texture, scaled_uv);
    float alpha = tex_color.a; 

    if (alpha < alpha_threshold) {
        discard;
    }

    float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), fresnel_power);
    vec3 final_color = mix(foliage_colour, fresnel_colour, fresnel * fresnel_strength);

    // Si quitamos unshaded, el ALBEDO interactúa con la luz del mundo
    ALBEDO = (tex_color.rgb * final_color) * color_strength;
    ALPHA = alpha;
}