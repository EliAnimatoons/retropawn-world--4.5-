extends CharacterBody3D

signal ataque_inminente(minion_ref)

@export var speed = 1.8
@export var detection_range = 6.0
@export var stop_range = 1.1

var escena_drop = preload("res://scenes/ItemDrop.tscn")
var ESCENA_SANGRE = preload("res://scenes/SangreMorada.tscn")

var health = 100
var max_health_ref = 100
var knockback_velocity = Vector3.ZERO
var is_stunned = false
var can_attack = true
var esta_muerto = false
var tutorial_congelado = false

var modo_huida = false
var tiempo_proxima_esquiva = 0.0

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
	sprite.modulate = Color(0.8, 0.5, 1.0)

func _physics_process(delta):
	if tutorial_congelado:
		velocity = Vector3.ZERO
		return

	# --- TARGET MÁS CERCANO (Solo nodos 3D válidos) ---
	var posibles = get_tree().get_nodes_in_group("player") + get_tree().get_nodes_in_group("allies")
	var mas_cercano = null
	var dist_minima = 9999.0

	for p in posibles:
		# Validamos que exista Y que su global_position sea un Vector3 (ignora el 2D)
		if is_instance_valid(p) and "global_position" in p and p.global_position is Vector3:
			var d = global_position.distance_to(p.global_position)
			if d < dist_minima:
				dist_minima = d
				mas_cercano = p

	if mas_cercano:
		player = mas_cercano

	if player == null or !is_instance_valid(player) or not (player.global_position is Vector3):
		player = get_tree().get_first_node_in_group("player")
		return

	# --- FIX FÍSICAS DE IMPACTO ---
	if knockback_velocity.length() > 0.1:
		velocity = knockback_velocity
		var friccion_actual = 50.0 if is_on_floor() else 5.0
		if not is_on_floor():
			knockback_velocity.y -= 25.0 * delta
		knockback_velocity = knockback_velocity.move_toward(Vector3.ZERO, delta * friccion_actual)

	elif not is_stunned and player:
		var dist = global_position.distance_to(player.global_position)

		if dist < 1.6 and not can_attack and Time.get_ticks_msec() > tiempo_proxima_esquiva:
			intentar_esquiva_tactica()

		if dist < detection_range:
			control_movimiento_tactico(dist)
		else:
			velocity = velocity.move_toward(Vector3.ZERO, speed)
			sprite.play("idle")
	else:
		velocity = velocity.move_toward(Vector3.ZERO, speed)

	evitar_amontonamiento(delta)
	move_and_slide()

func evitar_amontonamiento(_delta):
	for enemigo in get_tree().get_nodes_in_group("enemies"):
		if enemigo != self and is_instance_valid(enemigo):
			var dist_enemigo = global_position.distance_to(enemigo.global_position)
			if dist_enemigo < 0.8:
				# FIX: usamos Utils.direccion_segura en vez de normalized() directo
				var dir_escape = Utils.direccion_segura(enemigo.global_position, global_position)
				velocity.x += dir_escape.x * 0.4
				velocity.z += dir_escape.z * 0.4

func intentar_esquiva_tactica():
	if randf() < 0.7:
		# FIX: usamos Utils.direccion_segura antes de rotar
		var dir_esquiva = Utils.direccion_segura(player.global_position, global_position).rotated(Vector3.UP, randf_range(-PI/2, PI/2))
		knockback_velocity = dir_esquiva * 6.0
		sprite.play("hurt")
	tiempo_proxima_esquiva = Time.get_ticks_msec() + 1500

func control_movimiento_tactico(dist):
	# FIX: usamos Utils.direccion_segura en vez de normalized() directo
	var dir = Utils.direccion_segura(global_position, player.global_position)

	if modo_huida:
		velocity.x = -dir.x * (speed * 1.4)
		velocity.z = -dir.z * (speed * 1.4)
		sprite.play("walk")
		sprite.flip_h = dir.x < 0
		if dist > 3.8: modo_huida = false
		return

	if dist > stop_range:
		velocity.x = dir.x * speed
		velocity.z = dir.z * speed
		sprite.play("walk")
		sprite.flip_h = dir.x > 0
	elif can_attack:
		velocity = Vector3.ZERO
		attack_player()

