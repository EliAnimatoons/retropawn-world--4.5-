extends CharacterBody3D

signal ataque_inminente(minion_ref)

@export var speed = 1.5
@export var detection_range = 5.0
@export var stop_range = 1.0

var escena_drop = preload("res://scenes/ItemDrop.tscn")
var ESCENA_SANGRE = preload("res://scenes/SangreMorada.tscn")

var health = 25
var max_health_ref = 25
var knockback_velocity = Vector3.ZERO
var is_stunned = false
var can_attack = true
var esta_muerto = false
var tutorial_congelado = false

#variable de cantar, pachonchito canta (poné probabilidad_canto = 0 para desactivarlo)
var is_singing = false
var ya_intento_cantar = false
@export var probabilidad_canto: float = 1

# =========================================================
# --- DAÑO (valores del script nuevo) ---
# =========================================================
@export_group("Daño")
@export var dano_normal: int = 4
@export var dano_berserker: int = 7
@export var dano_extra_imparable: int = 5
@export var dano_slide_normal: int = 5
@export var dano_slide_berserker: int = 7
# Daño que se come el minion cuando el jugador le hace parry (en el viejo era 5).
@export var dano_propio_por_parry: int = 5
@export_group("Ritmo de combate (valores del script viejo)")
@export var probabilidad_imparable: float = 0.20
@export var cooldown_ataque_normal: float = 2.5
@export var cooldown_ataque_berserker: float = 1.0
@export var duracion_stun_parry: float = 3.0
@export_group("")

# --- VARIABLES IA AVANCED ---
var detectado_permanentemente = false
var en_modo_berserker = false
var es_ataque_imparable = false
var angulo_flanqueo = 0.0
var tiempo_cambio_flanqueo = 0.0
var tiempo_proxima_esquiva = 0.0
var ya_llamo_refuerzos = false
var huyendo_al_lider = false
var tiempo_proxima_voz_idle = 0.0

# --- SISTEMA ANTI-QUILOMBO DE AUDIO ---
static var alguien_hablando_idle = false
var puede_reproducir_voz_combate = true

# --- AJUSTES DE RAREZA ---
var chance_voz_idle = 0.05
var chance_voz_dano = 0.25
var chance_voz_ataque = 0.35

# --- VARIABLES DE CAÍDA Y GOOFY ---
var esta_cayendo = false
var tiempo_en_aire = 0.0
var UMBRAL_CAIDA = 0.4
var modo_chicle = false

# --- GLORY KILL MINION LOGIC ---
var es_ejecutable: bool = false
var es_executable: bool = false
var siendo_ejecutado: bool = false
var area_deteccion_gk: Area3D = null
var _tween_ejecutable: Tween = null
var _ejecucion_terminada: bool = false

# --- SISTEMA DE AGARRE (GRAB) ---
var agarrando_a_sketch: bool = false
var cooldown_agarre: float = 2.0
const TIEMPO_COOLDOWN_AGARRE = 12.0
var grab_damage_timer: float = 0.0
@export var probabilidad_agarre: float = 0.25

# --- 1) PRIMER AVISO (NOTICE) ---
var ya_reacciono_primera_vez = false
@export var duracion_reaccion_notice: float = 0.35

# --- 2) BÚSQUEDA (SEARCH) al perder al jugador ---
var buscando_jugador = false
var ultima_pos_conocida_jugador = Vector3.ZERO
var tiempo_buscando = 0.0
@export var tiempo_max_busqueda: float = 4.0
@export var factor_perdida_vision: float = 1.8

# --- 3) AMAGUE (FEINT) ---
@export var probabilidad_amague: float = 0.18
var tiempo_proximo_amague_permitido = 0.0

# --- 4) BURLA (TAUNT) ---
@export var probabilidad_burla: float = 0.10
var tiempo_proxima_burla_permitida = 0.0

# --- 5) COORDINACIÓN DE FLANQUEO ---
var lado_flanqueo_asignado: int = 0
var tiempo_recalculo_flanqueo = 0.0

# --- 6) BLOQUEO (BLOCK) ---
@export var probabilidad_bloqueo: float = 0.25

# --- 7) LLAMADA DE REFUERZOS ---
@export var probabilidad_llamada_refuerzos: float = 0.15
var tiempo_proximo_chequeo_horda = 0.0
@export var tope_global_minions: int = 140

# --- 8) EVASIÓN DE PAREDES ---
@export var distancia_deteccion_pared: float = 0.6
@export var fuerza_evasion_pared: float = 1.3

# --- 9) SLIDE TACKLE (DERRAPE) - MUY RARO ---
@export_group("Slide (raro)")
# Chance por chequeo (se chequea como mucho cada 0.6 s cuando el jugador esta a rango de slide).
@export var probabilidad_slide: float = 0.03
@export var rango_min_slide: float = 2.0
@export var rango_max_slide: float = 4.5
@export var cooldown_slide_min: float = 15.0
@export var cooldown_slide_max: float = 25.0
@export var velocidad_slide: float = 6.0
@export var duracion_slide: float = 0.55
@export_group("")
var tiempo_proximo_slide_permitido: float = 0.0
var _slide_activo: bool = false

# --- STUN POR PARRY ---
var en_stun_parry: bool = false
var _id_stun: int = 0

const ANIMS_NO_PISAR: Array = ["grow", "parry", "call_help", "attack", "fall", "goofy", "minion grab sketch", "minion grab jane", "minion grab nubbe", "minion grab alloy", "notice", "feint", "taunt", "block", "slide"]
# Animaciones "de una sola vez": si tienen Loop activado "animation_finished" no se emite,
# asi que se trata la primera vuelta como el final.
const ANIMS_UNA_VEZ: Array = ["hurt", "attack", "parry", "block", "notice", "feint", "taunt", "call_help", "grow"]

# =========================================================
# --- OPTIMIZACIÓN ANTI-LAG ---
# =========================================================
var _tiempo_proximo_rechequeo_objetivo: int = 0
const INTERVALO_RECHEQUEO_OBJETIVO_MS: int = 200
var _stagger_offset: int = 0

static var _cache_enemigos: Array = []
static var _cache_enemigos_ms: int = 0
static var _cache_objetivos: Array = []
static var _cache_objetivos_ms: int = 0

var _zona_instructor = null
var _zona_instructor_buscada: bool = false

var _ultima_pos_valida: Vector3 = Vector3.ZERO

@onready var sprite = $AnimatedSprite3D
@onready var health_bar = $BarraVisual/SubViewport/ProgressBar
@onready var fly_audio = $FlySound
@onready var killhim_sprite = $Killhim

var _killhim_pos_base: Vector3 = Vector3.ZERO

var player = null


# =========================================================
# --- HELPERS ANTI-NaN Y CACHE ---
# =========================================================
func direccion_segura(desde: Vector3, hacia: Vector3, fallback := Vector3.FORWARD) -> Vector3:
	if not desde.is_finite() or not hacia.is_finite():
		return fallback
	var diff = hacia - desde
	if not diff.is_finite() or diff.length_squared() < 0.0001:
		return fallback
	return diff.normalized()


