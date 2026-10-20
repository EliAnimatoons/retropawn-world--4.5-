extends CharacterBody3D

var sufijo_control: String = ""
signal parry_realizado

@export var jump_velocity = 4.5
var puede_saltar_aqui = false
var puede_correr_aqui = false
@export var speed = 2.6
@export var run_speed = 5.0
var defensa_ectoplasma = false
@export var max_health = 90.0
var health = 90.0
@export var character_name = "Alloy"
var racha_parries = 0

# --- GLORY KILL: indices de animaciones del minion ---
# Animacion que reproduce el minion cuando Alloy le hace un glory kill.
@export var minion_kill_anim: String = "minion kill 16"
# Animacion del minion para el glory kill contra minioneye (solo si existe "Alloy Glory kill 3")
@export var minioneye_kill_anim_minion: String = "minioneye kill 3"

var escudo_golpes_restantes = 0
var esta_invisible = false
var tutorial_bloqueo = false

var posicion_hace_3s = Vector3.ZERO
var multiplicador_glitch = 1.0

# --- IDLE / BAILE ---
var idle_timer = 0.0
const TIME_TO_DANCE = 120.0
var is_dancing = false

@export_group("Música de Baile")
@export var musica_baile_1: AudioStream
@export var musica_baile_2: AudioStream
# Opcional: si no existe el nodo AudioStreamPlayer3D, baila sin musica (no da error)
@onready var reproductor_baile = get_node_or_null("AudioStreamPlayer3D")

# --- SISTEMA DE PROYECTIL Y RAFAGA SUPER ---
const BALA_ESCENA = preload("res://scenes/BalaJane.tscn")
@export var CADENCIA_DISPARO_SUPER: float = 0.15
var tiempo_siguiente_disparo: float = 0.0

var esta_cargando_disparo: bool = false
var esta_disparando_rafaga: bool = false
var temporizador_rafaga: float = 0.0
const DURACION_MAXIMA_RAFAGA: float = 2.0
var _id_carga: int = 0 # invalida "await" viejos de la secuencia de carga

# --- MODO SUPER / POWER ---
var power = 0.0
var max_power = 500.0
var is_max_mode = false
var transformando_super = false
var is_invulnerable = false
var anim_prefix = ""
var skin_prefix = ""

@onready var hitbox = $HitBox
@onready var sprite = $AnimatedSprite3D

# --- COMBAT & ACCIONES ---
var combo_step = 0
var attacking = false
var combo_timer = 0.0
const COMBO_TIME_WINDOW = 0.6
var is_parrying = false
var parry_cooldown = false
var parry_window = 0.25
var can_play_step = true

# --- GLORY KILL VARIABLES ---
var minion_ejecutable: Node3D = null
var haciendo_glory_kill: bool = false
var _gk_id: int = 0 # evita que un timer viejo cierre un glory kill nuevo

# --- SISTEMA DE AGARRE (GRAB) ---
var siendo_agarrado: bool = false
var minion_que_agarra: Node3D = null

func _ready():
	add_to_group("player")
	aplicar_mejoras_tienda()
	posicion_hace_3s = global_position
	iniciar_rastreo_posicion()

	# Si una animacion tiene Loop activado, "animation_finished" nunca se emite.
	# Escuchamos tambien "animation_looped" y la tratamos como un final.
	if not sprite.animation_looped.is_connected(_on_animated_sprite_3d_animation_looped):
		sprite.animation_looped.connect(_on_animated_sprite_3d_animation_looped)

func iniciar_rastreo_posicion():
	while true:
		await get_tree().create_timer(3.0).timeout
		if is_on_floor() and not attacking and not siendo_agarrado and not esta_disparando_rafaga:
			posicion_hace_3s = global_position

