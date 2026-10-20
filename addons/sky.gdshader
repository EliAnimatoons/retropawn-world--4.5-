shader_type sky;
render_mode use_half_res_pass;

uniform sampler2D cloud_shape_sampler : filter_linear_mipmap, repeat_enable;
uniform sampler2D cloud_curves;

uniform vec3 top_color : source_color;
uniform vec3 bottom_color : source_color;
uniform vec3 clouds_light_color : source_color;

uniform float clouds_density : hint_range(0.0, 1.0) = 0.5;
uniform float clouds_scale : hint_range(0.1, 2.0) = 1.0;
uniform float stars_intensity : hint_range(0.0, 5.0) = 0.0;
uniform float lightning_flash : hint_range(0.0, 1.0) = 0.0;
uniform bool is_night = false;

uniform float sun_size : hint_range(0.01, 1.0) = 0.05;
uniform float sun_blur : hint_range(0.01, 1.0) = 0.1;

void sky() {
	float horizon_mask = abs(EYEDIR.y);
	vec3 sky_gradient = mix(bottom_color, top_color, clamp(EYEDIR.y, 0.0, 1.0));
	
	// --- LÓGICA SOL / LUNA ---
	float sun_dot = dot(EYEDIR, LIGHT0_DIRECTION);
	float astro_mask = smoothstep(1.0 - sun_size - sun_blur, 1.0 - sun_size, sun_dot);
	
	// Color del astro: Blanco brillante si es sol, azul pálido si es luna
	vec3 astro_color = is_night ? vec3(0.6, 0.8, 1.0) * astro_mask : vec3(1.0, 0.9, 0.7) * astro_mask * 2.0;
	
	// --- NUBES ---
	vec2 cloud_uv = EYEDIR.xz / max(EYEDIR.y, 0.01);
	float cloud_time = TIME * 0.05;
	float noise = texture(cloud_shape_sampler, (cloud_uv + cloud_time) * clouds_scale).r;
	float curve_val = texture(cloud_curves, vec2(clamp(EYEDIR.y, 0.0, 1.0), 0.0)).r;
	float final_clouds = smoothstep(1.0 - clouds_density, 1.0, noise * curve_val);
	
	vec3 base_color = sky_gradient + astro_color;
	vec3 final_color = mix(base_color, clouds_light_color, final_clouds * (1.0 - horizon_mask));
	
	// --- EFECTO DE RAYO (Todo blanco) ---
	final_color = mix(final_color, vec3(1.0), lightning_flash);
	
	if (stars_intensity > 0.1) {
		float stars = fract(sin(dot(EYEDIR, vec3(12.9898, 78.233, 45.164))) * 43758.5453);
		if (stars > 0.995) final_color += vec3(stars_intensity) * (1.0 - final_clouds) * (1.0 - lightning_flash);
	}

	COLOR = final_color;
}