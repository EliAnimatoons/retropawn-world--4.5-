extends CharacterBody3D

@export var speed = 1.5
@export var detection_range = 8.0
@export var stop_range = 1.2
@export var damage_explosion = 80.0
@export var radio_explosion = 2.3

@export_group("Lanzamiento")
@export var lanzamiento_recto: bool = false   # la bomba va en parábola
@export var dano_impacto: int = 15
@export var radio_espacio_libre: float = 0.55

var ESCENA_SANGRE = preload("res://scenes/SangreMorada.tscn")

var esta_muerto = false
var esta_explotando = false
var knockback_velocity = Vector3.ZERO
var is_stunned = false

# =========================================================
# --- OPTIMIZACIÓN ANTI-LAG ---
# =========================================================
var _tiempo_proximo_rechequeo_objetivo: int = 0
const INTERVALO_RECHEQUEO_OBJETIVO_MS: int = 200

# Cache compartido de objetivos (mismo criterio que en minion.gd).
static var _cache_objetivos: Array = []
static var _cache_objetivos_ms: int = 0

# Cache del nodo del tutorial (find_child recursivo es carísimo).
var _zona_instructor = null
var _zona_instructor_buscada: bool = false

# Última posición buena, para rescatar al nodo si su transform queda en NaN.
var _ultima_pos_valida: Vector3 = Vector3.ZERO

# APAGADO POR DEFECTO: solo sirve si los enemigos tienen capa propia distinta
# de la del piso. En la capa 1 los hace atravesar el suelo y desaparecer.
@export var ignorar_colision_entre_enemigos: bool = false

const VELOCIDAD_HORIZONTAL_MAXIMA: float = 40.0
const KNOCKBACK_MAXIMO: float = 30.0

@onready var sprite = $AnimatedSprite3D

var player = null


func _ready():
	add_to_group("enemies")
	# FIX: sin este grupo el jugador nunca detectaba a la bomba como agarrable
	add_to_group("agarrable")
	player = get_tree().get_first_node_in_group("player")
	_ultima_pos_valida = global_position
	if ignorar_colision_entre_enemigos:
		var capa_enemigos = collision_layer & ~1
		var nueva_mascara = collision_mask & ~capa_enemigos
		if capa_enemigos != 0 and nueva_mascara != 0:
			collision_mask = nueva_mascara
	max_slides = 2
	safe_margin = 0.06


func direccion_segura(desde: Vector3, hacia: Vector3, fallback := Vector3.FORWARD) -> Vector3:
	if not desde.is_finite() or not hacia.is_finite():
		return fallback
	var diff = hacia - desde
	if not diff.is_finite() or diff.length_squared() < 0.0001:
		return fallback
	return diff.normalized()


func obtener_objetivos() -> Array:
	var ahora = Time.get_ticks_msec()
	if ahora >= _cache_objetivos_ms:
		_cache_objetivos_ms = ahora + 200
		_cache_objetivos = get_tree().get_nodes_in_group("player") + get_tree().get_nodes_in_group("allies")
	return _cache_objetivos


# =========================================================
# --- MOVIMIENTO SEGURO (REEMPLAZA A move_and_slide) ---
# =========================================================
func _mover_seguro() -> void:
	if not global_position.is_finite():
		global_position = _ultima_pos_valida
		velocity = Vector3.ZERO
		knockback_velocity = Vector3.ZERO
	else:
		_ultima_pos_valida = global_position

	aplicar_limite_de_velocidad_seguro()
	move_and_slide()

	if not global_position.is_finite():
		global_position = _ultima_pos_valida
		velocity = Vector3.ZERO
		knockback_velocity = Vector3.ZERO
	if not velocity.is_finite():
		velocity = Vector3.ZERO


func aplicar_knockback(dir: Vector3, fuerza: float) -> void:
	if not dir.is_finite():
		knockback_velocity = Vector3.ZERO
		return
	var k = dir * fuerza
	if not k.is_finite():
		knockback_velocity = Vector3.ZERO
		return
	knockback_velocity = k.limit_length(KNOCKBACK_MAXIMO)


func aplicar_limite_de_velocidad_seguro():
	if not is_finite(velocity.y):
		velocity.y = 0.0
	velocity.y = clampf(velocity.y, -60.0, 60.0)
	var horizontal = Vector3(velocity.x, 0, velocity.z)
	if not horizontal.is_finite():
		velocity.x = 0.0
		velocity.z = 0.0
	elif horizontal.length() > VELOCIDAD_HORIZONTAL_MAXIMA:
		horizontal = horizontal.limit_length(VELOCIDAD_HORIZONTAL_MAXIMA)
		velocity.x = horizontal.x
		velocity.z = horizontal.z