func _physics_process(delta):
	# --- CONTROL DE AGARRE ---
	if siendo_agarrado:
		if not is_instance_valid(minion_que_agarra):
			liberado_de_agarre()
			return
		velocity.x = 0
		velocity.z = 0
		if not is_on_floor():
			velocity.y -= 9.8 * delta
		move_and_slide()
		return

	if tutorial_bloqueo or haciendo_glory_kill: return

	# Permisos del nivel padre
	var padre = get_parent()
	if padre:
		puede_saltar_aqui = padre.is_in_group("nivel_con_gravedad")
		puede_correr_aqui = padre.is_in_group("nivel_con_carrera")

	skin_prefix = ""
	anim_prefix = "super " if is_max_mode else ""

	var base_speed = speed if not is_max_mode else 4.8
	var current_speed = base_speed * multiplicador_glitch

	# Disparo en modo super (no durante la animacion de transformacion)
	if is_max_mode and not haciendo_glory_kill and not transformando_super:
		procesar_rafaga_disparos(delta)

	# Bloqueo de movimiento durante ataques, parries, cargas, dano o transformacion
	if attacking or is_parrying or esta_cargando_disparo or esta_disparando_rafaga or transformando_super or (sprite.animation.contains("hurt") if sprite.animation else false) or sprite.animation == "super":
		velocity.x = move_toward(velocity.x, 0, current_speed)
		velocity.z = move_toward(velocity.z, 0, current_speed)
		reset_idle()
	else:
		handle_movement(current_speed, delta)

	# Temporizador de combo melee
	if combo_timer > 0: combo_timer -= delta
	else: combo_step = 0

	# Glory Kill
	if Input.is_action_just_pressed("glory_kill") and minion_ejecutable != null and not attacking and not is_parrying and not is_max_mode and not haciendo_glory_kill:
		iniciar_glory_kill()

	# Ataque melee (solo modo normal)
	if not is_max_mode:
		if Input.is_action_just_pressed("ataque" + sufijo_control) and not attacking and not is_parrying and not haciendo_glory_kill:
			execute_attack()

	# Parry (solo modo normal)
	if Input.is_action_just_pressed("parry" + sufijo_control) and not is_max_mode and not haciendo_glory_kill:
		if not attacking and not is_parrying and not parry_cooldown:
			execute_parry()

	# Salto / gravedad
	if puede_saltar_aqui:
		if not is_on_floor():
			velocity.y -= ProjectSettings.get_setting("physics/3d/default_gravity") * delta
		if Input.is_action_just_pressed("salto" + sufijo_control) and is_on_floor():
			velocity.y = jump_velocity
			reset_idle()
	else:
		if not is_on_floor():
			velocity.y -= 9.8 * delta

	move_and_slide()

func handle_movement(move_speed, delta):
	var input_dir = Input.get_vector(
		"izquierda" + sufijo_control,
		"derecha" + sufijo_control,
		"arriba" + sufijo_control,
		"abajo" + sufijo_control
	)
	var direction = Utils.normalizar_seguro(Vector3(input_dir.x, 0, input_dir.y), Vector3.ZERO)

	if direction:
		reset_idle()
		velocity.x = direction.x * move_speed
		velocity.z = direction.z * move_speed

		var anim_walk = skin_prefix + anim_prefix + "walk"
		if sprite.sprite_frames.has_animation(anim_walk):
			sprite.play(anim_walk)
		else:
			sprite.play("walk")

		sprite.flip_h = direction.x < 0
		hitbox.scale.x = -1 if sprite.flip_h else 1

		if (sprite.frame == 1 or sprite.frame == 4) and can_play_step:
			can_play_step = false
			EfectosManager.play_sound("pasos", global_position, true, -12.0)
			await get_tree().create_timer(0.35).timeout
			can_play_step = true
	else:
		velocity.x = move_toward(velocity.x, 0, move_speed)
		velocity.z = move_toward(velocity.z, 0, move_speed)

		if not is_dancing and not esta_disparando_rafaga and not esta_cargando_disparo:
			if not is_max_mode:
				idle_timer += delta
				if idle_timer >= TIME_TO_DANCE:
					iniciar_baile_aleatorio()
					return
			_reproducir_idle()

func _reproducir_idle():
	var anim_idle = skin_prefix + anim_prefix + "idle"
	if sprite.sprite_frames.has_animation(anim_idle):
		sprite.play(anim_idle)
	else:
		sprite.play("idle" if not is_max_mode else "super idle")

func reset_idle():
	idle_timer = 0.0
	if is_dancing:
		is_dancing = false
		EfectosManager.reanudar_musica_nivel()
		if is_instance_valid(reproductor_baile) and reproductor_baile.playing:
			reproductor_baile.stop()

