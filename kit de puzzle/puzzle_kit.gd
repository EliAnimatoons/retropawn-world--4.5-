extends Node3D

@export var rock_wall: StaticBody3D
@export var wall_collision: CollisionShape3D
@export var pressure_plate: Area3D
@export var plate_mesh: MeshInstance3D  # El nodo visual de la placa (MeshInstance3D o Sprite3D)
@export var lever: StaticBody3D
@export var lever_sprite: AnimatedSprite3D

var is_plate_active: bool = false
var is_lever_pressed: bool = false
var is_solved: bool = false

# Colores para el feedback visual
var original_color: Color = Color.WHITE
var active_color: Color = Color(0.2, 1.2, 0.3) # Verde verde/brillante

func _ready():
	if pressure_plate:
		pressure_plate.body_entered.connect(_on_plate_body_entered)
		pressure_plate.body_exited.connect(_on_plate_body_exited)
	
	# Guardamos y duplicamos el material para no pintar otras placas del mapa
	if plate_mesh:
		if plate_mesh.get_active_material(0):
			var mat = plate_mesh.get_active_material(0).duplicate()
			plate_mesh.material_override = mat
			original_color = mat.albedo_color
		elif "modulate" in plate_mesh: # Por si es un Sprite3D / AnimatedSprite3D
			original_color = plate_mesh.modulate

	if lever_sprite and lever_sprite.sprite_frames.has_animation("idle"):
		lever_sprite.play("idle")

func _on_plate_body_entered(body: Node3D):
	if body.is_in_group("pushable"):
		is_plate_active = true
		_update_plate_color(true)
		print("Kit Puzzle: Tacho detectado en la placa.")
		check_puzzle()

func _on_plate_body_exited(body: Node3D):
	if body.is_in_group("pushable"):
		is_plate_active = false
		_update_plate_color(false)

func _update_plate_color(active: bool):
	if not plate_mesh:
		return
	
	var target_color = active_color if active else original_color
	
	# Si es un Mesh 3D con material
	if plate_mesh.material_override and plate_mesh.material_override is StandardMaterial3D:
		plate_mesh.material_override.albedo_color = target_color
	# Si es un Sprite3D o AnimatedSprite3D
	elif "modulate" in plate_mesh:
		plate_mesh.modulate = target_color

func trigger_lever():
	if not is_lever_pressed:
		is_lever_pressed = true
		if lever_sprite and lever_sprite.sprite_frames.has_animation("pressed"):
			lever_sprite.play("pressed")
		print("Kit Puzzle: Palanca bajada.")
		check_puzzle()

func check_puzzle():
	if is_solved:
		return
		
	if is_plate_active and is_lever_pressed:
		is_solved = true
		open_wall()

func open_wall():
	print("¡PUZZLE RESUELTO! Abriendo el muro de rocas...")
	if not rock_wall:
		return
		
	var tween = create_tween()
	tween.tween_property(rock_wall, "position:y", rock_wall.position.y - 5.0, 1.5)
	await tween.finished
	
	if wall_collision:
		wall_collision.disabled = true
