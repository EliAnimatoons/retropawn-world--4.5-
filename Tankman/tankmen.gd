extends CharacterBody3D

var sufijo_control: String = ""
signal parry_realizado

@export var jump_velocity = 4.5
var puede_saltar_aqui = false
var puede_correr_aqui = false
@export var speed = 2.4 
@export var run_speed = 4.5
var defensa_ectoplasma = false
@export var max_health = 100.0 
var health = 100.0
@export var character_name = "Tankman"
var racha_parries = 0

var escudo_golpes_restantes = 0
var esta_invisible = false

var posicion_hace_3s = Vector3.ZERO
var multiplicador_glitch = 1.0

# --- MECÁNICA DE ESCOPETA (FORMA BASE) ---
const BALA_ESCENA = preload("res://scenes/BalaJane.tscn")
var municion_escopeta: int = 2
const MAX_MUNICION_ESCOPETA: int = 2
var recargando_escopeta: bool = false

# --- MODO SUPER / TANQUE ---
var power = 0.0
var max_power = 500.0
var is_max_mode = false
var is_invulnerable = false
var anim_prefix = "" 
var skin_prefix = "" 
@export var velocidad_tanque: float = 1.6
@export var dano_embestida_tanque: float = 5.0
var tiempo_siguiente_embestida: float = 0.0

@onready var hitbox = $HitBox
@onready var sprite = $AnimatedSprite3D

# --- BAILE Y IDLE SISTEMA ---
var idle_time = 0.0
const TIME_TO_DANCE = 120.0
var is_dancing = false
var heal_timer = 0.0

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

# --- SISTEMA DE AGARRE (GRAB) ---
var siendo_agarrado: bool = false
var minion_que_agarra: Node3D = null

# --- CARGAR OBJETOS (TACHO / MINION BOMBA) ---
@export_group("Cargar Objetos")
@export var rango_agarre: float = 1.4
@export var rango_lanzamiento: float = 4.5
## Posición del tacho mientras lo cargás (X se espeja según hacia dónde mirás)
@export var offset_carga_tacho: Vector3 = Vector3(0, 0.6, 0)
## Posición de la bomba mientras la cargás
@export var offset_carga_bomba: Vector3 = Vector3(0, 0.6, 0)
var objeto_cargado: Node3D = null
var _offset_y_objeto: float = 0.0

func _ready():
	add_to_group("player")
	aplicar_mejoras_tienda()
	posicion_hace_3s = global_position
	iniciar_rastreo_posicion()

	# FIX: en Godot 4, si una animación tiene "Loop" activado en el SpriteFrames,
	# la señal "animation_finished" NUNCA se emite (solo "animation_looped", una
	# vez por cada vuelta completa). Escuchamos también esta señal.
	if not sprite.animation_looped.is_connected(_on_animated_sprite_3d_animation_looped):
		sprite.animation_looped.connect(_on_animated_sprite_3d_animation_looped)

func iniciar_rastreo_posicion():
	while true:
		await get_tree().create_timer(3.0).timeout
		if is_on_floor() and not attacking and not siendo_agarrado and not recargando_escopeta:
			posicion_hace_3s = global_position

