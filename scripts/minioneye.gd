extends CharacterBody3D

signal ataque_inminente(minion_ref)

@export var speed = 1.5
@export var detection_range = 5.0
@export var stop_range = 1.0

var escena_drop = preload("res://scenes/ItemDrop.tscn")
var ESCENA_SANGRE = preload("res://scenes/SangreMorada.tscn")

var health = 60
var max_health_ref = 60
var knockback_velocity = Vector3.ZERO
var is_stunned = false
var can_attack = true
var esta_muerto = false
var tutorial_congelado = false

# --- VARIABLES IA ---
var detectado_permanentemente = false
var angulo_flanqueo = 0.0
var tiempo_cambio_flanqueo = 0.0

# --- GLORY KILL MINION LOGIC ---
var es_ejecutable: bool = false
var siendo_ejecutado: bool = false
var area_deteccion_gk: Area3D = null
var ya_proceso_muerte_gk: bool = false

# =========================================================
# --- OPTIMIZACIÓN ANTI-LAG (nuevo) ---
# =========================================================
# Igual que en minion.gd: el objetivo más cercano se cachea y se recalcula
# como máximo 5 veces por segundo por minion, en vez de en todos los
# physics frames de los 120 enemigos.
var _tiempo_proximo_rechequeo_objetivo: int = 0
const INTERVALO_RECHEQUEO_OBJETIVO_MS: int = 200

# El anti-amontonamiento (que recorre TODOS los enemigos) se reparte en
# 3 turnos de frame según este offset para no correr los 120 a la vez.
var _stagger_offset: int = 0

@onready var sprite = $AnimatedSprite3D
@onready var health_bar = $BarraVisual/SubViewport/ProgressBar

var player = null

# FIX: helper para evitar normalizar un Vector3 (0,0,0) o casi nulo, Y
# TAMBIÉN un Vector3 con componentes NaN/Infinito. Antes este script
# llamaba a .normalized() directo sin ningún guard, lo cual generaba los
# warnings "Vector3 cannot be normalized" apenas la posición del jugador
# (u otro objetivo) quedaba corrupta.
func direccion_segura(desde: Vector3, hacia: Vector3, fallback := Vector3.FORWARD) -> Vector3:
	var diff = hacia - desde
	if not diff.is_finite() or diff.length_squared() < 0.0001:
		return fallback
	return diff.normalized()

func _ready():
	if get_tree().current_scene.name != "NivelTutorial":
		tutorial_congelado = false
		is_stunned = false
	velocity.y = -2.0
	add_to_group("enemies")
	add_to_group("minioneye")  # Grupo clave para que Sketch detecte este tipo de enemigo
	max_health_ref = health
	player = get_tree().get_first_node_in_group("player")
	angulo_flanqueo = randf_range(-0.8, 0.8)
	_stagger_offset = randi() % 3

	if health_bar:
		health_bar.max_value = health
		health_bar.value = health
		health_bar.modulate = Color.GREEN


func _physics_process(delta):
	if siendo_ejecutado:
		velocity = Vector3.ZERO
		move_and_slide()
		return

	# --- OPTIMIZACIÓN: cacheamos el objetivo más cercano y solo lo
	# recalculamos cada INTERVALO_RECHEQUEO_OBJETIVO_MS, en vez de recorrer
	# los grupos "player"/"allies" en cada physics frame.
	var ahora_ms = Time.get_ticks_msec()
	if ahora_ms >= _tiempo_proximo_rechequeo_objetivo:
		_tiempo_proximo_rechequeo_objetivo = ahora_ms + INTERVALO_RECHEQUEO_OBJETIVO_MS
		var posibles = get_tree().get_nodes_in_group("player") + get_tree().get_nodes_in_group("allies")
		var mas_cercano = null
		var dist_minima = 9999.0

		for p in posibles:
			# Validamos que sea 3D para evitar crasheos si lee un nodo 2D
			if is_instance_valid(p) and "global_position" in p and p.global_position is Vector3:
				var d = global_position.distance_to(p.global_position)
				if d < dist_minima:
					dist_minima = d
					mas_cercano = p

		if mas_cercano:
			player = mas_cercano

	if player == null or !is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")
		return

	# Gravedad
	if not is_on_floor():
		velocity.y -= 18.0 * delta
	elif velocity.y < 0:
		velocity.y = -0.1

	# Knockback por daño estándar
	if knockback_velocity.length() > 0.1:
		velocity.x = knockback_velocity.x
		velocity.z = knockback_velocity.z
		if knockback_velocity.y != 0: velocity.y = knockback_velocity.y
		var friccion = 35.0
		knockback_velocity = knockback_velocity.move_toward(Vector3.ZERO, delta * friccion)
		if esta_muerto and knockback_velocity.y > 3.0:
			sprite.rotation.z += delta * 30.0
			sprite.rotation.x += delta * 15.0

	elif not is_stunned and player:
		var dist = global_position.distance_to(player.global_position)
		var rango_actual = detection_range

		if PocionManager.invisible:
			rango_actual = 0.5

		if dist < rango_actual or detectado_permanentemente:
			detectado_permanentemente = true
			follow_player_smart(dist, delta)
		else:
			velocity.x = move_toward(velocity.x, 0, speed)
			velocity.z = move_toward(velocity.z, 0, speed)
			if not sprite.animation in ["attack", "hurt"]:
				sprite.play("idle")
	else:
		if not siendo_ejecutado:
			velocity.x = move_toward(velocity.x, 0, speed)
			velocity.z = move_toward(velocity.z, 0, speed)

	# --- OPTIMIZACIÓN: anti-amontonamiento repartido en 3 turnos de frame
	# (cada minion lo corre 1 de cada 3 frames) para bajar el costo O(n²)
	# a un tercio con 120 enemigos activos.
	if (Engine.get_physics_frames() + _stagger_offset) % 3 == 0:
		evitar_amontonamiento(delta)
	aplicar_limite_de_velocidad_seguro()
	move_and_slide()


