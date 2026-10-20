extends CharacterBody3D

signal parry_realizado

# --- ATRIBUTOS ---
@export var character_name = "Nubbe"
@export var speed_normal = 3.5
@export var speed_run = 5.5 
@export var jump_velocity = 3.0
@export var max_health = 100.0
var health = 100.0
var racha_parries = 0

# --- VARIABLES DE NUEVOS ITEMS ---
var escudo_golpes_restantes = 0
var esta_invisible = false
var defensa_ectoplasma = false

# --- INYECCION QUIRURGICA: VARIABLES GLITCH ---
var posicion_hace_3s = Vector3.ZERO
var multiplicador_glitch = 1.0

# --- STAMINA Y COOLDOWN ---
@export var max_stamina = 100.0
var stamina = 100.0
var stamina_recovery_rate = 20.0 
var stamina_run_cost = 35.0      
var can_run = true 

var can_jump = true             
var is_jumping = false          

# --- ESTADOS ---
var is_max_mode = false
var is_running = false
var is_sliding = false 
var attacking = false
var is_parrying = false
var parry_cooldown = false 
var power = 0.0
var max_power = 500.0
var can_play_step = true
var esta_muerto = false 

# --- PREFIJOS DE SKINS Y MODOS ---
var anim_prefix = ""
var skin_prefix = ""

# --- COMBO ---
var combo_step = 0
var combo_timer = 0.0
const COMBO_TIME_WINDOW = 0.6

# --- LOGICA DE BAILE ---
var idle_timer = 0.0
const TIME_TO_DANCE = 120.0
var is_dancing = false

# --- SISTEMA DE AGARRE (GRAB) ---
var siendo_agarrado: bool = false
var minion_que_agarra: Node3D = null

# --- GLORY KILL VARIABLES ---
var minion_ejecutable: Node3D = null
var haciendo_glory_kill: bool = false

@onready var sprite = $AnimatedSprite3D
@onready var hitbox = $HitBox

func _ready():
	add_to_group("player")
	esta_muerto = false
	aplicar_mejoras_tienda()
	stamina = max_stamina
	posicion_hace_3s = global_position
	iniciar_rastreo_posicion()
	if not sprite.animation_finished.is_connected(_on_animated_sprite_3d_animation_finished):
		sprite.animation_finished.connect(_on_animated_sprite_3d_animation_finished)

func iniciar_rastreo_posicion():
	while true:
		await get_tree().create_timer(3.0).timeout
		if is_on_floor() and not attacking and not esta_muerto and not siendo_agarrado:
			posicion_hace_3s = global_position

