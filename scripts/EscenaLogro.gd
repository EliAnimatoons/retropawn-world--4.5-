extends CanvasLayer

func configurar_logro(titulo: String, nombre_animacion: String):
	# 1. Cambiamos el texto del logro
	$Control/TextoLogro.text = titulo
	
	# 2. En lugar de cargar un archivo, le decimos al AnimatedSprite2D 
	# que ponga la animación que toca (ej: "insignia17")
	if has_node("Control/IconoLogro"):
		$Control/IconoLogro.play(nombre_animacion)
	
	# 3. Animación de entrada de la notificación
	if has_node("AnimationPlayer"):
		$AnimationPlayer.play("aparecer")
	
	# 4. Auto-destrucción
	await get_tree().create_timer(4.0).timeout
	queue_free()
