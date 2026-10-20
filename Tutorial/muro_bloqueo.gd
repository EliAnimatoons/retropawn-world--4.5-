# MuroBloqueo.gd
extends Node3D

@export var pared_fisica: StaticBody3D
@export var contenedor_minions: Node3D

var minions_restantes: int = 0

func _ready() -> void:
	# Nos vinculamos a los minions al arrancar
	conectar_minions()

func conectar_minions() -> void:
	minions_restantes = 0
	var lista = contenedor_minions.get_children() if is_instance_valid(contenedor_minions) else get_children()
	
	for child in lista:
		if child.is_in_group("enemies"):
			minions_restantes += 1
			if child.has_signal("muerto") and not child.is_connected("muerto", _on_minion_muerto):
				child.connect("muerto", _on_minion_muerto)
			if not child.tree_exiting.is_connected(_on_minion_eliminado):
				child.tree_exiting.connect(_on_minion_eliminado)

func _notification(what: int) -> void:
	# Cuando el TriggerColapso lo activa (process_mode cambia), nos aseguramos de reconectar
	if what == NOTIFICATION_ENABLED:
		conectar_minions()

func _on_minion_muerto() -> void:
	_comprobar_liberacion()

func _on_minion_eliminado() -> void:
	_comprobar_liberacion()

func _comprobar_liberacion() -> void:
	minions_restantes -= 1
	print("--> [MURO] Minions restantes en esta pared: ", max(0, minions_restantes))
	
	if minions_restantes <= 0:
		destruir_muro()

func destruir_muro() -> void:
	print("¡¡¡MURO DESTRUIDO!!! Camino despejado.")
	queue_free()