func obtener_enemigos() -> Array:
	var ahora = Time.get_ticks_msec()
	if ahora >= _cache_enemigos_ms:
		_cache_enemigos_ms = ahora + 250
		_cache_enemigos = get_tree().get_nodes_in_group("enemies")
	return _cache_enemigos


func obtener_objetivos() -> Array:
	var ahora = Time.get_ticks_msec()
	if ahora >= _cache_objetivos_ms:
		_cache_objetivos_ms = ahora + 200
		_cache_objetivos = get_tree().get_nodes_in_group("player") + get_tree().get_nodes_in_group("allies")
	return _cache_objetivos


func obtener_zona_instructor():
	if not _zona_instructor_buscada:
		_zona_instructor_buscada = true
		_zona_instructor = get_tree().current_scene.find_child("ZonaInstructor", true, false)
	if _zona_instructor and not is_instance_valid(_zona_instructor):
		_zona_instructor = null
	return _zona_instructor


# Devuelve true si el minion ya no esta en condiciones de seguir una accion
# (murio, lo ejecutan, quedo KO o salio del arbol).
func _accion_cortada() -> bool:
	return not is_inside_tree() or esta_muerto or siendo_ejecutado or es_ejecutable


func _restaurar_tinte() -> void:
	if es_ejecutable or siendo_ejecutado or en_stun_parry:
		return
	sprite.modulate = Color(1.5, 0.5, 0.5) if en_modo_berserker else Color(1, 1, 1)


func _ready():
	if get_tree().current_scene.name != "NivelTutorial":
		tutorial_congelado = false
		is_stunned = false
	velocity.y = -2.0
	add_to_group("enemies")
	max_health_ref = health
	player = get_tree().get_first_node_in_group("player")
	angulo_flanqueo = randf_range(-0.8, 0.8)
	_stagger_offset = randi() % 4
	_ultima_pos_valida = global_position

	max_slides = 2
	safe_margin = 0.06

	if not sprite.animation_finished.is_connected(_on_animated_sprite_3d_animation_finished):
		sprite.animation_finished.connect(_on_animated_sprite_3d_animation_finished)
	if not sprite.animation_looped.is_connected(_on_animated_sprite_3d_animation_looped):
		sprite.animation_looped.connect(_on_animated_sprite_3d_animation_looped)

	if has_node("BarraVisual"):
		$BarraVisual.visible = false
		if has_node("BarraVisual/SubViewport"):
			$BarraVisual/SubViewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE

	if killhim_sprite:
		_killhim_pos_base = killhim_sprite.position
		killhim_sprite.visible = false

	if sprite.sprite_frames.has_animation("grow"):
		sprite.play("grow")
		is_stunned = true
		await get_tree().create_timer(0.6).timeout
		if not _accion_cortada(): is_stunned = false

	if health_bar:
		health_bar.max_value = health
		health_bar.value = health
		health_bar.modulate = Color.GREEN
	else:
		print("¡ADVERTENCIA!: No se encontró Barra en ", name)


func _exit_tree():
	if agarrando_a_sketch and player and is_instance_valid(player):
		if player.has_method("remove_collision_exception_with"):
			player.remove_collision_exception_with(self)
		if player.has_method("liberado_de_agarre"):
			player.liberado_de_agarre()


# =========================================================
# --- MOVIMIENTO SEGURO (ANTI-NaN) ---
# =========================================================
const KNOCKBACK_MAXIMO: float = 30.0
const VELOCIDAD_HORIZONTAL_MAXIMA: float = 40.0
const EPSILON_VELOCIDAD: float = 0.001

static var _knockbacks_este_frame: int = 0
static var _frame_de_knockbacks: int = -1
const MAX_KNOCKBACKS_DUROS_POR_FRAME: int = 6

func _puede_recibir_knockback_duro() -> bool:
	var frame_actual = Engine.get_physics_frames()
	if frame_actual != _frame_de_knockbacks:
		_frame_de_knockbacks = frame_actual
		_knockbacks_este_frame = 0
	if _knockbacks_este_frame < MAX_KNOCKBACKS_DUROS_POR_FRAME:
		_knockbacks_este_frame += 1
		return true
	return false


func _mover_seguro() -> void:
	if not global_position.is_finite():
		global_position = _ultima_pos_valida
		velocity = Vector3.ZERO
		knockback_velocity = Vector3.ZERO
	else:
		_ultima_pos_valida = global_position

	aplicar_limite_de_velocidad_seguro()

	if not velocity.is_finite():
		velocity = Vector3.ZERO

	move_and_slide()

	if not global_position.is_finite():
		global_position = _ultima_pos_valida
		velocity = Vector3.ZERO
		knockback_velocity = Vector3.ZERO
	if not velocity.is_finite():
		velocity = Vector3.ZERO


func aplicar_limite_de_velocidad_seguro():
	if not is_finite(velocity.y):
		velocity.y = 0.0
	velocity.y = clampf(velocity.y, -60.0, 60.0)
	var horizontal = Vector3(velocity.x, 0, velocity.z)
	if not horizontal.is_finite():
		velocity.x = 0.0
		velocity.z = 0.0
	elif horizontal.length() > VELOCIDAD_HORIZONTAL_MAXIMA:
		horizontal = horizontal.limit_length(VELOCIDAD_HORIZONTAL_MAXIMA)
		velocity.x = horizontal.x
		velocity.z = horizontal.z

	if abs(velocity.x) < EPSILON_VELOCIDAD:
		velocity.x = 0.0
	if abs(velocity.z) < EPSILON_VELOCIDAD:
		velocity.z = 0.0


func aplicar_knockback(dir: Vector3, fuerza: float) -> void:
	if not dir.is_finite():
		knockback_velocity = Vector3.ZERO
		return
	var k = dir * fuerza
	if not k.is_finite():
		knockback_velocity = Vector3.ZERO
		return
	knockback_velocity = k.limit_length(KNOCKBACK_MAXIMO)


# =========================================================
# --- CANTO SOLITARIO ---
# =========================================================
func chequear_canto_solitario():
	ya_intento_cantar = true
	var solo_yo = true
	for e in obtener_enemigos():
		if e != self and is_instance_valid(e) and not e.get("esta_muerto"):
			solo_yo = false
			break
	if solo_yo and randf() <= probabilidad_canto:
		print("¡El minion se quedó solo y canta!")
		iniciar_canto()


func iniciar_canto():
	is_singing = true
	is_stunned = true
	can_attack = false
	velocity = Vector3.ZERO
	if sprite.sprite_frames.has_animation("minion singing"):
		sprite.play("minion singing")
	if has_node("AudioCanto"):
		$AudioCanto.play()
	await get_tree().create_timer(4.5).timeout
	if is_inside_tree() and not esta_muerto and not siendo_ejecutado and is_singing:
		terminar_canto()


func terminar_canto():
	if not is_singing: return
	is_singing = false
	is_stunned = false
	can_attack = true
	if has_node("AudioCanto"):
		$AudioCanto.stop()
	if not esta_muerto and not siendo_ejecutado:
		sprite.play("idle")


