shader_type canvas_item;

// Puedes ajustar estos valores desde el Inspector
uniform vec3 color = vec3(0.5, 0.6, 0.7); // Color de la niebla
uniform float octaves = 4.0;
uniform float speed = 0.05;
uniform float density = 0.5;

float rand(vec2 coord) {
	return fract(sin(dot(coord, vec2(56, 78)) * 1000.0) * 1000.0);
}

float noise(vec2 coord) {
	vec2 i = floor(coord);
	vec2 f = fract(coord);
	float a = rand(i);
	float b = rand(i + vec2(1.0, 0.0));
	float c = rand(i + vec2(0.0, 1.0));
	float d = rand(i + vec2(1.0, 1.0));
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
}

void fragment() {
	vec2 uv = UV * 3.0;
	float motion = noise(uv + TIME * speed);
	float final_noise = noise(uv + motion);
	
	COLOR = vec4(color, final_noise * density);
}