func _physics_process(delta):
	# --- GRAVEDAD ---
	if not is_on_floor():
		velocity.y -= 20.0 * delta
	else:
		if velocity.y < 0:
			velocity.y = -0.5

	# --- Objetivo más cercano, cacheado ---
	var ahora_ms = Time.get_ticks_msec()
	if ahora_ms >= _tiempo_proximo_rechequeo_objetivo:
		_tiempo_proximo_rechequeo_objetivo = ahora_ms + INTERVALO_RECHEQUEO_OBJETIVO_MS
		var posibles = obtener_objetivos()
		var mas_cercano = null
		var dist_minima = 9999.0
		for p in posibles:
			if is_instance_valid(p) and "global_position" in p and p.global_position is Vector3:
				if not p.global_position.is_finite(): continue
				var d = global_position.distance_to(p.global_position)
				if d < dist_minima:
					dist_minima = d
					mas_cercano = p
		if mas_cercano:
			player = mas_cercano

	if player == null or !is_instance_valid(player) or not (player.global_position is Vector3):
		player = get_tree().get_first_node_in_group("player")
		return

	# Guarda: knockback roto no se propaga a velocity.
	if not knockback_velocity.is_finite():
		knockback_velocity = Vector3.ZERO

	# Lógica de empuje (Knockback)
	if knockback_velocity.length() > 0.5:
		velocity.x = knockback_velocity.x
		velocity.z = knockback_velocity.z
		knockback_velocity = knockback_velocity.move_toward(Vector3.ZERO, delta * 40)
	elif not is_stunned and not esta_explotando and player:
		var dist = global_position.distance_to(player.global_position)
		if dist < detection_range:
			follow_player(dist)
		else:
			velocity.x = move_toward(velocity.x, 0, speed)
			velocity.z = move_toward(velocity.z, 0, speed)
			sprite.play("idle")
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)

	_mover_seguro()


func follow_player(dist):
	var dir = direccion_segura(global_position, player.global_position)
	if dist > stop_range:
		velocity.x = dir.x * speed
		velocity.z = dir.z * speed
		sprite.play("walk")
		sprite.flip_h = dir.x > 0
	else:
		velocity.x = 0
		velocity.z = 0
		sprite.play("idle")


func take_damage(_amount, source_pos):
	if esta_explotando or esta_muerto: return
	# Mientras la cargan o vuela por el aire no se puede activar
	if siendo_cargado: return

	# Validamos la posición de origen ANTES de usarla.
	if not (source_pos is Vector3) or not source_pos.is_finite():
		source_pos = global_position - Vector3(0, 0, 1)

	esta_explotando = true
	is_stunned = true
	sprite.play("hurt")

	var dir = direccion_segura(source_pos, global_position, Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized())
	dir.y = 0
	aplicar_knockback(dir, 3.5)

	_secuencia_bomba()


func _secuencia_bomba():
	await get_tree().create_timer(0.4).timeout
	if not is_inside_tree(): return

	sprite.play("explotando")
	knockback_velocity = Vector3.ZERO

	await get_tree().create_timer(1.0).timeout
	if not is_inside_tree(): return

	_explotar_con_fuerza_bruta()


func obtener_zona_instructor():
	if not _zona_instructor_buscada:
		_zona_instructor_buscada = true
		_zona_instructor = get_tree().current_scene.find_child("ZonaInstructor", true, false)
	if _zona_instructor and not is_instance_valid(_zona_instructor):
		_zona_instructor = null
	return _zona_instructor


