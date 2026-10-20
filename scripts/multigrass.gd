extends MultiMeshInstance3D

func _ready():
	# Si tu mapa es muy grande, subí la cantidad a 2000
	var cantidad = 2000 
	multimesh.instance_count = cantidad
	
	for i in range(cantidad):
		# RANGO DE DISPERSIÓN: 
		# Si tu mapa es de 100x100 metros, usá -50 y 50.
		# Probemos con un rango bien amplio para que lo veas:
		var x = randf_range(-60.0, 60.0)
		var z = randf_range(-60.0, 60.0)
		var y = 0.0 # Ajustá a 0.1 si se entierra
		
		var pos = Transform3D()
		
		# 1. Rotación aleatoria
		pos = pos.rotated(Vector3(0, 1, 0), randf_range(0, PI * 2.0))
		
		# 2. Escala pequeña (Aero style)
		var escala = randf_range(0.1, 0.2)
		pos = pos.scaled(Vector3(escala, escala, escala))
		
		# 3. Posición final
		pos.origin = Vector3(x, y, z)
		
		multimesh.set_instance_transform(i, pos)
