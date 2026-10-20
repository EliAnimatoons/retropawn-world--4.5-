extends WorldEnvironment

var tiempo = 0.0

func _process(delta):
	tiempo += delta
	# Esto hace que la densidad de la neblina oscile suavemente
	# simulando nubes de humo que pasan.
	environment.fog_density = 0.05 + (sin(tiempo * 0.5) * 0.02)
	
	# Si querés que el color también cambie un poquito
	environment.fog_light_color = Color(0.5 + (sin(tiempo) * 0.1), 0.1, 0.1)