func iniciar_baile_aleatorio():
	var numero_baile = randi_range(1, 2)
	var anim_baile = "dance" + str(numero_baile)

	if not sprite.sprite_frames.has_animation(anim_baile):
		numero_baile = 1
		anim_baile = "dance1"
		if not sprite.sprite_frames.has_animation(anim_baile):
			# Alloy todavia no tiene baile: se queda en idle
			idle_timer = 0.0
			return

	is_dancing = true
	EfectosManager.pausar_musica_nivel()
	sprite.play(anim_baile)

	var cancion = musica_baile_1 if numero_baile == 1 else musica_baile_2
	if cancion and is_instance_valid(reproductor_baile):
		reproductor_baile.stream = cancion
		reproductor_baile.play()

# --- COMBO MELEE ---
func execute_attack():
	reset_idle()
	attacking = true
	combo_step += 1
	if combo_step > 3:
		combo_step = 1

	var nombre_anim = skin_prefix + "punch" + str(combo_step)
	if sprite.sprite_frames.has_animation(nombre_anim):
		sprite.play(nombre_anim)
	else:
		sprite.play("punch" + str(combo_step))

	EfectosManager.play_sound("viento", global_position, true)
	await get_tree().physics_frame

	var targets = hitbox.get_overlapping_bodies()
	for body in targets:
		if body != self:
			if body.is_in_group("enemy") or body.is_in_group("enemies") or "tacho" in body.name.to_lower():
				if body.has_method("take_damage"):
					EfectosManager.impact_effect(0.35, 0.12, body.global_position, combo_step)
					var dano_final = 3.5
					if ProgresoJuego.tiene_mejora_fuerza: dano_final *= 1.5
					body.take_damage(dano_final, global_position)
					add_power(8)

	combo_timer = COMBO_TIME_WINDOW

# --- SUPER: CARGA -> RAFAGA ---
func procesar_rafaga_disparos(delta: float):
	if Input.is_action_pressed("ataque" + sufijo_control):
		reset_idle()

		# 1. Fase de carga
		if not esta_disparando_rafaga and not esta_cargando_disparo:
			iniciar_secuencia_carga_y_rafaga()
			return

		# 2. Fase de rafaga activa
		if esta_disparando_rafaga:
			temporizador_rafaga += delta
			tiempo_siguiente_disparo -= delta

			if temporizador_rafaga >= DURACION_MAXIMA_RAFAGA:
				cancelar_rafaga_disparos()
				return

			if tiempo_siguiente_disparo <= 0.0:
				_disparar_proyectil_rafaga()
				tiempo_siguiente_disparo = CADENCIA_DISPARO_SUPER
	else:
		# Al soltar el boton se corta la rafaga
		if esta_disparando_rafaga or esta_cargando_disparo:
			cancelar_rafaga_disparos()

func iniciar_secuencia_carga_y_rafaga():
	esta_cargando_disparo = true
	attacking = true
	_id_carga += 1
	var mi_id = _id_carga

	var anim_carga = skin_prefix + "super carga"
	if sprite.sprite_frames.has_animation(anim_carga):
		sprite.play(anim_carga)
	else:
		sprite.play("super carga")

	await get_tree().create_timer(0.25).timeout

	# Si se cancelo (o empezo otra carga) mientras esperabamos, no hacemos nada
	if mi_id != _id_carga or not is_max_mode: return

	if Input.is_action_pressed("ataque" + sufijo_control) and not siendo_agarrado and not haciendo_glory_kill:
		esta_cargando_disparo = false
		esta_disparando_rafaga = true
		temporizador_rafaga = 0.0
		tiempo_siguiente_disparo = 0.0
	else:
		cancelar_rafaga_disparos()

