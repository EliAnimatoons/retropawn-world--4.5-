extends CharacterBody3D

# --- CONTROLES MÚLTIPLES (P2 JOYSTICK) ---
@export var sufijo_input: String = "_p2" # Asegúrate de tener "ataque_p2", "salto_p2", "curar_p2", etc. en tu Mapa de Inputs

@export var jump_velocity = 4.5
var puede_saltar_aqui = false
@export var speed = 2.4 
var defensa_ectoplasma = false
@export var max_health = 70.0 
var health = 70.0
@export var character_name = "Doodle"
var racha_parries = 0

var escudo_golpes_restantes = 0
var posicion_hace_3s = Vector3.ZERO
var multiplicador_glitch = 1.0

const BALA_ESCENA = preload("res://scenes/BalaJane.tscn")

var power = 0.0
var max_power = 500.0
var is_max_mode = false
var is_invulnerable = false
var anim_prefix = "" 
var skin_prefix = "" 

@onready var hitbox = $HitBox
@onready var sprite = $AnimatedSprite3D

var idle_time = 0.0
const TIME_TO_DANCE = 5.0
var is_dancing = false
var heal_timer = 0.0

var combo_step = 0
var attacking = false
var combo_timer = 0.0
const COMBO_TIME_WINDOW = 0.6
var is_parrying = false
var parry_cooldown = false 
var parry_window = 0.25
var can_play_step = true

# --- NUEVO SISTEMA DE CURACIÓN (SOPORTE COOP) ---
var esta_curando: bool = false
var cooldown_curacion: bool = false
const TIEMPO_MAX_CURA: float = 4.0
const TIEMPO_COOLDOWN_CURA: float = 12.0
var tiempo_actual_cura: float = 0.0

# --- GLORY KILL VARIABLES ---
var minion_ejecutable: Node3D = null
var haciendo_glory_kill: bool = false

# --- SISTEMA DE AGARRE (GRAB) ---
var siendo_agarrado: bool = false
var minion_que_agarra: Node3D = null

func _ready():
	add_to_group("player")
	aplicar_mejoras_tienda()
	posicion_hace_3s = global_position
	iniciar_rastreo_posicion()

func iniciar_rastreo_posicion():
	while true:
		await get_tree().create_timer(3.0).timeout
		if is_on_floor() and not attacking and not siendo_agarrado and not esta_curando:
			posicion_hace_3s = global_position

