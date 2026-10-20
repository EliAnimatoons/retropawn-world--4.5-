extends Area3D

var activado = false

func _ready():
	body_entered.connect(_on_body_entered)

func _on_body_entered(body):
	if body.is_in_group("player") and not activado:
		var instructor = get_tree().current_scene.find_child("ZonaInstructor", true, false)
		if instructor and instructor.etapa == 3: # Si ya pasaste el parry
			activado = true
			instructor.activar_paso_bomba()
			queue_free()
