extends CharacterBody3D

var sufijo_control: String = ""
signal parry_realizado
@export var jump_velocity = 4.5
var puede_saltar_aqui = false
var puede_correr_aqui = false
@export var speed = 3.0
@export var run_speed = 9.5
var defensa_ectoplasma = false
@export var max_health = 100
var health = 100
@export var character_name = "Sketch"
var racha_parries = 0
@export var minion_kill_base_index: int = 0

var escudo_golpes_restantes = 0
var esta_invisible = false

var posicion_hace_3s = Vector3.ZERO
var multiplicador_glitch = 1.0

var idle_timer = 0.0
const TIME_TO_DANCE = 120.0
var is_dancing = false

# --- SISTEMA DE BAILES Y MÚSICA ---
@export_group("Música de Baile")
@export var musica_baile_1: AudioStream
@export var musica_baile_2: AudioStream
@onready var reproductor_baile: AudioStreamPlayer3D = $AudioStreamPlayer3D

# --- SISTEMA DE ACELERACIÓN Y DERRAPE ---
var tiempo_caminando: float = 0.0
@export var TIEMPO_WALK_A_START: float = 2.2
@export var TIEMPO_START_A_RUN: float = 1.1
var esta_derrapando: bool = false
var tiempo_derrape: float = 0.0
const DURACION_DERRAPE: float = 0.38
var ultima_dir_x: float = 0.0
var ultima_dir_z: float = 0.0

# --- CONTROL DE INACTIVIDAD / RESET DE CARRERA ---
var tiempo_detenido_correr: float = 0.0
@export var TIEMPO_PARA_RESET_CARRERA: float = 1.0

# --- STAMINA / RESISTENCIA DE CARRERA ---
@export var STAMINA_CARRERA_MAX: float = 5.0
@export var STAMINA_RECUPERACION_MULT: float = 1.5
var stamina_carrera: float = STAMINA_CARRERA_MAX
var fatigado: bool = false

# --- RESISTENCIA (FATIGA AL CORRER) ---
@export var RESISTENCIA_MAX: float = 6.0
@export var RESISTENCIA_RECUPERACION_SEG: float = 4.0
var resistencia: float = RESISTENCIA_MAX
var cansado: bool = false
var corriendo_a_full_este_frame: bool = false

var power = 0.0
var max_power = 500.0
var is_max_mode = false
var is_invulnerable = false
var anim_prefix = ""
var skin_prefix = ""

@onready var hitbox = $HitBox
@onready var sprite = $AnimatedSprite3D

var combo_step = 0
var attacking = false
var combo_timer = 0.0
const COMBO_TIME_WINDOW = 0.6
var is_parrying = false
var parry_cooldown = false
var parry_window = 0.25
var can_play_step = true
var tutorial_bloqueo = false

# --- SQUASH & STRETCH ---
var _escala_base_sprite: Vector3 = Vector3.ONE
var _estaba_en_suelo: bool = true
var _velocidad_y_antes: float = 0.0

# --- GLORY KILL VARIABLES ---
var minion_ejecutable: Node3D = null
var haciendo_glory_kill: bool = false

# --- SISTEMA DE AGARRE SKILL CHECK SINCRONIZADO CON HUD ---
var siendo_agarrado: bool = false
var minion_que_agarra: CharacterBody3D = null

# --- CARGAR OBJETOS (TACHO / MINION BOMBA) ---
@export_group("Cargar Objetos")
@export var rango_agarre: float = 1.4
@export var rango_lanzamiento: float = 4.5
## Posición del tacho mientras lo cargás (X se espeja según hacia dónde mirás)
@export var offset_carga_tacho: Vector3 = Vector3(0, 0.35, 0)
## Posición de la bomba mientras la cargás
@export var offset_carga_bomba: Vector3 = Vector3(0, 0.35, 0)
var objeto_cargado: Node3D = null
var _offset_y_objeto: float = 0.0

func _ready():
	aplicar_mejoras_tienda()
	posicion_hace_3s = global_position
	iniciar_rastreo_posicion()
	_escala_base_sprite = sprite.scale

func iniciar_rastreo_posicion():
	while true:
		await get_tree().create_timer(3.0).timeout
		if is_on_floor():
			posicion_hace_3s = global_position

