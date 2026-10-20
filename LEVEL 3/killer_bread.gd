extends Area3D

@export var velocidad: float = 8.0
@export var invertir_direccion: bool = false

var persiguiendo: bool = false
var direccion_fija: Vector3 = Vector3.ZERO
var _pos_inicio: Vector3 = Vector3.ZERO

@onready var sprite_animado = $AnimatedSprite3D

func _ready():
	set_process(false)
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

func empezar_persecucion(player: Node3D):
	if persiguiendo:
		return
	persiguiendo = true

	var dir = (player.global_position - global_position)
	dir.y = 0.0
	dir = dir.normalized()

	if invertir_direccion:
		dir = -dir

	direccion_fija = dir
	_pos_inicio = global_position
	set_process(true)

	if sprite_animado and sprite_animado.sprite_frames:
		if sprite_animado.sprite_frames.has_animation("run"):
			sprite_animado.play("run")
		elif sprite_animado.sprite_frames.has_animation("default"):
			sprite_animado.play("default")

func _process(delta):
	if not persiguiendo:
		return

	global_position += direccion_fija * velocidad * delta

	if abs(direccion_fija.z) > abs(direccion_fija.x):
		global_position.x = _pos_inicio.x
	else:
		global_position.z = _pos_inicio.z

	global_position.y = _pos_inicio.y

func _on_body_entered(body: Node3D):
	if body.is_in_group("player"):
		print("¡El Pan Asesino te atrapó!")
		
		# Ejecuta los daños del jugador si los tiene
		if body.has_method("recibir_danio"):
			body.recibir_danio(999)
			
		# CORRECCIÓN DE SEGURIDAD: Llamamos a la muerte de forma diferida (call_deferred)
		var mundo = get_tree().current_scene
		if mundo.has_method("activar_game_over"):
			mundo.call_deferred("activar_game_over")
