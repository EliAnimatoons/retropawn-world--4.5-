extends GPUParticles3D

func _ready():
	emitting = true
	# Se borra automáticamente después de 2 segundos para no acumular basura
	get_tree().create_timer(2.0).timeout.connect(queue_free)