func _explotar_con_fuerza_bruta():
	# --- LÓGICA DE DETECCIÓN DE PARED PARA EL TUTORIAL ---
	var instructor = obtener_zona_instructor()
	var rompio_pared = false

	if instructor and is_instance_valid(instructor):
		if instructor.pared_bomba and is_instance_valid(instructor.pared_bomba):
			var dist_pared = global_position.distance_to(instructor.pared_bomba.global_position)
			if dist_pared <= radio_explosion + 1.2:
				rompio_pared = true
				instructor._on_bomba_exito()

		if not rompio_pared and instructor.etapa == 4:
			instructor._on_bomba_fallida()
			return

	# --- EXPLOSIÓN ---
	esta_muerto = true
	sprite.play("explosion")

	if has_node("SonidoExplosion"):
		$SonidoExplosion.play()

	EfectosManager.play_sound("res://sonidos/explosion.mp3", global_position)
	EfectosManager.impact_effect(1.8, 0.4, global_position, 0)

	if get_tree().current_scene.has_method("registrar_muerte"):
		get_tree().current_scene.registrar_muerte()

	soltar_sangre()

	var origen_explosion = global_position
	if not origen_explosion.is_finite():
		origen_explosion = _ultima_pos_valida

	var objetivos = get_tree().get_nodes_in_group("enemies") \
		+ get_tree().get_nodes_in_group("player") \
		+ get_tree().get_nodes_in_group("allies")

	var objetivos_en_rango: Array = []
	for obj in objetivos:
		if obj == self or !is_instance_valid(obj): continue
		if not ("global_position" in obj) or not obj.global_position.is_finite(): continue
		var d = origen_explosion.distance_to(obj.global_position)
		if d <= radio_explosion:
			objetivos_en_rango.append(obj)

	# Se reparte el daño en tandas de pocos objetivos por frame para que el
	# solver de colisiones nunca reciba muchas velocidades grandes a la vez.
	const OBJETIVOS_POR_TANDA := 4
	var i = 0
	while i < objetivos_en_rango.size():
		var tanda = objetivos_en_rango.slice(i, i + OBJETIVOS_POR_TANDA)
		for obj in tanda:
			if not is_instance_valid(obj): continue
			if obj.has_method("take_damage"):
				if obj.is_in_group("player"):
					var dano_final = damage_explosion
					if obj.get("defensa_ectoplasma") == true:
						dano_final = damage_explosion * 0.3
					obj.take_damage(dano_final, origen_explosion)
				elif obj.is_in_group("allies"):
					obj.take_damage(damage_explosion, origen_explosion)
				else:
					if obj.is_in_group("boss"):
						ProgresoJuego.desbloquear_logro_fisica()
					obj.take_damage(damage_explosion, origen_explosion)
		i += OBJETIVOS_POR_TANDA
		if i < objetivos_en_rango.size():
			await get_tree().physics_frame

	await sprite.animation_finished
	queue_free()


func soltar_sangre():
	var sangre = ESCENA_SANGRE.instantiate()
	get_tree().current_scene.add_child(sangre)
	var pos = global_position
	if not pos.is_finite():
		pos = _ultima_pos_valida
	sangre.global_position = pos + Vector3(0, 0.5, 0)


# ===== MECÁNICA DE AGARRE =====
const RADIO_IMPACTO: float = 1.6
var siendo_cargado: bool = false
var _capa_original: int = 0
var _mascara_original: int = 0
var _tween_vuelo: Tween = null

func puede_ser_agarrado() -> bool:
	return not siendo_cargado and not esta_explotando and not esta_muerto

func ser_agarrado_por(_jugador) -> void:
	siendo_cargado = true
	_capa_original = collision_layer
	_mascara_original = collision_mask
	collision_layer = 0
	collision_mask = 0
	velocity = Vector3.ZERO
	knockback_velocity = Vector3.ZERO
	set_physics_process(false)
	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation("idle"):
		sprite.play("idle")

# Sirve para "soft drop" (dano 0, arco bajo) y para "rude drop" (dano > 0, arco alto)
func ser_lanzado(origen: Vector3, destino: Vector3, desde: Vector3, dano: int, arco: float, duracion: float) -> void:
	global_position = origen
	if _tween_vuelo:
		_tween_vuelo.kill()
	_tween_vuelo = create_tween()
	_tween_vuelo.tween_method(_paso_vuelo.bind(origen, destino, arco), 0.0, 1.0, duracion)
	await _tween_vuelo.finished
	_impacto(destino, desde, dano)

func _paso_vuelo(t: float, origen: Vector3, destino: Vector3, arco: float) -> void:
	var p = origen.lerp(destino, t)
	p.y += sin(t * PI) * arco
	global_position = p

func _impacto(pos: Vector3, desde: Vector3, dano: int) -> void:
	global_position = pos
	if dano > 0:
		EfectosManager.impact_effect(0.5, 0.15, pos, 2)
		for e in get_tree().get_nodes_in_group("enemies"):
			if e == self or not is_instance_valid(e) or not (e is Node3D): continue
			if not e.global_position.is_finite(): continue
			if e.global_position.distance_to(pos) <= RADIO_IMPACTO and e.has_method("take_damage"):
				e.take_damage(dano, desde)
	velocity = Vector3.ZERO
	knockback_velocity = Vector3.ZERO
	# Reactiva colisiones solo cuando no hay nadie encima (evita el NaN por despenetración)
	while is_inside_tree() and not _espacio_libre():
		await get_tree().create_timer(0.1).timeout
	if not is_inside_tree(): return
	collision_layer = _capa_original
	collision_mask = _mascara_original
	siendo_cargado = false
	set_physics_process(true)

func _espacio_libre() -> bool:
	for grupo in ["enemies", "player", "allies"]:
		for n in get_tree().get_nodes_in_group(grupo):
			if n == self or not is_instance_valid(n) or not (n is Node3D): continue
			if not n.global_position.is_finite(): continue
			if Vector2(global_position.x - n.global_position.x, global_position.z - n.global_position.z).length() < radio_espacio_libre:
				return false
	return true
