extends CharacterBody3D

@export var jump_velocity = 4.5
var puede_saltar_aqui = false
@export var speed = 4.5
var defensa_ectoplasma = false
@export var max_health = 100.0
var health = 100.0
@export var character_name = "Prepucin"
var racha_parries = 0

var escudo_golpes_restantes = 0

var posicion_hace_3s = Vector3.ZERO
var multiplicador_glitch = 1.0

var power = 0.0
var max_power = 500.0
var is_max_mode = false
var is_invulnerable = false
var anim_prefix = ""

@onready var hitbox = $HitBox
@onready var sprite = $AnimatedSprite3D

var attacking = false
var is_parrying = false
var parry_cooldown = false
var parry_window = 0.25

var paso_reproducido_en_frame = false
var ecto_activado = false

func _ready():
	add_to_group("player")
	character_name = "Prepucin" if ProgresoJuego.idioma == "es" else "Forerat"

	aplicar_mejoras_tienda()
	health = max_health

	if ProgresoJuego.tiene_despertar_dios:
		sprite.modulate = Color(1.2, 1.2, 0.8)
	else:
		sprite.modulate = Color(1, 1, 1)

	posicion_hace_3s = global_position
	iniciar_rastreo_posicion()

	if sprite and not sprite.frame_changed.is_connected(_on_sprite_frame_changed):
		sprite.frame_changed.connect(_on_sprite_frame_changed)

func iniciar_rastreo_posicion():
	while true:
		await get_tree().create_timer(3.0).timeout
		if is_on_floor() and not attacking and not esta_muerto_temporal:
			posicion_hace_3s = global_position

func _physics_process(delta):
	if get_parent().is_in_group("nivel_con_gravedad"):
		puede_saltar_aqui = true

	anim_prefix = "super " if is_max_mode else ""
	var mult_dios = 2.0 if ProgresoJuego.tiene_despertar_dios else 1.0

	var base_speed = (speed * mult_dios) if not is_max_mode else (1.5 * speed * mult_dios)
	var current_speed = base_speed * multiplicador_glitch

	if attacking or is_parrying or (sprite.animation and sprite.animation.contains("hurt")) or sprite.animation == "super":
		velocity.x = move_toward(velocity.x, 0, current_speed)
		velocity.z = move_toward(velocity.z, 0, current_speed)
	else:
		handle_movement(current_speed)

	if Input.is_action_just_pressed("ataque") and not attacking and not is_parrying:
		execute_attack()

	if Input.is_action_just_pressed("parry") and not is_max_mode:
		if not attacking and not is_parrying and not parry_cooldown:
			execute_parry()

	if puede_saltar_aqui:
		if not is_on_floor():
			velocity.y -= ProjectSettings.get_setting("physics/3d/default_gravity") * delta
		if Input.is_action_just_pressed("salto") and is_on_floor():
			velocity.y = jump_velocity
	else:
		if not is_on_floor():
			velocity.y -= 9.8 * delta

	move_and_slide()

func _on_sprite_frame_changed():
	paso_reproducido_en_frame = false

func handle_movement(move_speed):
	var input_dir = Input.get_vector("izquierda", "derecha", "arriba", "abajo")
	var direction = (Vector3(input_dir.x, 0, input_dir.y)).normalized()

	if direction:
		velocity.x = direction.x * move_speed
		velocity.z = direction.z * move_speed
		sprite.play(anim_prefix + "walk")
		hitbox.scale.x = -1 if direction.x < 0 else 1

		if (sprite.frame == 1 or sprite.frame == 4) and not paso_reproducido_en_frame:
			paso_reproducido_en_frame = true
			EfectosManager.play_sound("pasos", global_position, true, -10.0)
	else:
		velocity.x = move_toward(velocity.x, 0, move_speed)
		velocity.z = move_toward(velocity.z, 0, move_speed)
		sprite.play(anim_prefix + "idle")

func execute_attack():
	attacking = true
	var nombre_anim = "super punch 1" if is_max_mode else "punch1"

	if sprite.sprite_frames.has_animation(nombre_anim):
		sprite.play(nombre_anim)
	else:
		sprite.play("punch1")

	# --- SONIDO AL ATACAR ---
	EfectosManager.play_sound("viento", global_position, true)

	await get_tree().physics_frame

	var targets = hitbox.get_overlapping_bodies()
	for body in targets:
		if body != self and (body.is_in_group("enemies") or body.is_in_group("boss")):
			# --- SONIDO AL IMPACTAR ENEMIGO ---
			EfectosManager.impact_effect(0.35, 0.12, body.global_position, 1)
			
			if is_max_mode:
				if ProgresoJuego.tiene_despertar_dios:
					if body.has_method("take_damage"): body.take_damage(200, global_position)
				else:
					if body.has_method("heal"): body.heal(15)
					take_damage(2, global_position)
			else:
				if body.has_method("take_damage"):
					var dano_base = 1.0
					if ProgresoJuego.tiene_despertar_dios: dano_base = 50.0
					if ProgresoJuego.tiene_mejora_fuerza: dano_base *= 1.5
					if ProgresoJuego.tiene_poison: dano_base += 10.0
					body.take_damage(dano_base, global_position)
					add_power(20 if ProgresoJuego.tiene_despertar_dios else 10)

func execute_parry():
	is_parrying = true
	parry_cooldown = true
	
	# --- SONIDO AL INICIAR PARRY ---
	EfectosManager.play_sound("viento", global_position)

	if sprite.sprite_frames.has_animation("parry"):
		sprite.play("parry")

	await get_tree().create_timer(parry_window).timeout
	is_parrying = false

	await get_tree().create_timer(1.5).timeout
	parry_cooldown = false

