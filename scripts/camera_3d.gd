extends Camera3D

@export var offset_pos : Vector3 = Vector3(0, 1.5, 5.0)          # Posición normal
@export var offset_pos_zoom : Vector3 = Vector3(0, 0.8, 3.0)     # Posición física durante Zoom
@export var smooth_speed : float = 4.0
var target = null

# --- CONFIGURACIÓN DE ZOOM ---
@export var fov_glory_kill: float = 25.0        # FOV de zoom cerrado
@export var fov_grab: float = 30.0              # FOV para cuando te agarran
@export var zoom_speed: float = 3.0             # Velocidad del zoom y reposicionamiento
@export var max_shake_glory_kill: float = 0.35 
@export var shake_grab_constante: float = 0.15 

# --- PUNTO DE ENFOQUE (LOOK AT) ---
@export var look_target_offset_normal: Vector3 = Vector3(0, 1.0, 0) # Altura a la que mira normalmente
@export var look_target_offset_zoom: Vector3 = Vector3(0, 0.5, 0)   # Altura a la que mira en Zoom

# --- CONFIGURACIÓN DE BAILE (TIKTOK EDIT) ---
@export_group("Dance Camera Settings")
@export var dance_orbit_speed: float = 1.2       # Velocidad de giro alrededor del jugador
@export var dance_height_base: float = 1.2       # Altura media de la cámara
@export var dance_height_variation: float = 1.0  # Cuánto sube y baja (contrapicados)
@export var dance_radius_base: float = 3.0       # Distancia base
@export var dance_radius_variation: float = 1.0  # Cuánto se acerca/aleja
@export var fov_dance: float = 65.0              # FOV ligeramente más cerrado para el edit

var _dance_orbit_angle: float = 0.0
var _dance_time: float = 0.0
var _was_dancing: bool = false

# Referencia al ColorRect con el Shader de Impacto
@export var impact_frame_rect: ColorRect

# --- CONFIGURACIÓN DEL SUNLIGHT (SUN FLARE) ---
@export_group("Sunlight Settings")
@export var sun_flare_texture_rect: TextureRect # Arrastra aquí tu TextureRect con el Sunlight
@export var luz_sol: DirectionalLight3D         # Opcional: Arrastra tu DirectionalLight3D
@export var sun_fade_speed: float = 4.0          # Velocidad de entrada y salida (Fade)
@export var sun_angle_threshold: float = 0.2     # Sensibilidad (0.2 para 2.5D/3D)

var fov_normal: float
var current_offset: Vector3
var current_look_offset: Vector3

var shake_strength = 0.0
var shake_decay = 2.0 
var current_shake_offset = Vector3.ZERO

# --- OPTIMIZACIÓN DE RAYCAST DE SOL ---
var _timer_oclusion: float = 0.0
var _sol_esta_visible: bool = true

# ==========================================
# --- EFECTOS APOCALÍPTICOS ---
# ==========================================
@export_group("Apocalipsis Settings")
@export var offset_apocalipsis: Vector3 = Vector3(0, 5.5, 7.0)      # Vista elevada y alejada durante el colapso
@export var look_offset_apocalipsis: Vector3 = Vector3(0, -0.5, 0)  # Mirando un poco hacia abajo, hacia el jugador
@export var fov_apocalipsis: float = 55.0                            # FOV mas abierto, sensacion de "vista general"
@export var apocalipsis_transition_speed: float = 1.5                # Que tan rapido gira/sube la camara al entrar
var _modo_apocalipsis: bool = false
var _intensidad_apocalipsis: float = 0.0
var _tiempo_apocalipsis: float = 0.0

func _ready():
	fov_normal = fov
	current_offset = offset_pos
	current_look_offset = look_target_offset_normal

	if not impact_frame_rect:
		var nodos = get_tree().get_nodes_in_group("impact_frame")
		if nodos.size() > 0:
			impact_frame_rect = nodos[0] as ColorRect

	# Búsqueda automática del TextureRect del sol si no fue asignado en el Inspector
	if not sun_flare_texture_rect:
		var nodos_flare = get_tree().get_nodes_in_group("sun_flare_ui")
		if nodos_flare.size() > 0 and nodos_flare[0] is TextureRect:
			sun_flare_texture_rect = nodos_flare[0] as TextureRect
		else:
			sun_flare_texture_rect = find_child("*SunFlare*", true, false) as TextureRect

	if sun_flare_texture_rect:
		sun_flare_texture_rect.modulate.a = 0.0

