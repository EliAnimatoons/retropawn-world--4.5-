extends CharacterBody3D

var sufijo_control: String = "" # Si está vacío, usa teclado. El modo coop le cambiará esto a "_p2"
@export var jump_velocity = 4.5 # Inyección de salto
var puede_saltar_aqui = false   # Detector de nivel especial
@export var speed = 1.8
var defensa_ectoplasma = false
@export var max_health = 150.0
var health = 200.0
@export var character_name = "Max"
var racha_parries = 0

# --- VARIABLES DE NUEVOS ITEMS ---
var escudo_golpes_restantes = 0
var esta_invisible = false

# --- INYECCIÓN QUIRÚRGICA: VARIABLES GLITCH ---
var posicion_hace_3s = Vector3.ZERO
var multiplicador_glitch = 1.0
# ----------------------------------------------

# --- LÓGICA DE BAILE ---
var idle_timer = 0.0
const TIME_TO_DANCE = 120.0
var is_dancing = false

var power = 0.0
var max_power = 500.0
var is_max_mode = false
var is_invulnerable = false
var anim_prefix = "" 
var skin_prefix = "" # Para manejar la skin clásica

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

func _ready():
	add_to_group("player")
	aplicar_mejoras_tienda()
	# health = max_health # Quitamos esto porque aplicar_mejoras ya lo setea bien
	
	# --- INICIALIZACIÓN RASTREO POSICIÓN ---
	posicion_hace_3s = global_position
	iniciar_rastreo_posicion()
	
	# --- FIX PIES HUNDIDOS ---
	if sprite:
		sprite.centered = true 
		sprite.position.y = 0.05

func iniciar_rastreo_posicion():
	while true:
		await get_tree().create_timer(3.0).timeout
		if is_on_floor() and not attacking:
			posicion_hace_3s = global_position

func _physics_process(delta):
	if get_parent().is_in_group("nivel_con_gravedad"):
		puede_saltar_aqui = true

	skin_prefix = "classic_" if ProgresoJuego.skin_max_equipada else ""
	anim_prefix = "super " if is_max_mode else ""
	
	# --- AJUSTE DE VELOCIDAD CON GLITCH ---
	var base_speed = speed if not is_max_mode else 3.5
	var current_speed = base_speed * multiplicador_glitch
	
	if attacking or is_parrying or sprite.animation.contains("hurt") or sprite.animation == "super":
		velocity.x = move_toward(velocity.x, 0, current_speed)
		velocity.z = move_toward(velocity.z, 0, current_speed)
		reset_idle() 
	else:
		handle_movement(current_speed, delta)

	if combo_timer > 0: combo_timer -= delta
	else: combo_step = 0

	# --- INYECCIÓN DE SUFIJO EN ACCIONES ---
	if Input.is_action_just_pressed("ataque" + sufijo_control) and not attacking and not is_parrying:
		execute_attack()
	if Input.is_action_just_pressed("parry" + sufijo_control) and not is_max_mode:
		if not attacking and not is_parrying and not parry_cooldown:
			execute_parry()
	
	if puede_saltar_aqui:
		if not is_on_floor():
			velocity.y -= ProjectSettings.get_setting("physics/3d/default_gravity") * delta
		if Input.is_action_just_pressed("salto" + sufijo_control) and is_on_floor():
			velocity.y = jump_velocity
	else:
		if not is_on_floor():
			velocity.y -= 9.8 * delta
		
	move_and_slide()
	if Input.is_action_just_pressed("ui_accept"): # La tecla ENTER
		print("¡POCIÓN ACTIVADA!")
	if Input.is_action_just_pressed("ui_focus_next"): # Tecla TAB
		PocionManager.activar_multiplicador_monedas(10.0, 2)



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
	# Restaurar color respetando veneno
	sprite.modulate = Color(0.7, 1.2, 0.7) if ProgresoJuego.tiene_poison else Color(1, 1, 1)
	multiplicador_glitch = 1.0

func handle_movement(move_speed, delta):
	# Le sumamos la variable 'sufijo_control' a las acciones
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
		
		var anim_a_reproducir = skin_prefix + anim_prefix + "walk"
		if sprite.sprite_frames.has_animation(anim_a_reproducir):
			sprite.play(anim_a_reproducir)
		else:
			sprite.play("walk") 
			
		sprite.flip_h = direction.x > 0 if not is_max_mode else direction.x < 0
		hitbox.scale.x = -1 if direction.x < 0 else 1
		
		if (sprite.frame == 1 or sprite.frame == 4) and can_play_step:
			can_play_step = false
			EfectosManager.play_sound("pasos", global_position, true, -12.0)
			await get_tree().create_timer(0.45).timeout
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
					if sprite.sprite_frames.has_animation(idle_anim):
						sprite.play(idle_anim)
					else:
						sprite.play("idle")
			else:
				if sprite.sprite_frames.has_animation(idle_anim):
					sprite.play(idle_anim)
				else:
					sprite.play("idle")

