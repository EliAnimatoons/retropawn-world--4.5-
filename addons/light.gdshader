shader_type canvas_item;
render_mode blend_add, unshaded;

uniform vec2 light_pos; // Viene del script
uniform vec3 sun_direction;
uniform vec3 cam_direction;
uniform vec4 sun_color : source_color;

uniform float ray_length : hint_range(0.0, 1.0) = 0.5;
uniform float intensity : hint_range(0.0, 5.0) = 1.2;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;

// TRUCO DE OPTIMIZACIÓN: Solo 32 muestras + Ruido
const int SAMPLES = 32; 

float interleaved_gradient_noise(vec2 uv) {
    return fract(52.9829189 * fract(dot(uv, vec2(0.06711056, 0.00583715))));
}

void fragment() {
	vec2 screen_size = 1.0 / SCREEN_PIXEL_SIZE;
	vec2 l_pos = light_pos / screen_size;
	vec2 uv = SCREEN_UV;
	vec2 dir = (uv - l_pos) * ray_length / float(SAMPLES);
	
	// Ruido para eliminar el banding (rayas feas)
	float noise = interleaved_gradient_noise(FRAGCOORD.xy);
	uv += dir * noise;

	float rays = 0.0;
	for (int i = 0; i < SAMPLES; i++) {
		// Muestreamos la pantalla. Si hay algo oscuro (árbol), bloquea la luz.
		vec3 samp = textureLod(screen_tex, uv, 0.0).rgb;
		float brightness = dot(samp, vec3(0.299, 0.587, 0.114));
		
		// Invertimos: lo que es luz deja pasar luz, lo que es sombra bloquea
		rays += (1.0 - brightness); 
		uv -= dir;
	}
	
	rays /= float(SAMPLES);
	
	// Solo mostrar rayos si miramos hacia el sol
	float view_dot = clamp(dot(cam_direction, sun_direction), 0.0, 1.0);
	float edge_fade = min(1.0, (1.0 - distance(SCREEN_UV, vec2(0.5))) * 2.0);
	
	vec3 final_color = sun_color.rgb * rays * intensity * view_dot * edge_fade;
	COLOR = vec4(final_color, 1.0);
}