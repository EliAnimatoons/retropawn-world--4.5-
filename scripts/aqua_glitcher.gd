extends CharacterBody3D

signal ataque_inminente(minion_ref)

@export var speed = 0.5
@export var detection_range = 50.0
@export var stop_range = 3.0
@export var distancia_escape = 1.5

var escena_proyectil = preload("res://LEVEL2/GlitchProject.tscn")
var escena_drop = preload("res://scenes/ItemDrop.tscn")
var ESCENA_SANGRE = preload("res://scenes/SangreMorada.tscn")

var health = 3
var max_health_ref = 3
var knockback_velocity = Vector3.ZERO
var is_stunned = false
var can_attack = true
var esta_muerto = false
var tutorial_congelado = false

var detectado_permanentemente = false
var en_modo_berserker = false
var huyendo_al_lider = false

var tiempo_flote = 0.0

@onready var sprite = $AnimatedSprite3D
@onready var health_bar = $BarraVisual/SubViewport/ProgressBar

var player = null

func _ready():
	add_to_group("enemies")
	max_health_ref = health
	player = get_tree().get_first_node_in_group("player")
	if health_bar:
		health_bar.max_value = health
		health_bar.value = health
	sprite.play("idle")

# FIX: helper para evitar normalizar un Vector3 (0,0,0) o con distancia casi nula
func direccion_segura(desde: Vector3, hacia: Vector3, fallback := Vector3.FORWARD) -> Vector3:
	var diff = hacia - desde
	if diff.length_squared() < 0.0001:
		return fallback
	return diff.normalized()

func _physics_process(delta):
	if tutorial_congelado or esta_muerto:
		velocity = Vector3.ZERO
		return

	# --- TARGET MÁS CERCANO (jugador o mascota) ---
	var posibles = get_tree().get_nodes_in_group("player") + get_tree().get_nodes_in_group("allies")
	var mas_cercano = null
	var dist_minima = 9999.0

	for p in posibles:
		if is_instance_valid(p) and p is Node3D:
			var distancia = global_position.distance_to(p.global_position)
			if distancia < dist_minima:
				dist_minima = distancia
				mas_cercano = p

	if mas_cercano:
		player = mas_cercano

	# Validación estricta por si el grupo "player" devuelve algo raro (como un nodo 2D)
	if player == null or !is_instance_valid(player) or not player is Node3D:
		player = null
		var fallbacks = get_tree().get_nodes_in_group("player")
		for fb in fallbacks:
			if is_instance_valid(fb) and fb is Node3D:
				player = fb
				break
		if player == null:
			return

	comprobar_estado_berserker()

	tiempo_flote += delta * 2.0
	sprite.position.y = sin(tiempo_flote) * 0.15

	if knockback_velocity.length() > 0.1:
		velocity.x = knockback_velocity.x
		velocity.z = knockback_velocity.z
		knockback_velocity = knockback_velocity.move_toward(Vector3.ZERO, delta * 35.0)
	elif not is_stunned and player:
		var dist = global_position.distance_to(player.global_position)
		if health < max_health_ref * 0.35:
			var lider = get_tree().get_first_node_in_group("boss")
			if lider and is_instance_valid(lider) and lider is Node3D:
				huyendo_al_lider = true
				seguir_al_lider(lider)
			else:
				huyendo_al_lider = false
		else:
			huyendo_al_lider = false

		if not huyendo_al_lider:
			if dist < detection_range or detectado_permanentemente:
				detectado_permanentemente = true
				follow_player_smart(dist, delta)
			else:
				velocity.x = move_toward(velocity.x, 0, speed)
				velocity.z = move_toward(velocity.z, 0, speed)
				if not sprite.animation in ["hurt", "attack"]:
					sprite.play("idle")
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)

	velocity.y = 0.0
	evitar_amontonamiento(delta)
	move_and_slide()

func follow_player_smart(dist, delta):
	# FIX: usamos direccion_segura en vez de normalized() directo
	var dir_hacia_jugador = direccion_segura(global_position, player.global_position)
	if dist < distancia_escape:
		velocity.x = -dir_hacia_jugador.x * speed
		velocity.z = -dir_hacia_jugador.z * speed
		sprite.flip_h = dir_hacia_jugador.x < 0
	elif dist <= stop_range:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)
		if can_attack:
			attack_player()
	else:
		velocity.x = dir_hacia_jugador.x * speed
		velocity.z = dir_hacia_jugador.z * speed
		if not sprite.animation in ["hurt", "attack"]:
			sprite.play("idle")
		sprite.flip_h = dir_hacia_jugador.x < 0

