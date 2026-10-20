extends Camera2D
class_name CamaraBatalla

@export var objetivo_jugador: Node2D
@export var objetivo_jefe: Node2D

@export_category("Encuadre y Zoom")
@export var usar_posicion_fija: bool = true
@export var zoom_arena: Vector2 = Vector2(0.85, 0.85)
@export var zoom_agarre: Vector2 = Vector2(1.25, 1.25)
@export var zoom_bala: Vector2 = Vector2(1.35, 1.35)
@export var zoom_muerte: Vector2 = Vector2(2.5, 2.5) # NUEVO: Controla qué tanto se acerca la cámara al morir

var haciendo_intro: bool = true
var intensidad_sacudida: float = 0.0
var posicion_fija_arena: Vector2 = Vector2.ZERO

# --- ESTADOS Y JUICE ---
var modo_seguimiento_bala: bool = false
var bala_objetivo: Node2D = null
var modo_agarre: bool = false
var tiempo_caminando: float = 0.0
var modo_muerte: bool = false # NUEVO: Bloquea el comportamiento normal si alguien muere

var impact_rect: ColorRect
var fade_rect: ColorRect # NUEVO: La pantalla negra para oscurecer todo

func _ready():
	add_to_group("camera")
	enabled = true
	posicion_fija_arena = global_position
	_preparar_shader_impact_frame()
	_preparar_fade_out() # Preparamos la pantalla de muerte

func _process(delta: float):
	# Si estamos en la intro o en la secuencia de muerte, no hacemos el seguimiento normal
	if haciendo_intro or modo_muerte:
		return

	var pos_deseada: Vector2 = posicion_fija_arena
	var zoom_deseado: Vector2 = zoom_arena

	# 1. SEGUIMIENTO DE BALA PARREADA (Prioridad Maxima)
	if modo_seguimiento_bala and is_instance_valid(bala_objetivo):
		pos_deseada = bala_objetivo.global_position
		zoom_deseado = zoom_bala

	# 2. ZOOM DURANTE EL AGARRE DEL JEFE
	elif modo_agarre and is_instance_valid(objetivo_jugador):
		if is_instance_valid(objetivo_jefe):
			pos_deseada = (objetivo_jugador.global_position + objetivo_jefe.global_position) / 2.0
		else:
			pos_deseada = objetivo_jugador.global_position
		zoom_deseado = zoom_agarre

	# 3. NAVEGACIÓN LIBRE O FIJA EN ARENA CON BALANCEO DE CAMINATA
	else:
		var offset_caminar = Vector2.ZERO
		if is_instance_valid(objetivo_jugador):
			var esta_moviéndose = false
			if "velocity" in objetivo_jugador:
				esta_moviéndose = objetivo_jugador.velocity.length() > 10.0
			elif "velocidad" in objetivo_jugador:
				esta_moviéndose = objetivo_jugador.velocidad.length() > 10.0

			if esta_moviéndose:
				tiempo_caminando += delta * 12.0
				offset_caminar = Vector2(sin(tiempo_caminando) * 4.0, cos(tiempo_caminando * 0.6) * 2.5)

		if not usar_posicion_fija and is_instance_valid(objetivo_jugador) and is_instance_valid(objetivo_jefe):
			pos_deseada = ((objetivo_jugador.global_position + objetivo_jefe.global_position) / 2.0) + offset_caminar
		else:
			pos_deseada = posicion_fija_arena + offset_caminar

	# Lerp suave hacia las posiciones y zoom objetivo
	global_position = global_position.lerp(pos_deseada, 6.0 * delta)
	zoom = zoom.lerp(zoom_deseado, 5.0 * delta)

	# Procesar Shake de impacto
	if intensidad_sacudida > 0:
		intensidad_sacudida = lerp(intensidad_sacudida, 0.0, 7.0 * delta)
		offset = Vector2(randf_range(-intensidad_sacudida, intensidad_sacudida), randf_range(-intensidad_sacudida, intensidad_sacudida))
	else:
		offset = Vector2.ZERO

# --- SISTEMA DE FREEZE FRAME / HITSTOP ---
func aplicar_hitstop(duracion: float = 0.06, escala_tiempo: float = 0.02):
	Engine.time_scale = escala_tiempo
	await get_tree().create_timer(duracion, true, false, true).timeout
	Engine.time_scale = 1.0