func reset_idle():
	idle_timer = 0.0
	is_dancing = false

func execute_attack():
	reset_idle()
	attacking = true
	combo_step += 1
	var nombre_anim = skin_prefix + ( "super punch " + str(combo_step) if is_max_mode else "punch" + str(combo_step) )
	
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
					var shake = 0.8 if is_max_mode else 0.5
					EfectosManager.impact_effect(shake, 0.15, body.global_position, combo_step)
					
					var dano_final = 6 if is_max_mode else 5
					if ProgresoJuego.tiene_mejora_fuerza:
						dano_final *= 3
						
					body.take_damage(dano_final, global_position)
					add_power(8)
					
	if combo_step >= 3: combo_step = 0
	combo_timer = COMBO_TIME_WINDOW

func execute_parry():
	reset_idle()
	is_parrying = true
	parry_cooldown = true
	sprite.play(skin_prefix + "parry") 
	await get_tree().create_timer(parry_window).timeout
	is_parrying = false
	await get_tree().create_timer(1.5).timeout
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
	await get_tree().create_timer(1.0).timeout
	attacking = false 
	sprite.modulate = Color(2.0, 1.2, 1.2)
	await get_tree().create_timer(12.0).timeout
	is_max_mode = false
	is_invulnerable = false
	power = 0
	sprite.modulate = Color(0.7, 1.2, 0.7) if ProgresoJuego.tiene_poison else Color(1, 1, 1)


func take_damage(amount: int, _source_pos: Vector3 = Vector3.ZERO):
	reset_idle()
	if is_parrying:
		EfectosManager.parry_success_effect(global_position)
		parry_cooldown = false 
		add_power(30)
		if ProgresoJuego.tiene_mejora_parry:
			heal(3)
			_on_parry_exitoso()
		return 
		
	# --- LÓGICA DE ESCUDO ---
	if escudo_golpes_restantes > 0:
		escudo_golpes_restantes -= 1
		EfectosManager.play_sound("Brokenshield", global_position) 
		var tw_esc = create_tween()
		sprite.modulate = Color(2, 2, 5) # Brillo azul Max
		tw_esc.tween_property(sprite, "modulate", Color(0.7, 1.2, 0.7) if ProgresoJuego.tiene_poison else Color(1, 1, 1), 0.2)
		if escudo_golpes_restantes <= 0:
			ProgresoJuego.tiene_shield = false
			ProgresoJuego.guardar_partida()
		return

	if is_invulnerable: return 
	_on_recibir_danio()
	

	EfectosManager.play_sound("hurt", global_position)
	health -= amount * 0.9
	
	# --- LÓGICA POISON ---
	if ProgresoJuego.tiene_poison:
		devolver_daño_veneno()

	chequear_ectoplasma(health, max_health)
	chequear_reloj_arena(health, max_health)
	
	var hurt_anim = skin_prefix + anim_prefix + "hurt"
	if sprite.sprite_frames.has_animation(hurt_anim):
		sprite.play(hurt_anim)
	else:
		sprite.play("hurt")
		
	attacking = false 
	
	if health <= 0:
		set_physics_process(false)
		is_invulnerable = true
		ProgresoJuego.ultima_ruta_nivel = get_tree().current_scene.scene_file_path
		var t = create_tween()
		t.tween_property(sprite, "modulate:a", 0.0, 0.2)
		await t.finished
		get_tree().call_deferred("change_scene_to_file", "res://scenes/GameOver.tscn")

func heal(amount): health = clamp(health + amount, 0, max_health)

func _on_animated_sprite_3d_animation_finished():
	if "punch" in sprite.animation or "hurt" in sprite.animation or "parry" in sprite.animation or sprite.animation.ends_with("super") or "dance" in sprite.animation:
		attacking = false
		is_dancing = false
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
	
	await get_tree().create_timer(20.0).timeout
	
	if is_instance_valid(self) and is_instance_valid(sprite):
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
		max_health += 50.0
	
	health = max_health # Reset de vida completa al inicio
	
	if ProgresoJuego.tiene_mejora_vel:
		speed += 1.5
		
	# --- ITEMS COMPRABLES ---
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
			body.take_damage(8, global_position) # Max devuelve más veneno por ser tanque
			
func _on_parry_exitoso():
	racha_parries += 1
	if racha_parries >= 5 and not ProgresoJuego.logro_parry_master:
		ProgresoJuego.logro_parry_master = true
		ProgresoJuego.guardar_partida()
		print("¡Logro desbloqueado: Parry Handler!")

func _on_recibir_danio():
	racha_parries = 0
