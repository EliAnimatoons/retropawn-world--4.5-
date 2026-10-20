shader_type spatial;
render_mode unshaded, blend_add, cull_disabled;

uniform vec4 core_color : source_color = vec4(1.0, 0.8, 0.2, 1.0);
uniform float speed = 5.0;
uniform sampler2D noise_tex; // Aquí ponés cualquier textura de ruido de Godot

void fragment() {
	// mUV ajustado para que la bala se estire horizontalmente
	vec2 mUV = UV;
	float time = TIME * speed;
	
	// Doble lectura de ruido para crear el efecto de fuego/plasma
	float n1 = texture(noise_tex, vec2(mUV.x - time, mUV.y)).r;
	float n2 = texture(noise_tex, vec2(mUV.x * 0.5 - time * 0.8, mUV.y * 1.5)).r;
	float final_noise = n1 * n2;
	
	// Máscara para que la bala tenga forma de gota o punta
	float mask = smoothstep(0.5, 0.0, length(UV - vec2(0.2, 0.5))); // Punta
	float tail = smoothstep(1.0, 0.0, UV.x); // Estela que se apaga
	
	float intensity = final_noise * mask * tail;
	
	ALBEDO = core_color.rgb * intensity * 3.0;
	ALPHA = clamp(intensity, 0.0, 1.0);
}