func _process(delta):
	# --- BÚSQUEDA DEL JUGADOR ---
	if target == null or not is_instance_valid(target) or not target is Node3D:
		target = null
		var players = get_tree().get_nodes_in_group("player")
		for p in players:
			if is_instance_valid(p) and p is Node3D:
				target = p
				break

		if target == null:
			_procesar_sunlight_flare(delta) # Actualizar sol aunque aún no haya jugador
			return 

	if not target.is_inside_tree():
		return

	# Procesar Lógica de Zoom, Offset y Efectos
	_procesar_efectos_camara(delta)

	# Procesar Lógica de Apocalipsis / Jumpscare
	_procesar_apocalipsis(delta)

	# Procesar Destello del Sol con Oclusión Optimizada
	_procesar_sunlight_flare(delta)

	# --- SHAKE ---
	if shake_strength > 0:
		current_shake_offset.x = randf_range(-shake_strength, shake_strength)
		current_shake_offset.y = randf_range(-shake_strength, shake_strength)
		current_shake_offset.z = randf_range(-shake_strength, shake_strength)
		shake_strength = move_toward(shake_strength, 0, shake_decay * delta)
	else:
		current_shake_offset = Vector3.ZERO

	# --- SEGUIMIENTO DE POSICIÓN DINÁMICO ---
	var desired_position = target.global_position + current_offset + current_shake_offset
	global_position = global_position.lerp(desired_position, smooth_speed * delta)

	# --- ENFOQUE DINÁMICO (LOOK AT) ---
	var look_target = target.global_position + current_look_offset
	look_at(look_target)


func _procesar_efectos_camara(delta: float) -> void:
	var esta_en_glory_kill: bool = false
	var esta_agarrado: bool = false
	var esta_bailando: bool = false

	# Detectar estados del jugador
	if "haciendo_glory_kill" in target:
		esta_en_glory_kill = target.haciendo_glory_kill
	elif "siendo_ejecutado" in target:
		esta_en_glory_kill = target.siendo_ejecutado

	if "siendo_agarrado" in target:
		esta_agarrado = target.siendo_agarrado
		
	if "is_dancing" in target:
		esta_bailando = target.is_dancing

	# 1. Lógica de Glory Kill
	if esta_en_glory_kill:
		fov = move_toward(fov, fov_glory_kill, zoom_speed * 10.0 * delta)
		current_offset = current_offset.lerp(offset_pos_zoom, zoom_speed * delta)
		current_look_offset = current_look_offset.lerp(look_target_offset_zoom, zoom_speed * delta)

		var progreso: float = clamp(inverse_lerp(fov_normal, fov_glory_kill, fov), 0.0, 1.0)
		shake_strength = progreso * max_shake_glory_kill
		_set_shader_intensity(pow(progreso, 2.0))

	# 2. Lógica de Agarre
	elif esta_agarrado:
		fov = move_toward(fov, fov_grab, zoom_speed * 10.0 * delta)
		current_offset = current_offset.lerp(offset_pos_zoom, zoom_speed * delta)
		current_look_offset = current_look_offset.lerp(look_target_offset_zoom, zoom_speed * delta)

		apply_shake(shake_grab_constante)
		_set_shader_intensity(0.5)

	# 3. Lógica de Baile (TikTok Edit Mode)
	elif esta_bailando:
		if not _was_dancing:
			# Inicializar el ángulo para que empiece a rotar desde la posición ACTUAL de la cámara
			_dance_orbit_angle = atan2(current_offset.z, current_offset.x)
			_dance_time = 0.0
			
		_dance_time += delta
		_dance_orbit_angle += dance_orbit_speed * delta
		
		# Ondas matemáticas para simular al camarógrafo (Radio y Altura dinámicas)
		var radio_actual = dance_radius_base + (sin(_dance_time * 1.5) * dance_radius_variation)
		var altura_actual = dance_height_base + (sin(_dance_time * 2.1) * dance_height_variation)
		
		# Posición orbital
		var target_dance_offset = Vector3(
			cos(_dance_orbit_angle) * radio_actual,
			altura_actual,
			sin(_dance_orbit_angle) * radio_actual
		)
		
		# Lerp hacia el modo baile
		current_offset = current_offset.lerp(target_dance_offset, zoom_speed * delta)
		current_look_offset = current_look_offset.lerp(Vector3(0, 1.2, 0), zoom_speed * delta) # Enfoca al pecho/cara
		fov = move_toward(fov, fov_dance, zoom_speed * 5.0 * delta)
		_set_shader_intensity(0.0)

	# 4. Lógica de Apocalipsis/Colapso: vista elevada y alejada (NUEVO)
	# FIX: antes esto vivía como "if not _modo_apocalipsis" DENTRO del bloque normal,
	# lo que bloqueaba el reset de la cámara para siempre una vez arrancaba el apocalipsis
	# (zoom/giros previos se quedaban pegados). Ahora es su propia rama con prioridad
	# propia, y el estado normal de abajo corre siempre que no estemos en ninguna de las 4.
	elif _modo_apocalipsis:
		fov = move_toward(fov, fov_apocalipsis, apocalipsis_transition_speed * 5.0 * delta)
		current_offset = current_offset.lerp(offset_apocalipsis, apocalipsis_transition_speed * delta)
		current_look_offset = current_look_offset.lerp(look_offset_apocalipsis, apocalipsis_transition_speed * delta)
		_set_shader_intensity(0.0)

	# 5. Estado Normal (Gameplay)
	else:
		fov = move_toward(fov, fov_normal, zoom_speed * 15.0 * delta)
		current_offset = current_offset.lerp(offset_pos, zoom_speed * delta)
		current_look_offset = current_look_offset.lerp(look_target_offset_normal, zoom_speed * delta)
		_set_shader_intensity(0.0)

	# Guardamos el estado para el frame siguiente
	_was_dancing = esta_bailando


