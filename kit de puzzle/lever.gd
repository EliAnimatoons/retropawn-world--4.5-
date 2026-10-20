extends StaticBody3D

# Al recibir un golpe, le avisa al nodo raíz del kit
func take_damage(_amount = 0, _source_pos = Vector3.ZERO):
	var kit = get_parent()
	if kit and kit.has_method("trigger_lever"):
		kit.trigger_lever()
