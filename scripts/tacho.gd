extends CharacterBody3D

var knockback_velocity = Vector3.ZERO
@onready var sprite = $AnimatedSprite3D

@export_group("Lanzamiento")
## true = vuela en línea recta (tacho). false = tiro parabólico (bomba)
@export var lanzamiento_recto: bool = true
## Daño normal del tacho al pegarle a un enemigo
@export var dano_impacto: int = 3
## Probabilidad de crítico (0.0 = nunca, 1.0 = siempre). 0.2 = 20%
@export_range(0.0, 1.0, 0.01) var probabilidad_critico: float = 0.2
## Daño mínimo y máximo cuando sale crítico
@export var dano_critico_min: int = 6
@export var dano_critico_max: int = 7
@export var velocidad_vuelo: float = 14.0
@export var distancia_maxima_vuelo: float = 5.0
## Qué tan ancho es el "golpe" del tacho en vuelo (en X/Z)
@export var radio_golpe_vuelo: float = 0.6
## Distancia que rebota hacia atrás después de pegarle a un enemigo
@export var rebote_al_golpear: float = 0.9
## Radio que debe estar libre para reactivar colisiones
@export var radio_espacio_libre: float = 0.55

func _ready():
	add_to_group("agarrable")

func _physics_process(delta):
	if knockback_velocity.length() > 0.1:
		velocity = knockback_velocity
		knockback_velocity = knockback_velocity.move_toward(Vector3.ZERO, delta * 25.0)
	else:
		velocity = Vector3.ZERO
	move_and_slide()

func take_damage(_amount, source_pos):
	sprite.modulate = Color(3, 3, 3)
	await get_tree().create_timer(0.1).timeout
	sprite.modulate = Color(1, 1, 1)

	var diff = global_position - source_pos
	diff.y = 0
	var dir = diff.normalized() if diff.length_squared() > 0.0001 else Vector3.FORWARD
	knockback_velocity = dir * 5.0

# ===== MECÁNICA DE AGARRE =====
const RADIO_IMPACTO: float = 1.6
var siendo_cargado: bool = false
var _capa_original: int = 0
var _mascara_original: int = 0
var _tween_vuelo: Tween = null

func puede_ser_agarrado() -> bool:
	return not siendo_cargado

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

# --- SOFT DROP (arco bajo, sin daño) ---
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
	_terminar_vuelo()

# --- RUDE DROP: tiro RECTO, sin autoapuntado ---
func ser_lanzado_recto(origen: Vector3, dir_x: float, desde: Vector3, suelo_y: float) -> void:
	if _tween_vuelo:
		_tween_vuelo.kill()
	global_position = origen
	var dir = Vector3(1.0 if dir_x >= 0 else -1.0, 0, 0)
	var recorrido := 0.0
	var golpeado: Node3D = null
	while recorrido < distancia_maxima_vuelo and golpeado == null:
		await get_tree().physics_frame
		if not is_inside_tree(): return
		var paso = velocidad_vuelo * get_physics_process_delta_time()
		global_position += dir * paso
		recorrido += paso
		golpeado = _buscar_golpeado_en_vuelo()
	_impacto_recto(golpeado, dir, desde, suelo_y)

func _buscar_golpeado_en_vuelo() -> Node3D:
	for e in get_tree().get_nodes_in_group("enemies"):
		if e == self or not is_instance_valid(e) or not (e is Node3D): continue
		if not e.global_position.is_finite(): continue
		if e.get("esta_muerto") == true: continue
		if _dist_h(global_position, e.global_position) <= radio_golpe_vuelo:
			return e
	return null

# Devuelve el daño del golpe y si fue crítico
func _calcular_dano() -> Dictionary:
	var es_critico = randf() < probabilidad_critico
	var dano = dano_impacto
	if es_critico:
		dano = randi_range(mini(dano_critico_min, dano_critico_max), maxi(dano_critico_min, dano_critico_max))
	return {"dano": dano, "critico": es_critico}

func _impacto_recto(golpeado: Node3D, dir: Vector3, desde: Vector3, suelo_y: float) -> void:
	var pos = global_position
	if golpeado and is_instance_valid(golpeado) and golpeado.has_method("take_damage"):
		var resultado = _calcular_dano()
		# Si es crítico el golpe se siente más fuerte (más sacudida de cámara)
		var shake = 0.9 if resultado["critico"] else 0.5
		EfectosManager.impact_effect(shake, 0.15, golpeado.global_position, 3 if resultado["critico"] else 2)
		golpeado.take_damage(resultado["dano"], desde)
		pos = global_position - dir * rebote_al_golpear  # rebota hacia atrás, no queda adentro del enemigo
	pos.y = suelo_y
	_tween_vuelo = create_tween()
	_tween_vuelo.tween_property(self, "global_position", pos, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await _tween_vuelo.finished
	_terminar_vuelo()

# --- Reactivar colisiones SOLO cuando no hay nadie encima ---
func _terminar_vuelo() -> void:
	velocity = Vector3.ZERO
	knockback_velocity = Vector3.ZERO
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
			if _dist_h(global_position, n.global_position) < radio_espacio_libre:
				return false
	return true

func _dist_h(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
