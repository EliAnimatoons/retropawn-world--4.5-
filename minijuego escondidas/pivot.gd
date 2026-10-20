extends Node3D

@export var sensibilidad = 0.2
var arrastrando = false

func _input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			arrastrando = event.pressed
			
	if event is InputEventMouseMotion and arrastrando:
		# Giramos el escenario completo en el eje Y
		rotation_degrees.y -= event.relative.x * sensibilidad