func _physics_process(delta):
	if siendo_agarrado:
		if not is_instance_valid(minion_que_agarra):
			liberado_de_agarre()
			return
		velocity = Vector3.ZERO
		move_and_slide()
		return

	if tutorial_bloqueo or haciendo_glory_kill: return

	# Detección de permisos del Nivel Padre
	var padre = get_parent()
	if padre:
		puede_saltar_aqui = padre.is_in_group("nivel_con_gravedad")
		puede_correr_aqui = padre.is_in_group("nivel_con_carrera")

	# Cargando un objeto: solo se puede caminar (nada de correr ni saltar)
	if objeto_cargado != null:
		puede_correr_aqui = false
		puede_saltar_aqui = false

	if ProgresoJuego.get("skin_neko_equipada"):
		skin_prefix = "neko_"
	elif ProgresoJuego.get("skin_max_equipada"):
		skin_prefix = "classic_"
	else:
		skin_prefix = ""

	anim_prefix = "super " if is_max_mode else ""

	var base_speed = speed if not is_max_mode else 5.5
	var current_speed = base_speed * multiplicador_glitch

	if attacking or is_parrying or (sprite.animation.contains("hurt") if sprite.animation else false) or sprite.animation == "super":
		velocity.x = move_toward(velocity.x, 0, current_speed)
		velocity.z = move_toward(velocity.z, 0, current_speed)
		reset_idle()
		reset_correr(true)
	else:
		handle_movement(current_speed, delta)

	if combo_timer > 0: combo_timer -= delta
	else: combo_step = 0

	if Input.is_action_just_pressed("glory_kill") and minion_ejecutable != null and objeto_cargado == null and not attacking and not is_parrying and not is_max_mode:
		iniciar_glory_kill()

	# ATAQUE: golpea normal, o lanza/suelta el objeto si lo está cargando
	if Input.is_action_just_pressed("ataque" + sufijo_control) and not attacking and not is_parrying and not haciendo_glory_kill:
		if objeto_cargado != null:
			lanzar_o_soltar_objeto()
		else:
			execute_attack()

	# PARRY: agarra un objeto cercano, o parrea si no hay nada para agarrar
	if Input.is_action_just_pressed("parry" + sufijo_control) and not is_max_mode and not haciendo_glory_kill:
		if objeto_cargado == null and not attacking and not is_parrying:
			var cercano = _buscar_objeto_agarrable()
			if cercano:
				agarrar_objeto(cercano)
			elif not parry_cooldown:
				execute_parry()

	var en_suelo_ahora = is_on_floor()
	if not _estaba_en_suelo and en_suelo_ahora and _velocidad_y_antes < -3.0:
		_hacer_squash()
	_estaba_en_suelo = en_suelo_ahora
	_velocidad_y_antes = velocity.y

	if puede_saltar_aqui:
		if not is_on_floor():
			velocity.y -= ProjectSettings.get_setting("physics/3d/default_gravity") * delta
		if Input.is_action_just_pressed("salto" + sufijo_control) and is_on_floor():
			velocity.y = jump_velocity
	else:
		if not is_on_floor():
			velocity.y -= 9.8 * delta

	move_and_slide()
	_seguir_objeto_cargado()

func _recuperar_resistencia(delta: float) -> void:
	if is_max_mode:
		return
	resistencia = min(RESISTENCIA_MAX, resistencia + delta * (RESISTENCIA_MAX / RESISTENCIA_RECUPERACION_SEG))

func reset_correr(forzar_reset_total: bool = false):
	esta_derrapando = false
	tiempo_derrape = 0.0
	ultima_dir_x = 0.0
	ultima_dir_z = 0.0
	corriendo_a_full_este_frame = false
	tiempo_detenido_correr = 0.0

	if forzar_reset_total:
		tiempo_caminando = 0.0
	else:
		if stamina_carrera > 0.0 and tiempo_caminando >= (TIEMPO_WALK_A_START + TIEMPO_START_A_RUN):
			tiempo_caminando = TIEMPO_WALK_A_START + TIEMPO_START_A_RUN
		else:
			tiempo_caminando = 0.0

var direccion_mirando_x: float = 1.0

func _obtener_animacion_valida(nombre_base: String) -> String:
	var opciones: Array[String] = []

	if skin_prefix == "neko_":
		opciones.append(nombre_base.capitalize().replace(" ", "") + "Neko")
		opciones.append("neko_" + nombre_base)
	elif skin_prefix != "":
		opciones.append(skin_prefix + nombre_base)

	opciones.append(nombre_base)

	for opt in opciones:
		if sprite.sprite_frames.has_animation(opt):
			return opt

	return nombre_base

