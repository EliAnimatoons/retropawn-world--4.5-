extends StaticBody3D

func take_damage(amount, source_pos = Vector3.ZERO):
	# Le pasa el daño al padre (el Sprite)
	if get_parent().has_method("take_damage"):
		get_parent().take_damage(amount, source_pos)
