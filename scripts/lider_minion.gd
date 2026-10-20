extends CharacterBody3D

@export var max_health = 500.0
@export var speed = 1.2
@export var escape_speed = 0.6 
@export var heal_amount = 10
@export var spawn_cooldown = 10.0

@export var distancia_segura = 5.0 
@export var distancia_limite = 3.0 
@export var limite_minions = 15

var health = 500.0
var esta_muerto = false
var is_stunned = false
var tiempo_invocacion = 0.0
var tiempo_curacion = 0.0 

# --- VARIABLES DE ESCENAS ---
@export var escena_minion : PackedScene 
var escena_drop = preload("res://scenes/ItemDrop.tscn")

@onready var sprite = $AnimatedSprite3D
@onready var health_bar = $BarraVisual/SubViewport/ProgressBar
@onready var aura_curacion = $AuraCuracion 
@onready var sfx_calling = $callingminions

var player = null

func _ready():
	if not escena_minion:
		escena_minion = load("res://scenes/minion.tscn")
	
	add_to_group("enemies") 
	add_to_group("boss")
	health = max_health
	player = get_tree().get_first_node_in_group("player")
	
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = health
	
	if has_node("/root/EfectosManager"):
		EfectosManager.play_sound("res://sonidos/boss_spawn.mp3", global_position)
	
	sprite.play("idle")

func _physics_process(delta):
	if esta_muerto: return

	tiempo_curacion += delta
	if tiempo_curacion >= 1.0:
		curar_minions_cercanos()
		tiempo_curacion = 0.0

	if not is_stunned:
		tiempo_invocacion += delta
		if tiempo_invocacion >= spawn_cooldown:
			invocar_refuerzos()
		
		if player and is_instance_valid(player):
			var dist = global_position.distance_to(player.global_position)
			var dir = (player.global_position - global_position).normalized()
			
			sprite.flip_h = dir.x < 0
			
			if not sprite.animation in ["calling", "attack", "hurt"]:
				if dist > distancia_segura:
					velocity.x = dir.x * speed
					velocity.z = dir.z * speed
					sprite.play("walk")
				elif dist < distancia_limite:
					velocity.x = -dir.x * escape_speed
					velocity.z = -dir.z * escape_speed
					sprite.play("walk")
				else:
					velocity.x = move_toward(velocity.x, 0, speed)
					velocity.z = move_toward(velocity.z, 0, speed)
					sprite.play("idle")
	
	if not is_on_floor():
		velocity.y -= 20.0 * delta

	move_and_slide()

func curar_minions_cercanos():
	for minion in get_tree().get_nodes_in_group("enemies"):
		if minion != self and is_instance_valid(minion):
			if global_position.distance_to(minion.global_position) < 7.0:
				if minion.has_method("heal"):
					minion.heal(heal_amount)

# --- Busca una posición válida en el navmesh, separada de otros enemigos ---
func buscar_posicion_spawn(mapa_nav: RID, intentos: int = 10) -> Vector3:
	var separacion_minima = 1.2  # distancia mínima entre spawns
	
	for _i in range(intentos):
		var angulo = randf() * TAU
		var radio = randf_range(2.0, 4.5)
		var offset = Vector3(cos(angulo) * radio, 0, sin(angulo) * radio)
		var pos_intento = global_position + offset
		var pos_legal = NavigationServer3D.map_get_closest_point(mapa_nav, pos_intento)
		
		# Validar que la posición no sea infinita ni NaN
		if not pos_legal.is_finite():
			continue
		# Validar que está cerca del suelo (no voló lejos del navmesh)
		if pos_legal.distance_to(pos_intento) > 3.0:
			continue
		
		# Validar separación con enemigos ya existentes
		var muy_cerca = false
		for ene in get_tree().get_nodes_in_group("enemies"):
			if ene != self and is_instance_valid(ene):
				if pos_legal.distance_to(ene.global_position) < separacion_minima:
					muy_cerca = true
					break
		
		if not muy_cerca:
			return pos_legal
	
	# Si no encontró posición libre en todos los intentos, devuelve Vector3.INF
	# para que el llamador lo detecte y cancele el spawn
	return Vector3.INF

func invocar_refuerzos():
	var minions_cerca = 0
	for ene in get_tree().get_nodes_in_group("enemies"):
		if ene != self and global_position.distance_to(ene.global_position) < 10.0:
			minions_cerca += 1
	
	if minions_cerca >= 6:
		tiempo_invocacion = 0.0
		return

	is_stunned = true
	velocity = Vector3.ZERO
	tiempo_invocacion = 0.0
	
	if sfx_calling and sfx_calling.stream: sfx_calling.play()
	if sprite.sprite_frames.has_animation("calling"):
		sprite.play("calling")
	else:
		sprite.play("attack")

	await get_tree().create_timer(1.5).timeout
	if esta_muerto: return

	var mapa_nav = get_world_3d().get_navigation_map()

	for i in range(2):
		if not escena_minion: continue
		
		var pos = buscar_posicion_spawn(mapa_nav)
		
		# Si no encontró lugar libre, cancelamos este spawn
		if not pos.is_finite():
			continue
		
		var m = escena_minion.instantiate()
		get_tree().current_scene.add_child(m)
		m.global_position = pos + Vector3(0, 0.2, 0)
		
		if m.has_node("AnimatedSprite3D"):
			var sm = m.get_node("AnimatedSprite3D")
			if sm.sprite_frames.has_animation("grow"): sm.play("grow")

	await get_tree().create_timer(0.5).timeout
	if not esta_muerto:
		is_stunned = false
		sprite.play("idle")

func take_damage(amount, _source_pos):
	if esta_muerto: return
	health -= amount
	if health_bar: health_bar.value = health
	
	if health <= 0:
		die()
		return
	
	if sprite.animation != "calling":
		is_stunned = true
		sprite.play("hurt")
		await get_tree().create_timer(0.3).timeout
		if not esta_muerto and sprite.animation != "calling":
			is_stunned = false
			sprite.play("idle")

func die():
	if esta_muerto: return
	esta_muerto = true
	var manager = get_tree().get_first_node_in_group("combo_manager")
	if manager:
		manager.registrar_muerte()
	set_physics_process(false)
	collision_layer = 0
	collision_mask = 0
	sprite.play("hurt")
	
	var mapa_nav = get_world_3d().get_navigation_map()

	for e in get_tree().get_nodes_in_group("enemies"):
		if e != self and global_position.distance_to(e.global_position) < 15:
			if e.has_method("die"): e.die()

	if escena_drop:
		for i in range(4):
			var d = escena_drop.instantiate()
			get_tree().current_scene.add_child(d)
			var pos_drop = global_position + Vector3(randf_range(-1.5, 1.5), 0, randf_range(-1.5, 1.5))
			var pos_legal_drop = NavigationServer3D.map_get_closest_point(mapa_nav, pos_drop)
			# Validar antes de usar
			if pos_legal_drop.is_finite():
				d.global_position = pos_legal_drop + Vector3(0, 0.1, 0)
			else:
				d.global_position = global_position + Vector3(0, 0.1, 0)
			var suerte = randf() * 100
			if suerte < 40: d.tipo_actual = 0 
			elif suerte < 80: d.tipo_actual = 1
			if d.has_method("actualizar_item"): d.actualizar_item()

	ProgresoJuego.lider_derrotado = true
	ProgresoJuego.guardar_partida()
	await get_tree().create_timer(1.0).timeout
	queue_free()
