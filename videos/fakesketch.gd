extends CharacterBody3D

# --- SEÑALES Y EXPORTS ---
signal parry_realizado 

@export var jump_velocity = 4.5
@export var speed = 3.0
@export var max_health = 100
@export var character_name = "Plastic Sketch"
var racha_parries = 0

# --- NODOS 3D ---
@onready var anim_player = $retrosketchworld/AnimationPlayer 
@onready var modelo_visual = $retrosketchworld 
@onready var hitbox = $HitBox

# --- VARIABLES DE ESTADO ---
var health = 100
var puede_saltar_aqui = false
var defensa_ectoplasma = false
var escudo_golpes_restantes = 0
var esta_invisible = false
var posicion_hace_3s = Vector3.ZERO
var multiplicador_glitch = 1.0

# --- IDLE / BAILE ---
var idle_timer = 0.0
const TIME_TO_DANCE = 120.0
var is_dancing = false

# --- COMBO ---
var combo_secuencia = ["punch", "punch2", "punch3"]
var combo_step = 0
var combo_timer = 0.0
const COMBO_WINDOW = 0.6

# --- SÚPER ---
var power = 0.0
var max_power = 500.0
var is_max_mode = false
var is_invulnerable = false
var attacking = false
var is_parrying = false
var parry_cooldown = false 
var parry_window = 0.25
var can_play_step = true
var tutorial_bloqueo = false 

# --- DASH ---
var is_sliding = false
var dash_cooldown = false
@export var super_flight_speed = 6.0
@export var slide_speed = 22.0
@export var super_punch_speed = 14.0 # Embestida más larga y notoria

# --- GHOST TRAIL ---
var generando_trail = false

# ─────────────────────────────────────────────
# GHOST TRAIL GENÉRICO
# ─────────────────────────────────────────────
func iniciar_ghost_trail(duracion: float, color_base: Color, color_emision: Color):
	generando_trail = true
	var tiempo = 0.0
	while tiempo < duracion and generando_trail:
		await get_tree().process_frame
		_spawnear_ghost(color_base, color_emision)
		await get_tree().create_timer(0.045).timeout
		tiempo += 0.045
	generando_trail = false