# =========================================================
# --- RED DE SEGURIDAD ANTI-NaN/OVERFLOW (nuevo) ---
# =========================================================
# El "instance_set_transform ... !v.is_finite()" y el normalize() que falla
# DENTRO de move_and_slide() (no en nuestro propio código) pasan porque la
# velocidad ya venía rota (NaN o Infinito) antes de llamar a move_and_slide().
# Esto es típico cuando muchísimos minions quedan superpuestos sobre un
# mismo objetivo (tu acompañante peleando sola mientras vos te alejás): la
# resolución de colisiones entre decenas de cuerpos profundamente
# superpuestos puede generar velocidades de empuje absurdamente grandes que
# desbordan el float (Infinito) y de ahí a NaN (Infinito/Infinito = NaN).
# Esta red de seguridad se llama siempre antes de move_and_slide() y
# garantiza que la velocidad nunca sea no-finita ni absurdamente grande.
const VELOCIDAD_HORIZONTAL_MAXIMA: float = 40.0

func aplicar_limite_de_velocidad_seguro():
	if not is_finite(velocity.y):
		velocity.y = 0.0
	var horizontal = Vector3(velocity.x, 0, velocity.z)
	if not horizontal.is_finite():
		velocity.x = 0.0
		velocity.z = 0.0
	elif horizontal.length() > VELOCIDAD_HORIZONTAL_MAXIMA:
		horizontal = horizontal.limit_length(VELOCIDAD_HORIZONTAL_MAXIMA)
		velocity.x = horizontal.x
		velocity.z = horizontal.z


func follow_player_smart(dist, delta):
	if es_ejecutable:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)
		if sprite.animation != "hurt":
			sprite.play("hurt")
		return

	tiempo_cambio_flanqueo -= delta
	if tiempo_cambio_flanqueo <= 0:
		angulo_flanqueo = randf_range(-1.2, 1.2)
		tiempo_cambio_flanqueo = randf_range(2.0, 4.0)

	# FIX: usamos direccion_segura en vez de normalized() directo
	var dir_hacia_jugador = direccion_segura(global_position, player.global_position)
	var dir_final = dir_hacia_jugador.rotated(Vector3.UP, angulo_flanqueo)

	if dist > stop_range:
		velocity.x = dir_final.x * speed
		velocity.z = dir_final.z * speed
		if not sprite.animation in ["attack", "hurt"]:
			sprite.play("walk")
		sprite.flip_h = dir_hacia_jugador.x > 0
	elif can_attack:
		velocity.x = 0
		velocity.z = 0
		attack_player()
	else:
		var acecho = dir_hacia_jugador.rotated(Vector3.UP, PI/2)
		velocity.x = acecho.x * (speed * 0.7)
		velocity.z = acecho.z * (speed * 0.7)
		if not sprite.animation in ["attack", "hurt"]:
			sprite.play("walk")


func evitar_amontonamiento(_delta):
	for enemigo in get_tree().get_nodes_in_group("enemies"):
		if enemigo != self and is_instance_valid(enemigo):
			var dist_enemigo = global_position.distance_to(enemigo.global_position)
			if dist_enemigo < 0.7:
				# FIX: usamos direccion_segura en vez de normalized() directo
				var dir_escape = direccion_segura(enemigo.global_position, global_position)
				velocity.x += dir_escape.x * 0.3
				velocity.z += dir_escape.z * 0.3


func attack_player():
	var zona = get_tree().current_scene.find_child("ZonaInstructor", true, false)
	if zona and zona.etapa == 2:
		zona.trigger_congelar_parry()
		if not is_inside_tree() or tutorial_congelado or is_stunned: return

	can_attack = false
	is_stunned = true

	sprite.play("attack")
	emit_signal("ataque_inminente", self)
	await get_tree().create_timer(0.5).timeout
	if not is_inside_tree() or esta_muerto or siendo_ejecutado: return

	if player and global_position.distance_to(player.global_position) < 1.4:
		if player.get("is_parrying"):
			EstadisticasNivel.registrar_parry() 
			stun_minion(3.0)
			take_damage(5, global_position)
			player.take_damage(0, global_position)
			return
		else:
			var dano = 10
			if player.get("defensa_ectoplasma") == true: dano /= 3
			player.take_damage(dano, global_position)

	await get_tree().create_timer(0.5).timeout
	if not is_inside_tree() or esta_muerto or siendo_ejecutado: return

	if not es_ejecutable:
		is_stunned = false

	var cooldown = 2.5
	await get_tree().create_timer(cooldown).timeout
	can_attack = true