# --- CONTROL DE SEGUIMIENTO CINEMATÓGRAFICO ---
func iniciar_seguimiento_bala(bala: Node2D):
	bala_objetivo = bala
	modo_seguimiento_bala = true

func detener_seguimiento_bala():
	modo_seguimiento_bala = false
	bala_objetivo = null

func iniciar_zoom_agarre():
	modo_agarre = true

func detener_zoom_agarre():
	modo_agarre = false

func aplicar_golpe_shake(fuerza: float = 12.0):
	intensidad_sacudida = fuerza

func reproducir_cinematica_intro(pos_jefe: Vector2, pos_jugador: Vector2, callback_al_terminar: Callable):
	haciendo_intro = true
	global_position = pos_jugador
	
	var tw = create_tween().set_parallel(false)
	tw.tween_property(self, "global_position", pos_jefe, 1.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(self, "zoom", Vector2(1.3, 1.3), 1.5)
	tw.tween_interval(0.8)
	tw.tween_property(self, "global_position", posicion_fija_arena, 1.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tw.parallel().tween_property(self, "zoom", zoom_arena, 1.2)
	
	await tw.finished
	haciendo_intro = false
	callback_al_terminar.call()

# --- SECUENCIA DE MUERTE (DIE) ---
func reproducir_animacion_muerte(pos_objetivo: Vector2, callback_al_terminar: Callable = Callable()):
	modo_muerte = true
	intensidad_sacudida = 0.0 # Detenemos cualquier shake para que el zoom sea limpio
	
	var tw = create_tween().set_parallel(true)
	
	# 1. Hacemos zoom dramático y movemos la cámara al cuerpo en 1.5 segundos
	tw.tween_property(self, "global_position", pos_objetivo, 1.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(self, "zoom", zoom_muerte, 1.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	
	# 2. Oscurecemos la pantalla gradualmente a negro (empieza un poco después, a los 0.6 seg)
	tw.tween_property(fade_rect, "color", Color(0, 0, 0, 1.0), 1.2).set_delay(0.6)
	
	await tw.finished
	
	# Llamamos a tu función de fin (ej: abrir la pantalla de "Game Over")
	if callback_al_terminar.is_valid():
		callback_al_terminar.call()

# --- CAPAS VISUALES (UI) ---
func _preparar_fade_out():
	var canvas_layer = CanvasLayer.new()
	canvas_layer.layer = 120 # Lo ponemos por encima del impact frame (layer 100)
	add_child(canvas_layer)
	
	fade_rect = ColorRect.new()
	fade_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade_rect.color = Color(0, 0, 0, 0) # Empieza totalmente transparente
	canvas_layer.add_child(fade_rect)

func disparar_impact_frame(duracion: float = 0.08):
	if not is_instance_valid(impact_rect): return
	impact_rect.visible = true
	var mat = impact_rect.material as ShaderMaterial
	if mat:
		mat.set_shader_parameter("intensity", 1.0)
		mat.set_shader_parameter("invert", randf() > 0.5)
		
	await get_tree().create_timer(duracion, true, false, true).timeout
	if is_instance_valid(impact_rect):
		impact_rect.visible = false

func _preparar_shader_impact_frame():
	var canvas_layer = CanvasLayer.new()
	canvas_layer.layer = 100
	add_child(canvas_layer)
	
	impact_rect = ColorRect.new()
	impact_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	impact_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	impact_rect.visible = false
	
	var shader_code = """
	shader_type canvas_item;
	uniform float threshold : hint_range(0.0, 1.0) = 0.5;
	uniform float smoothness : hint_range(0.0, 0.5) = 0.05;
	uniform vec4 bg_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
	uniform vec4 fg_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
	uniform bool invert = false;
	uniform float intensity : hint_range(0.0, 1.0) = 1.0;
	uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

	void fragment() {
		vec4 screen_color = texture(SCREEN_TEXTURE, SCREEN_UV);
		float luminance = dot(screen_color.rgb, vec3(0.299, 0.587, 0.114));
		float value = smoothstep(threshold - smoothness, threshold + smoothness, luminance);
		vec4 final_color = mix(bg_color, fg_color, value);
		if (invert) final_color = mix(fg_color, bg_color, value);
		COLOR = mix(screen_color, final_color, intensity);
	}
	"""
	var mat = ShaderMaterial.new()
	var shader = Shader.new()
	shader.code = shader_code
	mat.shader = shader
	impact_rect.material = mat
	canvas_layer.add_child(impact_rect)
