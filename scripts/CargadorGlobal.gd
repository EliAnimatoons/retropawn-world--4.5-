# Cargador.gd (Autoload) - VERSIÓN CORREGIDA
extends Node

var escena_destino : String = ""

func ir_a_escena(ruta_nueva: String):
	escena_destino = ruta_nueva
	
	# ResourceLoader.exists es la forma correcta de buscar en el ejecutable (.exe)
	if ResourceLoader.exists(ruta_nueva):
		# IMPORTANTE: Asegúrate de que "PantallaDeCarga.tscn" esté en la raíz res:// 
		# y que el nombre coincida exactamente (mayúsculas/minúsculas)
		get_tree().change_scene_to_file("res://PantallaDeCarga.tscn")
	else:
		# Este print saldrá en la consola si algo falla
		print("ERROR CRÍTICO: El ResourceLoader no encuentra: ", ruta_nueva)
