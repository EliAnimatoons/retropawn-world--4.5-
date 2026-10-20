
extends StaticBody3D

func take_damage(amount, source_pos):
	
	get_parent().take_damage(amount, source_pos)
