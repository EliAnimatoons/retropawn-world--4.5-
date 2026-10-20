extends CharacterBody3D

var sufijo_control: String = ""
signal parry_realizado

# --- STATS DE TANQUE ---
@export var jump_velocity = 4.0
var puede_saltar_aqui = false
@export var speed = 1.5
var defensa_ectoplasma = false
@export var max_health = 180.0
@onready var health = 180.0
@export var character_name = "Chosmix"
var racha_parries = 0
@export var minion_kill_base_index: int = 0

# --- MECÁNICA ÚNICA: MODO FANTASMA (HABILIDAD ACTIVA) ---
var modo_fantasma_activo: bool = false
var cooldown_fantasma: bool = false
@export var duracion_fantasma: float = 6.0
@export var tiempo_cooldown_fantasma: float = 12.0
var mascara_colision_original: int = 0

# --- VARIABLES DE ESTADO Y MEJORAS ---
var escudo_golpes_restantes = 0
var esta_invisible = false

var posicion_hace_3s = Vector3.ZERO
var multiplicador_glitch = 1.0

var idle_timer = 0.0
const TIME_TO_DANCE = 120.0
var is_dancing = false

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

# --- VARIABLES DE FÍSICAS ---
var _estaba_en_suelo: bool = true
var _velocidad_y_antes: float = 0.0

# --- GLORY KILL VARIABLES ---
var minion_ejecutable: Node3D = null
var haciendo_glory_kill: bool = false

# --- SISTEMA DE AGARRE ---
var siendo_agarrado: bool = false
var minion_que_agarra: CharacterBody3D = null

func _ready():
	if sprite:
		if not sprite.animation_finished.is_connected(_on_animated_sprite_3d_animation_finished):
			sprite.animation_finished.connect(_on_animated_sprite_3d_animation_finished)
			
	if not InputMap.has_action("modo_fantasma"):
		InputMap.add_action("modo_fantasma")
		var evento_tecla = InputEventKey.new()
		evento_tecla.physical_keycode = KEY_SPACE
		InputMap.action_add_event("modo_fantasma", evento_tecla)

func iniciar_rastreo_posicion():
	while true:
		await get_tree().create_timer(3.0).timeout
		if is_on_floor() and not attacking:
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

	if get_parent().is_in_group("nivel_con_gravedad"):
		puede_saltar_aqui = true

	if ProgresoJuego.get("skin_neko_equipada"):
		skin_prefix = "neko_"
	elif ProgresoJuego.get("skin_max_equipada"):
		skin_prefix = "classic_"
	elif ProgresoJuego.get("skin_maid_equipada"):
		skin_prefix = "maid_"
	else:
		skin_prefix = ""

	anim_prefix = "super " if is_max_mode else ""

	var base_speed = speed if not is_max_mode else 3.5
	if modo_fantasma_activo:
		base_speed *= 1.75
	var current_speed = base_speed * multiplicador_glitch

	if attacking or is_parrying or (sprite.animation.contains("hurt") if sprite.animation else false) or sprite.animation == "super":
		velocity.x = move_toward(velocity.x, 0, current_speed)
		velocity.z = move_toward(velocity.z, 0, current_speed)
		reset_idle()
	else:
		handle_movement(current_speed, delta)

	if combo_timer > 0:
		combo_timer -= delta
	else:
		combo_step = 0

	if Input.is_action_just_pressed("modo_fantasma" + sufijo_control) and not modo_fantasma_activo and not cooldown_fantasma and not haciendo_glory_kill:
		activar_modo_fantasma_chosmix()

	if Input.is_action_just_pressed("glory_kill") and minion_ejecutable != null and not attacking and not is_parrying and not is_max_mode:
		iniciar_glory_kill()

	if Input.is_action_just_pressed("ataque" + sufijo_control) and not attacking and not is_parrying and not haciendo_glory_kill:
		execute_attack()

	if Input.is_action_just_pressed("parry" + sufijo_control) and not is_max_mode and not haciendo_glory_kill:
		if not attacking and not is_parrying and not parry_cooldown:
			execute_parry()

	var en_suelo_ahora = is_on_floor()
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

func aplicar_glitch(desde_donde_vino_el_golpe: Vector3):
	sprite.modulate = Color(10, 10, 10)
	var dir_impacto = (global_position - desde_donde_vino_el_golpe)
	dir_impacto.y = 0
	var dir_final = dir_impacto.normalized()
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
	is_dancing = false
	await get_tree().create_timer(1.5).timeout
	sprite.modulate = Color(0.7, 1.2, 0.7) if ProgresoJuego.tiene_poison else Color(1, 1, 1)
	multiplicador_glitch = 1.0