# =========================================================
# --- LOOP PRINCIPAL ---
# =========================================================
func _physics_process(delta):
	if Engine.time_scale <= 0.0:
		return
	if siendo_ejecutado:
		velocity = Vector3.ZERO
		return
	if is_singing:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)
		_mover_seguro()
		return

	if cooldown_agarre > 0.0:
		cooldown_agarre -= delta

	if agarrando_a_sketch:
		velocity = Vector3.ZERO
		if player and is_instance_valid(player):
			# Si el jugador rechazo el agarre (glory kill, invulnerable, modo super...) soltamos.
			if "siendo_agarrado" in player and not player.siendo_agarrado:
				soltar_a_sketch(false)
				return
			if global_position.is_finite():
				var offset_agarre = Vector3(0.5 if sprite.flip_h else -0.5, 0, 0)
				player.global_position = global_position + offset_agarre
			grab_damage_timer += delta
			if grab_damage_timer >= 0.6:
				grab_damage_timer = 0.0
				if player.has_method("take_damage"):
					player.take_damage(2, global_position)
		else:
			soltar_a_sketch(false)
		_mover_seguro()
		return

	# Buscar objetivo mas cercano (throttled para no matar la CPU con muchos minions)
	var ahora_ms = Time.get_ticks_msec()
	if ahora_ms >= _tiempo_proximo_rechequeo_objetivo:
		_tiempo_proximo_rechequeo_objetivo = ahora_ms + INTERVALO_RECHEQUEO_OBJETIVO_MS
		var mas_cercano = null
		var dist_minima = 9999.0
		for p in obtener_objetivos():
			if is_instance_valid(p) and "global_position" in p and p.global_position is Vector3:
				if not p.global_position.is_finite(): continue
				var d = global_position.distance_to(p.global_position)
				if d < dist_minima:
					dist_minima = d
					mas_cercano = p
		if mas_cercano:
			player = mas_cercano

	if player == null or !is_instance_valid(player) or not (player.global_position is Vector3):
		player = get_tree().get_first_node_in_group("player")
		return

	if modo_chicle:
		if not is_on_floor():
			velocity.y -= 18.0 * delta
		else:
			velocity.y = -0.1
		velocity.x = 0
		velocity.z = 0
		_mover_seguro()
		return

	if tutorial_congelado:
		velocity.x = 0
		velocity.z = 0
		return

	comprobar_estado_berserker()

	if not is_on_floor():
		velocity.y -= 18.0 * delta
		tiempo_en_aire += delta
		if tiempo_en_aire > UMBRAL_CAIDA and velocity.y < -4.0 and not esta_cayendo and not esta_muerto:
			esta_cayendo = true
			sprite.play("fall")
	elif velocity.y < 0:
		tiempo_en_aire = 0.0
		if esta_cayendo:
			esta_cayendo = false
			activar_efecto_chicle()
		velocity.y = -0.1

	if not knockback_velocity.is_finite():
		knockback_velocity = Vector3.ZERO

	if knockback_velocity.length() > 0.1:
		velocity.x = knockback_velocity.x
		velocity.z = knockback_velocity.z
		if knockback_velocity.y != 0: velocity.y = knockback_velocity.y
		var friccion = 1.0 if esta_muerto and knockback_velocity.y > 2.0 else 35.0
		knockback_velocity = knockback_velocity.move_toward(Vector3.ZERO, delta * friccion)
		if esta_muerto and knockback_velocity.y > 3.0:
			sprite.rotation.z += delta * 30.0
			sprite.rotation.x += delta * 15.0

	elif not is_stunned and player and not esta_cayendo:
		var dist = global_position.distance_to(player.global_position)

		var rango_actual = detection_range
		if PocionManager.invisible:
			rango_actual = 0.5

		if health < max_health_ref * 0.35:
			if not ya_intento_cantar:
				chequear_canto_solitario()
			var lider = get_tree().get_first_node_in_group("boss")
			if lider and is_instance_valid(lider):
				huyendo_al_lider = true
				seguir_al_lider(lider)
			else:
				huyendo_al_lider = false
		else:
			huyendo_al_lider = false

		if not huyendo_al_lider:
			if dist < 1.6 and not can_attack and Time.get_ticks_msec() > tiempo_proxima_esquiva:
				intentar_esquiva_tactica()

			if dist < rango_actual or detectado_permanentemente:
				# reacción de "primer aviso"
				if not ya_reacciono_primera_vez:
					reaccionar_primer_aviso()
					return

				detectado_permanentemente = true
				buscando_jugador = false
				ultima_pos_conocida_jugador = player.global_position
				tiempo_buscando = 0.0

				if not ya_llamo_refuerzos:
					chequear_llamada_horda()

				follow_player_smart(dist, delta)

			elif detectado_permanentemente and dist < rango_actual * factor_perdida_vision:
				# todavía lo tiene a la vista aunque salió del rango base
				ultima_pos_conocida_jugador = player.global_position
				follow_player_smart(dist, delta)

			elif detectado_permanentemente:
				# perdió al jugador, va a buscarlo antes de rendirse
				buscar_jugador_perdido(delta)

			else:
				velocity.x = move_toward(velocity.x, 0, speed)
				velocity.z = move_toward(velocity.z, 0, speed)
				if not str(sprite.animation) in ANIMS_NO_PISAR:
					sprite.play("idle")
					if Time.get_ticks_msec() > tiempo_proxima_voz_idle and not alguien_hablando_idle:
						if randf() < chance_voz_idle:
							alguien_hablando_idle = true
							EfectosManager.play_minion_voice("idle", global_position)
							await get_tree().create_timer(2.0).timeout
							alguien_hablando_idle = false
						tiempo_proxima_voz_idle = Time.get_ticks_msec() + randf_range(15000, 30000)
	else:
		if not siendo_ejecutado:
			velocity.x = move_toward(velocity.x, 0, speed)
			velocity.z = move_toward(velocity.z, 0, speed)

	# Durante el slide el movimiento lo hace la propia corrutina del slide
	if not _slide_activo:
		# Anti-lag: amontonamiento y paredes se calculan 1 de cada 4 frames, escalonado por minion
		if (Engine.get_physics_frames() + _stagger_offset) % 4 == 0:
			evitar_amontonamiento(delta)
			evitar_paredes()
		_mover_seguro()


# =========================================================
# --- REACCIÓN DE PRIMER AVISO ---
# =========================================================
func reaccionar_primer_aviso():
	ya_reacciono_primera_vez = true
	is_stunned = true
	velocity.x = 0
	velocity.z = 0
	if sprite.sprite_frames.has_animation("notice"):
		sprite.play("notice")
	else:
		sprite.play("idle")
	await get_tree().create_timer(duracion_reaccion_notice).timeout
	if not _accion_cortada() and not agarrando_a_sketch:
		is_stunned = false