func attack_player():
	if not is_inside_tree() or tutorial_congelado or is_stunned: return
	is_stunned = true
	can_attack = false
	sprite.play("attack")
	emit_signal("ataque_inminente", self)

	await get_tree().create_timer(0.5).timeout
	if not is_inside_tree() or esta_muerto: return

	if player and global_position.distance_to(player.global_position) < 1.5:
		if player.get("is_parrying"):
			EstadisticasNivel.registrar_parry()   # cuenta el parry para el score
			stun_minion(2.5)
			take_damage(5, global_position)
		else:
			var dano = 5
			if player.get("defensa_ectoplasma") == true: dano = 1
			player.take_damage(dano, global_position)
			aplicar_veneno_al_jugador(player)

	await get_tree().create_timer(0.4).timeout
	if not is_inside_tree() or esta_muerto: return

	if not sprite.modulate == Color(2, 2, 0):
		is_stunned = false
		modo_huida = true

	await get_tree().create_timer(2.0).timeout
	can_attack = true

func aplicar_veneno_al_jugador(p):
	if p.get("character_name") in ["Forerat", "Prepucin"] or p.get("defensa_ectoplasma"): return
	if p.get("envenenado"): return
	p.set("envenenado", true)

	# Cambiar color de forma segura según la estructura del personaje
	_cambiar_color_jugador(p, Color(0.2, 1.0, 0.2))

	for i in range(4):
		await get_tree().create_timer(0.5).timeout
		if is_instance_valid(p): p.take_damage(2, global_position)

	if is_instance_valid(p):
		_cambiar_color_jugador(p, Color(1, 1, 1))
		p.set("envenenado", false)

func _cambiar_color_jugador(p, color: Color):
	if p.has_method("set_model_color"):
		p.set_model_color(color)
	elif "sprite" in p and p.sprite != null:
		p.sprite.modulate = color
	elif p.has_node("AnimatedSprite3D"):
		p.get_node("AnimatedSprite3D").modulate = color

func stun_minion(duration):
	if not is_inside_tree(): return
	knockback_velocity = Vector3.ZERO
	velocity = Vector3.ZERO
	is_stunned = true
	modo_huida = false
	if has_node("SonidoParry"): $SonidoParry.play()
	sprite.modulate = Color(2, 2, 0)
	sprite.play("hurt")

	await get_tree().create_timer(duration).timeout
	if not is_inside_tree() or esta_muerto: return

	sprite.modulate = Color(0.8, 0.5, 1.0)
	is_stunned = false
	sprite.play("idle")

func take_damage(amount, source_pos):
	if esta_muerto: return
	health -= amount
	actualizar_barra_vida()
	if health <= 0:
		die()
		return

	is_stunned = true
	sprite.play("hurt")
	# FIX: usamos Utils.direccion_segura en vez de normalized() directo
	var dir = Utils.direccion_segura(source_pos, global_position)
	knockback_velocity = Vector3(dir.x, 0, dir.z) * 3.0

func actualizar_barra_vida():
	if health_bar:
		health_bar.value = health
		var porcentaje = float(health) / float(max_health_ref)
		if porcentaje > 0.6: health_bar.modulate = Color.GREEN
		elif porcentaje > 0.3: health_bar.modulate = Color.ORANGE
		else: health_bar.modulate = Color.RED

func die():
	if esta_muerto: return
	esta_muerto = true
	var manager = get_tree().get_first_node_in_group("combo_manager")
	if manager:
		manager.registrar_muerte()
	is_stunned = true
	sprite.play("hurt")
	ProgresoJuego.monedas_nivel += 1
	ProgresoJuego.total_minions_muertos = int(ProgresoJuego.total_minions_muertos) + 1   # cuenta la kill para el score
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
		drop.tipo_actual = 0 if suerte < 40 else 1
		if drop.has_method("actualizar_item"):
			drop.actualizar_item()

func soltar_sangre():
	var sangre = ESCENA_SANGRE.instantiate()
	get_tree().current_scene.add_child(sangre)
	sangre.global_position = global_position + Vector3(0, 0.5, 0)

func _on_animated_sprite_3d_animation_finished():
	if sprite.animation in ["hurt", "attack", "parry"]:
		if health > 0 and not sprite.modulate == Color(2, 2, 0):
			is_stunned = false
			sprite.play("idle")