func _physics_process(delta):
	# --- CONTROL DE AGARRE ULTRA PRIORITARIO ---
	if siendo_agarrado:
		velocity.x = 0
		velocity.z = 0
		if not is_on_floor():
			velocity.y -= 9.8 * delta
		
		if Input.is_action_just_pressed("parry" + sufijo_input) or Input.is_joy_button_pressed(1, JOY_BUTTON_MISC1):
			print("[Doodle] Intentando zafarse del agarre con botón parry / joypad 10")
			if is_instance_valid(minion_que_agarra) and minion_que_agarra.has_method("soltar_por_liberacion_jugador"):
				minion_que_agarra.soltar_por_liberacion_jugador()
			else:
				liberado_de_agarre()
		
		move_and_slide()
		return

	if haciendo_glory_kill: return

	if get_parent().is_in_group("nivel_con_gravedad"):
		puede_saltar_aqui = true

	skin_prefix = "lion_" if ProgresoJuego.skin_lionel_equipada else ""
	anim_prefix = "super " if is_max_mode else ""
	
	var base_speed = speed if not is_max_mode else 4.5
	var current_speed = base_speed * multiplicador_glitch
	
	var input_dir = Input.get_vector("izquierda" + sufijo_input, "derecha" + sufijo_input, "arriba" + sufijo_input, "abajo" + sufijo_input)
	
	# --- LÓGICA ACTIVA DE CURACIÓN ---
	if esta_curando:
		velocity.x = move_toward(velocity.x, 0, current_speed)
		velocity.z = move_toward(velocity.z, 0, current_speed)
		procesar_curacion_coop(delta)
		if not is_on_floor() and puede_saltar_aqui:
			velocity.y -= ProjectSettings.get_setting("physics/3d/default_gravity") * delta
		move_and_slide()
		return

	if input_dir == Vector2.ZERO and not attacking and not is_parrying and not is_max_mode:
		idle_time += delta
		if idle_time >= TIME_TO_DANCE:
			if not is_dancing:
				is_dancing = true
				var anim_baile = skin_prefix + "dance"
				if sprite.sprite_frames.has_animation(anim_baile):
					sprite.play(anim_baile)
				else:
					sprite.play("dance")
			
			heal_timer += delta
			if heal_timer >= 5.0:
				health = clamp(health + 1.0, 0, max_health)
				heal_timer = 0.0
	else:
		idle_time = 0.0
		heal_timer = 0.0
		if is_dancing:
			is_dancing = false

	if attacking or is_parrying or sprite.animation.contains("hurt") or sprite.animation == "super":
		velocity.x = move_toward(velocity.x, 0, current_speed)
		velocity.z = move_toward(velocity.z, 0, current_speed)
	else:
		handle_movement(current_speed, input_dir)

	if combo_timer > 0: combo_timer -= delta
	else: combo_step = 0

	if Input.is_action_just_pressed("curar" + sufijo_input) and not cooldown_curacion and not attacking and not is_parrying and is_on_floor():
		iniciar_curacion_coop()

	if Input.is_action_just_pressed("glory_kill" + sufijo_input) and minion_ejecutable != null and not attacking and not is_parrying and not is_max_mode and not haciendo_glory_kill:
		iniciar_glory_kill()

	if Input.is_action_just_pressed("ataque" + sufijo_input):
		if not attacking and not is_parrying and not haciendo_glory_kill:
			execute_attack()

	if Input.is_action_just_pressed("parry" + sufijo_input) and not is_max_mode:
		if not attacking and not is_parrying and not parry_cooldown:
			execute_parry()
			
	if puede_saltar_aqui:
		if not is_on_floor():
			velocity.y -= ProjectSettings.get_setting("physics/3d/default_gravity") * delta
		if Input.is_action_just_pressed("salto" + sufijo_input) and is_on_floor():
			velocity.y = jump_velocity
			is_dancing = false
	else:
		if not is_on_floor():
			velocity.y -= 9.8 * delta
		
	move_and_slide()

# --- MECÁNICA EXCLUSIVA: LANZAR ENERGÍA CURATIVA ---
func iniciar_curacion_coop():
	esta_curando = true
	is_dancing = false
	tiempo_actual_cura = 0.0
	
	if sprite.sprite_frames.has_animation("Health player"):
		sprite.play("Health player")
	else:
		sprite.play("idle")
		
	EfectosManager.play_sound("curacion_coop", global_position)

func procesar_curacion_coop(delta: float):
	tiempo_actual_cura += delta
	
	# CORRECCIÓN: Autocuración para Doodle mientras canaliza
	health = clamp(health + (8.0 * delta), 0.0, max_health)
	
	if hitbox and hitbox.monitoring:
		var cuerpos = hitbox.get_overlapping_bodies()
		for cuerpo in cuerpos:
			# Cura al compañero (Sketch / Player 1) si está en el rango
			if cuerpo != self and cuerpo.is_in_group("player") and cuerpo.has_method("take_damage"):
				if "health" in cuerpo and "max_health" in cuerpo:
					cuerpo.health = clamp(cuerpo.health + (8.0 * delta), 0.0, cuerpo.max_health)

	if tiempo_actual_cura >= TIEMPO_MAX_CURA:
		finalizar_curacion_coop()

func finalizar_curacion_coop():
	esta_curando = false
	cooldown_curacion = true
	sprite.play(skin_prefix + anim_prefix + "idle")
	
	await get_tree().create_timer(TIEMPO_COOLDOWN_CURA).timeout
	cooldown_curacion = false
	print("[Doodle] ¡Curación lista otra vez!")