# =========================================================
# --- BÚSQUEDA AL PERDER AL JUGADOR ---
# =========================================================
func buscar_jugador_perdido(delta):
	buscando_jugador = true
	tiempo_buscando += delta

	if tiempo_buscando > tiempo_max_busqueda:
		# se rinde: vuelve a idle "confundido"
		detectado_permanentemente = false
		buscando_jugador = false
		tiempo_buscando = 0.0
		ya_reacciono_primera_vez = false
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)
		if str(sprite.animation) == "search":
			sprite.play("idle")
		return

	if not ultima_pos_conocida_jugador.is_finite():
		ultima_pos_conocida_jugador = global_position

	var dist_a_ultima_pos = global_position.distance_to(ultima_pos_conocida_jugador)
	if dist_a_ultima_pos > 0.4:
		var dir = direccion_segura(global_position, ultima_pos_conocida_jugador)
		velocity.x = dir.x * (speed * 0.85)
		velocity.z = dir.z * (speed * 0.85)
		sprite.flip_h = dir.x < 0
		if sprite.sprite_frames.has_animation("search"):
			sprite.play("search")
		else:
			sprite.play("walk")
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)
		if sprite.sprite_frames.has_animation("search"):
			sprite.play("search")


func activar_efecto_chicle():
	if esta_muerto: return
	esta_cayendo = false
	tiempo_en_aire = 0.0
	modo_chicle = true
	is_stunned = true
	velocity = Vector3.ZERO

	if sprite.sprite_frames.has_animation("goofy"):
		sprite.sprite_frames.set_animation_loop("goofy", false)
		sprite.play("goofy")
		var duracion = sprite.sprite_frames.get_frame_count("goofy") / sprite.sprite_frames.get_animation_speed("goofy")
		await get_tree().create_timer(duracion + 0.1).timeout
		if modo_chicle and not esta_muerto:
			volver_de_chicle()
	else:
		await get_tree().create_timer(0.6).timeout
		if not esta_muerto:
			volver_de_chicle()


func volver_de_chicle():
	if not modo_chicle: return
	modo_chicle = false
	is_stunned = false
	if not esta_muerto and not siendo_ejecutado:
		sprite.play("idle")


func seguir_al_lider(lider):
	var dir = direccion_segura(global_position, lider.global_position)
	velocity.x = dir.x * (speed * 1.3)
	velocity.z = dir.z * (speed * 1.3)
	sprite.play("walk")
	sprite.flip_h = dir.x < 0
	if global_position.distance_to(lider.global_position) < 2.5:
		velocity = Vector3.ZERO
		sprite.play("idle")


func heal(amount):
	health = clamp(health + amount, 0, max_health_ref)
	actualizar_barra_vida()
	if health >= max_health_ref * 0.9:
		huyendo_al_lider = false


func chequear_llamada_horda():
	if Time.get_ticks_msec() < tiempo_proximo_chequeo_horda:
		return
	tiempo_proximo_chequeo_horda = Time.get_ticks_msec() + 800

	var enemigos = obtener_enemigos()
	if enemigos.size() >= tope_global_minions:
		return
	if enemigos.size() < 3 and randf() < probabilidad_llamada_refuerzos:
		ya_llamo_refuerzos = true
		invocar_refuerzos()


func invocar_refuerzos():
	is_stunned = true
	velocity = Vector3.ZERO
	if sprite.sprite_frames.has_animation("call_help"):
		sprite.play("call_help")
	else:
		sprite.play("attack")
	await get_tree().create_timer(1.0).timeout
	if _accion_cortada(): return
	var mapa_nav = get_world_3d().get_navigation_map()
	var angulo_base = randf() * TAU
	for i in range(2):
		var nuevo_minion = load(self.scene_file_path).instantiate()
		get_tree().current_scene.add_child(nuevo_minion)
		var angulo = angulo_base + (TAU / 2.0) * i
		var radio = randf_range(2.0, 3.5)
		var offset = Vector3(cos(angulo) * radio, 0, sin(angulo) * radio)
		var pos_intento = global_position + offset
		var pos_legal = NavigationServer3D.map_get_closest_point(mapa_nav, pos_intento)
		if pos_legal == Vector3.ZERO or not pos_legal.is_finite():
			pos_legal = pos_intento
		if not pos_legal.is_finite():
			pos_legal = global_position
		nuevo_minion.global_position = pos_legal + Vector3(0, 0.2, 0)
	_cache_enemigos_ms = 0
	is_stunned = false


func intentar_esquiva_tactica():
	if not player or not is_instance_valid(player):
		return
	# a veces bloquea en vez de esquivar
	if randf() < probabilidad_bloqueo and sprite.sprite_frames.has_animation("block"):
		sprite.play("block")
		knockback_velocity = Vector3.ZERO
		tiempo_proxima_esquiva = Time.get_ticks_msec() + 1500
		return

	if randf() < 0.6:
		var dir_esquiva = direccion_segura(player.global_position, global_position).rotated(Vector3.UP, randf_range(-PI/2, PI/2))
		aplicar_knockback(dir_esquiva, 6.0)
		if sprite.sprite_frames.has_animation("parry"):
			sprite.play("parry")
		else:
			sprite.play("hurt")
	tiempo_proxima_esquiva = Time.get_ticks_msec() + 2000


func comprobar_estado_berserker():
	if health <= max_health_ref * 0.4 and not en_modo_berserker:
		en_modo_berserker = true
		speed *= 1.8
		if not en_stun_parry and not es_ejecutable:
			sprite.modulate = Color(1.5, 0.5, 0.5)


# =========================================================
# --- COORDINACIÓN DE FLANQUEO ENTRE MINIONS ---
# =========================================================
func recalcular_flanqueo_coordinado():
	if not player: return
	var dir_a_jugador = (global_position - player.global_position)
	if not dir_a_jugador.is_finite():
		dir_a_jugador = Vector3.FORWARD
	var lado_der = dir_a_jugador.cross(Vector3.UP).x < 0

	var izquierda_ocupada = false
	var derecha_ocupada = false
	for e in obtener_enemigos():
		if e == self or not is_instance_valid(e): continue
		var lado = e.get("lado_flanqueo_asignado")
		if lado == -1:
			izquierda_ocupada = true
		elif lado == 1:
			derecha_ocupada = true

	if not izquierda_ocupada and (derecha_ocupada or randf() < 0.5):
		lado_flanqueo_asignado = -1
	elif not derecha_ocupada:
		lado_flanqueo_asignado = 1
	else:
		lado_flanqueo_asignado = -1 if lado_der else 1

	angulo_flanqueo = randf_range(0.5, 1.2) * lado_flanqueo_asignado


