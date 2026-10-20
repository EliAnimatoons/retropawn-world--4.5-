extends Marker3D

func _ready():
	# Esperamos un momento para asegurar que el mapa cargó
	await get_tree().create_timer(0.1).timeout
	
	var personaje_id = GameManager.personaje_elegido
	
	# Verificamos si el personaje existe en el diccionario
	if not GameManager.rutas.has(personaje_id):
		print("ERROR: El personaje '", personaje_id, "' no existe en GameManager.rutas")
		return

	var ruta = GameManager.rutas[personaje_id]
	var escena
	
	# CIRUGÍA: Si la ruta ya es una escena (PackedScene), la usamos. Si es texto, la cargamos.
	if ruta is PackedScene:
		escena = ruta
	else:
		escena = load(ruta)
	
	if escena:
		var instancia = escena.instantiate()
		
		# Lo añadimos al nivel
		get_parent().add_child(instancia)
		
		# Ajuste de posición (un poco arriba para que no atraviese el suelo)
		instancia.global_position = global_position + Vector3(0, 0.2, 0)
		
		# Configuración de grupos y colisiones
		instancia.add_to_group("player")
		instancia.set_collision_layer_value(1, true)
		instancia.set_collision_mask_value(1, true)
		
		print("--- REPORTE DE APARICIÓN ---")
		print("Personaje: ", personaje_id)
		print("Escena cargada correctamente desde: ", ruta)
		
		# Vincular la cámara
		var camara = get_viewport().get_camera_3d()
		if camara and "target" in camara:
			camara.target = instancia
			print("Cámara vinculada con éxito.")
		
		print("---------------------------")
	else:
		print("ERROR CRÍTICO: No se pudo cargar la escena. Ruta: ", ruta)
