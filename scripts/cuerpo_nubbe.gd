extends StaticBody3D

func take_damage(amount, source_pos = Vector3.ZERO):
	# Reenvía el daño al script principal de Nubbe
	if get_parent().has_method("take_damage"):
		get_parent().take_damage(amount, source_pos)