func _disparar_proyectil_rafaga():
	var anim_shoot = skin_prefix + "shoot"
	if sprite.animation != anim_shoot and sprite.animation != "shoot":
		if sprite.sprite_frames.has_animation(anim_shoot):
			sprite.play(anim_shoot)
		else:
			sprite.play("shoot")

	var bala = BALA_ESCENA.instantiate()
	get_tree().current_scene.add_child(bala)
	bala.global_position = global_position + Vector3(0, 0.1, 0)

	if bala.has_method("set_source"):
		bala.set_source(global_position)
	elif "source_pos" in bala:
		bala.source_pos = global_position

	var dir_x = -1.0 if sprite.flip_h else 1.0
	bala.direccion = Vector3(dir_x, 0, 0)
	bala.rotation.y = PI if dir_x < 0 else 0.0

	if "max_distancia" in bala:
		bala.max_distancia = 8.0

	bala.scale = Vector3(1.8, 1.8, 1.8)
	if "dano" in bala:
		var dano_shoot = 8.0
		if ProgresoJuego.tiene_mejora_fuerza: dano_shoot *= 1.5
		bala.dano = dano_shoot

	EfectosManager.play_sound("Shoot sound", global_position, true)

func cancelar_rafaga_disparos():
	_id_carga += 1 # invalida cualquier await de carga pendiente
	esta_disparando_rafaga = false
	esta_cargando_disparo = false
	attacking = false
	temporizador_rafaga = 0.0
	tiempo_siguiente_disparo = 0.0

	if is_max_mode and not transformando_super and not haciendo_glory_kill:
		var anim_idle = skin_prefix + "super idle"
		if sprite.sprite_frames.has_animation(anim_idle):
			sprite.play(anim_idle)
		else:
			sprite.play("super idle")

# --- PARRY ---
func execute_parry():
	reset_idle()
	is_parrying = true
	parry_cooldown = true
	var anim_parry = skin_prefix + "parry"
	if sprite.sprite_frames.has_animation(anim_parry):
		sprite.play(anim_parry)
	else:
		sprite.play("parry")

	emit_signal("parry_realizado")
	await get_tree().create_timer(parry_window).timeout
	is_parrying = false
	await get_tree().create_timer(1.2).timeout
	parry_cooldown = false

# --- MODO SUPER ---
func add_power(amount):
	if is_max_mode: return
	power = clamp(power + amount, 0, max_power)
	if power >= max_power: activate_max_mode()

func activate_max_mode():
	if siendo_agarrado: return
	reset_idle()
	is_max_mode = true
	transformando_super = true
	is_invulnerable = true
	attacking = true

	var anim_super = skin_prefix + "super"
	if sprite.sprite_frames.has_animation(anim_super):
		sprite.play(anim_super)
	else:
		sprite.play("super")

	EfectosManager.play_sound("power", global_position)
	reproducir_cancion_super()

	await get_tree().create_timer(1.0).timeout
	if not is_inside_tree(): return
	transformando_super = false
	attacking = false
	sprite.modulate = Color(2.0, 1.5, 0.5)

	await get_tree().create_timer(20.0).timeout
	if not is_inside_tree(): return

	is_max_mode = false
	is_invulnerable = false
	transformando_super = false
	cancelar_rafaga_disparos()
	power = 0
	_detener_cancion_super()
	sprite.modulate = Color(0.7, 1.2, 0.7) if ProgresoJuego.tiene_poison else Color(1, 1, 1)
	sprite.play(skin_prefix + "idle")

func reproducir_cancion_super():
	var extensiones = [".mp3", ".ogg", ".wav"]
	var ruta_base = "res://SUPER SONGS!/super_alloy"
	var audio_cargado = false

	for ext in extensiones:
		var ruta_completa = ruta_base + ext
		if ResourceLoader.exists(ruta_completa):
			if EfectosManager.has_method("play_music"):
				EfectosManager.play_music(ruta_completa)
			else:
				var stream = load(ruta_completa)
				var player = AudioStreamPlayer.new()
				player.stream = stream
				player.name = "SuperAlloyMusic"
				add_child(player)
				player.play()
			audio_cargado = true
			break

	if not audio_cargado:
		print("[AUDIO WARNING] No se encontró super_alloy en res://SUPER SONGS!/")

func _detener_cancion_super():
	# Limpia el reproductor de fallback (antes quedaba sonando / acumulandose)
	var m = get_node_or_null("SuperAlloyMusic")
	if m:
		m.queue_free()
	# Si tu EfectosManager.play_music NO restaura la musica del nivel al terminar,
	# descomenta esto:
	# if EfectosManager.has_method("reanudar_musica_nivel"):
	#	EfectosManager.reanudar_musica_nivel()

