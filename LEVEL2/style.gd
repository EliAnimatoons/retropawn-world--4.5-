extends CharacterBody3D

@export var speed = 4.5
@export var follow_distance = 1.0
@export var stop_range = 0.6
@export var max_distance_to_owner = 6.0

@export var boredom_time = 5.0
@export var wander_radius = 4.0

var player = null
var target_enemy = null

var can_attack = true
var combo_step = 1
var is_acting = false

@onready var sprite = $AnimatedSprite3D

@onready var snd_punch = $SndPunch
@onready var snd_walk  = $SndWalk
@onready var snd_hurt  = $SndHurt
@onready var snd_parry = $SndParry

@onready var voice_jane   = $VoiceJane
@onready var voice_normal = $VoiceNormal
@onready var voice_hurt   = $VoiceHurt
@onready var voice_attack = $VoiceAttack
@onready var voice_parry  = $VoiceParry

var ya_salude = false
var _paso_timer = 0.0
var _paso_intervalo = 0.35

# BOREDOM
enum NPCState { FOLLOWING, WAITING, BORED, RETURNING }
var npc_state = NPCState.FOLLOWING
var _boredom_timer = 0.0
var _player_last_pos = Vector3.ZERO
var _wander_target = Vector3.ZERO
var _wander_timer = 0.0
var _wander_interval = 3.0

func _ready():
	add_to_group("allies")
	call_deferred("_configurar_jugador_seguro")
	npc_state = NPCState.FOLLOWING
	_boredom_timer = 0.0

func _configurar_jugador_seguro():
	player = get_tree().get_first_node_in_group("player")
	if is_instance_valid(player) and player is CollisionObject3D:
		add_collision_exception_with(player)
		_player_last_pos = player.global_position

func _physics_process(delta):
	if not is_on_floor():
		velocity.y -= 20.0 * delta
	else:
		velocity.y = -0.5

	# Chequeo seguro del jugador (igual que el viejo)
	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")
		return

	if not "global_position" in player or not (player.global_position is Vector3):
		return

	if not ya_salude and global_position.distance_to(player.global_position) < 4.0:
		chequear_saludo_personaje()

	if is_acting:
		velocity.x = move_toward(velocity.x, 0, 0.5)
		velocity.z = move_toward(velocity.z, 0, 0.5)
		move_and_slide()
		return

	var dist_al_player = global_position.distance_to(player.global_position)
	var player_moved = _player_last_pos.distance_to(player.global_position) > 0.15
	_player_last_pos = player.global_position

	# BOREDOM: máquina de estados
	match npc_state:
		NPCState.FOLLOWING:
			if not player_moved:
				_boredom_timer += delta
				if _boredom_timer >= 1.0:
					npc_state = NPCState.WAITING
					_boredom_timer = 0.0
			else:
				_boredom_timer = 0.0

		NPCState.WAITING:
			if player_moved:
				npc_state = NPCState.FOLLOWING
				_boredom_timer = 0.0
			else:
				_boredom_timer += delta
				if _boredom_timer >= boredom_time:
					_activar_aburrimiento()

		NPCState.BORED:
			if player_moved:
				npc_state = NPCState.RETURNING
				_wander_target = Vector3.ZERO
				_boredom_timer = 0.0

		NPCState.RETURNING:
			if dist_al_player <= follow_distance + 0.5:
				npc_state = NPCState.FOLLOWING
				_boredom_timer = 0.0

	# BORED: explorar
	if npc_state == NPCState.BORED:
		_logica_wandering(delta)
		_sonido_pasos(delta)
		move_and_slide()
		return

	# RETURNING: ir directo al jugador, ignorar todo lo demás
	if npc_state == NPCState.RETURNING:
		mover_hacia(player.global_position, follow_distance)
		_sonido_pasos(delta)
		move_and_slide()
		return

	# --- Lógica normal del viejo script (FOLLOWING / WAITING) ---
	if not is_acting:
		buscar_enemigo_cercano()

		if is_instance_valid(target_enemy):
			var dist_enemigo = global_position.distance_to(target_enemy.global_position)
			if dist_enemigo > 1.2:
				mover_hacia(target_enemy.global_position, 1.2)
			elif can_attack:
				frenar()
				ejecutar_ataque()
		else:
			volver_con_dueño(dist_al_player)

	_sonido_pasos(delta)
	move_and_slide()