func _physics_process(delta):
	if esta_muerto: return

	if haciendo_glory_kill: return

	if siendo_agarrado:
		velocity.x = 0
		velocity.z = 0
		if not is_on_floor():
			velocity.y -= ProjectSettings.get_setting("physics/3d/default_gravity") * delta
		move_and_slide()
		return

	# --- DETECCION DINAMICA DE SKINS DESDE PROGRESO ---
	if ProgresoJuego.get("skin_chibi_nubbe_equipada"):
		skin_prefix = "Chibi nubbe " # Mantiene el espacio al final para "Chibi nubbe walk"
	elif ProgresoJuego.get("skin_neko_equipada"):
		skin_prefix = "neko_"
	elif ProgresoJuego.get("skin_max_equipada"):
		skin_prefix = "classic_"
	elif ProgresoJuego.get("skin_maid_equipada"):
		skin_prefix = "maid_"
	else:
		skin_prefix = ""

	# Si está en modo max, el prefijo es "super ", sino vacío.
	anim_prefix = "super " if is_max_mode else ""

	if not is_on_floor():
		velocity.y -= ProjectSettings.get_setting("physics/3d/default_gravity") * delta
	elif is_jumping and velocity.y <= 0:
		is_jumping = false

	var input_dir = Input.get_vector("izquierda", "derecha", "arriba", "abajo")
	var is_pressing_run = Input.is_action_pressed("salto") 
	
	if is_pressing_run and input_dir != Vector2.ZERO and stamina > 0 and can_run and not is_max_mode:
		is_running = true
		stamina -= stamina_run_cost * delta
		if stamina <= 0:
			stamina = 0
			bloquear_corrida()
	else:
		is_running = false
		stamina = move_toward(stamina, max_stamina, stamina_recovery_rate * delta)

	if not is_sliding and is_on_floor() and not attacking:
		var velocidad_horizontal = Vector2(velocity.x, velocity.z).length()
		if velocidad_horizontal > speed_normal + 1.0 and input_dir == Vector2.ZERO:
			is_sliding = true
			# Combina: anim_prefix + skin_prefix + "slide" -> ej: "super Chibi nubbe slide" o "Chibi nubbe slide"
			var target_slide = anim_prefix + skin_prefix + "slide"
			if sprite.sprite_frames.has_animation(target_slide):
				sprite.play(target_slide)
			else:
				sprite.play("slide")
			EfectosManager.play_sound("viento", global_position, true, -10.0)

	if is_max_mode:
		if Input.is_action_just_pressed("salto") and is_on_floor() and can_jump:
			ejecutar_salto()

	var current_speed = (speed_run if is_running else speed_normal) * multiplicador_glitch
	if is_max_mode: current_speed *= 1.4
	
	if combo_timer > 0:
		combo_timer -= delta
	else:
		combo_step = 0

	if attacking or is_parrying or is_sliding or is_jumping or (sprite.animation and "hurt" in sprite.animation):
		if is_jumping:
			handle_movement(input_dir, current_speed, delta, true)
		else:
			var frenado = 0.94 if is_sliding else 0.8
			velocity.x = move_toward(velocity.x, 0, current_speed * (1.0 - frenado))
			velocity.z = move_toward(velocity.z, 0, current_speed * (1.0 - frenado))
	else:
		handle_movement(input_dir, current_speed, delta, false)

	if Input.is_action_just_pressed("glory_kill") and minion_ejecutable != null and not attacking and not is_parrying and not is_max_mode and not haciendo_glory_kill:
		iniciar_glory_kill()

	if Input.is_action_just_pressed("ataque") and not attacking and not is_parrying and not haciendo_glory_kill:
		execute_attack()
	
	if Input.is_action_just_pressed("parry") and not is_max_mode and not attacking and not parry_cooldown:
		execute_parry()

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

func bloquear_corrida():
	can_run = false
	is_running = false
	var tw = create_tween()
	tw.tween_property(sprite, "modulate", Color(1, 0.5, 0.5), 0.2)
	tw.tween_property(sprite, "modulate", Color(1, 1, 1), 0.2)
	await get_tree().create_timer(3.0).timeout 
	can_run = true

func ejecutar_salto():
	is_jumping = true
	can_jump = false
	velocity.y = jump_velocity
	
	var target_jump = anim_prefix + skin_prefix + "jump"
	if sprite.sprite_frames.has_animation(target_jump):
		sprite.play(target_jump)
	else:
		sprite.play("jump")
		
	await get_tree().create_timer(2.0).timeout
	can_jump = true