func execute_attack():
	is_dancing = false
	attacking = true
	
	combo_step += 1
	
	# NUEVO/MODIFICADO: Si está en Súper, prioriza las animaciones de "super shoot X"
	if is_max_mode:
		var anim_disparo = skin_prefix + "super shoot " + str(combo_step)
		if sprite.sprite_frames.has_animation(anim_disparo):
			sprite.play(anim_disparo)
		else:
			sprite.play("super shoot 1") # Animación por defecto si falla el string
	else:
		# Combo normal de golpes físicos
		if sprite.sprite_frames.has_animation(skin_prefix + anim_prefix + "punch" + str(combo_step)):
			sprite.play(skin_prefix + anim_prefix + "punch" + str(combo_step))
		else:
			sprite.play("punch1")
		
	EfectosManager.play_sound("viento", global_position, true)
	
	if is_max_mode:
		var bala = BALA_ESCENA.instantiate()
		get_tree().current_scene.add_child(bala)
		bala.global_position = global_position + Vector3(0, 0.08, 0)
		
		if bala.has_method("set_source"):
			bala.set_source(global_position)
		elif "source_pos" in bala:
			bala.source_pos = global_position
		
		var dir_x = -1.0 if sprite.flip_h else 1.0
		bala.direccion = Vector3(dir_x, 0, 0)
		
		if dir_x < 0:
			bala.rotation.y = PI
		else:
			bala.rotation.y = 0.0
		
		if "max_distancia" in bala:
			bala.max_distancia = 3.0

		bala.scale = Vector3(1.8, 1.8, 1.8) 
		if "dano" in bala:
			var dano_max = 5.0
			if ProgresoJuego.tiene_mejora_fuerza: dano_max *= 2
			bala.dano = dano_max
	else:
		# --- CORRECCIÓN DE SONIDO DINÁMICO EN GOLPE BASE ---
		if is_instance_valid(hitbox):
			var cuerpos_en_rango = hitbox.get_overlapping_bodies()
			var golpeo_alguien = false
			
			for cuerpo in cuerpos_en_rango:
				if cuerpo != self and (cuerpo.is_in_group("enemies") or "minion" in cuerpo.name.to_lower()):
					if cuerpo.has_method("take_damage"):
						var dano_punos = 15.0
						if ProgresoJuego.tiene_mejora_fuerza: dano_punos *= 2
						
						cuerpo.take_damage(dano_punos, global_position)
						golpeo_alguien = true
						print("[Doodle HITBOX] ¡Impacto físico confirmado en: ", cuerpo.name, "!")
			
			if golpeo_alguien:
				var sonido_punch = "punch" + str(combo_step)
				if not EfectosManager.sonidos.has(sonido_punch):
					sonido_punch = "punch1"
				
				EfectosManager.play_sound(sonido_punch, global_position, true)

	add_power(4) 
	if combo_step >= 3: combo_step = 0
	combo_timer = COMBO_TIME_WINDOW

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
	esta_curando = false
	
	await get_tree().create_timer(1.5).timeout
	sprite.modulate = Color(0.7, 1.2, 0.7) if ProgresoJuego.tiene_poison else Color(1, 1, 1)
	multiplicador_glitch = 1.0

