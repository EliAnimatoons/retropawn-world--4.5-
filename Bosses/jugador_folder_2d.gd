extends CharacterBody2D

# --- CONFIGURACIÓN ---
@export var speed: float = 250.0
@export var parry_duration: float = 0.25 # Ventana de tiempo activa del Parry en segundos
@export var parry_cooldown: float = 0.6  # Cooldown si se falla el parry
@export var max_health: float = 100.0
var health: float = 100.0

# --- ESTADOS ---
var is_parrying: bool = false
var can_parry: bool = true
var parry_exitoso: bool = false
var is_grabbed: bool = false
var is_victorious: bool = false
var is_dead: bool = false
var puede_moverse: bool = true

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D

signal parry_realizado
signal vida_cambiada(nueva_vida: float, vida_maxima: float)

func _ready():
	add_to_group("player2d")
	health = max_health
	emit_signal("vida_cambiada", health, max_health)

func _physics_process(_delta):
	if is_grabbed or is_victorious or is_dead or not puede_moverse:
		velocity = Vector2.ZERO
		return

	# 1. MOVIMIENTO EN 8 DIRECCIONES
	var input_dir = Input.get_vector("izquierda", "derecha", "arriba", "abajo")
	velocity = input_dir * speed
	move_and_slide()

	# 2. MANEJO DE ANIMACIONES DE MOVIMIENTO Y PARRY
	if not is_parrying:
		if velocity.length() > 0:
			if anim.sprite_frames and anim.sprite_frames.has_animation("walk"):
				anim.play("walk")
			else:
				anim.play("idle")
		else:
			anim.play("idle")

	# 3. ACCIÓN DE PARRY
	if Input.is_action_just_pressed("parry") and can_parry and not is_parrying:
		_ejecutar_parry()

func _ejecutar_parry():
	is_parrying = true
	can_parry = false
	parry_exitoso = false
	
	if anim.sprite_frames and anim.sprite_frames.has_animation("parry"):
		anim.play("parry")
	
	# Sonido de intento/viento de parry
	EfectosManager.play_sound("viento", Vector3(global_position.x, global_position.y, 0), true, -2.0)
	
	emit_signal("parry_realizado")

	# Buscar proyectiles enemigos cercanos para parrear inmediatamente
	if _detectar_y_parrear_proyectiles_cercanos():
		notificar_parry_exitoso()

	# Ventana de parry activo con interrupción instantánea si acierta
	var timer = 0.0
	while timer < parry_duration:
		await get_tree().process_frame
		timer += get_process_delta_time()
		if parry_exitoso:
			break

	is_parrying = false

	if parry_exitoso:
		# ¡Acierto! Se recarga automáticamente el parry sin esperar cooldown
		can_parry = true
	else:
		# Fallo: Espera el cooldown completo
		var tiempo_espera = max(0.0, parry_cooldown - parry_duration)
		await get_tree().create_timer(tiempo_espera).timeout
		can_parry = true

func _detectar_y_parrear_proyectiles_cercanos() -> bool:
	var hubo_acierto = false
	var proyectiles = get_tree().get_nodes_in_group("proyectil_enemigo")
	for proyectil in proyectiles:
		if is_instance_valid(proyectil):
			var distancia = global_position.distance_to(proyectil.global_position)
			if distancia <= 75.0: # Radio de parry en píxeles
				if proyectil.has_method("parrear"):
					proyectil.parrear()
					hubo_acierto = true
	return hubo_acierto

func notificar_parry_exitoso():
	parry_exitoso = true
	can_parry = true

func esta_parreando() -> bool:
	return is_parrying

func recibir_dano(cantidad: float = 1.0):
	if is_parrying or is_victorious or is_dead:
		return
		
	health = max(0.0, health - cantidad)
	emit_signal("vida_cambiada", health, max_health)
	
	EfectosManager.play_sound("hurt", Vector3(global_position.x, global_position.y, 0), true, 2.0)
	EfectosManager.impact_effect(0.2, 0.04, Vector3(global_position.x, global_position.y, 0), 1)
	
	var tw = create_tween()
	tw.tween_property(anim, "modulate", Color.RED, 0.1)
	tw.tween_property(anim, "modulate", Color.WHITE, 0.1)
	
	if health <= 0:
		_morir()
		return

	if anim.sprite_frames and anim.sprite_frames.has_animation("hurt"):
		anim.play("hurt")
		
	set_physics_process(false)
	await get_tree().create_timer(0.25).timeout
	if not is_dead:
		set_physics_process(true)

func _morir():
	is_dead = true
	if anim.sprite_frames and anim.sprite_frames.has_animation("muerto"):
		anim.play("muerto")
	elif anim.sprite_frames and anim.sprite_frames.has_animation("hurt"):
		anim.play("hurt")

func set_grabbed(estado: bool):
	is_grabbed = estado
	if is_grabbed:
		if anim.sprite_frames and anim.sprite_frames.has_animation("grabbed_struggle"):
			anim.play("grabbed_struggle")
		elif anim.sprite_frames and anim.sprite_frames.has_animation("hurt"):
			anim.play("hurt")

func celebrar_victoria():
	is_victorious = true
	if anim.sprite_frames and anim.sprite_frames.has_animation("victoria"):
		anim.play("victoria")


# --- AGREGAR AL FINAL DEL SCRIPT JUGADOR2D ---
func revivir():
	health = max_health
	is_dead = false
	is_grabbed = false
	is_parrying = false
	is_victorious = false
	can_parry = true
	puede_moverse = true
	
	set_physics_process(true)
	
	if anim.sprite_frames and anim.sprite_frames.has_animation("idle"):
		anim.play("idle")
		
	# Actualizamos la UI
	emit_signal("vida_cambiada", health, max_health)