func follow_player_smart(dist, delta):
	if es_ejecutable:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)
		var anim_ejecutable = "ko" if sprite.sprite_frames.has_animation("ko") else "hurt"
		if not anim_ejecutable in str(sprite.animation):
			sprite.play(anim_ejecutable)
		return

	if cooldown_agarre <= 0.0 and not agarrando_a_sketch and player and player.is_in_group("player") and not player.get("siendo_agarrado") and not player.get("is_max_mode"):
		var vida_baja = health <= (max_health_ref * 0.35)
		if dist < 0.8 or (vida_baja and dist < 1.3):
			if randf() <= probabilidad_agarre:
				intentar_agarrar_a_sketch()
				return
			else:
				cooldown_agarre = 3.5

	# coordinación de flanqueo
	tiempo_cambio_flanqueo -= delta
	tiempo_recalculo_flanqueo -= delta
	if tiempo_cambio_flanqueo <= 0 or tiempo_recalculo_flanqueo <= 0:
		recalcular_flanqueo_coordinado()
		tiempo_cambio_flanqueo = randf_range(2.5, 4.5)
		tiempo_recalculo_flanqueo = randf_range(3.0, 5.0)

	var dir_hacia_jugador = direccion_segura(global_position, player.global_position)
	var dir_final = dir_hacia_jugador.rotated(Vector3.UP, angulo_flanqueo)
	if dist > stop_range:
		# el slide es muy raro, pero si sale, sale aca
		if evaluar_slide_tackle(dist, dir_hacia_jugador):
			return
		velocity.x = dir_final.x * speed
		velocity.z = dir_final.z * speed
		if not str(sprite.animation) in ANIMS_NO_PISAR:
			sprite.play("walk")
		sprite.flip_h = dir_hacia_jugador.x < 0
	elif can_attack:
		velocity.x = 0
		velocity.z = 0
		# a veces amaga en vez de atacar de verdad
		if Time.get_ticks_msec() > tiempo_proximo_amague_permitido and randf() < probabilidad_amague:
			intentar_amague()
		# a veces se burla si va ganando
		elif en_modo_berserker and Time.get_ticks_msec() > tiempo_proxima_burla_permitida and randf() < probabilidad_burla:
			intentar_burla()
		else:
			attack_player()
	else:
		var acecho = dir_hacia_jugador.rotated(Vector3.UP, PI/2)
		velocity.x = acecho.x * (speed * 0.7)
		velocity.z = acecho.z * (speed * 0.7)
		if not str(sprite.animation) in ANIMS_NO_PISAR:
			sprite.play("walk")


# =========================================================
# --- AMAGUE (FEINT) ---
# =========================================================
func intentar_amague():
	can_attack = false
	is_stunned = true
	tiempo_proximo_amague_permitido = Time.get_ticks_msec() + 4000
	if sprite.sprite_frames.has_animation("feint"):
		sprite.play("feint")
	else:
		sprite.play("attack")
	await get_tree().create_timer(0.35).timeout
	if _accion_cortada(): return
	# retrocede un poco tras el amague
	if player and is_instance_valid(player):
		var dir_atras = direccion_segura(player.global_position, global_position)
		aplicar_knockback(dir_atras, 2.5)
	await get_tree().create_timer(0.3).timeout
	if _accion_cortada(): return
	is_stunned = false
	can_attack = true


# =========================================================
# --- BURLA (TAUNT) ---
# =========================================================
func intentar_burla():
	can_attack = false
	is_stunned = true
	tiempo_proxima_burla_permitida = Time.get_ticks_msec() + 6000
	if sprite.sprite_frames.has_animation("taunt"):
		sprite.play("taunt")
	else:
		sprite.play("idle")
	if puede_reproducir_voz_combate and randf() < 0.5:
		EfectosManager.play_minion_voice("idle", global_position)
		esperar_para_proxima_voz(0.6)
	await get_tree().create_timer(0.6).timeout
	if _accion_cortada(): return
	is_stunned = false
	can_attack = true


func evitar_amontonamiento(_delta):
	var empujes = 0
	for enemigo in obtener_enemigos():
		if empujes >= 4:
			break
		if enemigo != self and is_instance_valid(enemigo):
			var d2 = global_position.distance_squared_to(enemigo.global_position)
			if d2 < 0.49:
				var dir_escape = direccion_segura(enemigo.global_position, global_position)
				velocity.x += dir_escape.x * 0.3
				velocity.z += dir_escape.z * 0.3
				empujes += 1


# =========================================================
# --- EVASIÓN DE PAREDES ---
# =========================================================
func evitar_paredes():
	var dir_mov = Vector3(velocity.x, 0, velocity.z)
	if not dir_mov.is_finite() or dir_mov.length() < 0.05:
		return
	if not global_position.is_finite():
		return

	dir_mov = dir_mov.normalized()
	var origen = global_position + Vector3(0, 0.5, 0)
	var destino = origen + dir_mov * distancia_deteccion_pared

	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(origen, destino)
	query.exclude = [self]
	var resultado = space_state.intersect_ray(query)

	if resultado:
		var normal = resultado.normal
		var cruz = normal.cross(Vector3.UP)
		# ignorar si lo que detectó es piso/techo, solo nos importan paredes
		if abs(normal.y) < 0.4 and cruz.is_finite() and cruz.length_squared() > 0.0001:
			var lateral = cruz.normalized()
			if lateral.dot(dir_mov) < 0:
				lateral = -lateral
			velocity.x += lateral.x * speed * fuerza_evasion_pared
			velocity.z += lateral.z * speed * fuerza_evasion_pared


# =========================================================
# --- ATAQUE (IGUAL QUE EL SCRIPT VIEJO) ---
# =========================================================
func attack_player():
	var zona = obtener_zona_instructor()
	if zona and zona.etapa == 2:
		zona.trigger_congelar_parry()
		if not is_inside_tree() or tutorial_congelado or is_stunned: return
	can_attack = false
	is_stunned = true
	if puede_reproducir_voz_combate and randf() < chance_voz_ataque:
		EfectosManager.play_minion_voice("attack", global_position)
		esperar_para_proxima_voz(0.7)
	es_ataque_imparable = randf() < probabilidad_imparable
	if es_ataque_imparable:
		sprite.modulate = Color(2, 0, 2)
	sprite.play("attack")
	emit_signal("ataque_inminente", self)
	await get_tree().create_timer(0.5).timeout
	if _accion_cortada(): return

	if player and is_instance_valid(player) and global_position.distance_to(player.global_position) < 1.4:
		if player.get("is_parrying") and not es_ataque_imparable:
			# parry exitoso: el minion queda aturdido y se come daño
			EstadisticasNivel.registrar_parry()   
			stun_minion(duracion_stun_parry)
			take_damage(dano_propio_por_parry, global_position)
			player.take_damage(0, global_position)
			return
		else:
			var dano = dano_berserker if en_modo_berserker else dano_normal
			if es_ataque_imparable: dano += dano_extra_imparable
			if player.get("defensa_ectoplasma") == true: dano = int(round(dano / 3.0))
			player.take_damage(dano, global_position)

	await get_tree().create_timer(0.5).timeout
	if _accion_cortada(): return
	if not en_stun_parry:
		is_stunned = false
		_restaurar_tinte()
	es_ataque_imparable = false
	var cooldown = cooldown_ataque_berserker if en_modo_berserker else cooldown_ataque_normal
	await get_tree().create_timer(cooldown).timeout
	if _accion_cortada(): return
	can_attack = true