func handle_movement(move_speed, input_dir: Vector2):
	var direction = (Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	if direction:
		velocity.x = direction.x * move_speed
		velocity.z = direction.z * move_speed
		sprite.play(skin_prefix + anim_prefix + "walk") 
		sprite.flip_h = direction.x < 0 
		
		if hitbox:
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
			sprite.play(skin_prefix + anim_prefix + "idle")

func execute_parry():
	is_dancing = false
	is_parrying = true
	parry_cooldown = true
	var anim_parry = skin_prefix + "parry"
	if sprite.sprite_frames.has_animation(anim_parry):
		sprite.play(anim_parry)
	else:
		sprite.play("parry")
	
	await get_tree().create_timer(parry_window).timeout
	is_parrying = false
	await get_tree().create_timer(1.2).timeout
	parry_cooldown = false

func add_power(amount):
	if is_max_mode: return
	power = clamp(power + amount, 0, max_power)
	if power >= max_power: activate_max_mode()

func activate_max_mode():
	if siendo_agarrado: return 
	is_max_mode = true
	is_invulnerable = true
	attacking = true 
	esta_curando = false
	
	var anim_super = skin_prefix + "super"
	if sprite.sprite_frames.has_animation(anim_super):
		sprite.play(anim_super)
	else:
		sprite.play("super")
		
	# MODIFICADO: Reproduce el tema o efecto del súper de Doodle
	EfectosManager.play_sound("super_doodle_activa", global_position) 
	
	await get_tree().create_timer(1.0).timeout
	attacking = false 
	sprite.modulate = Color(2.5, 1.2, 2.5)
	await get_tree().create_timer(20.0).timeout
	is_max_mode = false
	is_invulnerable = false
	power = 0
	sprite.modulate = Color(0.7, 1.2, 0.7) if ProgresoJuego.tiene_poison else Color(1, 1, 1)

func take_damage(amount: int, source_pos: Vector3 = Vector3.ZERO):
	is_dancing = false
	if haciendo_glory_kill: return
	if esta_curando: finalizar_curacion_coop()
	
	if siendo_agarrado and minion_que_agarra and is_instance_valid(minion_que_agarra):
		if source_pos != Vector3.ZERO and global_position.distance_to(source_pos) > 1.5:
			if minion_que_agarra.has_method("soltar_a_sketch"):
				minion_que_agarra.soltar_a_sketch(false)
	
	if is_parrying:
		EfectosManager.parry_success_effect(global_position)
		parry_cooldown = false 
		add_power(30)
		if ProgresoJuego.tiene_mejora_parry:
			health = clamp(health + 8.0, 0, max_health)
			_on_parry_exitoso()
		return 
		
	if escudo_golpes_restantes > 0:
		escudo_golpes_restantes -= 1
		EfectosManager.play_sound("Brokenshield", global_position) 
		var tw_esc = create_tween()
		sprite.modulate = Color(3, 1, 3)
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
		devolver_daño_veneno(minion_que_agarra)

	chequear_ectoplasma(health, max_health)
	chequear_reloj_arena(health, max_health)
	
	if not siendo_agarrado:
		var hurt_anim = skin_prefix + anim_prefix + "hurt"
		sprite.play(hurt_anim if sprite.sprite_frames.has_animation(hurt_anim) else "hurt")
		attacking = false 
	
	if health <= 0:
		morir()

func morir():
	if siendo_agarrado and minion_que_agarra and is_instance_valid(minion_que_agarra):
		if minion_que_agarra.has_method("soltar_a_sketch"):
			minion_que_agarra.soltar_a_sketch(false)
	set_physics_process(false)
	is_invulnerable = true
	ProgresoJuego.ultima_ruta_nivel = get_tree().current_scene.scene_file_path
	var t = create_tween()
	t.tween_property(sprite, "modulate:a", 0.0, 0.2)
	await t.finished
	get_tree().call_deferred("change_scene_to_file", "res://scenes/GameOver.tscn")

func _on_animated_sprite_3d_animation_finished():
	if siendo_agarrado: return 

	if sprite.animation and ("Jane Glory kill" in sprite.animation):
		_finalizar_glory_kill_logica()
		return

	# AGREGADO: "shoot" para que limpie el estado al terminar de disparar
	if "punch" in sprite.animation or "hurt" in sprite.animation or "parry" in sprite.animation or "super" in sprite.animation or "dance" in sprite.animation or "shoot" in sprite.animation:
		attacking = false
		is_parrying = false
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
	if is_instance_valid(self) and is_instance_valid(sprite):
		var tw2 = create_tween().set_parallel(true)
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
	health = max_health
	if ProgresoJuego.tiene_mejora_vel:
		speed += 1.2
	if ProgresoJuego.tiene_shield:
		escudo_golpes_restantes = 5
	if ProgresoJuego.tiene_poison:
		sprite.modulate = Color(0.7, 1.2, 0.7)

func devolver_daño_veneno(atacante_directo: Node3D = null):
	if hitbox and hitbox.monitoring:
		var targets = hitbox.get_overlapping_bodies()
		for body in targets:
			if body != self and body.has_method("take_damage"):
				body.take_damage(3, global_position)
				
	elif atacante_directo and is_instance_valid(atacante_directo):
		if "health" in atacante_directo:
			atacante_directo.health -= 3
			if atacante_directo.health <= 0 and atacante_directo.has_method("morir"):
				atacante_directo.morir()
		elif "vida" in atacante_directo:
			atacante_directo.vida -= 3
			if atacante_directo.vida <= 0 and atacante_directo.has_method("morir"):
				atacante_directo.morir()
		elif atacante_directo.has_method("take_damage"):
			atacante_directo.take_damage(3, atacante_directo.global_position)
			
func _on_parry_exitoso():
	racha_parries += 1
	if racha_parries >= 5 and not ProgresoJuego.logro_parry_master:
		ProgresoJuego.logro_parry_master = true
		ProgresoJuego.guardar_partida()
		print("¡Logro desbloqueado: Parry Master!")

func _on_recibir_danio():
	racha_parries = 0

# --- GLORY KILL ---
func iniciar_glory_kill():
	if minion_ejecutable == null or is_instance_valid(minion_ejecutable) == false: return

	haciendo_glory_kill = true
	is_invulnerable = true
	is_dancing = false
	esta_curando = false
	velocity = Vector3.ZERO

	var minion_sprite = minion_ejecutable.get_node("AnimatedSprite3D")
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
		if hitbox:
			hitbox.scale.x = -1 if sprite.flip_h else 1

	var numero_random = randi_range(1, 2)
	var id_kill = str(numero_random)

	var nombre_anim = skin_prefix + "Jane Glory kill " + id_kill
	var base_offset = 6 if skin_prefix == "lion_" else 2
	var nombre_anim_minion = "minion kill " + str(numero_random + base_offset)

	var nombre_audio_gk: String
	if skin_prefix == "lion_":
		nombre_audio_gk = "Glory kill " + id_kill + " Lionel audio"
	else:
		nombre_audio_gk = "Glory kill " + id_kill + " Jane audio"

	EfectosManager.play_sound(nombre_audio_gk, global_position)

	if minion_ejecutable.has_method("ser_ejecutado_dinamico"):
		minion_ejecutable.ser_ejecutado_dinamico(nombre_anim_minion)
	elif minion_ejecutable.has_method("ser_ejecutado"):
		minion_ejecutable.ser_ejecutado(id_kill)

	if sprite.sprite_frames.has_animation(nombre_anim):
		sprite.play(nombre_anim)
	else:
		var minuscula = nombre_anim.to_lower()
		if sprite.sprite_frames.has_animation(minuscula):
			sprite.play(minuscula)
		else:
			await get_tree().create_timer(0.5).timeout
			_finalizar_glory_kill_logica()

func _finalizar_glory_kill_logica():
	haciendo_glory_kill = false
	is_invulnerable = false
	attacking = false
	minion_ejecutable = null
	health = clamp(health + 20.0, 0, max_health)
	add_power(20)
	combo_step = 0
	sprite.play(skin_prefix + anim_prefix + "idle")

func ser_agarrado(minion: Node3D):
	if haciendo_glory_kill or is_max_mode or siendo_agarrado: return
	
	siendo_agarrado = true
	minion_que_agarra = minion
	is_dancing = false
	attacking = false
	is_parrying = false
	esta_curando = false
	velocity = Vector3.ZERO
	
	if is_instance_valid(hitbox):
		hitbox.set_deferred("monitoring", false)
		hitbox.set_deferred("monitorable", false)
	
	var anim_agarre = skin_prefix + "grabbed Jane"
	if sprite.sprite_frames.has_animation(anim_agarre):
		sprite.play(anim_agarre)
	else:
		sprite.play("grabbed Jane")

func liberado_de_agarre():
	if not siendo_agarrado: return
	siendo_agarrado = false
	minion_que_agarra = null
	
	if is_instance_valid(hitbox):
		hitbox.set_deferred("monitoring", true)
		hitbox.set_deferred("monitorable", true)
		
	reset_idle()

func reset_idle():
	sprite.play(skin_prefix + anim_prefix + "idle")

func _on_hit_box_body_entered(body: Node3D) -> void:
	pass

func _on_hit_box_box_exited(body: Node3D) -> void:
	pass