func _spawnear_ghost(color_base: Color, color_emision: Color):
	var ghost = modelo_visual.duplicate()
	var ap_ghost = ghost.get_node_or_null("AnimationPlayer")
	if ap_ghost:
		ap_ghost.queue_free()
	get_parent().add_child(ghost)
	ghost.global_transform = modelo_visual.global_transform
	_aplicar_material_ghost(ghost, color_base, color_emision)
	var tw = create_tween()
	tw.tween_method(func(a): _set_ghost_alpha(ghost, a), color_base.a, 0.0, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tw.finished
	if is_instance_valid(ghost):
		ghost.queue_free()

func _aplicar_material_ghost(nodo: Node, color_base: Color, color_emision: Color):
	if nodo is MeshInstance3D:
		var mat = StandardMaterial3D.new()
		mat.albedo_color = color_base
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.emission_enabled = true
		mat.emission = color_emision
		mat.emission_energy_multiplier = 1.4
		nodo.material_override = mat
	for hijo in nodo.get_children():
		_aplicar_material_ghost(hijo, color_base, color_emision)

func _set_ghost_alpha(ghost: Node, alpha: float):
	if not is_instance_valid(ghost): return
	_set_alpha_recursivo(ghost, alpha)

func _set_alpha_recursivo(nodo: Node, alpha: float):
	if nodo is MeshInstance3D:
		var mat = nodo.material_override
		if mat and mat is StandardMaterial3D:
			mat.albedo_color.a = alpha
	for hijo in nodo.get_children():
		_set_alpha_recursivo(hijo, alpha)

# ─────────────────────────────────────────────
# MODULATE SEGURO
# ─────────────────────────────────────────────
func set_model_color(color: Color):
	_color_recursivo(modelo_visual, color)

func _color_recursivo(nodo: Node, color: Color):
	if "modulate" in nodo and nodo != modelo_visual:
		nodo.modulate = color
	for hijo in nodo.get_children():
		_color_recursivo(hijo, color)

func _set_alpha_modelo(alpha: float):
	_alpha_recursivo(modelo_visual, alpha)

func _alpha_recursivo(nodo: Node, alpha: float):
	if "modulate" in nodo and nodo != modelo_visual:
		nodo.modulate.a = alpha
	for hijo in nodo.get_children():
		_alpha_recursivo(hijo, alpha)

# ─────────────────────────────────────────────

func _ready():
	add_to_group("player")
	health = max_health
	aplicar_mejoras_tienda()
	posicion_hace_3s = global_position
	iniciar_rastreo_posicion()
	if anim_player and not anim_player.animation_finished.is_connected(_on_animation_player_animation_finished):
		anim_player.animation_finished.connect(_on_animation_player_animation_finished)

func iniciar_rastreo_posicion():
	while true:
		await get_tree().create_timer(3.0).timeout
		if is_on_floor() and not attacking:
			posicion_hace_3s = global_position

func _physics_process(delta):
	if tutorial_bloqueo: return 

	if combo_step > 0:
		combo_timer -= delta
		if combo_timer <= 0:
			combo_step = 0

	if is_max_mode:
		velocity.y = 0.0
	else:
		if not is_on_floor():
			velocity.y -= 25.0 * delta 
		elif is_on_floor():
			velocity.y = -0.5

	if (attacking and is_max_mode) or is_sliding:
		move_and_slide()
		return

	var base_speed = speed if not is_max_mode else super_flight_speed
	var current_speed = base_speed * multiplicador_glitch
	
	var anim_actual = anim_player.current_animation
	if attacking or is_parrying or anim_actual.contains("hurt") or anim_actual == "activesuper" or anim_actual == "charge":
		velocity.x = move_toward(velocity.x, 0, current_speed)
		velocity.z = move_toward(velocity.z, 0, current_speed)
		reset_idle() 
	else:
		handle_movement(current_speed, delta)

	# Se bloquea cualquier ataque extra mientras 'attacking' sea verdader
	if Input.is_action_just_pressed("ataque") and not attacking and not is_parrying and not is_sliding:
		execute_attack()
	if Input.is_action_just_pressed("parry") and not is_max_mode:
		if not attacking and not is_parrying and not parry_cooldown:
			execute_parry()
	if is_max_mode and Input.is_action_just_pressed("salto") and not is_sliding and not attacking and not dash_cooldown:
		ejecutar_slide_dash()
	if Input.is_action_just_pressed("salto") and not is_max_mode:
		if puede_saltar_aqui and is_on_floor():
			velocity.y = jump_velocity

	move_and_slide()

func handle_movement(move_speed, delta):
	var input_dir = Input.get_vector("izquierda", "derecha", "arriba", "abajo")
	var direction = Vector3(input_dir.x, 0, input_dir.y).normalized()
	
	if direction:
		reset_idle()
		velocity.x = direction.x * move_speed
		velocity.z = direction.z * move_speed
		if is_max_mode:
			play_anim("super walk")
		else:
			if is_on_floor(): play_anim("walk")
			if can_play_step: reproducir_pasos()
		rotation.y = atan2(direction.x, direction.z)
	else:
		velocity.x = move_toward(velocity.x, 0, move_speed)
		velocity.z = move_toward(velocity.z, 0, move_speed)
		if not is_dancing:
			idle_timer += delta
			if idle_timer >= TIME_TO_DANCE and not is_max_mode:
				is_dancing = true
				play_anim("dance")
			else:
				play_anim("idle super" if is_max_mode else "idle")

# ─────────────────────────────────────────────
# DASH — con ghost trail amarillo
# ─────────────────────────────────────────────
func ejecutar_slide_dash():
	is_sliding = true
	is_invulnerable = true 
	dash_cooldown = true
	play_anim("slidesuper")
	EfectosManager.play_sound("viento", global_position, true, -1.0)
	
	var input_dir = Input.get_vector("izquierda", "derecha", "arriba", "abajo")
	var direction = Vector3(input_dir.x, 0, input_dir.y).normalized()
	if direction == Vector3.ZERO:
		direction = transform.basis.z.normalized()
	else:
		rotation.y = atan2(direction.x, direction.z)

	velocity.x = direction.x * slide_speed
	velocity.z = direction.z * slide_speed

	iniciar_ghost_trail(0.35, Color(1.0, 0.85, 0.1, 0.6), Color(1.0, 0.7, 0.0))

	var tw = create_tween()
	tw.tween_property(self, "velocity:x", 0.0, 0.28).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(self, "velocity:z", 0.0, 0.28).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	
	await get_tree().create_timer(0.45).timeout
	is_sliding = false
	is_invulnerable = false
	generando_trail = false
	await get_tree().create_timer(1.5).timeout
	dash_cooldown = false

# ─────────────────────────────────────────────
# EMBESTIDA SÚPER — más larga, con ghost trail azul
# ─────────────────────────────────────────────
func execute_attack():
	if attacking: return # Malla de seguridad para no interrumpir el ataque
	reset_idle()
	attacking = true
	
	if is_max_mode:
		is_invulnerable = true
		play_anim("superpunch")
		EfectosManager.play_sound("viento", global_position, true)

		await get_tree().process_frame
		await get_tree().process_frame

		iniciar_ghost_trail(0.5, Color(0.15, 0.45, 1.0, 0.6), Color(0.1, 0.35, 1.0))

		var avance_dir = transform.basis.z.normalized()
		velocity.x = avance_dir.x * super_punch_speed
		velocity.z = avance_dir.z * super_punch_speed
		velocity.y = 0.0

		var tw_freno = create_tween()
		tw_freno.tween_property(self, "velocity:x", 0.0, 0.45).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
		tw_freno.parallel().tween_property(self, "velocity:z", 0.0, 0.45).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)

		await get_tree().physics_frame
		await get_tree().physics_frame
		var targets = hitbox.get_overlapping_bodies()
		for body in targets:
			if body != self and body.has_method("take_damage"):
				EfectosManager.impact_effect(0.5, 0.15, body.global_position, 2)
				body.take_damage(100, global_position)

		await tw_freno.finished
		velocity = Vector3.ZERO
		is_invulnerable = false
		generando_trail = false
		play_anim("charge")

	else:
		# COMBO: "punch" → "punch2" → "punch3"
		var anim_golpe = combo_secuencia[combo_step]
		combo_step = (combo_step + 1) % 3
		combo_timer = COMBO_WINDOW

		play_anim(anim_golpe)
		EfectosManager.play_sound("viento", global_position, true)

		await get_tree().physics_frame

		var targets = hitbox.get_overlapping_bodies()
		for body in targets:
			if body != self and body.has_method("take_damage"):
				var danio = 6 if anim_golpe == "punch3" else 5
				EfectosManager.impact_effect(0.35, 0.12, body.global_position, combo_step)
				body.take_damage(danio, global_position)
				add_power(6)

		# Esperar la animación o un timer antes de permitir otro ataque para no cancelar la animación
		await get_tree().create_timer(0.35).timeout
		attacking = false

