shader_type spatial;
render_mode unshaded, blend_add, cull_disabled; // cull_disabled para que se vea de ambos lados

uniform vec4 fire_color : source_color = vec4(1.0, 0.4, 0.1, 1.0);
uniform float speed = 0.8; // Controla qué tan rápido suben las llamas
uniform float fire_scale = 3.0; // Controla el tamaño de las "bolas" de fuego

float rand(vec2 co) {
    return fract(sin(dot(co.xy ,vec2(12.9898,78.233))) * 43758.5453);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    float a = rand(i);
    float b = rand(i + vec2(1.0, 0.0));
    float c = rand(i + vec2(0.0, 1.0));
    float d = rand(i + vec2(1.0, 1.0));
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void fragment() {
    // Usamos UV para que el fuego se adapte al plano
    vec2 uv = UV;
    
    // Creamos dos capas de movimiento para que el fuego se vea errático
    float movement = TIME * speed;
    
    // Capa 1: Sube hacia arriba
    float n = noise(uv * fire_scale + vec2(0.0, movement));
    
    // Capa 2: Se mueve un poco hacia los lados y más rápido (distorsión)
    n += noise(uv * (fire_scale * 1.5) - vec2(sin(TIME) * 0.2, movement * 1.2)) * 0.5;
    
    // El gradiente hace que la base sea sólida y la punta se desvanezca
    // uv.y en Godot 3D va de 0 (arriba) a 1 (abajo) o viceversa según el Mesh
    // Si ves que sale al revés, cambia (1.0 - uv.y) por (uv.y)
    float gradient = pow(1.0 - uv.y, 2.5);
    
    float final_fire = n * gradient;
    
    ALBEDO = fire_color.rgb * final_fire * 2.5; // Multiplicamos por 2.5 para que brille
    ALPHA = clamp(final_fire, 0.0, 1.0);
}