func attack_player():
	if not is_inside_tree() or tutorial_congelado or is_stunned: return
	can_attack = false
	is_stunned = true
	sprite.play("attack")
	emit_signal("ataque_inminente", self)

	await get_tree().create_timer(0.4).timeout
	if not is_inside_tree() or esta_muerto: return

	if is_instance_valid(player) and player is Node3D:
		var proj = escena_proyectil.instantiate()
		get_tree().current_scene.add_child(proj)

		var altura_jugador = player.global_position.y + 0.8
		proj.global_position = Vector3(global_position.x, altura_jugador, global_position.z)

		var target_pos = Vector3(player.global_position.x, altura_jugador, player.global_position.z)
		# FIX: usamos direccion_segura en vez de normalized() directo
		proj.direction = direccion_segura(proj.global_position, target_pos)

	await sprite.animation_finished
	if not is_inside_tree() or esta_muerto: return
	if sprite.modulate != Color(5, 5, 0):
		is_stunned = false
		sprite.play("idle")

	await get_tree().create_timer(6.0).timeout
	can_attack = true

func stun_minion(duration):
	if not is_inside_tree(): return
	is_stunned = true
	can_attack = false
	sprite.modulate = Color(5, 5, 0)
	sprite.play("hurt")
	if has_node("/root/EfectosManager"):
		get_node("/root/EfectosManager").parry_success_effect(global_position)
	await get_tree().create_timer(duration).timeout
	if not is_inside_tree() or esta_muerto: return
	sprite.modulate = Color(1, 1, 1)
	is_stunned = false
	can_attack = true
	sprite.play("idle")

func take_damage(amount, source_pos):
	if esta_muerto: return
	health -= amount
	actualizar_barra_vida()
	if health <= 0:
		die()
		return
	if sprite.modulate != Color(5, 5, 0):
		is_stunned = true
		sprite.play("hurt")
		# FIX: usamos direccion_segura en vez de normalized() directo
		var dir = direccion_segura(source_pos, global_position)
		knockback_velocity = Vector3(dir.x, 0, dir.z) * 4.0
		await get_tree().create_timer(0.4).timeout
		if not is_inside_tree() or esta_muerto: return
		if sprite.modulate != Color(5, 5, 0):
			is_stunned = false
			sprite.play("idle")

func actualizar_barra_vida():
	if health_bar:
		health_bar.value = health

func die():
	if esta_muerto: return
	esta_muerto = true
	var manager = get_tree().get_first_node_in_group("combo_manager")
	if manager:
		manager.registrar_muerte()
	sprite.play("hurt")
	ProgresoJuego.monedas_nivel += 1
	ProgresoJuego.total_minions_muertos = int(ProgresoJuego.total_minions_muertos) + 1
	ProgresoJuego.guardar_partida()
	var drop = escena_drop.instantiate()
	get_tree().current_scene.add_child(drop)
	drop.global_position = global_position
	soltar_sangre()
	await get_tree().create_timer(0.2).timeout
	queue_free()

func soltar_sangre():
	var sangre = ESCENA_SANGRE.instantiate()
	get_tree().current_scene.add_child(sangre)
	sangre.global_position = global_position + Vector3(0, 0.5, 0)

func comprobar_estado_berserker():
	if health <= max_health_ref * 0.4 and not en_modo_berserker:
		en_modo_berserker = true
		speed *= 1.5

func seguir_al_lider(lider):
	# FIX: usamos direccion_segura en vez de normalized() directo
	var dir = direccion_segura(global_position, lider.global_position)
	velocity.x = dir.x * speed
	velocity.z = dir.z * speed
	sprite.play("idle")

func evitar_amontonamiento(delta):
	for enemigo in get_tree().get_nodes_in_group("enemies"):
		if enemigo != self and is_instance_valid(enemigo):
			if global_position.distance_to(enemigo.global_position) < 0.8:
				# FIX: usamos direccion_segura en vez de normalized() directo
				var dir_escape = direccion_segura(enemigo.global_position, global_position)
				velocity.x += dir_escape.x * 0.4
				velocity.z += dir_escape.z * 0.4

func _on_animated_sprite_3d_animation_finished():
	if esta_muerto or is_stunned: return
	sprite.play("idle")