func handle_movement(input_dir, move_speed, delta, jumping):
	var direction = (Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction:
		reset_idle()
		velocity.x = direction.x * move_speed
		velocity.z = direction.z * move_speed
		if not jumping and not is_sliding:
			var anim = "run" if is_running else "walk"
			var target_anim = anim_prefix + skin_prefix + anim
			if sprite.animation != target_anim:
				if sprite.sprite_frames.has_animation(target_anim):
					sprite.play(target_anim)
				else:
					sprite.play(anim)
					
		sprite.flip_h = direction.x < 0
		hitbox.scale.x = -1 if sprite.flip_h else 1
		if is_on_floor() and (sprite.frame == 1 or sprite.frame == 4) and can_play_step:
			can_play_step = false
			EfectosManager.play_sound("pasos", global_position, true, -12.0)
			await get_tree().create_timer(0.35).timeout
			can_play_step = true
	else:
		velocity.x = move_toward(velocity.x, 0, move_speed)
		velocity.z = move_toward(velocity.z, 0, move_speed)
		if not is_dancing and not jumping and not is_sliding:
			idle_timer += delta
			if idle_timer >= TIME_TO_DANCE:
				is_dancing = true
				# El baile no lleva "super", pero sí el skin prefix
				var target_dance = skin_prefix + "dance1"
				if sprite.sprite_frames.has_animation(target_dance):
					sprite.play(target_dance)
				else:
					sprite.play("dance1")
			else:
				var target_idle = anim_prefix + skin_prefix + "idle"
				if sprite.animation != target_idle:
					if sprite.sprite_frames.has_animation(target_idle):
						sprite.play(target_idle)
					else:
						sprite.play("idle")

func reset_idle():
	idle_timer = 0.0
	is_dancing = false

func execute_attack():
	reset_idle()
	attacking = true
	is_sliding = false 
	combo_step = (combo_step % 3) + 1
	
	var base_punch = "punch" + str(combo_step)
	var anim_name = anim_prefix + skin_prefix + base_punch
	
	if sprite.sprite_frames.has_animation(anim_name):
		sprite.play(anim_name)
	else:
		sprite.play(base_punch)
		
	EfectosManager.play_sound("viento", global_position, true)
	combo_timer = COMBO_TIME_WINDOW
	await get_tree().create_timer(0.15).timeout
	if not attacking: return
	var impacto = false
	if hitbox and hitbox.monitoring:
		for body in hitbox.get_overlapping_bodies():
			if body.has_method("take_damage") and body != self:
				var dano_final = 6 if not is_max_mode else 5
				if ProgresoJuego.tiene_mejora_fuerza: dano_final *= 1.5
				body.take_damage(dano_final, global_position)
				impacto = true
				add_power(6)
	if impacto:
		EfectosManager.impact_effect(0.4, 0.08, global_position, combo_step)

func execute_parry():
	reset_idle()
	is_parrying = true
	is_sliding = false
	
	var target_parry = anim_prefix + skin_prefix + "parry"
	if sprite.sprite_frames.has_animation(target_parry):
		sprite.play(target_parry)
	else:
		sprite.play("parry")
		
	emit_signal("parry_realizado")
	await get_tree().create_timer(0.25).timeout
	is_parrying = false
	parry_cooldown = true
	await get_tree().create_timer(1.2).timeout
	parry_cooldown = false

func take_damage(amount: int, source_pos: Vector3 = Vector3.ZERO):
	if haciendo_glory_kill: return
	if esta_muerto or is_parrying:
		if is_parrying:
			EfectosManager.parry_success_effect(global_position)
			add_power(35)
			if ProgresoJuego.tiene_mejora_parry: heal(5)
			_on_parry_exitoso()
		return
	if siendo_agarrado and minion_que_agarra and is_instance_valid(minion_que_agarra):
		if source_pos != Vector3.ZERO and global_position.distance_to(source_pos) > 1.5:
			if minion_que_agarra.has_method("soltar_a_sketch"):
				minion_que_agarra.soltar_a_sketch(false)
	if escudo_golpes_restantes > 0:
		escudo_golpes_restantes -= 1
		EfectosManager.play_sound("Brokenshield", global_position) 
		var tw_esc = create_tween()
		sprite.modulate = Color(3, 3, 3) 
		tw_esc.tween_property(sprite, "modulate", Color(0.7, 1.2, 0.7) if ProgresoJuego.tiene_poison else Color(1, 1, 1), 0.2)
		if escudo_golpes_restantes <= 0:
			ProgresoJuego.tiene_shield = false
			ProgresoJuego.guardar_partida()
		return
	_on_recibir_danio()
	health -= amount
	reset_idle()
	if ProgresoJuego.tiene_poison:
		devolver_daño_veneno(minion_que_agarra)
	chequear_ectoplasma(health, max_health)
	chequear_reloj_arena(health, max_health)
	if health <= 0:
		morir()
	else:
		if not siendo_agarrado:
			attacking = false
			is_sliding = false
			
			var target_hurt = anim_prefix + skin_prefix + "hurt"
			if sprite.sprite_frames.has_animation(target_hurt):
				sprite.play(target_hurt)
			else:
				var fallback_hurt = skin_prefix + "hurt"
				if sprite.sprite_frames.has_animation(fallback_hurt):
					sprite.play(fallback_hurt)
				else:
					sprite.play("hurt")
					
			EfectosManager.play_sound("hurt", global_position)

func heal(amount):
	health = clamp(health + amount, 0, max_health)

func morir():
	if esta_muerto: return
	esta_muerto = true
	if siendo_agarrado and minion_que_agarra and is_instance_valid(minion_que_agarra):
		if minion_que_agarra.has_method("soltar_a_sketch"):
			minion_que_agarra.soltar_a_sketch(false)
	if get_node_or_null("/root/ProgresoJuego"):
		get_node("/root/ProgresoJuego").ultima_ruta_nivel = get_tree().current_scene.scene_file_path
	remove_from_group("player")
	EfectosManager.play_sound("hurt", global_position)
	
	var target_hurt = skin_prefix + "hurt"
	if sprite.sprite_frames.has_animation(target_hurt):
		sprite.play(target_hurt)
	else:
		sprite.play("hurt")
		
	var tw = create_tween()
	tw.tween_property(sprite, "modulate:a", 0.0, 0.5)
	await tw.finished
	get_tree().change_scene_to_file("res://scenes/GameOver.tscn")

func add_power(amount):
	if is_max_mode: return
	power = clamp(power + amount, 0, max_power)
	if power >= max_power: activate_max_mode()

func activate_max_mode():
	if siendo_agarrado: return
	is_max_mode = true
	EfectosManager.play_sound("power", global_position)
	sprite.modulate = Color(1.5, 1.5, 2.5)
	await get_tree().create_timer(12.0).timeout
	is_max_mode = false
	power = 0
	sprite.modulate = Color(0.7, 1.2, 0.7) if ProgresoJuego.tiene_poison else Color(1, 1, 1)

var ecto_activado = false
func chequear_ectoplasma(vida_actual: float, vida_maxima: float):
	if ProgresoJuego.tiene_batido_ectoplasma and not ecto_activado and vida_actual <= (vida_maxima * 0.3):
		activar_modo_fantasma()

func activar_modo_fantasma():
	ecto_activado = true
	ProgresoJuego.tiene_batido_ectoplasma = false
	defensa_ectoplasma = true
	var tw = create_tween().set_parallel(true)
	tw.tween_property(sprite, "modulate:a", 0.5, 0.5)
	var v_orig = speed_normal
	speed_normal *= 1.4
	await get_tree().create_timer(20.0).timeout
	if is_instance_valid(self):
		sprite.modulate.a = 1.0 if not esta_invisible else 0.3
		speed_normal = v_orig
		defensa_ectoplasma = false

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
	sprite.modulate = Color(0.7, 1.2, 0.7) if ProgresoJuego.tiene_poison else Color(1, 1, 1)

func aplicar_mejoras_tienda():
	if ProgresoJuego.tiene_mejora_vida: max_health += 50.0
	health = max_health
	if ProgresoJuego.tiene_mejora_vel:
		speed_normal += 1.0
		speed_run += 1.0
	if ProgresoJuego.tiene_shield: escudo_golpes_restantes = 5
	if ProgresoJuego.tiene_poison: sprite.modulate = Color(0.7, 1.2, 0.7)

func activar_invisibilidad():
	esta_invisible = true
	sprite.modulate.a = 0.3
	add_to_group("invisible")

func devolver_daño_veneno(atacante_directo: Node3D = null):
	if hitbox and hitbox.monitoring:
		for body in hitbox.get_overlapping_bodies():
			if body.has_method("take_damage") and body != self:
				body.take_damage(5, global_position)
	elif atacante_directo and is_instance_valid(atacante_directo):
		if "health" in atacante_directo:
			atacante_directo.health -= 5
			if atacante_directo.health <= 0 and atacante_directo.has_method("morir"):
				atacante_directo.morir()
		elif "vida" in atacante_directo:
			atacante_directo.vida -= 5
			if atacante_directo.vida <= 0 and atacante_directo.has_method("morir"):
				atacante_directo.morir()
		elif atacante_directo.has_method("take_damage"):
			atacante_directo.take_damage(5, atacante_directo.global_position)

func _on_animated_sprite_3d_animation_finished():
	if siendo_agarrado: return
	if sprite.animation and ("Nubbe Glory kill" in sprite.animation):
		_finalizar_glory_kill_logica()
		return
	var anim = sprite.animation
	if "hurt" in anim or "punch" in anim or "parry" in anim or "dance" in anim or "slide" in anim:
		attacking = false
		is_dancing = false
		is_sliding = false
		if not esta_muerto:
			var target_idle = anim_prefix + skin_prefix + "idle"
			if sprite.sprite_frames.has_animation(target_idle):
				sprite.play(target_idle)
			else:
				sprite.play("idle")

func _on_parry_exitoso():
	racha_parries += 1
	if racha_parries >= 5 and not ProgresoJuego.logro_parry_master:
		ProgresoJuego.logro_parry_master = true
		ProgresoJuego.guardar_partida()
		print("Logro desbloqueado: Parry Handler!")

func _on_recibir_danio():
	racha_parries = 0

func ser_agarrado(minion: Node3D):
	if is_max_mode or siendo_agarrado or esta_muerto or haciendo_glory_kill: return
	siendo_agarrado = true
	minion_que_agarra = minion
	is_dancing = false
	attacking = false
	is_parrying = false
	is_sliding = false
	velocity = Vector3.ZERO
	if is_instance_valid(hitbox):
		hitbox.set_deferred("monitoring", false)
		hitbox.set_deferred("monitorable", false)
		
	var target_grabbed = "grabbed Nubbe"
	if sprite.sprite_frames.has_animation(skin_prefix + target_grabbed):
		sprite.play(skin_prefix + target_grabbed)
	elif sprite.sprite_frames.has_animation(target_grabbed):
		sprite.play(target_grabbed)
	else:
		sprite.play(skin_prefix + "hurt" if sprite.sprite_frames.has_animation(skin_prefix + "hurt") else "hurt")

func liberado_de_agarre():
	if not siendo_agarrado: return
	siendo_agarrado = false
	minion_que_agarra = null
	if is_instance_valid(hitbox):
		hitbox.set_deferred("monitoring", true)
		hitbox.set_deferred("monitorable", true)
	reset_idle()
	if not esta_muerto:
		var target_idle = anim_prefix + skin_prefix + "idle"
		if sprite.sprite_frames.has_animation(target_idle):
			sprite.play(target_idle)
		else:
			sprite.play("idle")

func iniciar_glory_kill():
	if minion_ejecutable == null or is_instance_valid(minion_ejecutable) == false: return

	haciendo_glory_kill = true
	is_dancing = false
	attacking = false
	velocity = Vector3.ZERO

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

	var numero_random = randi_range(1, 2)
	var id_kill = str(numero_random)

	# Modificado para que si es Chibi mantenga su estructura limpia de strings
	var nombre_anim = skin_prefix + "Nubbe Glory kill " + id_kill
	var nombre_anim_minion = "minion kill " + str(numero_random + 8)
	
	var nombre_audio: String
	if skin_prefix == "Chibi nubbe ":
		nombre_audio = "Glory kill " + id_kill + " Chibi Nubbe audio"
	elif skin_prefix == "neko_":
		nombre_audio = "Glory kill " + id_kill + " Neko Nubbe audio"
	elif skin_prefix == "maid_":
		nombre_audio = "Glory kill " + id_kill + " Maid Nubbe audio"
	else:
		nombre_audio = "Glory kill " + id_kill + " Nubbe audio"

	EfectosManager.play_sound(nombre_audio, global_position)

	if minion_ejecutable.has_method("ser_ejecutado_dinamico"):
		minion_ejecutable.ser_ejecutado_dinamico(nombre_anim_minion)
	elif minion_ejecutable.has_method("ser_ejecutado"):
		minion_ejecutable.ser_ejecutado()

	sprite.stop()

	print("[GK Nubbe] Intentando reproducir: ", nombre_anim)
	if sprite.sprite_frames.has_animation(nombre_anim):
		sprite.play(nombre_anim)
	else:
		var base_gk = "Nubbe Glory kill " + id_kill
		if sprite.sprite_frames.has_animation(base_gk):
			sprite.play(base_gk)
		else:
			print("[GK ERROR Nubbe] No tiene la animacion: '", nombre_anim, "'!")
			await get_tree().create_timer(0.5).timeout
			_finalizar_glory_kill_logica()

func _finalizar_glory_kill_logica():
	haciendo_glory_kill = false
	attacking = false
	minion_ejecutable = null
	heal(20.0)
	add_power(20)
	
	var target_idle = anim_prefix + skin_prefix + "idle"
	if sprite.sprite_frames.has_animation(target_idle):
		sprite.play(target_idle)
	else:
		sprite.play("idle")
