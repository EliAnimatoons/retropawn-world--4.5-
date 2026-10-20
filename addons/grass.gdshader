shader_type spatial;
// Agregamos depth_draw_always para evitar que el pasto desaparezca detrás de otro pasto
render_mode cull_disabled, diffuse_toon, specular_toon, depth_draw_always;

uniform vec3 grass_color : source_color = vec3(0.2, 0.8, 0.3);
uniform vec3 wind_color : source_color = vec3(0.5, 1.0, 0.5);
uniform float wind_speed : hint_range(0.0, 10.0) = 1.2;
uniform float wind_strength : hint_range(0.0, 5.0) = 0.5;

void vertex() {
	float strength_mask = pow(1.0 - UV.y, 2.0);
	float world_pos_offset = MODEL_MATRIX[3].x + MODEL_MATRIX[3].z;
	float time = TIME * wind_speed;
	float sway = sin(time + world_pos_offset);
	VERTEX.x += sway * wind_strength * strength_mask;
	VERTEX.z += cos(time * 0.5 + world_pos_offset) * wind_strength * 0.5 * strength_mask;
}

void fragment() {
	float mix_factor = 1.0 - UV.y;
	ALBEDO = mix(grass_color, wind_color, mix_factor * 0.4);
	ROUGHNESS = 0.5;
	
	// TRANSPARENCIA: 0.0 es invisible, 1.0 es sólido.
	// La punta (mix_factor alto) es más transparente que la base.
	ALPHA = mix(0.9, 0.3, mix_factor);
}