func handle_movement(move_speed, delta):
	var input_dir = Input.get_vector(
		"izquierda" + sufijo_control,
		"derecha" + sufijo_control,
		"arriba" + sufijo_control,
		"abajo" + sufijo_control
	)
	var direction = (Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction:
		reset_idle()
		velocity.x = direction.x * move_speed
		velocity.z = direction.z * move_speed
		var anim_target = skin_prefix + anim_prefix + "walk"
		if sprite.sprite_frames.has_animation(anim_target):
			sprite.play(anim_target)
		else:
			sprite.play(anim_prefix + "walk")
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
		if not is_dancing:
			var idle_anim = skin_prefix + anim_prefix + "idle"
			if not is_max_mode:
				idle_timer += delta
				if idle_timer >= TIME_TO_DANCE:
					is_dancing = true
					sprite.play(skin_prefix + "dance1")
				else:
					if sprite.sprite_frames.has_animation(idle_anim): sprite.play(idle_anim)
					else: sprite.play("idle")
			else:
				if sprite.sprite_frames.has_animation(idle_anim): sprite.play(idle_anim)
				else: sprite.play("super idle" if is_max_mode else "idle")

func reset_idle():
	idle_timer = 0.0
	is_dancing = false

func execute_attack():
	reset_idle()
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
				var shake = 0.8 if is_max_mode else 0.5
				EfectosManager.impact_effect(shake, 0.15, body.global_position, combo_step)
				var dano_base = 5.0 if is_max_mode else 1.0
				if modo_fantasma_activo:
					dano_base *= 0.5
				if ProgresoJuego.tiene_mejora_fuerza:
					dano_base *= 1.5
				body.take_damage(dano_base, global_position)
				add_power(6)
	combo_timer = COMBO_TIME_WINDOW

func execute_parry():
	reset_idle()
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
	reset_idle()
	is_max_mode = true
	is_invulnerable = true
	attacking = true
	sprite.play(skin_prefix + "super")
	EfectosManager.play_sound("power", global_position)
	EfectosManager.play_sound("musica_super", global_position)
	await get_tree().create_timer(1.0).timeout
	attacking = false
	sprite.modulate = Color(1.5, 1.5, 2.5)
	await get_tree().create_timer(20.0).timeout
	is_max_mode = false
	is_invulnerable = false
	power = 0
	sprite.modulate = Color(0.7, 1.2, 0.7) if ProgresoJuego.tiene_poison else Color(1, 1, 1)
	if EfectosManager.has_method("stop_sound"):
		EfectosManager.stop_sound("musica_super")

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
	EfectosManager.play_sound("hurt", global_position)

	var danio_mitigado = amount * 0.85
	health -= danio_mitigado

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
	set_physics_process(false)
	is_invulnerable = true
	ProgresoJuego.ultima_ruta_nivel = get_tree().current_scene.scene_file_path
	var t = create_tween()
	t.tween_property(sprite, "modulate:a", 0.0, 0.2)
	await t.finished
	get_tree().call_deferred("change_scene_to_file", "res://scenes/GameOver.tscn")

func heal(amount):
	health = clamp(health + amount, 0, max_health)

func _on_animated_sprite_3d_animation_finished():
	if sprite.animation and ("Glory kill" in sprite.animation):
		_finalizar_glory_kill_logica()
		return

	if sprite.animation and ("punch" in sprite.animation or "hurt" in sprite.animation or "parry" in sprite.animation or sprite.animation == "super" or sprite.animation == "dance1"):
		attacking = false
		is_dancing = false
		sprite.play(skin_prefix + anim_prefix + "idle")

# --- MÉTODOS DE MODO FANTASMA ---
func activar_modo_fantasma_chosmix():
	modo_fantasma_activo = true
	esta_invisible = true
	add_to_group("invisible")
	var tw = create_tween()
	tw.tween_property(sprite, "modulate:a", 0.25, 0.4)
	EfectosManager.play_sound("viento", global_position, true)
	for body in get_tree().get_nodes_in_group("enemy"):
		if body is CollisionObject3D:
			add_collision_exception_with(body)
	await get_tree().create_timer(duracion_fantasma).timeout
	desactivar_modo_fantasma_chosmix()

func desactivar_modo_fantasma_chosmix():
	if not is_instance_valid(self): return
	for body in get_tree().get_nodes_in_group("enemy"):
		if body is CollisionObject3D:
			remove_collision_exception_with(body)
	var tw = create_tween()
	tw.tween_property(sprite, "modulate:a", 1.0, 0.4)
	modo_fantasma_activo = false
	esta_invisible = false
	remove_from_group("invisible")
	cooldown_fantasma = true
	await get_tree().create_timer(tiempo_cooldown_fantasma).timeout
	cooldown_fantasma = false

# --- ITEM BATIDO ECTOPLASMA ---
var ecto_activado = false
func chequear_ectoplasma(vida_actual: float, vida_maxima: float):
	if ProgresoJuego.tiene_batido_ectoplasma and not ecto_activado and vida_actual <= (vida_maxima * 0.3):
		activar_modo_fantasma()

func activar_modo_fantasma():
	ecto_activado = true
	ProgresoJuego.tiene_batido_ectoplasma = false
	ProgresoJuego.guardar_partida()
	defensa_ectoplasma = true
	var tw = create_tween()
	tw.tween_property(sprite, "modulate:a", 0.5, 0.5)
	var v_original = speed
	speed *= 1.5
	await get_tree().create_timer(10.0).timeout
	if is_instance_valid(self):
		var tw2 = create_tween()
		tw2.tween_property(sprite, "modulate:a", 1.0 if not esta_invisible else 0.3, 0.5)
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
			body.take_damage(8, global_position)

func _on_parry_exitoso():
	racha_parries += 1
	if racha_parries >= 5 and not ProgresoJuego.logro_parry_master:
		ProgresoJuego.logro_parry_master = true
		ProgresoJuego.guardar_partida()
		print("¡Logro desbloqueado: Parry Handler!")

func _on_parry_fallido():
	racha_parries = 0

func _on_recibir_danio():
	racha_parries = 0

# --- GLORY KILLS ---
func iniciar_glory_kill():
	if minion_ejecutable == null or is_instance_valid(minion_ejecutable) == false: return

	haciendo_glory_kill = true
	is_invulnerable = true
	velocity = Vector3.ZERO
	attacking = false
	is_dancing = false

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

	# Chosmix tiene 2 glory kills, sin distincion de skin por ahora
	var numero_random = randi_range(1, 2)
	var id_kill = str(numero_random)

	# "Chosmix Glory kill 1" o "Chosmix Glory kill 2"
	var nombre_anim = "Chosmix Glory kill " + id_kill
	# minion kill 11 para kill 1, minion kill 12 para kill 2
	var nombre_anim_minion = "minion kill " + str(numero_random + 10)
	# "Glory kill 1 Chosmix audio" o "Glory kill 2 Chosmix audio"
	var nombre_audio = "Glory kill " + id_kill + " Chosmix audio"

	EfectosManager.play_sound(nombre_audio, global_position)

	if minion_ejecutable.has_method("ser_ejecutado_dinamico"):
		minion_ejecutable.ser_ejecutado_dinamico(nombre_anim_minion)
	elif minion_ejecutable.has_method("ser_ejecutado"):
		minion_ejecutable.ser_ejecutado()

	sprite.stop()

	print("[GK Chosmix] Intentando reproducir: ", nombre_anim)
	if sprite.sprite_frames.has_animation(nombre_anim):
		sprite.play(nombre_anim)
	else:
		var minuscula = nombre_anim.to_lower()
		if sprite.sprite_frames.has_animation(minuscula):
			sprite.play(minuscula)
		else:
			print("[GK ERROR Chosmix] No tiene la animacion: '", nombre_anim, "'!")
			await get_tree().create_timer(0.5).timeout
			_finalizar_glory_kill_logica()

func _finalizar_glory_kill_logica():
	haciendo_glory_kill = false
	is_invulnerable = false
	attacking = false
	minion_ejecutable = null
	heal(40)
	add_power(20)
	sprite.play(skin_prefix + anim_prefix + "idle")

# --- MÉTODOS DEL SISTEMA DE AGARRE ---
func ser_agarrado(minion_ref: CharacterBody3D):
	if haciendo_glory_kill or is_invulnerable or siendo_agarrado or esta_invisible: return

	siendo_agarrado = true
	attacking = false
	is_dancing = false
	minion_que_agarra = minion_ref
	velocity = Vector3.ZERO

	if is_instance_valid(minion_ref) and not minion_ref.tree_exiting.is_connected(_on_minion_agarrador_destruido):
		minion_ref.tree_exiting.connect(_on_minion_agarrador_destruido)

	if sprite.sprite_frames.has_animation("grabbed Sketch"):
		sprite.play("grabbed Sketch")
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
	is_dancing = false
	is_parrying = false
	velocity = Vector3.ZERO

	var hud = get_tree().get_first_node_in_group("hud")
	if hud and hud.get("contenedor_skill_check"):
		hud.skill_check_activa = false
		hud.contenedor_skill_check.visible = false

	sprite.play(skin_prefix + anim_prefix + "idle")
