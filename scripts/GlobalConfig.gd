extends Node

# Esta variable controla el estado global
var shaders_enabled: bool = true:
	set(value):
		shaders_enabled = value
		# Avisamos a todo el juego que esto cambió
		get_tree().call_group("post_process_nodes", "update_shader_status", value)