# =========================================================
# --- CARGAR OBJETOS ---
# =========================================================
func _dist_horizontal(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()

# Offset de carga según el tipo de objeto (tacho = lanzamiento recto, bomba = parabólico).
# El X se espeja según hacia dónde mira el personaje.
func _offset_para(obj: Node3D) -> Vector3:
	var o = offset_carga_tacho if obj.get("lanzamiento_recto") == true else offset_carga_bomba
	o.x *= direccion_mirando_x
	return o

func _buscar_objeto_agarrable() -> Node3D:
	var mejor: Node3D = null
	var mejor_dist := rango_agarre
	for o in get_tree().get_nodes_in_group("agarrable"):
		if not is_instance_valid(o) or not o.has_method("puede_ser_agarrado"): continue
		if not o.puede_ser_agarrado(): continue
		var d = _dist_horizontal(global_position, o.global_position)
		if d < mejor_dist:
			mejor_dist = d
			mejor = o
	return mejor

func _buscar_enemigo_para_lanzar(ignorar: Node3D) -> Node3D:
	var mejor: Node3D = null
	var mejor_dist := rango_lanzamiento
	for e in get_tree().get_nodes_in_group("enemies"):
		if e == ignorar or not is_instance_valid(e) or not (e is Node3D): continue
		if not e.global_position.is_finite(): continue
		if e.get("esta_muerto") == true: continue
		var dx = e.global_position.x - global_position.x
		if dx * direccion_mirando_x < -0.3: continue # está detrás, no cuenta
		var d = _dist_horizontal(global_position, e.global_position)
		if d < mejor_dist:
			mejor_dist = d
			mejor = e
	return mejor

func agarrar_objeto(obj: Node3D) -> void:
	reset_idle()
	reset_correr(true)
	objeto_cargado = obj
	_offset_y_objeto = obj.global_position.y - global_position.y
	obj.ser_agarrado_por(self)
	sprite.play(_obtener_animacion_valida("grab item idle"))

func _seguir_objeto_cargado() -> void:
	if objeto_cargado == null: return
	if not is_instance_valid(objeto_cargado):
		objeto_cargado = null
		return
	objeto_cargado.global_position = global_position + _offset_para(objeto_cargado)

func lanzar_o_soltar_objeto() -> void:
	if objeto_cargado == null: return
	reset_idle()
	var obj = objeto_cargado
	objeto_cargado = null
	attacking = true
	var origen = global_position + _offset_para(obj)
	var suelo_y = global_position.y + _offset_y_objeto
	var es_recto = obj.get("lanzamiento_recto") == true
	var dano = obj.get("dano_impacto")
	if dano == null: dano = 10
	var objetivo = _buscar_enemigo_para_lanzar(obj)

	if objetivo:
		if es_recto:
			# Tacho: tiro recto hacia donde MIRA, sin girar ni autoapuntar
			sprite.play(_obtener_animacion_valida("rude drop"))
			EfectosManager.play_sound("viento", global_position, true)
			obj.ser_lanzado_recto(origen, direccion_mirando_x, global_position, suelo_y)
		else:
			# Bomba: parábola hacia el grupo, aterriza un poquito ANTES del enemigo
			direccion_mirando_x = 1.0 if objetivo.global_position.x >= global_position.x else -1.0
			sprite.flip_h = direccion_mirando_x < 0
			hitbox.scale.x = -1 if sprite.flip_h else 1
			sprite.play(_obtener_animacion_valida("rude drop"))
			EfectosManager.play_sound("viento", global_position, true)
			var hacia = Vector3(objetivo.global_position.x - global_position.x, 0, objetivo.global_position.z - global_position.z)
			hacia = Utils.normalizar_seguro(hacia, Vector3(direccion_mirando_x, 0, 0))
			var destino = objetivo.global_position - hacia * 0.9
			destino.y = suelo_y
			obj.ser_lanzado(origen, destino, global_position, dano, 1.2, 0.35)
	else:
		sprite.play(_obtener_animacion_valida("soft drop"))
		var destino = global_position + Vector3(direccion_mirando_x * 0.9, _offset_y_objeto, 0)
		obj.ser_lanzado(origen, destino, global_position, 0, 0.4, 0.2)

func soltar_objeto_por_golpe() -> void:
	if objeto_cargado == null: return
	var obj = objeto_cargado
	objeto_cargado = null
	if not is_instance_valid(obj): return
	var destino = global_position + Vector3(direccion_mirando_x * 0.9, _offset_y_objeto, 0)
	obj.ser_lanzado(global_position + _offset_para(obj), destino, global_position, 0, 0.6, 0.25)

func _mover_cargando(input_dir: Vector2, direction: Vector3, move_speed: float, delta: float) -> void:
	reset_idle()
	_recuperar_resistencia(delta)
	if input_dir.x != 0:
		direccion_mirando_x = input_dir.x
	sprite.flip_h = direccion_mirando_x < 0
	hitbox.scale.x = -1 if sprite.flip_h else 1
	if direction:
		velocity.x = direction.x * move_speed
		velocity.z = direction.z * move_speed
	else:
		velocity.x = move_toward(velocity.x, 0, move_speed)
		velocity.z = move_toward(velocity.z, 0, move_speed)
	var anim = _obtener_animacion_valida("grab item walk" if direction else "grab item idle")
	if not sprite.sprite_frames.has_animation(anim):
		anim = _obtener_animacion_valida("grab item idle")
	if sprite.animation != anim and sprite.sprite_frames.has_animation(anim):
		sprite.play(anim)

func handle_movement(move_speed, delta):
	var input_dir = Input.get_vector(
		"izquierda" + sufijo_control,
		"derecha" + sufijo_control,
		"arriba" + sufijo_control,
		"abajo" + sufijo_control
	)
	# Normalización segura: con el jugador quieto (0,0,0) no tira warnings.
	var direction = Utils.normalizar_seguro(Vector3(input_dir.x, 0, input_dir.y), Vector3.ZERO)

	# Cargando un objeto: movimiento simple, solo caminar
	if objeto_cargado != null:
		_mover_cargando(input_dir, direction, move_speed, delta)
		return

	var cambio_brusco_x = (input_dir.x != 0) and (sign(input_dir.x) != sign(ultima_dir_x)) and (ultima_dir_x != 0)
	var tiempo_total_para_run = TIEMPO_WALK_A_START + TIEMPO_START_A_RUN
	var va_a_entrar_a_slide = cambio_brusco_x and tiempo_caminando >= tiempo_total_para_run and not is_max_mode and puede_correr_aqui

	if not is_max_mode:
		stamina_carrera = max(0.0, stamina_carrera - delta)

	if not esta_derrapando and not va_a_entrar_a_slide:
		if input_dir.x != 0:
			direccion_mirando_x = input_dir.x
		sprite.flip_h = direccion_mirando_x < 0
		hitbox.scale.x = -1 if sprite.flip_h else 1

	if is_max_mode:
		if esta_derrapando or tiempo_caminando > 0.0:
			reset_correr(true)

		if direction:
			reset_idle()
			velocity.x = direction.x * move_speed
			velocity.z = direction.z * move_speed

			var anim_super = skin_prefix + anim_prefix + "walk"
			if sprite.sprite_frames.has_animation(anim_super):
				sprite.play(anim_super)
			else:
				sprite.play(anim_prefix + "walk")

			if (sprite.frame == 1 or sprite.frame == 4) and can_play_step:
				can_play_step = false
				EfectosManager.play_sound("pasos", global_position, true, -12.0)
				await get_tree().create_timer(0.35).timeout
				can_play_step = true
		else:
			velocity.x = move_toward(velocity.x, 0, move_speed)
			velocity.z = move_toward(velocity.z, 0, move_speed)
			var idle_super = skin_prefix + anim_prefix + "idle"
			if sprite.sprite_frames.has_animation(idle_super):
				sprite.play(idle_super)
			else:
				sprite.play("super idle")
		return

	if esta_derrapando:
		_recuperar_resistencia(delta)
		tiempo_derrape -= delta
		velocity.x = move_toward(velocity.x, 0, move_speed * 10.0 * delta)
		velocity.z = move_toward(velocity.z, 0, move_speed * 10.0 * delta)

		var slide_anim = _obtener_animacion_valida("Slide")
		if sprite.sprite_frames.has_animation(slide_anim):
			sprite.play(slide_anim)

		if tiempo_derrape <= 0.0:
			esta_derrapando = false
			reset_correr(false)
		return

	if direction:
		reset_idle()
		var target_speed = move_speed
		corriendo_a_full_este_frame = false

		if va_a_entrar_a_slide:
			esta_derrapando = true
			tiempo_derrape = DURACION_DERRAPE
			EfectosManager.play_sound("viento", global_position, true, -4.0)
			return

		if input_dir.x != 0: ultima_dir_x = input_dir.x
		if input_dir.y != 0: ultima_dir_z = input_dir.y

		tiempo_caminando += delta

		var anim_a_reproducir = skin_prefix + anim_prefix + "walk"
		var target_max_run = run_speed

		if not puede_correr_aqui:
			target_speed = move_speed
			anim_a_reproducir = skin_prefix + anim_prefix + "walk"
			_recuperar_resistencia(delta)
		elif cansado:
			target_speed = move_speed
			anim_a_reproducir = skin_prefix + anim_prefix + "walk"
			_recuperar_resistencia(delta)
			if resistencia >= RESISTENCIA_MAX:
				cansado = false
		elif tiempo_caminando < TIEMPO_WALK_A_START:
			target_speed = move_speed
			anim_a_reproducir = skin_prefix + anim_prefix + "walk"
			_recuperar_resistencia(delta)

			tiempo_detenido_correr += delta
			if tiempo_detenido_correr >= TIEMPO_PARA_RESET_CARRERA:
				tiempo_caminando = min(tiempo_caminando, TIEMPO_WALK_A_START)

		elif tiempo_caminando < tiempo_total_para_run:
			var progreso_impulso = (tiempo_caminando - TIEMPO_WALK_A_START) / TIEMPO_START_A_RUN
			target_speed = lerp(move_speed, target_max_run * multiplicador_glitch, progreso_impulso)

			anim_a_reproducir = _obtener_animacion_valida("Start running")
			_recuperar_resistencia(delta)
		else:
			target_speed = target_max_run * multiplicador_glitch
			anim_a_reproducir = _obtener_animacion_valida("Run")
			stamina_carrera = STAMINA_CARRERA_MAX
			tiempo_detenido_correr = 0.0

			if not is_max_mode:
				resistencia = max(0.0, resistencia - delta)
				if resistencia <= 0.0:
					cansado = true
					tiempo_caminando = 0.0
					stamina_carrera = 0.0
			corriendo_a_full_este_frame = true

		velocity.x = direction.x * target_speed
		velocity.z = direction.z * target_speed

		if sprite.sprite_frames.has_animation(anim_a_reproducir):
			sprite.play(anim_a_reproducir)
		else:
			sprite.play(anim_prefix + "walk")

		if (sprite.frame == 1 or sprite.frame == 4) and can_play_step:
			can_play_step = false
			var delay_pasos = 0.35 if target_speed <= move_speed else 0.18
			EfectosManager.play_sound("pasos", global_position, true, -12.0)
			await get_tree().create_timer(delay_pasos).timeout
			can_play_step = true
	else:
		_recuperar_resistencia(delta)

		if corriendo_a_full_este_frame and puede_correr_aqui:
			corriendo_a_full_este_frame = false
			esta_derrapando = true
			tiempo_derrape = DURACION_DERRAPE
			EfectosManager.play_sound("viento", global_position, true, -4.0)
			return

		tiempo_detenido_correr += delta
		if tiempo_detenido_correr >= TIEMPO_PARA_RESET_CARRERA:
			reset_correr(true)
		else:
			reset_correr(false)

		velocity.x = move_toward(velocity.x, 0, move_speed)
		velocity.z = move_toward(velocity.z, 0, move_speed)
		if not is_dancing:
			var idle_anim = skin_prefix + anim_prefix + "idle"
			idle_timer += delta
			if idle_timer >= TIME_TO_DANCE:
				iniciar_baile_aleatorio()
			else:
				if sprite.sprite_frames.has_animation(idle_anim): sprite.play(idle_anim)
				else: sprite.play("idle")

func _hacer_squash():
	var intensidad = clamp(abs(_velocidad_y_antes) / 15.0, 0.05, 0.35)
	var escala_aplastada = Vector3(
		_escala_base_sprite.x * (1.0 + intensidad * 0.8),
		_escala_base_sprite.y * (1.0 - intensidad),
		_escala_base_sprite.z * (1.0 + intensidad * 0.8)
	)
	var tw = create_tween()
	tw.tween_property(sprite, "scale", escala_aplastada, 0.06).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(sprite, "scale", _escala_base_sprite, 0.18).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

func aplicar_glitch(desde_donde_vino_el_golpe: Vector3):
	sprite.modulate = Color(10, 10, 10)
	var dir_impacto = (global_position - desde_donde_vino_el_golpe)
	dir_impacto.y = 0
	var dir_final = Utils.normalizar_seguro(dir_impacto)
	var destino_retroceso = global_position + (dir_final * 2.0)
	var space_state = get_world_3d().direct_space_state
	var query_retroceso = PhysicsRayQueryParameters3D.create(global_position, destino_retroceso)
	var rayo_pared = space_state.intersect_ray(query_retroceso)
	if not rayo_pared.is_empty():
		destino_retroceso = rayo_pared.position + rayo_pared.normal * 0.4
	var tween = create_tween()
	tween.tween_property(self, "global_position", destino_retroceso, 0.15).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	await tween.finished
	await get_tree().create_timer(0.1).timeout
	if global_position.distance_to(posicion_hace_3s) > 1.0:
		var query_pasado = PhysicsRayQueryParameters3D.create(global_position, posicion_hace_3s)
		var rayo_pasado = space_state.intersect_ray(query_pasado)
		if rayo_pasado.is_empty():
			global_position = posicion_hace_3s
		else:
			global_position = rayo_pasado.position + rayo_pasado.normal * 0.5
	multiplicador_glitch = 0.2
	attacking = false
	reset_idle()
	reset_correr(true)
	await get_tree().create_timer(1.5).timeout
	sprite.modulate = Color(0.7, 1.2, 0.7) if ProgresoJuego.tiene_poison else Color(1, 1, 1)
	multiplicador_glitch = 1.0

func reset_idle():
	idle_timer = 0.0
	if is_dancing:
		is_dancing = false
		EfectosManager.reanudar_musica_nivel()
		if is_instance_valid(reproductor_baile) and reproductor_baile.playing:
			reproductor_baile.stop()

func execute_attack():
	reset_idle()
	reset_correr(true)
	attacking = true
	combo_step += 1
	if combo_step > 3:
		combo_step = 1
	var nombre_anim = skin_prefix + ("super punch " + str(combo_step) if is_max_mode else "punch" + str(combo_step))
	if sprite.sprite_frames.has_animation(nombre_anim):
		sprite.play(nombre_anim)
	else:
		sprite.play("punch1")
	EfectosManager.play_sound("viento", global_position, true)
	await get_tree().physics_frame
	var targets = hitbox.get_overlapping_bodies()
	for body in targets:
		if body != self:
			if body.has_method("take_damage"):
				var shake = 0.6 if is_max_mode else 0.35
				EfectosManager.impact_effect(shake, 0.12, body.global_position, combo_step)
				var dano_base = 6 if is_max_mode else 5
				if ProgresoJuego.tiene_mejora_fuerza:
					dano_base *= 3
				body.take_damage(dano_base, global_position)
				add_power(5)
	combo_timer = COMBO_TIME_WINDOW

func execute_parry():
	reset_idle()
	reset_correr(true)
	is_parrying = true
	parry_cooldown = true
	sprite.play(skin_prefix + "parry")
	emit_signal("parry_realizado")
	await get_tree().create_timer(parry_window).timeout
	is_parrying = false
	await get_tree().create_timer(1.2).timeout
	parry_cooldown = false

func add_power(amount):
	if is_max_mode: return
	power = clamp(power + amount, 0, max_power)
	if power >= max_power: activate_max_mode()

func activate_max_mode():
	soltar_objeto_por_golpe()
	reset_idle()
	reset_correr(true)
	is_max_mode = true
	is_invulnerable = true
	attacking = true
	sprite.play(skin_prefix + "super")
	EfectosManager.play_sound("power", global_position)
	await get_tree().create_timer(1.0).timeout
	attacking = false
	sprite.modulate = Color(1.5, 1.5, 2.5)
	await get_tree().create_timer(20.0).timeout
	is_max_mode = false
	is_invulnerable = false
	power = 0
	reset_correr(true)
	sprite.modulate = Color(0.7, 1.2, 0.7) if ProgresoJuego.tiene_poison else Color(1, 1, 1)

func take_damage(amount: int, _source_pos: Vector3 = Vector3.ZERO):
	reset_idle()
	reset_correr(true)
	if haciendo_glory_kill: return

	if siendo_agarrado:
		health -= amount
		EfectosManager.play_sound("hurt", global_position)
		if health <= 0:
			liberado_de_agarre()
			morir_jugador()
		return

	if is_parrying:
		EfectosManager.parry_success_effect(global_position)
		parry_cooldown = false
		add_power(30)
		if ProgresoJuego.tiene_mejora_parry:
			heal(3)
			_on_parry_exitoso()
		return
	if escudo_golpes_restantes > 0:
		escudo_golpes_restantes -= 1
		EfectosManager.play_sound("Brokenshield", global_position)
		var tw_esc = create_tween()
		sprite.modulate = Color(2, 2, 5)
		tw_esc.tween_property(sprite, "modulate", Color(0.7, 1.2, 0.7) if ProgresoJuego.tiene_poison else Color(1, 1, 1), 0.2)
		if escudo_golpes_restantes <= 0:
			ProgresoJuego.tiene_shield = false
			ProgresoJuego.guardar_partida()
		return
	if is_invulnerable: return
	_on_recibir_danio()
	soltar_objeto_por_golpe()
	EfectosManager.play_sound("hurt", global_position)
	health -= amount
	if ProgresoJuego.tiene_poison:
		devolver_daño_veneno()
	chequear_ectoplasma(health, max_health)
	chequear_reloj_arena(health, max_health)
	var hurt_anim = skin_prefix + anim_prefix + "hurt"
	if sprite.sprite_frames.has_animation(hurt_anim):
		sprite.play(hurt_anim)
	else:
		var fallback_hurt = skin_prefix + "hurt"
		if sprite.sprite_frames.has_animation(fallback_hurt):
			sprite.play(fallback_hurt)
		else:
			sprite.play("hurt")
	attacking = false
	if health <= 0:
		morir_jugador()

func morir_jugador():
	soltar_objeto_por_golpe()
	set_physics_process(false)
	is_invulnerable = true
	reset_idle()
	ProgresoJuego.ultima_ruta_nivel = get_tree().current_scene.scene_file_path
	var t = create_tween()
	t.tween_property(sprite, "modulate:a", 0.0, 0.2)
	await t.finished
	get_tree().call_deferred("change_scene_to_file", "res://scenes/GameOver.tscn")

func heal(amount): health = clamp(health + amount, 0, max_health)

func _on_animated_sprite_3d_animation_finished():
	if sprite.animation and ("Glory kill" in sprite.animation):
		_finalizar_glory_kill_logica()
		return

	if sprite.animation and ("dance" in sprite.animation or "Dance" in sprite.animation):
		reset_idle()
		return

	# La pose de "grab item" se queda congelada en el último frame mientras carga
	if sprite.animation and ("grab item" in sprite.animation):
		return

	if sprite.animation and ("punch" in sprite.animation or "hurt" in sprite.animation or "parry" in sprite.animation or "drop" in sprite.animation or sprite.animation == "super"):
		attacking = false
		sprite.play(skin_prefix + anim_prefix + "idle")

var ecto_activado = false
func chequear_ectoplasma(vida_actual: float, vida_maxima: float):
	if ProgresoJuego.tiene_batido_ectoplasma and not ecto_activado and vida_actual <= (vida_maxima * 0.3):
		activar_modo_fantasma()

func activar_modo_fantasma():
	ecto_activado = true
	ProgresoJuego.tiene_batido_ectoplasma = false
	ProgresoJuego.guardar_partida()
	defensa_ectoplasma = true
	var tw = create_tween().set_parallel(true)
	tw.tween_property(sprite, "modulate:a", 0.5, 0.5)
	tw.tween_property(sprite, "scale", sprite.scale * 1.2, 0.5)
	var v_original = speed
	speed *= 1.5
	await get_tree().create_timer(10.0).timeout
	if is_instance_valid(self):
		var tw2 = create_tween().set_parallel(true)
		tw2.tween_property(sprite, "modulate:a", 1.0 if not esta_invisible else 0.3, 0.5)
		tw2.tween_property(sprite, "scale", sprite.scale / 1.2, 0.5)
		speed = v_original
		defensa_ectoplasma = false

var reloj_activado = false
func chequear_reloj_arena(vida_actual: float, vida_maxima: float):
	if ProgresoJuego.tiene_reloj_arena and not reloj_activado and vida_actual <= (vida_maxima * 0.25):
		activar_reloj_lento()

func activar_reloj_lento():
	reloj_activado = true
	ProgresoJuego.tiene_reloj_arena = false
	ProgresoJuego.guardar_partida()
	Engine.time_scale = 0.4
	sprite.modulate = Color(0.7, 0.8, 1.0)
	await get_tree().create_timer(4.0, true, false, true).timeout
	Engine.time_scale = 1.0
	sprite.modulate = Color(0.7, 1.2, 0.7) if ProgresoJuego.tiene_poison else Color(1, 1, 1)

func aplicar_mejoras_tienda():
	if ProgresoJuego.tiene_mejora_vida:
		max_health += 50
		health = max_health
	if ProgresoJuego.tiene_mejora_vel:
		speed += 1.5
		run_speed += 2.0
	if ProgresoJuego.tiene_shield:
		escudo_golpes_restantes = 5
	if ProgresoJuego.tiene_poison:
		sprite.modulate = Color(0.7, 1.2, 0.7)

func activar_invisibilidad():
	esta_invisible = true
	sprite.modulate.a = 0.3
	add_to_group("invisible")

func devolver_daño_veneno():
	var targets = hitbox.get_overlapping_bodies()
	for body in targets:
		if body != self and body.has_method("take_damage"):
			body.take_damage(5, global_position)

func _on_parry_exitoso():
	racha_parries += 1
	print("Parries seguidos: ", racha_parries)
	if racha_parries >= 5 and not ProgresoJuego.logro_parry_master:
		ProgresoJuego.logro_parry_master = true
		ProgresoJuego.guardar_partida()
		print("¡Logro desbloqueado: Parry Handler!")

func _on_parry_fallido():
	racha_parries = 0
	print("¡Racha de parries reiniciada por fallo!")

func _on_recibir_danio():
	racha_parries = 0
	reset_idle()
	print("¡Racha de parries reiniciada por golpe!")

func iniciar_glory_kill():
	if minion_ejecutable == null or is_instance_valid(minion_ejecutable) == false: return

	haciendo_glory_kill = true
	is_invulnerable = true
	velocity = Vector3.ZERO
	attacking = false
	reset_idle()
	reset_correr(true)

	var minion_sprite = minion_ejecutable.get_node_or_null("AnimatedSprite3D")
	var offset_atras = Vector3.ZERO
	var distancia_combate = 0.44

	if minion_sprite:
		if minion_sprite.flip_h:
			offset_atras = Vector3(distancia_combate, 0, 0)
		else:
			offset_atras = Vector3(-distancia_combate, 0, 0)
	else:
		offset_atras = Vector3(0, 0, distancia_combate)

	global_position = minion_ejecutable.global_position + offset_atras

	if minion_sprite:
		sprite.flip_h = minion_sprite.flip_h
		hitbox.scale.x = -1 if sprite.flip_h else 1

	var es_minioneye = minion_ejecutable.is_in_group("minioneye")

	var nombre_anim: String
	var nombre_anim_minion: String
	var nombre_audio: String

	if es_minioneye:
		if skin_prefix == "neko_":
			nombre_anim = "neko_Sketch Glory kill 3"
			nombre_anim_minion = "minioneye kill 2"
			nombre_audio = "Glory kill 3 Neko Sketch audio"
		else:
			nombre_anim = "Sketch Glory kill 3"
			nombre_anim_minion = "minioneye kill 1"
			nombre_audio = "Glory kill 3 Sketch audio"
	else:
		var numero_random = randi_range(1, 2)
		var id_kill = str(numero_random)

		nombre_anim = skin_prefix + "Sketch Glory kill " + id_kill

		var base_index = minion_kill_base_index
		if skin_prefix == "neko_":
			base_index = 4
		var numero_minion = base_index + numero_random
		nombre_anim_minion = "minion kill " + str(numero_minion)

		if skin_prefix == "neko_":
			nombre_audio = "Glory kill " + id_kill + " Neko Sketch audio"
		else:
			nombre_audio = "Glory kill " + id_kill + " Sketch audio"

	EfectosManager.play_sound(nombre_audio, global_position)

	if minion_ejecutable.has_method("ser_ejecutado_dinamico"):
		minion_ejecutable.ser_ejecutado_dinamico(nombre_anim_minion)
	elif minion_ejecutable.has_method("ser_ejecutado"):
		minion_ejecutable.ser_ejecutado()

	sprite.stop()

	print("[GK Jugador] Intentando reproducir en Jugador: ", nombre_anim)
	if sprite.sprite_frames.has_animation(nombre_anim):
		sprite.play(nombre_anim)
	else:
		var minuscula = nombre_anim.to_lower()
		if sprite.sprite_frames.has_animation(minuscula):
			sprite.play(minuscula)
		else:
			print("[GK ERROR Jugador] No tiene la animacion: '", nombre_anim, "'!")
			await get_tree().create_timer(0.5).timeout
			_finalizar_glory_kill_logica()

func _finalizar_glory_kill_logica():
	haciendo_glory_kill = false
	is_invulnerable = false
	attacking = false
	minion_ejecutable = null
	heal(25)
	add_power(20)
	sprite.play(skin_prefix + anim_prefix + "idle")

func ser_agarrado(minion_ref: CharacterBody3D):
	if haciendo_glory_kill or is_invulnerable or siendo_agarrado or esta_invisible: return

	soltar_objeto_por_golpe()
	siendo_agarrado = true
	attacking = false
	reset_idle()
	reset_correr(true)
	minion_que_agarra = minion_ref
	velocity = Vector3.ZERO

	if is_instance_valid(minion_ref) and not minion_ref.tree_exiting.is_connected(_on_minion_agarrador_destruido):
		minion_ref.tree_exiting.connect(_on_minion_agarrador_destruido)

	var anim_agarre = _obtener_animacion_valida("grabbed Sketch")
	if sprite.sprite_frames.has_animation(anim_agarre):
		sprite.play(anim_agarre)
	else:
		sprite.play("hurt")

	var hud = get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("iniciar_skill_check_liberacion"):
		hud.iniciar_skill_check_liberacion()

func _on_minion_agarrador_destruido():
	if siendo_agarrado:
		liberado_de_agarre()

func liberado_de_agarre():
	if not siendo_agarrado and minion_que_agarra == null:
		return

	if is_instance_valid(minion_que_agarra):
		if minion_que_agarra.has_method("remove_collision_exception_with"):
			remove_collision_exception_with(minion_que_agarra)
		if minion_que_agarra.tree_exiting.is_connected(_on_minion_agarrador_destruido):
			minion_que_agarra.tree_exiting.disconnect(_on_minion_agarrador_destruido)

	siendo_agarrado = false
	minion_que_agarra = null
	attacking = false
	reset_idle()
	is_parrying = false
	reset_correr(true)
	velocity = Vector3.ZERO

	var hud = get_tree().get_first_node_in_group("hud")
	if hud and hud.get("contenedor_skill_check"):
		hud.skill_check_activa = false
		hud.contenedor_skill_check.visible = false

	sprite.play(skin_prefix + anim_prefix + "idle")

func iniciar_baile_aleatorio():
	is_dancing = true
	EfectosManager.pausar_musica_nivel()

	var numero_baile = randi_range(1, 2)
	var anim_baile = _obtener_animacion_valida("dance" + str(numero_baile))

	if sprite.sprite_frames.has_animation(anim_baile):
		sprite.play(anim_baile)
	else:
		sprite.play(_obtener_animacion_valida("dance1"))
		numero_baile = 1

	var cancion_a_sonarla = musica_baile_1 if numero_baile == 1 else musica_baile_2
	if cancion_a_sonarla and is_instance_valid(reproductor_baile):
		reproductor_baile.stream = cancion_a_sonarla
		reproductor_baile.play()