# --- DANO ---
func take_damage(amount: int, _source_pos: Vector3 = Vector3.ZERO):
	reset_idle()
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
			heal(5)
			_on_parry_exitoso()
		return

	if escudo_golpes_restantes > 0:
		escudo_golpes_restantes -= 1
		EfectosManager.play_sound("Brokenshield", global_position)
		var tw_esc = create_tween()
		sprite.modulate = Color(3, 2, 1)
		tw_esc.tween_property(sprite, "modulate", Color(0.7, 1.2, 0.7) if ProgresoJuego.tiene_poison else Color(1, 1, 1), 0.2)
		if escudo_golpes_restantes <= 0:
			ProgresoJuego.tiene_shield = false
			ProgresoJuego.guardar_partida()
		return

	if is_invulnerable: return
	_on_recibir_danio()

	EfectosManager.play_sound("hurt", global_position)
	health -= amount

	if ProgresoJuego.tiene_poison:
		devolver_daño_veneno()

	chequear_ectoplasma(health, max_health)
	chequear_reloj_arena(health, max_health)

	cancelar_rafaga_disparos()

	var hurt_anim = skin_prefix + anim_prefix + "hurt"
	if sprite.sprite_frames.has_animation(hurt_anim):
		sprite.play(hurt_anim)
	else:
		sprite.play("hurt")

	attacking = false

	if health <= 0:
		morir_jugador()

func morir_jugador():
	set_physics_process(false)
	is_invulnerable = true
	reset_idle()
	_detener_cancion_super()
	ProgresoJuego.ultima_ruta_nivel = get_tree().current_scene.scene_file_path
	var t = create_tween()
	t.tween_property(sprite, "modulate:a", 0.0, 0.2)
	await t.finished
	get_tree().call_deferred("change_scene_to_file", "res://scenes/GameOver.tscn")

func heal(amount): health = clamp(health + amount, 0, max_health)

# --- SEÑALES DE ANIMACION ---
func _on_animated_sprite_3d_animation_finished():
	var anim = str(sprite.animation)
	var anim_lower = anim.to_lower()

	if "glory kill" in anim_lower:
		_finalizar_glory_kill_logica()
		return

	if "dance" in anim_lower:
		reset_idle()
		return

	# La animacion de disparo debe seguir mientras dure la rafaga
	if anim_lower.ends_with("shoot") and esta_disparando_rafaga:
		sprite.play(anim)
		return

	if "punch" in anim or "hurt" in anim or "parry" in anim or anim == "super":
		attacking = false
		is_parrying = false
		if anim == "super":
			transformando_super = false
		sprite.play(skin_prefix + anim_prefix + "idle")

func _on_animated_sprite_3d_animation_looped():
	# Si alguna animacion "de una sola vez" quedo con Loop activado,
	# la primera vuelta completa cuenta como final.
	var anim = str(sprite.animation)
	if "glory kill" in anim.to_lower() or "punch" in anim or "hurt" in anim or "parry" in anim or anim == "super":
		_on_animated_sprite_3d_animation_finished()