func add_power(amount):
	if is_max_mode: return
	power = clamp(power + amount, 0, max_power)
	if power >= max_power: activate_max_mode()

func activate_max_mode():
	is_max_mode = true
	is_invulnerable = true
	attacking = true

	# --- SONIDO DE SÚPER DE PREPUCIN ---
	EfectosManager.play_sound("prepucin super", global_position)

	sprite.play("super")
	if ProgresoJuego.tiene_despertar_dios:
		sprite.modulate = Color(3, 3, 0)

	await get_tree().create_timer(1.0).timeout
	attacking = false

	var duracion = 25.0 if ProgresoJuego.tiene_despertar_dios else 12.0
	await get_tree().create_timer(duracion).timeout

	is_max_mode = false
	is_invulnerable = false
	power = 0

	if ProgresoJuego.tiene_poison:
		sprite.modulate = Color(0.7, 1.2, 0.7)
	elif ProgresoJuego.tiene_despertar_dios:
		sprite.modulate = Color(1.2, 1.2, 0.8)
	else:
		sprite.modulate = Color(1, 1, 1)

func take_damage(amount: int, source_pos: Vector3 = Vector3.ZERO):
	if is_invulnerable or esta_muerto_temporal: return

	if is_parrying:
		EfectosManager.parry_success_effect(global_position)
		parry_cooldown = false 
		add_power(30)
		_on_parry_exitoso()
		return

	if escudo_golpes_restantes > 0:
		escudo_golpes_restantes -= 1
		EfectosManager.play_sound("Brokenshield", global_position)
		if escudo_golpes_restantes <= 0:
			ProgresoJuego.tiene_shield = false
			_on_parry_exitoso()
		return

	var dano_final = amount
	if ProgresoJuego.tiene_despertar_dios: dano_final *= 0.1

	# --- SONIDO DE DAÑO DE PREPUCIN ---
	EfectosManager.play_sound("prepucin damage", global_position)

	health -= dano_final

	if ProgresoJuego.tiene_poison:
		devolver_daño_veneno()

	chequear_ectoplasma(health, max_health)
	chequear_reloj_arena(health, max_health)

	var hurt_anim = anim_prefix + "hurt"
	if sprite.sprite_frames.has_animation(hurt_anim):
		sprite.play(hurt_anim)

	if health <= 0:
		morir()

var esta_muerto_temporal = false
func morir():
	if esta_muerto_temporal: return
	esta_muerto_temporal = true
	ProgresoJuego.ultima_ruta_nivel = get_tree().current_scene.scene_file_path
	set_physics_process(false)
	var tw = create_tween()
	tw.tween_property(sprite, "modulate:a", 0.0, 0.5)
	await tw.finished
	get_tree().change_scene_to_file("res://scenes/GameOver.tscn")

func _on_animated_sprite_3d_animation_finished():
	var anim = sprite.animation
	if "punch" in anim or "hurt" in anim or "parry" in anim or anim == "super":
		attacking = false
		sprite.play(anim_prefix + "idle")

func chequear_ectoplasma(vida_actual: float, vida_maxima: float):
	if ProgresoJuego.tiene_batido_ectoplasma and not ecto_activado and vida_actual <= (vida_maxima * 0.3):
		activar_modo_fantasma()

func activar_modo_fantasma():
	ecto_activado = true
	ProgresoJuego.tiene_batido_ectoplasma = false
	defensa_ectoplasma = true
	var tw = create_tween().set_parallel(true)
	tw.tween_property(sprite, "modulate:a", 0.5, 0.5)
	tw.tween_property(self, "scale", scale * 1.2, 0.5)
	var v_original = speed
	speed *= 1.5
	await get_tree().create_timer(20.0).timeout
	if is_instance_valid(self):
		var tw2 = create_tween().set_parallel(true)
		tw2.tween_property(self, "scale", scale / 1.2, 0.5)
		speed = v_original
		defensa_ectoplasma = false
		ecto_activado = false

var reloj_activado = false
func chequear_reloj_arena(vida_actual: float, vida_maxima: float):
	if ProgresoJuego.tiene_reloj_arena and not reloj_activado and vida_actual <= (vida_maxima * 0.25):
		activar_reloj_lento()

func activar_reloj_lento():
	reloj_activado = true
	ProgresoJuego.tiene_reloj_arena = false
	Engine.time_scale = 0.4
	sprite.modulate = Color(0.7, 0.8, 1.0)
	await get_tree().create_timer(4.0, true, false, true).timeout
	Engine.time_scale = 1.0
	sprite.modulate = Color(1, 1, 1)

func aplicar_mejoras_tienda():
	if ProgresoJuego.tiene_mejora_vida: max_health += 50.0
	if ProgresoJuego.tiene_mejora_vel: speed += 1.5
	if ProgresoJuego.tiene_despertar_dios:
		max_health = 500.0
	if ProgresoJuego.tiene_shield: escudo_golpes_restantes = 10
	if ProgresoJuego.tiene_poison: sprite.modulate = Color(0.7, 1.2, 0.7)
	health = max_health

func devolver_daño_veneno():
	var targets = hitbox.get_overlapping_bodies()
	for body in targets:
		if body != self and body.has_method("take_damage"):
			body.take_damage(15, global_position)

func _on_parry_exitoso():
	racha_parries += 1
	if racha_parries >= 5 and not ProgresoJuego.logro_parry_master:
		ProgresoJuego.logro_parry_master = true
		ProgresoJuego.guardar_partida()

func _on_recibir_danio():
	racha_parries = 0
