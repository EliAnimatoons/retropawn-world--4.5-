shader_type canvas_item;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

group_uniforms Warmth_and_Tint;
// Tinte cálido principal (un tono melocotón / rosa / dorado suave)
uniform vec4 warm_tint : source_color = vec4(1.05, 0.98, 0.92, 1.0);
// Saturación para que los colores se sientan alegres pero no chillones
uniform float saturation : hint_range(0.0, 2.0) = 1.15;
uniform float brightness : hint_range(0.5, 1.5) = 1.05;

group_uniforms Soft_Dreamy_Glow;
// Desenfoque suave en las zonas claras para dar sensación de ensueño/fantasia
uniform float glow_intensity : hint_range(0.0, 1.0) = 0.25;
uniform float glow_threshold : hint_range(0.0, 1.0) = 0.6;

group_uniforms Cozy_Vignette;
// En lugar de sombra negra, usamos una viñeta suave en tonos crema/rosa
uniform vec4 vignette_color : source_color = vec4(1.0, 0.92, 0.88, 1.0); // Rosa/crema suave
uniform float vignette_amount : hint_range(0.0, 1.0) = 0.3;
uniform float vignette_softness : hint_range(0.1, 2.0) = 0.8;

// Función para ajustar la saturación de color
vec3 adjust_saturation(vec3 color, float sat) {
	float luma = dot(color, vec3(0.2126, 0.7152, 0.0722));
	return mix(vec3(luma), color, sat);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec4 base_color = texture(SCREEN_TEXTURE, uv);
	vec3 color = base_color.rgb;

	// 1. Simulación de Bloom / Glow suave (Tomamos muestras cercanas para suavizar)
	vec2 texel = SCREEN_PIXEL_SIZE * 2.0;
	vec3 blur = texture(SCREEN_TEXTURE, uv + vec2(-texel.x, -texel.y)).rgb;
	blur += texture(SCREEN_TEXTURE, uv + vec2(texel.x, -texel.y)).rgb;
	blur += texture(SCREEN_TEXTURE, uv + vec2(-texel.x, texel.y)).rgb;
	blur += texture(SCREEN_TEXTURE, uv + vec2(texel.x, texel.y)).rgb;
	blur *= 0.25;

	// Solo aplicamos el brillo a las partes claras de la pantalla
	float luminance = dot(blur, vec3(0.299, 0.587, 0.114));
	if (luminance > glow_threshold) {
		color += blur * glow_intensity * (luminance - glow_threshold);
	}

	// 2. Tinte cálido y ajuste de brillo/saturación
	color *= warm_tint.rgb;
	color *= brightness;
	color = adjust_saturation(color, saturation);

	// 3. Viñeta Pastel / Luz Suave (Bordes claros y no oscuros)
	vec2 position = uv - vec2(0.5);
	float dist = length(position);
	float vignette = smoothstep(0.5 - vignette_amount, 0.5 + vignette_softness, dist);
	
	// Mezclamos el borde hacia el color pastel seleccionado
	color = mix(color, color * vignette_color.rgb + (vignette_color.rgb * 0.15), vignette * vignette_amount);

	COLOR = vec4(color, base_color.a);
}