func _physics_process(delta):
	# Control de agarre
	if siendo_agarrado:
		velocity.x = 0
		velocity.z = 0
		if not is_on_floor():
			velocity.y -= 9.8 * delta
		move_and_slide()
		return

	if haciendo_glory_kill: return

	var padre = get_parent()
	if padre:
		puede_saltar_aqui = padre.is_in_group("nivel_con_gravedad")
		puede_correr_aqui = padre.is_in_group("nivel_con_carrera")

	# Cargando un objeto: solo se puede caminar (nada de saltar)
	if objeto_cargado != null:
		puede_correr_aqui = false
		puede_saltar_aqui = false

	skin_prefix = ""
	anim_prefix = "super " if is_max_mode else ""

	var base_speed = speed if not is_max_mode else velocidad_tanque
	var current_speed = base_speed * multiplicador_glitch

	# Lógica Idle / Baile
	var input_dir = Input.get_vector(
		"izquierda" + sufijo_control,
		"derecha" + sufijo_control,
		"arriba" + sufijo_control,
		"abajo" + sufijo_control
	)

	# Bailar solo si NO está cargando un objeto
	if input_dir == Vector2.ZERO and not attacking and not is_parrying and not recargando_escopeta and not is_max_mode and objeto_cargado == null:
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

	if attacking or is_parrying or recargando_escopeta or (sprite.animation.contains("hurt") if sprite.animation else false) or sprite.animation == "super":
		velocity.x = move_toward(velocity.x, 0, current_speed)
		velocity.z = move_toward(velocity.z, 0, current_speed)
	else:
		handle_movement(current_speed)

	# Embestida controlada en modo tanque
	if is_max_mode and velocity.length() > 0.1:
		procesar_embestida_tanque(delta)

	if combo_timer > 0: combo_timer -= delta
	else: combo_step = 0

	# Glory Kill Input (no se puede mientras carga un objeto)
	if Input.is_action_just_pressed("glory_kill") and minion_ejecutable != null and objeto_cargado == null and not attacking and not is_parrying and not is_max_mode and not haciendo_glory_kill:
		iniciar_glory_kill()

	# ATAQUE: dispara normal, o lanza/suelta el objeto si lo está cargando
	if Input.is_action_just_pressed("ataque" + sufijo_control):
		if not attacking and not is_parrying and not recargando_escopeta and not haciendo_glory_kill:
			if objeto_cargado != null:
				lanzar_o_soltar_objeto()
			else:
				execute_attack()

	# PARRY: agarra un objeto cercano, o parrea si no hay nada para agarrar
	if Input.is_action_just_pressed("parry" + sufijo_control) and not is_max_mode and not haciendo_glory_kill:
		if objeto_cargado == null and not attacking and not is_parrying and not recargando_escopeta:
			var cercano = _buscar_objeto_agarrable()
			if cercano:
				agarrar_objeto(cercano)
			elif not parry_cooldown:
				execute_parry()

	# Salto (no se puede mientras carga un objeto)
	if puede_saltar_aqui:
		if not is_on_floor():
			velocity.y -= ProjectSettings.get_setting("physics/3d/default_gravity") * delta
		if Input.is_action_just_pressed("salto" + sufijo_control) and is_on_floor() and objeto_cargado == null:
			velocity.y = jump_velocity
			is_dancing = false
	else:
		if not is_on_floor():
			velocity.y -= 9.8 * delta

	move_and_slide()
	_seguir_objeto_cargado()

func handle_movement(move_speed):
	var input_dir = Input.get_vector(
		"izquierda" + sufijo_control,
		"derecha" + sufijo_control,
		"arriba" + sufijo_control,
		"abajo" + sufijo_control
	)
	# Normalización segura: con el jugador quieto (0,0,0) no tira warnings
	var direction = Utils.normalizar_seguro(Vector3(input_dir.x, 0, input_dir.y), Vector3.ZERO)

	# Cargando un objeto: movimiento simple, solo caminar
	if objeto_cargado != null:
		_mover_cargando(input_dir, direction, move_speed)
		return

	if direction:
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
			await get_tree().create_timer(0.45 if is_max_mode else 0.35).timeout
			can_play_step = true
	else:
		velocity.x = move_toward(velocity.x, 0, move_speed)
		velocity.z = move_toward(velocity.z, 0, move_speed)
		if not is_dancing:
			var anim_idle = skin_prefix + anim_prefix + "idle"
			if sprite.sprite_frames.has_animation(anim_idle):
				sprite.play(anim_idle)
			else:
				sprite.play("idle" if not is_max_mode else "super idle")

# =========================================================
# --- CARGAR OBJETOS ---
# =========================================================
func _dir_x() -> float:
	return -1.0 if sprite.flip_h else 1.0