func stun_minion(duration):
	if not is_inside_tree() or siendo_ejecutado or esta_muerto: return
	_id_stun += 1
	var mi_id = _id_stun
	en_stun_parry = true
	is_stunned = true
	can_attack = false
	sprite.modulate = Color(2, 2, 0)
	sprite.play("hurt")
	await get_tree().create_timer(duration).timeout
	if mi_id != _id_stun or not is_inside_tree() or esta_muerto or siendo_ejecutado: return
	en_stun_parry = false
	if es_ejecutable: return
	_restaurar_tinte()
	is_stunned = false
	can_attack = true
	sprite.play("idle")


# =========================================================
# --- SLIDE TACKLE (DERRAPE) - MUY RARO ---
# =========================================================
func puede_intentar_slide(dist: float) -> bool:
	if probabilidad_slide <= 0.0:
		return false
	if esta_muerto or siendo_ejecutado or es_ejecutable or agarrando_a_sketch:
		return false
	if not can_attack or is_stunned or _slide_activo:
		return false
	if Time.get_ticks_msec() < tiempo_proximo_slide_permitido:
		return false
	if dist < rango_min_slide or dist > rango_max_slide:
		return false
	return true


func es_angulo_valido_para_slide(dir_hacia_jugador: Vector3) -> bool:
	if not dir_hacia_jugador.is_finite():
		return false
	return abs(dir_hacia_jugador.x) >= abs(dir_hacia_jugador.z)


func evaluar_slide_tackle(dist: float, dir_hacia_jugador: Vector3) -> bool:
	if not puede_intentar_slide(dist):
		return false
	if not es_angulo_valido_para_slide(dir_hacia_jugador):
		return false

	# Como mucho un chequeo cada 0.6 s
	tiempo_proximo_slide_permitido = Time.get_ticks_msec() + 600

	var chance = probabilidad_slide
	# Si el jugador se aleja, un poquito mas de chance (sigue siendo raro)
	if player and is_instance_valid(player) and "velocity" in player:
		var vel_jugador = Vector3(player.velocity.x, 0, player.velocity.z)
		if vel_jugador.is_finite() and vel_jugador.length() > 0.5:
			if vel_jugador.normalized().dot(dir_hacia_jugador) > 0.4:
				chance = min(chance * 2.5, 0.12)

	if randf() > chance:
		return false

	can_attack = false
	intentar_slide_tackle(dir_hacia_jugador)
	return true


func _slide_interrumpido() -> bool:
	return not is_inside_tree() or esta_muerto or siendo_ejecutado or es_ejecutable


func intentar_slide_tackle(dir_hacia_jugador: Vector3):
	is_stunned = true
	_slide_activo = true
	velocity.x = 0
	velocity.z = 0
	tiempo_proximo_slide_permitido = Time.get_ticks_msec() + randf_range(cooldown_slide_min, cooldown_slide_max) * 1000.0

	sprite.flip_h = dir_hacia_jugador.x < 0
	if sprite.sprite_frames.has_animation("slide"):
		sprite.play("slide")
	else:
		print("[SLIDE] No se encontró la animación 'slide' en el SpriteFrames, usando 'attack' de respaldo.")
		sprite.play("attack")

	await get_tree().create_timer(0.12).timeout
	if _slide_interrumpido():
		_slide_activo = false
		return
	if not player or not is_instance_valid(player):
		_slide_activo = false
		is_stunned = false
		can_attack = true
		sprite.play("idle")
		return

	var dir_slide = direccion_segura(global_position, player.global_position)
	dir_slide.z = 0.0
	if dir_slide.length() < 0.0001:
		dir_slide = Vector3(1, 0, 0) if not sprite.flip_h else Vector3(-1, 0, 0)
	else:
		dir_slide = dir_slide.normalized()
	sprite.flip_h = dir_slide.x < 0

	var tiempo_slide = 0.0
	var impacto = false
	var tiempo_minimo_antes_de_impactar = 0.12

	while tiempo_slide < duracion_slide and not _slide_interrumpido():
		if Engine.time_scale <= 0.0:
			await get_tree().physics_frame
			continue

		velocity.x = dir_slide.x * velocidad_slide
		velocity.z = 0.0
		_mover_seguro()

		if tiempo_slide >= tiempo_minimo_antes_de_impactar and player and is_instance_valid(player):
			var dist_slide = global_position.distance_to(player.global_position)
			if dist_slide < 1.1:
				impacto = true
				var esta_deslizando = player.get("is_sliding") == true
				var es_invulnerable = player.get("es_invulnerable") == true
				if not esta_deslizando and not es_invulnerable:
					var dano_slide = dano_slide_berserker if en_modo_berserker else dano_slide_normal
					player.take_damage(dano_slide, global_position)
					if player.has_method("aplicar_tackle"):
						player.aplicar_tackle(dir_slide)
				break

		tiempo_slide += get_physics_process_delta_time()
		await get_tree().physics_frame

	_slide_activo = false
	if _slide_interrumpido():
		return

	velocity.x = 0
	velocity.z = 0

	await get_tree().create_timer(0.2).timeout
	if _slide_interrumpido(): return

	sprite.play("idle")

	var recuperacion = 0.35 if impacto else 0.7
	await get_tree().create_timer(recuperacion).timeout
	if _slide_interrumpido(): return
	is_stunned = false
	can_attack = true


# =========================================================
# --- DAÑO RECIBIDO (IGUAL QUE EL SCRIPT VIEJO) ---
# =========================================================
func take_damage(amount, source_pos):
	if esta_muerto or siendo_ejecutado: return

	if not (source_pos is Vector3) or not source_pos.is_finite():
		source_pos = global_position - Vector3(0, 0, 1)

	if is_singing:
		print("¡Golpearon al minion y dejó de cantar!")
		terminar_canto()

	if agarrando_a_sketch:
		soltar_a_sketch(false)

	health -= amount
	actualizar_barra_vida()
	if puede_reproducir_voz_combate and randf() < chance_voz_dano:
		EfectosManager.play_minion_voice("hurt", global_position)
		esperar_para_proxima_voz(0.5)
	if health <= 0:
		if randf() < 0.05:
			lanzar_por_los_aires(source_pos)
		else:
			die()
		return

	if health <= max_health_ref * 0.25 and not es_ejecutable:
		activar_estado_ejecutable()
		return

	# En pleno slide no se le pisa la animacion (el daño igual se aplico arriba)
	if _slide_activo:
		return

	if not en_stun_parry and not es_ejecutable:
		is_stunned = true
		sprite.play("hurt")
		var dir = direccion_segura(source_pos, global_position)
		var fuerza = 3.5 if _puede_recibir_knockback_duro() else 1.0
		aplicar_knockback(Vector3(dir.x, 0, dir.z), fuerza)


func esperar_para_proxima_voz(tiempo):
	puede_reproducir_voz_combate = false
	await get_tree().create_timer(tiempo).timeout
	puede_reproducir_voz_combate = true