func execute_parry():
	reset_idle()
	is_parrying = true
	parry_cooldown = true
	play_anim("parry")
	emit_signal("parry_realizado") 
	await get_tree().create_timer(parry_window).timeout
	is_parrying = false
	await get_tree().create_timer(1.2).timeout
	parry_cooldown = false

func take_damage(amount: int, _source_pos: Vector3 = Vector3.ZERO): 
	# AHORA TAMBIÉN EVALÚA is_max_mode PARA NO RECIBIR DAÑO EN SÚPER
	if is_invulnerable or is_max_mode: return 
	_on_recibir_danio()
	reset_idle()
	
	if is_parrying:
		EfectosManager.parry_success_effect(global_position)
		parry_cooldown = false 
		add_power(30)
		_on_parry_exitoso()
		return 
	if escudo_golpes_restantes > 0:
		escudo_golpes_restantes -= 1
		EfectosManager.play_sound("Brokenshield", global_position)
		var tw = create_tween()
		tw.tween_method(_set_alpha_modelo, 0.1, 1.0, 0.15)
		return

	EfectosManager.play_sound("hurt", global_position)
	health -= amount
	play_anim("hurt")
	attacking = false 
	is_sliding = false
	generando_trail = false
	combo_step = 0 
	if health <= 0: morir()

