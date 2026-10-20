extends Area3D

func _on_body_entered(body: Node3D):
	if body.is_in_group("player"):
		var mundo = get_tree().current_scene
		if mundo.has_method("actualizar_checkpoint"):
			# Le pasa la posición de este objeto al script del mundo
			mundo.actualizar_checkpoint(global_position) 
			queue_free() # Se destruye para que no se active mil veces