func lanzar_por_los_aires(source_pos):
	esta_muerto = true
	is_stunned = true
	_slide_activo = false
	_matar_tween_ejecutable()
	ocultar_indicador_ejecucion()
	if area_deteccion_gk: area_deteccion_gk.queue_free()
	if sprite.sprite_frames.has_animation("fly"): sprite.play("fly")
	if fly_audio: fly_audio.play()
	if has_node("BarraVisual"): $BarraVisual.visible = false
	var dir_escape = direccion_segura(source_pos, global_position)
	var dir_vuelo = dir_escape + Vector3(0, 8.0, 0)
	if not dir_vuelo.is_finite() or dir_vuelo.length_squared() < 0.0001:
		dir_vuelo = Vector3(0, 1, 0)
	aplicar_knockback(dir_vuelo.normalized(), 26.0)
	ProgresoJuego.monedas_nivel += 1
	ProgresoJuego.total_minions_muertos = int(ProgresoJuego.total_minions_muertos) + 1
	ProgresoJuego.guardar_partida()
	soltar_item_con_probabilidad()
	soltar_sangre()
	await get_tree().create_timer(1.8).timeout
	queue_free()


func actualizar_barra_vida():
	if has_node("BarraVisual"):
		$BarraVisual.visible = health < max_health_ref and health > 0
	if health_bar:
		health_bar.value = health
		var porcentaje = float(health) / float(max_health_ref)
		if porcentaje > 0.6: health_bar.modulate = Color.GREEN
		elif porcentaje > 0.3: health_bar.modulate = Color.ORANGE
		else: health_bar.modulate = Color.RED


func soltar_sangre():
	var sangre = ESCENA_SANGRE.instantiate()
	get_tree().current_scene.add_child(sangre)
	var pos = global_position
	if not pos.is_finite():
		pos = _ultima_pos_valida
	sangre.global_position = pos + Vector3(0, 0.5, 0)


func die():
	if esta_muerto: return
	esta_muerto = true
	is_stunned = true
	_slide_activo = false
	_matar_tween_ejecutable()
	ocultar_indicador_ejecucion()
	if area_deteccion_gk: area_deteccion_gk.queue_free()
	var manager = get_tree().get_first_node_in_group("combo_manager")
	if manager:
		manager.registrar_muerte()
	if get_tree().current_scene.has_method("registrar_muerte"):
		get_tree().current_scene.registrar_muerte()
	sprite.play("hurt")
	ProgresoJuego.monedas_nivel += 1
	ProgresoJuego.total_minions_muertos = int(ProgresoJuego.total_minions_muertos) + 1
	ProgresoJuego.guardar_partida()
	soltar_item_con_probabilidad()
	soltar_sangre()
	await get_tree().create_timer(0.2).timeout
	queue_free()


func soltar_item_con_probabilidad():
	var suerte = randf() * 100
	if suerte < 80:
		var drop = escena_drop.instantiate()
		get_tree().current_scene.add_child(drop)
		var pos = global_position
		if not pos.is_finite():
			pos = _ultima_pos_valida
		drop.global_position = pos + Vector3(0, 0.09, 0)
		if suerte < 40:
			drop.tipo_actual = 0
		else:
			drop.tipo_actual = 1
		if drop.has_method("actualizar_item"):
			drop.actualizar_item()


# =========================================================
# --- SEÑALES DE ANIMACION (COMO EL VIEJO) ---
# =========================================================
func _on_animated_sprite_3d_animation_finished():
	if siendo_ejecutado:
		_morir_por_ejecucion()
		return

	match str(sprite.animation):
		"fall":
			if esta_cayendo and not esta_muerto:
				esta_cayendo = false
				activar_efecto_chicle()
		"goofy":
			volver_de_chicle()
		"hurt", "attack", "fly", "parry", "grow", "call_help", "minion grab sketch", "minion grab jane", "minion grab nubbe", "minion grab alloy", "notice", "search", "feint", "taunt", "block", "slide":
			if health > 0 and not en_stun_parry and not esta_cayendo and not agarrando_a_sketch and not es_ejecutable and not _slide_activo and not modo_chicle:
				is_stunned = false
				sprite.play("idle")


func _on_animated_sprite_3d_animation_looped():
	# Si una animacion "de una sola vez" quedo con Loop activado, "animation_finished"
	# nunca se emite. Tratamos la primera vuelta como el final.
	if siendo_ejecutado:
		_morir_por_ejecucion()
		return
	if str(sprite.animation) in ANIMS_UNA_VEZ:
		_on_animated_sprite_3d_animation_finished()


func despertar_minion():
	tutorial_congelado = false
	is_stunned = false
	can_attack = true
	player = get_tree().get_first_node_in_group("player")
	velocity = Vector3(0, -2, 0)


# =========================================================
# --- INDICADOR DE GLORY KILL (Killhim / la X) ---
# =========================================================
func mostrar_indicador_ejecucion():
	if not killhim_sprite:
		return

	killhim_sprite.visible = true
	killhim_sprite.modulate = Color(1, 1, 1, 1)

	if killhim_sprite.sprite_frames and killhim_sprite.sprite_frames.has_animation("pressx"):
		killhim_sprite.play("pressx")

	var altura_normal = _killhim_pos_base.y
	var altura_rebote = altura_normal + 0.35
	var altura_inicio = altura_normal - 0.9

	killhim_sprite.position.y = altura_inicio

	var tw = create_tween()
	tw.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(killhim_sprite, "position:y", altura_rebote, 0.25)
	tw.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw.tween_property(killhim_sprite, "position:y", altura_normal, 0.35)


func ocultar_indicador_ejecucion():
	if not killhim_sprite:
		return
	killhim_sprite.visible = false
	killhim_sprite.stop()
	killhim_sprite.position = _killhim_pos_base


func _matar_tween_ejecutable() -> void:
	if _tween_ejecutable and _tween_ejecutable.is_valid():
		_tween_ejecutable.kill()
	_tween_ejecutable = null


func activar_estado_ejecutable():
	if es_ejecutable: return
	es_ejecutable = true
	es_executable = true
	is_stunned = true
	can_attack = false
	_slide_activo = false
	# Si estaba aturdido por parry, ese stun deja de mandar
	_id_stun += 1
	en_stun_parry = false

	mostrar_indicador_ejecucion()

	sprite.stop()
	if sprite.sprite_frames.has_animation("ko"):
		sprite.play("ko")
	else:
		sprite.play("hurt")

	# Parpadeo rojo/blanco, guardado para poder cortarlo al morir o ser ejecutado
	_matar_tween_ejecutable()
	_tween_ejecutable = create_tween().set_loops()
	_tween_ejecutable.tween_property(sprite, "modulate", Color(5, 5, 5), 0.2)
	_tween_ejecutable.tween_property(sprite, "modulate", Color(1, 0, 0), 0.2)

	area_deteccion_gk = Area3D.new()
	var colision = CollisionShape3D.new()
	var esfera = SphereShape3D.new()
	esfera.radius = 1.6
	colision.shape = esfera
	area_deteccion_gk.add_child(colision)
	add_child(area_deteccion_gk)

	area_deteccion_gk.body_entered.connect(func(body):
		if body.is_in_group("player") and body.has_method("iniciar_glory_kill"):
			body.minion_ejecutable = self
	)
	area_deteccion_gk.body_exited.connect(func(body):
		if body.is_in_group("player") and body.get("minion_ejecutable") == self:
			body.minion_ejecutable = null
	)