# --- GLORY KILL ---
func iniciar_glory_kill():
	if minion_ejecutable == null or not is_instance_valid(minion_ejecutable): return
	if minion_ejecutable.get("siendo_ejecutado") == true: return

	haciendo_glory_kill = true
	is_invulnerable = true
	velocity = Vector3.ZERO
	attacking = false
	cancelar_rafaga_disparos()
	reset_idle()

	_gk_id += 1
	var mi_gk = _gk_id

	var minion_sprite = minion_ejecutable.get_node_or_null("AnimatedSprite3D")
	var offset_atras = Vector3.ZERO
	var distancia_combate = 0.44

	if minion_sprite:
		offset_atras = Vector3(distancia_combate if minion_sprite.flip_h else -distancia_combate, 0, 0)
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
	var id_minion: String

	if es_minioneye and sprite.sprite_frames.has_animation("Alloy Glory kill 3"):
		nombre_anim = "Alloy Glory kill 3"
		nombre_anim_minion = minioneye_kill_anim_minion
		nombre_audio = "Glory kill 3 Alloy audio"
		id_minion = "3"
	else:
		var numero_random = randi_range(1, 2)
		nombre_anim = "Alloy Glory kill " + str(numero_random)
		nombre_anim_minion = minion_kill_anim
		nombre_audio = "Glory kill " + str(numero_random) + " Alloy audio"
		id_minion = minion_kill_anim.trim_prefix("minion kill ")

	EfectosManager.play_sound(nombre_audio, global_position)

	if minion_ejecutable.has_method("ser_ejecutado_dinamico"):
		minion_ejecutable.ser_ejecutado_dinamico(nombre_anim_minion)
	elif minion_ejecutable.has_method("ser_ejecutado"):
		minion_ejecutable.ser_ejecutado(id_minion)

	sprite.stop()

	print("[GK Alloy] Intentando reproducir: ", nombre_anim)
	var anim_final = nombre_anim
	if not sprite.sprite_frames.has_animation(anim_final):
		anim_final = nombre_anim.to_lower()

	if sprite.sprite_frames.has_animation(anim_final):
		sprite.play(anim_final)

		# Seguro anti-freeze (ultimo recurso). Tope fijo, ignora time_scale.
		var frames = sprite.sprite_frames.get_frame_count(anim_final)
		var fps = sprite.sprite_frames.get_animation_speed(anim_final)
		var duracion_estimada = (float(frames) / fps) + 0.3 if fps > 0.1 else 1.5
		var duracion_segura = clamp(duracion_estimada, 0.3, 8.0)
		await get_tree().create_timer(duracion_segura, true, false, true).timeout
		if haciendo_glory_kill and mi_gk == _gk_id:
			print("[GK] Seguro anti-freeze activado en: ", anim_final, " (fps: ", fps, ")")
			_finalizar_glory_kill_logica()
	else:
		print("[GK ERROR Alloy] No tiene la animacion: '", nombre_anim, "'!")
		await get_tree().create_timer(0.5).timeout
		if haciendo_glory_kill and mi_gk == _gk_id:
			_finalizar_glory_kill_logica()

func _finalizar_glory_kill_logica():
	# Evita ejecutarlo dos veces (senal + timer de seguridad)
	if not haciendo_glory_kill: return

	haciendo_glory_kill = false
	is_invulnerable = false
	attacking = false
	minion_ejecutable = null
	heal(20)
	combo_step = 0
	add_power(20)

	# Si add_power activo el modo super, no pisamos su animacion
	if not is_max_mode:
		sprite.play(skin_prefix + anim_prefix + "idle")

# --- SISTEMA DE AGARRE (GRAB) ---
func ser_agarrado(minion_ref: Node3D):
	if haciendo_glory_kill or is_invulnerable or siendo_agarrado or is_max_mode or esta_invisible: return

	siendo_agarrado = true
	attacking = false
	cancelar_rafaga_disparos()
	reset_idle()
	minion_que_agarra = minion_ref
	velocity = Vector3.ZERO

	if is_instance_valid(minion_ref) and not minion_ref.tree_exiting.is_connected(_on_minion_agarrador_destruido):
		minion_ref.tree_exiting.connect(_on_minion_agarrador_destruido)

	if sprite.sprite_frames.has_animation("grabbed Alloy"):
		sprite.play("grabbed Alloy")
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
	cancelar_rafaga_disparos()
	reset_idle()
	is_parrying = false
	velocity = Vector3.ZERO

	var hud = get_tree().get_first_node_in_group("hud")
	if hud and hud.get("contenedor_skill_check"):
		hud.skill_check_activa = false
		hud.contenedor_skill_check.visible = false

	sprite.play(skin_prefix + anim_prefix + "idle")

# --- EFECTOS / TIENDA ---
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
	if racha_parries >= 5 and not ProgresoJuego.logro_parry_master:
		ProgresoJuego.logro_parry_master = true
		ProgresoJuego.guardar_partida()

func _on_recibir_danio():
	racha_parries = 0

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
	cancelar_rafaga_disparos()
	reset_idle()
	await get_tree().create_timer(1.5).timeout
	sprite.modulate = Color(0.7, 1.2, 0.7) if ProgresoJuego.tiene_poison else Color(1, 1, 1)
	multiplicador_glitch = 1.0
