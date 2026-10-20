extends MeshInstance3D

# Esta línea es la que CREA la casilla en el Inspector
@export var luz_principal : DirectionalLight3D 

func _ready():
	# Esto es para que tu botón de configuración lo apague/prenda
	add_to_group("post_process_nodes")
	visible = ProgresoJuego.shaders_activos

func _process(_delta):
	# Si la casilla tiene una luz y el efecto está prendido...
	if visible and luz_principal:
		# Le pasamos la dirección al shader (Basis Z invertida)
		var direccion = -luz_principal.global_transform.basis.z
		# "light_world_dir" es el nombre exacto que usa el shader que pasaste
		set_instance_shader_parameter("light_world_dir", direccion)

# Función para que el menú de opciones lo controle
func update_shader_status(is_active: bool):
	visible = is_active