func stun_minion(duration):
	if not is_inside_tree() or siendo_ejecutado: return
	is_stunned = true
	can_attack = false
	sprite.modulate = Color(2, 2, 0)
	sprite.play("hurt")
	await get_tree().create_timer(duration).timeout
	if not is_inside_tree() or esta_muerto or siendo_ejecutado: return
	sprite.modulate = Color(1, 1, 1)
	is_stunned = false
	can_attack = true
	sprite.play("idle")


func take_damage(amount, source_pos):
	if esta_muerto or siendo_ejecutado: return

	health -= amount
	actualizar_barra_vida()

	if health <= 0:
		die()
		return

	# Entra en estado ejecutable al llegar al 25% de vida
	if health <= (max_health_ref * 0.25) and not es_ejecutable:
		activar_estado_ejecutable()
		return

	if not es_ejecutable and sprite.modulate != Color(2, 2, 0):
		is_stunned = true
		sprite.play("hurt")
		# FIX: usamos direccion_segura en vez de normalized() directo
		var dir = direccion_segura(source_pos, global_position)
		knockback_velocity = Vector3(dir.x, 0, dir.z) * 3.5

		await get_tree().create_timer(0.2).timeout
		if not es_ejecutable and not esta_muerto and not siendo_ejecutado:
			is_stunned = false


func actualizar_barra_vida():
	if health_bar:
		health_bar.value = health
		var porcentaje = float(health) / float(max_health_ref)
		if porcentaje > 0.6: health_bar.modulate = Color.GREEN
		elif porcentaje > 0.3: health_bar.modulate = Color.ORANGE
		else: health_bar.modulate = Color.RED


func soltar_sangre():
	var sangre = ESCENA_SANGRE.instantiate()
	get_tree().current_scene.add_child(sangre)
	sangre.global_position = global_position + Vector3(0, 0.5, 0)


func die():
	if esta_muerto: return
	esta_muerto = true
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
		drop.global_position = global_position + Vector3(0, 0.09, 0)
		if suerte < 40:
			drop.tipo_actual = 0
		else:
			drop.tipo_actual = 1
		if drop.has_method("actualizar_item"):
			drop.actualizar_item()


func _on_animated_sprite_3d_animation_finished():
	if siendo_ejecutado:
		_morir_por_ejecucion()
		return

	match sprite.animation:
		"hurt", "attack":
			if health > (max_health_ref * 0.25) and sprite.modulate != Color(2, 2, 0):
				is_stunned = false
				sprite.play("idle")


func activar_estado_ejecutable():
	es_ejecutable = true
	is_stunned = true
	can_attack = false

	var tw = create_tween().set_loops()
	tw.tween_property(sprite, "modulate", Color(5, 5, 5), 0.2)
	tw.tween_property(sprite, "modulate", Color(1, 0, 0), 0.2)

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


# Método dinámico: recibe el nombre exacto de la animación desde Sketch
func ser_ejecutado_dinamico(nombre_anim_completo: String):
	print("[GK Minioneye] Reproduciendo: ", nombre_anim_completo)
	siendo_ejecutado = true
	esta_muerto = true
	velocity = Vector3.ZERO  # Evita que salga volando por velocidad acumulada
	if area_deteccion_gk: area_deteccion_gk.queue_free()
	if has_node("BarraVisual"): $BarraVisual.visible = false

	var player_node = get_tree().get_first_node_in_group("player")
	if player_node:
		sprite.flip_h = player_node.global_position.x > global_position.x

	if sprite.sprite_frames.has_animation(nombre_anim_completo):
		# Desactivar loop por si acaso está activado en el editor — sin esto animation_finished nunca dispara
		sprite.sprite_frames.set_animation_loop(nombre_anim_completo, false)
		sprite.play(nombre_anim_completo)
		# Timer de seguridad: si animation_finished no disparó (loop, anim corta, etc), matamos igual
		var duracion = sprite.sprite_frames.get_frame_count(nombre_anim_completo) / sprite.sprite_frames.get_animation_speed(nombre_anim_completo)
		await get_tree().create_timer(duracion + 0.3).timeout
		if is_instance_valid(self) and siendo_ejecutado:
			_morir_por_ejecucion()
	else:
		print("[GK ERROR Minioneye] No existe la animacion: '", nombre_anim_completo, "'")
		sprite.play("hurt")
		await get_tree().create_timer(0.4).timeout
		_morir_por_ejecucion()


# Método sin argumentos: fallback por compatibilidad, siempre usa kill 1
func ser_ejecutado():
	ser_ejecutado_dinamico("minioneye kill 1")


func _morir_por_ejecucion():
	if ya_proceso_muerte_gk: return
	ya_proceso_muerte_gk = true

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
