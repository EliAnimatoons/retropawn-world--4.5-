# Script para el ColorRect del shader
extends ColorRect

func _ready():
	add_to_group("post_process_nodes") # Se une al grupo para recibir órdenes
	# Se configura según lo que diga el guardado al empezar
	visible = ProgresoJuego.shaders_activos 

func update_shader_status(is_active: bool):
	visible = is_active