# =========================================================
# --- GLORY KILLS (soporta "minion kill 16", "minion kill 17", etc.) ---
# =========================================================
# Busca la animacion sin importar mayusculas/minusculas ni guiones bajos vs espacios.
func _resolver_animacion(nombre: String) -> String:
	var frames = sprite.sprite_frames
	if frames == null:
		return ""
	if frames.has_animation(nombre):
		return nombre
	var objetivo = nombre.to_lower().replace("_", " ").strip_edges()
	for a in frames.get_animation_names():
		if str(a).to_lower().replace("_", " ").strip_edges() == objetivo:
			return str(a)
	return ""


func _duracion_animacion(anim: String) -> float:
	var frames = sprite.sprite_frames
	var fps = frames.get_animation_speed(anim)
	if fps <= 0.1:
		return 1.5
	var total = 0.0
	for i in range(frames.get_frame_count(anim)):
		total += frames.get_frame_duration(anim, i)
	return total / fps


func ser_ejecutado_dinamico(nombre_anim_completo: String):
	if siendo_ejecutado: return
	if agarrando_a_sketch:
		soltar_a_sketch(false)

	siendo_ejecutado = true
	esta_muerto = true
	_ejecucion_terminada = false
	is_stunned = true
	can_attack = false
	_slide_activo = false
	_id_stun += 1
	en_stun_parry = false
	_matar_tween_ejecutable()
	ocultar_indicador_ejecucion()
	if area_deteccion_gk: area_deteccion_gk.queue_free()
	if has_node("BarraVisual"): $BarraVisual.visible = false

	# Sin parpadeo rojo ni tintes encima de la animacion de ejecucion
	sprite.modulate = Color(1, 1, 1)

	var player_node = get_tree().get_first_node_in_group("player")
	if player_node:
		sprite.flip_h = player_node.global_position.x > global_position.x

	var anim_real = _resolver_animacion(nombre_anim_completo)
	if anim_real == "":
		var candidatas: Array = []
		if sprite.sprite_frames:
			for a in sprite.sprite_frames.get_animation_names():
				if "kill" in str(a).to_lower():
					candidatas.append(str(a))
		print("[GK ERROR Minion] Este minion (", name, ") no tiene la animación '", nombre_anim_completo, "'. Animaciones 'kill' que SI tiene: ", candidatas)
		sprite.play("hurt")
		await get_tree().create_timer(0.4).timeout
		_morir_por_ejecucion()
		return

	print("[GK Minion] Reproduciendo: ", anim_real)
	# Sin loop: si tenia Loop activado, "animation_finished" nunca se emitia.
	sprite.sprite_frames.set_animation_loop(anim_real, false)
	sprite.stop()
	sprite.play(anim_real)

	# Seguro anti-freeze: si por cualquier motivo no llega la señal, muere igual.
	var duracion_segura = clamp(_duracion_animacion(anim_real) + 0.4, 0.5, 8.0)
	await get_tree().create_timer(duracion_segura, true, false, true).timeout
	if is_inside_tree():
		_morir_por_ejecucion()


func ser_ejecutado(id_kill: String):
	ser_ejecutado_dinamico("minion kill " + id_kill)


func _morir_por_ejecucion():
	if _ejecucion_terminada: return
	_ejecucion_terminada = true
	var manager = get_tree().get_first_node_in_group("combo_manager")
	if manager: manager.registrar_muerte()
	if get_tree().current_scene.has_method("registrar_muerte"):
		get_tree().current_scene.registrar_muerte()

	ProgresoJuego.monedas_nivel += 2
	ProgresoJuego.total_minions_muertos = int(ProgresoJuego.total_minions_muertos) + 1
	ProgresoJuego.guardar_partida()
	soltar_item_con_probabilidad()
	soltar_sangre()
	queue_free()


# =========================================================
# --- AGARRE (GRAB) ---
# =========================================================
func intentar_agarrar_a_sketch():
	if esta_muerto or is_stunned or siendo_ejecutado or agarrando_a_sketch: return

	if player and is_instance_valid(player) and not player.get("siendo_agarrado"):
		agarrando_a_sketch = true
		grab_damage_timer = 0.0
		velocity = Vector3.ZERO

		add_collision_exception_with(player)
		if player.has_method("add_collision_exception_with"):
			player.add_collision_exception_with(self)

		sprite.flip_h = (player.global_position.x < global_position.x)

		var nombre_anim_grab = "minion grab sketch"
		if player.name.to_lower().contains("jane") or player.get("character_name") == "Jane":
			nombre_anim_grab = "minion grab jane"
		if player.name.to_lower().contains("nubbe") or player.get("character_name") == "Nubbe":
			nombre_anim_grab = "minion grab nubbe"
		if player.name.to_lower().contains("alloy") or player.get("character_name") == "Alloy":
			if sprite.sprite_frames.has_animation("minion grab alloy"):
				nombre_anim_grab = "minion grab alloy"

		if sprite.sprite_frames.has_animation(nombre_anim_grab):
			sprite.play(nombre_anim_grab)
		else:
			sprite.play("attack")

		if player.has_method("ser_agarrado"):
			player.ser_agarrado(self)

		# Si el jugador rechazo el agarre (glory kill, super, invulnerable...), abortamos.
		if "siendo_agarrado" in player and not player.siendo_agarrado:
			soltar_a_sketch(false)
			cooldown_agarre = 3.5
			return

		var hud = get_tree().get_first_node_in_group("hud")
		if hud and hud.has_method("iniciar_skill_check_liberacion"):
			hud.iniciar_skill_check_liberacion()


func soltar_por_liberacion_jugador():
	if not agarrando_a_sketch: return
	print("[AGARRE] Liberación exitosa. Forzando aturdimiento inmediato en el Minion.")
	soltar_a_sketch(true)


func soltar_a_sketch(aplicar_stun: bool = false):
	if not agarrando_a_sketch: return

	agarrando_a_sketch = false
	cooldown_agarre = TIEMPO_COOLDOWN_AGARRE
	grab_damage_timer = 0.0

	if player and is_instance_valid(player):
		remove_collision_exception_with(player)
		if player.has_method("remove_collision_exception_with"):
			player.remove_collision_exception_with(self)

		if player.get("siendo_agarrado") == true:
			if player.has_method("liberado_de_agarre"):
				player.liberado_de_agarre()
			else:
				player.set("siendo_agarrado", false)
				player.set("minion_que_agarra", null)
				if player.has_method("reset_idle"):
					player.reset_idle()

	if aplicar_stun:
		sprite.play("hurt")
		stun_minion(2.0)
	else:
		is_stunned = false
		can_attack = true
		if not esta_muerto and not siendo_ejecutado:
			sprite.play("idle")
