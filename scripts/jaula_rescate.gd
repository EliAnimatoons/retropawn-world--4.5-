extends StaticBody3D

var destruida = false

func _ready():
	add_to_group("enemies") # Grupo para que la bala de Jane la detecte
	set_collision_layer_value(2, true) 
	set_collision_mask_value(1, true)
	set_collision_mask_value(2, true)
	set_collision_mask_value(3, true)

func take_damage(_amount, source_pos = Vector3.ZERO):
	if destruida: return
	destruida = true
	
	var personaje_dentro = null
	# Buscamos al hijo que sea rescatable
	for child in get_children():
		if child.has_method("habilitar_reclamo") or child.has_method("activar_rescate"):
			personaje_dentro = child
			break
	
	# Si hay alguien y NO se ha borrado por el script de NPC
	if personaje_dentro and is_instance_valid(personaje_dentro):
		var pos_actual = personaje_dentro.global_position
		call_deferred("_liberar_personaje", personaje_dentro, pos_actual)

	collision_layer = 0 
	var dir_final = (global_position - source_pos).normalized()
	if source_pos == Vector3.ZERO: dir_final = Vector3.UP
	dir_final.y = 2.5 
	
	var tween = create_tween().set_parallel(true)
	tween.tween_property(self, "position", position + (dir_final * 20.0), 1.2).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(self, "rotation", Vector3(randf(), randf(), randf()) * 10, 1.2)
	tween.chain().tween_callback(queue_free)

func _liberar_personaje(p, pos):
	if is_instance_valid(p) and p.get_parent() == self:
		remove_child(p)
		get_tree().current_scene.add_child(p)
		p.global_position = pos
		if p.has_method("habilitar_reclamo"):
			p.habilitar_reclamo()
		elif p.has_method("activar_rescate"):
			p.activar_rescate()