# BOREDOM
func _activar_aburrimiento():
	npc_state = NPCState.BORED
	_elegir_destino_wander()
	if randf() < 0.25 and voice_normal and not voice_normal.playing:
		voice_normal.play()

func _elegir_destino_wander():
	var angulo = randf() * TAU
	var distancia = randf_range(1.5, wander_radius)
	_wander_target = global_position + Vector3(
		cos(angulo) * distancia,
		0.0,
		sin(angulo) * distancia
	)
	_wander_timer = _wander_interval + randf_range(-0.5, 0.5)

func _logica_wandering(delta):
	_wander_timer -= delta
	var dist_destino = global_position.distance_to(_wander_target)

	if dist_destino < 0.5 or _wander_timer <= 0.0:
		_elegir_destino_wander()
		if randf() < 0.3:
			frenar()
			return

	mover_hacia(_wander_target, 0.4)

func _sonido_pasos(delta):
	if is_on_floor() and (abs(velocity.x) + abs(velocity.z)) > 0.5:
		_paso_timer -= delta
		if _paso_timer <= 0.0:
			_paso_timer = _paso_intervalo
			if snd_walk and not snd_walk.playing:
				snd_walk.play()

# --- DIÁLOGOS ---

func chequear_saludo_personaje():
	ya_salude = true
	if player.get("es_jane") == true or "Jane" in player.name:
		if voice_jane: voice_jane.play()
	else:
		if voice_normal: voice_normal.play()

# --- COMBATE ---

func ejecutar_ataque():
	is_acting = true
	can_attack = false

	var anim = "punch" + str(combo_step)
	sprite.play(anim)
	sprite.flip_h = (target_enemy.global_position - global_position).x < 0

	if snd_punch: snd_punch.play()
	if randf() < 0.2 and voice_attack:
		voice_attack.play()

	await get_tree().create_timer(0.2).timeout

	if is_instance_valid(target_enemy) and global_position.distance_to(target_enemy.global_position) < 1.5:
		if target_enemy.has_method("take_damage"):
			target_enemy.take_damage(8, global_position)

	await get_tree().create_timer(0.2).timeout

	is_acting = false
	combo_step = 2 if combo_step == 1 else 1

	await get_tree().create_timer(0.4).timeout
	can_attack = true

func take_damage(amount, source_pos):
	if is_acting and sprite.animation == "parry": return

	if randf() < 0.15:
		realizar_parry()
		return

	sprite.play("hurt")
	if snd_hurt: snd_hurt.play()
	if randf() < 0.2 and voice_hurt:
		voice_hurt.play()

	is_acting = true
	var dir = (global_position - source_pos).normalized()
	velocity.x = dir.x * 3.0
	velocity.z = dir.z * 3.0

	await get_tree().create_timer(0.4).timeout
	is_acting = false

func realizar_parry():
	is_acting = true
	sprite.play("parry")

	if snd_parry: snd_parry.play()
	if randf() < 0.3 and voice_parry:
		voice_parry.play()

	sprite.modulate = Color(2, 2, 2)
	await get_tree().create_timer(0.3).timeout
	sprite.modulate = Color(1, 1, 1)
	is_acting = false

# --- MOVIMIENTO ---

func volver_con_dueño(dist):
	if dist > follow_distance:
		mover_hacia(player.global_position, follow_distance)
	else:
		frenar()

func mover_hacia(objetivo: Vector3, distancia_frenado: float):
	var dir = (objetivo - global_position).normalized()
	dir.y = 0
	velocity.x = dir.x * speed
	velocity.z = dir.z * speed
	if sprite.sprite_frames.has_animation("walk"):
		sprite.play("walk")
	sprite.flip_h = dir.x < 0

func frenar():
	if not is_acting:
		velocity.x = move_toward(velocity.x, 0, 0.5)
		velocity.z = move_toward(velocity.z, 0, 0.5)
		if sprite.sprite_frames.has_animation("idle"):
			sprite.play("idle")

func buscar_enemigo_cercano():
	var enemigos = get_tree().get_nodes_in_group("enemies")
	var distancia_vision = 7.0
	target_enemy = null
	for ene in enemigos:
		if is_instance_valid(ene) and not ene.get("esta_muerto"):
			var d = global_position.distance_to(ene.global_position)
			if d < distancia_vision:
				distancia_vision = d
				target_enemy = ene