func _obtener_animacion_valida(nombre_base: String) -> String:
	var con_prefijo = skin_prefix + nombre_base
	if sprite.sprite_frames.has_animation(con_prefijo):
		return con_prefijo
	return nombre_base

func _dist_horizontal(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()

# Offset de carga según el tipo de objeto (tacho = lanzamiento recto, bomba = parabólico).
# El X se espeja según hacia dónde mira el personaje.
func _offset_para(obj: Node3D) -> Vector3:
	var o = offset_carga_tacho if obj.get("lanzamiento_recto") == true else offset_carga_bomba
	o.x *= _dir_x()
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
		if dx * _dir_x() < -0.3: continue # está detrás, no cuenta
		var d = _dist_horizontal(global_position, e.global_position)
		if d < mejor_dist:
			mejor_dist = d
			mejor = e
	return mejor

func agarrar_objeto(obj: Node3D) -> void:
	is_dancing = false
	idle_time = 0.0
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
	is_dancing = false
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
			obj.ser_lanzado_recto(origen, _dir_x(), global_position, suelo_y)
		else:
			# Bomba: parábola hacia el grupo, aterriza un poquito ANTES del enemigo
			sprite.flip_h = objetivo.global_position.x < global_position.x
			hitbox.scale.x = -1 if sprite.flip_h else 1
			sprite.play(_obtener_animacion_valida("rude drop"))
			EfectosManager.play_sound("viento", global_position, true)
			var hacia = Vector3(objetivo.global_position.x - global_position.x, 0, objetivo.global_position.z - global_position.z)
			hacia = Utils.normalizar_seguro(hacia, Vector3(_dir_x(), 0, 0))
			var destino = objetivo.global_position - hacia * 0.9
			destino.y = suelo_y
			obj.ser_lanzado(origen, destino, global_position, dano, 1.2, 0.35)
	else:
		sprite.play(_obtener_animacion_valida("soft drop"))
		var destino = global_position + Vector3(_dir_x() * 0.9, _offset_y_objeto, 0)
		obj.ser_lanzado(origen, destino, global_position, 0, 0.4, 0.2)

func soltar_objeto_por_golpe() -> void:
	if objeto_cargado == null: return
	var obj = objeto_cargado
	objeto_cargado = null
	if not is_instance_valid(obj): return
	var destino = global_position + Vector3(_dir_x() * 0.9, _offset_y_objeto, 0)
	obj.ser_lanzado(global_position + _offset_para(obj), destino, global_position, 0, 0.6, 0.25)

func _mover_cargando(input_dir: Vector2, direction: Vector3, move_speed: float) -> void:
	is_dancing = false
	idle_time = 0.0
	if input_dir.x != 0:
		sprite.flip_h = input_dir.x < 0
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

# --- ATAQUE Y DISPARO ---
func execute_attack():
	is_dancing = false

	if is_max_mode:
		disparar_canon_tanque()
		return

	if municion_escopeta <= 0:
		iniciar_recarga_escopeta()
		return

	attacking = true
	municion_escopeta -= 1

	var anim_shoot = skin_prefix + "shoot"
	if sprite.sprite_frames.has_animation(anim_shoot):
		sprite.play(anim_shoot)
	else:
		sprite.play("shoot")

	# AUDIOS DE DISPARO
	EfectosManager.play_sound("Shoot sound", global_position, true)
	EfectosManager.play_sound("viento", global_position, true, -6.0)

	var dir_x = -1.0 if sprite.flip_h else 1.0
	var angulos = [-0.15, 0.0, 0.15]

	for angulo in angulos:
		var bala = BALA_ESCENA.instantiate()
		get_tree().current_scene.add_child(bala)
		bala.global_position = global_position + Vector3(0, 0.1, 0)

		if bala.has_method("set_source"):
			bala.set_source(global_position)
		elif "source_pos" in bala:
			bala.source_pos = global_position

		var direccion_base = Vector3(dir_x, 0, 0).rotated(Vector3.UP, angulo)
		bala.direccion = direccion_base
		bala.rotation.y = (PI if dir_x < 0 else 0.0) + angulo

		if "max_distancia" in bala:
			bala.max_distancia = 4.5

		if "dano" in bala:
			var dano_escopeta = 4
			if ProgresoJuego.tiene_mejora_fuerza: dano_escopeta *= 1.5
			bala.dano = dano_escopeta

	add_power(6)
	combo_timer = COMBO_TIME_WINDOW

func disparar_canon_tanque():
	attacking = true
	
	if sprite.sprite_frames.has_animation("super shoot"):
		sprite.play("super shoot")
	elif sprite.sprite_frames.has_animation("super_shoot"):
		sprite.play("super_shoot")
	else:
		sprite.play("shoot")

	# Sonido potente para el cañón del tanque
	EfectosManager.play_sound("Shoot sound", global_position, true, 3.0)

	var bala = BALA_ESCENA.instantiate()
	get_tree().current_scene.add_child(bala)
	bala.global_position = global_position + Vector3(0, 0.2, 0)

	if bala.has_method("set_source"):
		bala.set_source(global_position)
	elif "source_pos" in bala:
		bala.source_pos = global_position

	var dir_x = -1.0 if sprite.flip_h else 1.0
	bala.direccion = Vector3(dir_x, 0, 0)
	bala.rotation.y = PI if dir_x < 0 else 0.0

	if "max_distancia" in bala:
		bala.max_distancia = 12.0

	bala.scale = Vector3(2.5, 2.5, 2.5)
	if "dano" in bala:
		var dano_tanque = 5.0
		if ProgresoJuego.tiene_mejora_fuerza: dano_tanque *= 1.5
		bala.dano = dano_tanque

func iniciar_recarga_escopeta():
	recargando_escopeta = true

	# Reproducir sonido de recarga
	EfectosManager.play_sound("reload", global_position)

	var anim_reload = skin_prefix + "reload"
	if sprite.sprite_frames.has_animation(anim_reload):
		sprite.play(anim_reload)
	elif sprite.sprite_frames.has_animation("reload"):
		sprite.play("reload")
	else:
		print("No se encontró la animación 'reload'")

# --- EMBESTIDA TANQUE ---
func procesar_embestida_tanque(delta: float):
	tiempo_siguiente_embestida -= delta
	if tiempo_siguiente_embestida > 0.0: return

	var enemigos = get_tree().get_nodes_in_group("enemy") + get_tree().get_nodes_in_group("enemies")
	for enemigo in enemigos:
		if is_instance_valid(enemigo) and enemigo != self:
			var dist = global_position.distance_to(enemigo.global_position)
			if dist <= 1.2:
				var dir_empuje = Utils.normalizar_seguro(enemigo.global_position - global_position)
				dir_empuje.y = 0

				if enemigo.has_method("take_damage"):
					enemigo.take_damage(dano_embestida_tanque, global_position)
				
				if "velocity" in enemigo:
					enemigo.velocity += dir_empuje * 5.0

				EfectosManager.impact_effect(0.4, 0.2, enemigo.global_position, 1)
				tiempo_siguiente_embestida = 0.5 # Cooldown para evitar acumulación excesiva de daño

# --- PARRY & MODO SUPER ---
func execute_parry():
	is_dancing = false
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

func add_power(amount):
	if is_max_mode: return
	power = clamp(power + amount, 0, max_power)
	if power >= max_power: activate_max_mode()

func activate_max_mode():
	if siendo_agarrado: return
	soltar_objeto_por_golpe()
	is_dancing = false
	is_max_mode = true
	is_invulnerable = true
	attacking = true
	recargando_escopeta = false

	var anim_super = skin_prefix + "super"
	if sprite.sprite_frames.has_animation(anim_super):
		sprite.play(anim_super)
	else:
		sprite.play("super")

	EfectosManager.play_sound("power", global_position)
	reproducir_cancion_super()

	await get_tree().create_timer(1.2).timeout
	attacking = false
	sprite.modulate = Color(1.8, 1.8, 1.2)

	await get_tree().create_timer(20.0).timeout

	is_max_mode = false
	is_invulnerable = false
	power = 0
	municion_escopeta = MAX_MUNICION_ESCOPETA
	sprite.modulate = Color(0.7, 1.2, 0.7) if ProgresoJuego.tiene_poison else Color(1, 1, 1)

func reproducir_cancion_super():
	var extensiones = [".mp3", ".ogg", ".wav"]
	var ruta_base = "res://SUPER SONGS!/super_tankman"
	for ext in extensiones:
		var ruta_completa = ruta_base + ext
		if ResourceLoader.exists(ruta_completa):
			if EfectosManager.has_method("play_music"):
				EfectosManager.play_music(ruta_completa)
			else:
				var stream = load(ruta_completa)
				var player = AudioStreamPlayer.new()
				player.stream = stream
				player.name = "SuperTankmanMusic"
				add_child(player)
				player.play()
			break

func take_damage(amount: int, source_pos: Vector3 = Vector3.ZERO):
	is_dancing = false
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
		sprite.modulate = Color(2, 2, 2)
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
		sprite.play("hurt")

	recargando_escopeta = false
	attacking = false

	if health <= 0:
		morir_jugador()

func morir_jugador():
	soltar_objeto_por_golpe()
	set_physics_process(false)
	is_invulnerable = true
	ProgresoJuego.ultima_ruta_nivel = get_tree().current_scene.scene_file_path
	var t = create_tween()
	t.tween_property(sprite, "modulate:a", 0.0, 0.2)
	await t.finished
	get_tree().call_deferred("change_scene_to_file", "res://scenes/GameOver.tscn")

func heal(amount): health = clamp(health + amount, 0, max_health)

func _on_animated_sprite_3d_animation_finished():
	if sprite.animation and ("Tankman Glory kill" in sprite.animation):
		_finalizar_glory_kill_logica()
		return

	# La pose de "grab item" se queda congelada en el último frame mientras carga
	if sprite.animation and ("grab item" in sprite.animation):
		return

	if sprite.animation and ("reload" in sprite.animation):
		municion_escopeta = MAX_MUNICION_ESCOPETA
		recargando_escopeta = false
		sprite.play(skin_prefix + anim_prefix + "idle")
		return

	if sprite.animation and ("shoot" in sprite.animation or "hurt" in sprite.animation or "parry" in sprite.animation or sprite.animation == "super" or "dance" in sprite.animation or "drop" in sprite.animation):
		attacking = false
		is_parrying = false
		recargando_escopeta = false
		sprite.play(skin_prefix + anim_prefix + "idle")

func _on_animated_sprite_3d_animation_looped():
	# Esta señal se dispara cuando una animación con Loop activado completa
	# una vuelta (en vez de "animation_finished"). La Glory Kill no debería
	# loopear nunca, así que la primera vuelta cuenta como el final real.
	if sprite.animation and ("Tankman Glory kill" in sprite.animation):
		_finalizar_glory_kill_logica()
		return

	# Seguro: si "rude drop" / "soft drop" quedaron con Loop activado, no dejamos
	# al personaje trabado en "attacking".
	if sprite.animation and ("drop" in sprite.animation):
		attacking = false
		sprite.play(skin_prefix + anim_prefix + "idle")

# --- GLORY KILLS ---
func iniciar_glory_kill():
	if minion_ejecutable == null or not is_instance_valid(minion_ejecutable): return

	haciendo_glory_kill = true
	is_invulnerable = true
	is_dancing = false
	velocity = Vector3.ZERO

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

	var id_rand = randi_range(1, 2)
	var nombre_anim = "Tankman Glory kill " + str(id_rand)
	var nombre_audio = "Glory kill " + str(id_rand) + " Tankman audio"

	# El minion usará "minion kill 13" o "minion kill 14"
	var id_minion_kill = 12 + id_rand
	var nombre_anim_minion = "minion kill " + str(id_minion_kill)

	EfectosManager.play_sound(nombre_audio, global_position)

	if minion_ejecutable.has_method("ser_ejecutado_dinamico"):
		minion_ejecutable.ser_ejecutado_dinamico(nombre_anim_minion)
	elif minion_ejecutable.has_method("ser_ejecutado"):
		minion_ejecutable.ser_ejecutado(str(id_minion_kill))

	sprite.stop()

	if sprite.sprite_frames.has_animation(nombre_anim):
		sprite.play(nombre_anim)
		# Seguro anti-freeze (último recurso) por si "animation_finished" no se
		# dispara. Tope máximo fijo, ignorando Engine.time_scale.
		var frames = sprite.sprite_frames.get_frame_count(nombre_anim)
		var fps = sprite.sprite_frames.get_animation_speed(nombre_anim)
		var duracion_estimada = (float(frames) / fps) + 0.3 if fps > 0.1 else 1.5
		var duracion_segura = clamp(duracion_estimada, 0.3, 8.0)
		await get_tree().create_timer(duracion_segura, true, false, true).timeout
		if haciendo_glory_kill:
			print("[GK] Seguro anti-freeze (último recurso) activado en: ", nombre_anim, " (fps configurado: ", fps, ")")
			_finalizar_glory_kill_logica()
	else:
		await get_tree().create_timer(0.8).timeout
		_finalizar_glory_kill_logica()

func _finalizar_glory_kill_logica():
	# Evita ejecutar la lógica dos veces si la señal y el timer de seguridad
	# llegan a dispararse ambos.
	if not haciendo_glory_kill: return

	haciendo_glory_kill = false
	is_invulnerable = false
	attacking = false
	minion_ejecutable = null
	heal(20)
	add_power(20)
	municion_escopeta = MAX_MUNICION_ESCOPETA

	# Si add_power(20) activó el modo súper, no pisamos la animación "super"
	# que activate_max_mode() acaba de poner.
	if not is_max_mode:
		sprite.play(skin_prefix + anim_prefix + "idle")

# --- AGARRE Y MEJORAS DE TIENDA ---
func ser_agarrado(minion_ref: Node3D):
	if haciendo_glory_kill or is_invulnerable or siendo_agarrado or is_max_mode: return

	soltar_objeto_por_golpe()
	siendo_agarrado = true
	recargando_escopeta = false
	is_dancing = false
	minion_que_agarra = minion_ref
	velocity = Vector3.ZERO

	if is_instance_valid(minion_ref) and not minion_ref.tree_exiting.is_connected(_on_minion_agarrador_destruido):
		minion_ref.tree_exiting.connect(_on_minion_agarrador_destruido)

	if sprite.sprite_frames.has_animation("grabbed Tankman"):
		sprite.play("grabbed Tankman")
	else:
		sprite.play("hurt")

func _on_minion_agarrador_destruido():
	if siendo_agarrado:
		liberado_de_agarre()

func liberado_de_agarre():
	if not siendo_agarrado and minion_que_agarra == null: return

	if is_instance_valid(minion_que_agarra):
		if minion_que_agarra.has_method("remove_collision_exception_with"):
			remove_collision_exception_with(minion_que_agarra)
		if minion_que_agarra.tree_exiting.is_connected(_on_minion_agarrador_destruido):
			minion_que_agarra.tree_exiting.disconnect(_on_minion_agarrador_destruido)

	siendo_agarrado = false
	minion_que_agarra = null
	is_parrying = false
	velocity = Vector3.ZERO

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
		tw2.tween_property(sprite, "modulate:a", 1.0, 0.5)
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
		speed += 1.2
		run_speed += 1.8
	if ProgresoJuego.tiene_shield:
		escudo_golpes_restantes = 5
	if ProgresoJuego.tiene_poison:
		sprite.modulate = Color(0.7, 1.2, 0.7)

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
	recargando_escopeta = false
	attacking = false
	is_dancing = false
	await get_tree().create_timer(1.5).timeout
	sprite.modulate = Color(0.7, 1.2, 0.7) if ProgresoJuego.tiene_poison else Color(1, 1, 1)
	multiplicador_glitch = 1.0
