extends CharacterBody3D

@export var detection_range = 8.0
@export var velocidad_embestida = 15.0  # Velocidad del deslizamiento rápido
@export var daño_ataque = 15.0
@export var tiempo_recarga_ataque = 4.0  # Segundos para volver a atacar

var health = 2
var max_health = 2
var knockback_velocity = Vector3.ZERO

# Estados del enemigo
var is_stunned = false
var can_attack = true
var esta_muerto = false
var preparando_ataque = false

var player = null
var direccion_ataque = Vector3.ZERO

@onready var sprite = $AnimatedSprite3D
@onready var health_bar = $BarraVisual/SubViewport/ProgressBar

func _ready():
	add_to_group("enemies")
	player = get_tree().get_first_node_in_group("player")
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = health

func _physics_process(delta):
	if esta_muerto: return

	# 1. Manejo de Impactos (Knockback) si recibe daño
	if knockback_velocity.length() > 0.1:
		velocity = knockback_velocity
		knockback_velocity = knockback_velocity.move_toward(Vector3.ZERO, delta * 30.0)
		move_and_slide()
		return

	# Si está haciendo la animación de "hurt" o preparando el salto, frena su movimiento normal
	if is_stunned:
		move_and_slide()
		return

	if preparando_ataque:
		# Durante la embestida se mueve en la dirección fija que calculó
		velocity = direccion_ataque * velocidad_embestida
		move_and_slide()
		# Detectar si chocó contra el jugador durante el deslizamiento
		chequear_colision_ataque()
		return

	# Buscar al jugador si no existe la referencia
	if player == null or !is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")
		sprite.play("idle")
		return

	# 2. Lógica de detección y ataque
	var dist = global_position.distance_to(player.global_position)
	
	if dist < detection_range and can_attack:
		iniciar_secuencia_ataque()
	else:
		velocity = Vector3.ZERO
		sprite.play("idle")
		
	move_and_slide()

func iniciar_secuencia_ataque():
	can_attack = false
	is_stunned = true  # Bloquea el movimiento normal mientras avisa
	
	# --- FASE 1: AVISO (Retroceder y Parpadear) ---
	var dir_hacia_jugador = (player.global_position - global_position).normalized()
	dir_hacia_jugador.y = 0 # Mantenerlo en el plano del suelo
	
	# Girar el sprite hacia el jugador
	sprite.flip_h = dir_hacia_jugador.x > 0
	
	# Retrocede un poco como un toro antes de embestir
	velocity = -dir_hacia_jugador * 2.0 
	
	# Parpadeo rápido en rojo (3 ciclos de 0.1s)
	for i in range(3):
		sprite.modulate = Color(10, 0, 0) # Rojo intenso (Glow si tenés WorldEnvironment)
		await get_tree().create_timer(0.1).timeout
		sprite.modulate = Color(1, 1, 1)
		await get_tree().create_timer(0.1).timeout

	if esta_muerto: return

	# --- FASE 2: EL DESLIZAMIENTO (Ataque) ---
	sprite.play("attack")
	# Guardamos la dirección exacta de donde ESTABA el jugador para ir directo ahí
	direccion_ataque = (player.global_position - global_position).normalized()
	direccion_ataque.y = 0
	
	preparando_ataque = true
	is_stunned = false

	# Duración del deslizamiento rápido (0.4 segundos de dash)
	await get_tree().create_timer(0.4).timeout
	
	# --- FASE 3: FIN DEL DESLIZAMIENTO ---
	preparando_ataque = false
	velocity = Vector3.ZERO
	sprite.play("idle")
	
	# --- FASE 4: COOLDOWN (Espera de 4 segundos) ---
	await get_tree().create_timer(tiempo_recarga_ataque).timeout
	can_attack = true

func chequear_colision_ataque():
	# Si pasa cerca del jugador mientras se desliza, le mete el golpe
	if player and global_position.distance_to(player.global_position) < 1.3:
		if player.has_method("take_damage"):
			player.take_damage(daño_ataque, global_position)
			# Frenamos el ataque para que no le pegue múltiples veces en el mismo dash
			preparando_ataque = false 
			velocity = Vector3.ZERO

func take_damage(amount, source_pos):
	if esta_muerto: return
	
	# Como se muere de dos golpes, restamos 1 siempre o el amount que pases
	health -= 1 
	if health_bar: health_bar.value = health
	
	if health <= 0:
		die()
		return

	# Interrumpe cualquier ataque si le pegan
	preparando_ataque = false
	is_stunned = true
	sprite.modulate = Color(1, 1, 1) # Reset color por si estaba parpadeando
	sprite.play("hurt")
	
	# Empujón por el golpe
	var dir = (global_position - source_pos).normalized()
	knockback_velocity = Vector3(dir.x, 0, dir.z) * 4.0

func die():
	if esta_muerto: return
	esta_muerto = true
	is_stunned = true
	preparando_ataque = false
	sprite.play("hurt")
	
	# Animación rápida de muerte/desaparición
	await get_tree().create_timer(0.2).timeout
	queue_free()

# Resetear estados cuando terminen las animaciones mecánicas
func _on_animated_sprite_3d_animation_finished():
	if sprite.animation == "hurt" and not esta_muerto:
		is_stunned = false
		sprite.play("idle")
