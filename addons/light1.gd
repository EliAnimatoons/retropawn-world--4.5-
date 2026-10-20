extends ColorRect

@export var sol_path : NodePath

@export var camara_path : NodePath
@onready var camara : Camera3D = get_node(camara_path)

func _ready():
	# Añadimos este nodo al grupo para que el Global lo encuentre
	add_to_group("post_process_nodes")
	# Aplicamos el estado inicial
	update_shader_status(GlobalConfig.shaders_enabled)
	
func _process(_delta: float) -> void:

	
	material.set_shader_parameter("cam_direction", -camara.global_basis.z.normalized())
	# Usamos el color real de tu script de temperatura Kelvin

	

# Esta función la llama tu Script Global automáticamente
func update_shader_status(value: bool):
	# Si value es false, el ColorRect se oculta y el shader DEJA de procesarse
	visible = value