func morir():
	set_physics_process(false)
	is_invulnerable = true
	var tw = create_tween()
	tw.tween_method(_set_alpha_modelo, 1.0, 0.0, 0.5)
	await tw.finished
	get_tree().change_scene_to_file("res://scenes/GameOver.tscn")

# Fuerza la animación independientemente si es la misma si se requiere reiniciarla con elegancia
func play_anim(anim_name: String):
	if anim_player.has_animation(anim_name):
		if anim_player.current_animation != anim_name:
			anim_player.play(anim_name)

func _on_animation_player_animation_finished(anim_name: StringName):
	if anim_name == "dance" or anim_name.contains("punch") or anim_name == "hurt" \
	or anim_name == "superpunch" or anim_name == "slidesuper" or anim_name == "charge":
		attacking = false
		is_dancing = false
		is_sliding = false
		idle_timer = 0.0
		play_anim("idle super" if is_max_mode else "idle")

func add_power(amount: float):
	if is_max_mode: return
	power = clamp(power + amount, 0, max_power)
	if power >= max_power: activate_max_mode()

func activate_max_mode():
	reset_idle() 
	is_max_mode = true
	is_invulnerable = true
	attacking = true 
	play_anim("activesuper")
	
	EfectosManager.play_sound("power", global_position)
	
	# Reproducir canción de súper
	reproducir_cancion_super()
	
	await get_tree().create_timer(1.0).timeout
	attacking = false 
	set_model_color(Color(1.5, 1.5, 2.5))
	await get_tree().create_timer(20.0).timeout
	is_max_mode = false
	is_invulnerable = false
	is_sliding = false
	generando_trail = false
	power = 0
	set_model_color(Color(1.0, 1.0, 1.0))

func reproducir_cancion_super():
	var extensiones = [".mp3", ".ogg", ".wav"]
	var ruta_base = "res://SUPER SONGS!/super_plasticsketch" # Ajusta la carpeta si es diferente
	for ext in extensiones:
		var ruta_completa = ruta_base + ext
		if ResourceLoader.exists(ruta_completa):
			if EfectosManager.has_method("play_music"):
				EfectosManager.play_music(ruta_completa)
			else:
				var stream = load(ruta_completa)
				var player = AudioStreamPlayer.new()
				player.stream = stream
				player.name = "SuperPlasticSketchMusic"
				add_child(player)
				player.play()
			break

func reproducir_pasos():
	can_play_step = false
	EfectosManager.play_sound("pasos", global_position, true, -12.0)
	await get_tree().create_timer(0.35).timeout
	can_play_step = true

func reset_idle():
	idle_timer = 0.0
	is_dancing = false

func aplicar_mejoras_tienda():
	if ProgresoJuego.tiene_mejora_vida: health = max_health + 50
	if ProgresoJuego.tiene_mejora_vel: speed += 1.5
	if ProgresoJuego.tiene_shield: escudo_golpes_restantes = 5

func get_sprite_animation():
	return anim_player.current_animation

func _on_parry_exitoso():
	racha_parries += 1
	if racha_parries >= 5 and not ProgresoJuego.logro_parry_master:
		ProgresoJuego.logro_parry_master = true
		ProgresoJuego.guardar_partida()

func _on_recibir_danio():
	racha_parries = 0
