# npc_atrapaditas.gd
extends CharacterBody3D

@export var velocidad: float = 3.8
var direccion_actual: Vector3 = Vector3.ZERO
var tiempo_cambio_dir: float = 0.0
var tiempo_atascado: float = 0.0
var ultima_posicion: Vector3 = Vector3.ZERO

func _ready():
	add_to_group("npcs")
	ultima_posicion = global_position
	# Nos aseguramos de que el NPC esté listo para procesar física
	set_physics_process(true)

func _physics_process(_delta):
	# Si están aturdidos o tocados, aseguramos que reproduzcan su animación correspondiente
	pass

func mover_hacia(destino: Vector3, delta: float, limites: Array):
	var dir = (destino - global_position)
	dir.y = 0
	
	if dir.length() < 0.1:
		velocity = Vector3.ZERO
		move_and_slide()
		reproducir_animacion("run")
		return
		
	dir = dir.normalized()
	_comprobar_atascamiento(dir, delta)
	
	velocity = dir * velocidad
	
	global_position.x = clamp(global_position.x, limites[0], limites[1])
	global_position.z = clamp(global_position.z, limites[2], limites[3])
	
	move_and_slide()
	
	if abs(dir.x) > 0.05:
		_orientar_sprite(dir.x < 0)
		
	reproducir_animacion("run")

func mover_aleatorio(delta: float, limites: Array):
	if Time.get_ticks_msec() > tiempo_cambio_dir or direccion_actual == Vector3.ZERO:
		direccion_actual = Vector3(randf_range(-1.0, 1.0), 0, randf_range(-1.0, 1.0)).normalized()
		tiempo_cambio_dir = Time.get_ticks_msec() + randi_range(1500, 3500)

	var pos_futura = global_position + direccion_actual * velocidad * delta
	
	if pos_futura.x <= limites[0] or pos_futura.x >= limites[1]:
		direccion_actual.x *= -1.0
	if pos_futura.z <= limites[2] or pos_futura.z >= limites[3]:
		direccion_actual.z *= -1.0

	_comprobar_atascamiento(direccion_actual, delta)
	
	velocity = direccion_actual * velocidad
	global_position.x = clamp(global_position.x, limites[0], limites[1])
	global_position.z = clamp(global_position.z, limites[2], limites[3])
	
	move_and_slide()
	
	if abs(direccion_actual.x) > 0.05:
		_orientar_sprite(direccion_actual.x < 0)
		
	reproducir_animacion("run")

func _comprobar_atascamiento(dir_deseada: Vector3, delta: float):
	if global_position.distance_to(ultima_posicion) < 0.02:
		tiempo_atascado += delta
		if tiempo_atascado > 0.5:
			direccion_actual = Vector3(-dir_deseada.z, 0, dir_deseada.x).normalized()
			if direccion_actual == Vector3.ZERO:
				direccion_actual = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized()
			tiempo_cambio_dir = Time.get_ticks_msec() + 1000
			tiempo_atascado = 0.0
	else:
		tiempo_atascado = 0.0
		
	ultima_posicion = global_position

func _orientar_sprite(flip: bool):
	var spr = find_child("AnimatedSprite3D", true, false)
	if spr and spr is AnimatedSprite3D:
		spr.flip_h = flip

func reproducir_animacion(anim_nombre: String):
	var spr = find_child("AnimatedSprite3D", true, false)
	if spr and spr is AnimatedSprite3D:
		var nombre_final = anim_nombre
		if anim_nombre == "hurted" and not spr.sprite_frames.has_animation("hurted"):
			if spr.sprite_frames.has_animation("hurt"):
				nombre_final = "hurt"

		if spr.sprite_frames and spr.sprite_frames.has_animation(nombre_final):
			if spr.animation != nombre_final:
				spr.play(nombre_final)
