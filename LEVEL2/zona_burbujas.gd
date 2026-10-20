extends Area3D

@export var fuerza_empuje: float = 0.8

func _physics_process(_delta: float) -> void:
	var cuerpos = get_overlapping_bodies()
	
	for cuerpo in cuerpos:
		# Filtramos para que SOLO afecte a nodos que pertenezcan al grupo "player"
		if cuerpo.is_in_group("player"):
			if "velocity" in cuerpo:
				# Aplicamos el empuje directamente a la velocidad vertical del jugador
				cuerpo.velocity.y = fuerza_empuje