# --- LÓGICA CON RAYCAST ULTRA OPTIMIZADO ---
func _procesar_sunlight_flare(delta: float) -> void:
	if not is_instance_valid(sun_flare_texture_rect):
		return

	if not is_instance_valid(luz_sol):
		luz_sol = get_tree().root.find_child("DirectionalLight3D", true, false) as DirectionalLight3D
		if not luz_sol:
			return

	var dir_sol: Vector3 = luz_sol.global_transform.basis.z.normalized()
	var dir_camara: Vector3 = -global_transform.basis.z.normalized()

	var alineacion: float = dir_camara.dot(dir_sol)
	var opacidad_objetivo: float = 0.0

	if alineacion > sun_angle_threshold:
		# Lanza el rayo de comprobación solo 6 veces por segundo (cada 0.15s)
		_timer_oclusion += delta
		if _timer_oclusion >= 0.15:
			_timer_oclusion = 0.0
			_sol_esta_visible = _comprobar_sol_visible(dir_sol)

		if _sol_esta_visible:
			var t = remap(alineacion, sun_angle_threshold, 1.0, 0.0, 1.0)
			opacidad_objetivo = clamp(t, 0.0, 1.0)

	# Transición suave (Fade-In / Fade-Out)
	sun_flare_texture_rect.modulate.a = lerp(sun_flare_texture_rect.modulate.a, opacidad_objetivo, sun_fade_speed * delta)


# Lanzador del rayo
func _comprobar_sol_visible(dir_sol: Vector3) -> bool:
	var espacio_3d = get_world_3d().direct_space_state
	if not espacio_3d: return true

	var origen_rayo = global_position
	var destino_rayo = global_position + (dir_sol * 100.0)

	var query = PhysicsRayQueryParameters3D.create(origen_rayo, destino_rayo)

	# Excluimos al jugador para que su propio colisionador no tape la cámara
	if is_instance_valid(target):
		query.exclude = [target.get_rid()]

	var resultado = espacio_3d.intersect_ray(query)

	# Si no choca con nada, el sol se ve
	return resultado.is_empty()


func _set_shader_intensity(valor: float) -> void:
	if impact_frame_rect and impact_frame_rect.material:
		var shader_mat = impact_frame_rect.material as ShaderMaterial
		shader_mat.set_shader_parameter("intensity", valor)


func apply_shake(strength: float):
	shake_strength = strength

# ==========================================
# --- FUNCIONES DE CÁMARA APOCALÍPTICA ---
# ==========================================
func _procesar_apocalipsis(delta: float):
	if _modo_apocalipsis:
		_tiempo_apocalipsis += delta * 12.0 # Velocidad del temblor (fluida)
		
		# Generamos un balanceo rítmico e inquietante en 2D aplicado al 3D, sin sacudir la escena
		var noise_x = sin(_tiempo_apocalipsis) * _intensidad_apocalipsis
		var noise_y = cos(_tiempo_apocalipsis * 1.3) * _intensidad_apocalipsis
		
		# Aplicamos usando los offset nativos de la cámara para que sea cinemático
		h_offset = noise_x
		v_offset = noise_y
	else:
		# Si se detiene forzosamente aseguramos que regrese a 0 suavemente
		h_offset = lerp(h_offset, 0.0, delta * 5.0)
		v_offset = lerp(v_offset, 0.0, delta * 5.0)

func iniciar_apocalipsis():
	_modo_apocalipsis = true
	# Intensidad BAJA para que moleste poco pero sume tensión
	_intensidad_apocalipsis = 0.08 
	_tiempo_apocalipsis = 0.0

func detener_apocalipsis():
	_modo_apocalipsis = false
	var tw = create_tween()
	# Volvemos la cámara a su centro suavemente
	tw.tween_property(self, "h_offset", 0.0, 0.5)
	tw.tween_property(self, "v_offset", 0.0, 0.5)
