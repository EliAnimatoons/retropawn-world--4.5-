shader_type sky;
render_mode use_half_res_pass; // Ultra optimizado para OpenGL / GLES3

// --- CIELO ---
group_uniforms Sky_Settings;
uniform vec3 top_color : source_color = vec3(0.0, 0.35, 0.75);      
uniform vec3 bottom_color : source_color = vec3(0.98, 0.65, 0.4);   

// --- SOL ---
group_uniforms Sun_Settings;
uniform vec3 sun_color : source_color = vec3(1.0, 0.95, 0.8);
uniform float sun_size : hint_range(0.0, 0.1) = 0.03;
uniform float sun_blur : hint_range(0.0, 0.1) = 0.005;
uniform float sun_intensity : hint_range(1.0, 20.0) = 8.0; // ¡NUEVO! Fuerza la ceguedad del sol

// --- REFLECTOR DE LENTE (LENS FLARE) ---
group_uniforms Lens_Flare_Settings;
uniform vec3 flare_color : source_color = vec3(1.0, 0.7, 0.3);
uniform float flare_intensity : hint_range(0.0, 5.0) = 2.5;

// --- NUBES ---
group_uniforms Cloud_Settings;
uniform vec3 cloud_color : source_color = vec3(1.0, 0.95, 0.9);    
uniform vec3 cloud_shadow : source_color = vec3(0.4, 0.45, 0.55);   
uniform float cloud_coverage : hint_range(0.0, 1.0) = 0.4;          
uniform float cloud_speed : hint_range(0.0, 0.1) = 0.01;           

// Funciones de Noise
float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i + vec2(0.0, 0.0)), hash(i + vec2(1.0, 0.0)), u.x),
	           mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	float value = 0.0;
	float factor = 0.5;
	for (int i = 0; i < 3; i++) { 
		value += factor * noise(p);
		p *= 2.0;
		factor *= 0.5;
	}
	return value;
}

// Funciones para el Lens Flare
float draw_flare_ring(vec3 view_dir, vec3 sun_dir, float dist_factor, float size, float width) {
	vec3 flare_pos = normalize(mix(sun_dir, -sun_dir, dist_factor));
	float d = distance(view_dir, flare_pos);
	return smoothstep(size + width, size, d) * smoothstep(size - width, size, d);
}

float draw_flare_circle(vec3 view_dir, vec3 sun_dir, float dist_factor, float size) {
	vec3 flare_pos = normalize(mix(sun_dir, -sun_dir, dist_factor));
	float d = distance(view_dir, flare_pos);
	return smoothstep(size, 0.0, d);
}

void sky() {
	// 1. CIELO
	float horizon_factor = clamp(abs(EYEDIR.y) / 0.25, 0.0, 1.0);
	vec3 sky_color = mix(bottom_color, top_color, horizon_factor);
	if (EYEDIR.y < 0.0) {
		sky_color = bottom_color;
	}

	// 2. SOL CON INTENSIDAD HDR
	vec3 sun_dir = LIGHT0_DIRECTION;
	float d_to_sun = distance(EYEDIR, sun_dir);
	float sun_mask = smoothstep(sun_size + sun_blur, sun_size, d_to_sun);
	
	// Resplandor del sol más amplio
	float sun_halo = smoothstep(sun_size * 15.0, sun_size, d_to_sun) * 0.6;

	// 3. NUBES
	vec3 final_sky = sky_color;
	if (EYEDIR.y > 0.0) {
		vec2 sky_uv = (EYEDIR.xz / (EYEDIR.y + 0.3)) * 1.5;
		sky_uv += vec2(TIME * cloud_speed, TIME * cloud_speed * 0.5);

		float cloud_noise = fbm(sky_uv);
		float cloud_mask = smoothstep(1.0 - cloud_coverage, 1.0, cloud_noise);

		vec3 cloud_final_color = mix(cloud_shadow, cloud_color, cloud_noise);
		final_sky = mix(final_sky, cloud_final_color, cloud_mask * clamp(EYEDIR.y * 3.0, 0.0, 1.0));
	}

	// 4. APLICAR DISCO SOLAR (CON MULTIPLICADOR HDR)
	vec3 sun_hdr_color = sun_color * sun_intensity; // Esto hace que el Glow de Godot explote en brillo
	final_sky = mix(final_sky, sun_hdr_color, sun_mask);
	final_sky += sun_color * sun_halo * 2.0;

	// 5. REFLECTOR DE LENTE (LENS FLARE)
	float flare_acc = 0.0;
	if (dot(EYEDIR, sun_dir) > 0.0) {
		flare_acc += draw_flare_ring(EYEDIR, sun_dir, 0.08, 0.15, 0.03) * 1.2;
		flare_acc += draw_flare_circle(EYEDIR, sun_dir, 0.15, 0.06) * 0.8;
		flare_acc += draw_flare_circle(EYEDIR, sun_dir, 0.35, 0.10) * 0.5;
		flare_acc += draw_flare_ring(EYEDIR, sun_dir, 0.50, 0.22, 0.02) * 0.6;
		flare_acc += draw_flare_circle(EYEDIR, sun_dir, 0.70, 0.05) * 0.9;
		flare_acc += draw_flare_circle(EYEDIR, sun_dir, 0.90, 0.18) * 0.4;
	}

	final_sky += flare_color * flare_acc * flare_intensity;

	COLOR = final_sky;
}