# minijuego_traes.gd
extends Node

signal juego_iniciado
signal persecutor_cambiado(nuevo_persecutor)

@export var musica_atrapaditas: AudioStream
@export var velocidad_carrera_npc: float = 6.5
@export var distancia_toque: float = 1.2

var persecutor: Node = null # Quien "las trae"
var participantes: Array[Node] = []
var juego_activo: bool = false
var musica_player: AudioStreamPlayer = null

func iniciar_secuencia_minijuego():
	print("--- [MINIJUGO] Iniciando cuenta regresiva para las Atrapaditas... ---")
	_cambiar_musica()
	await _mostrar_contador_ui()
	_iniciar_juego()

func _cambiar_musica():
	# Muteamos la música de fondo actual
	var musica_actual = get_tree().current_scene.find_child("*Theme*", true, false)
	if musica_actual and musica_actual is AudioStreamPlayer:
		var tw = create_tween()
		tw.tween_property(musica_actual, "volume_db", -80.0, 1.0)
		tw.tween_callback(func(): musica_actual.stop())
		
	if musica_atrapaditas:
		musica_player = AudioStreamPlayer.new()
		musica_player.stream = musica_atrapaditas
		musica_player.name = "MusicaAtrapaditas"
		add_child(musica_player)
		musica_player.play()

func _mostrar_contador_ui():
	var canvas = CanvasLayer.new()
	canvas.layer = 100
	add_child(canvas)
	
	var label = Label.new()
	label.set_anchors_preset(Control.PRESET_CENTER)
	label.add_theme_font_size_override("font_size", 72)
	canvas.add_child(label)
	
	var cuenta = ["3", "2", "1", "¡A CORRER! / RUN!"]
	for t in cuenta:
		label.text = t
		label.scale = Vector2(0.5, 0.5)
		var tw = create_tween().set_parallel(true)
		tw.tween_property(label, "scale", Vector2(1.2, 1.2), 0.4).set_trans(Tween.TRANS_BACK)
		await get_tree().create_timer(0.8).timeout
		
	canvas.queue_free()

func _iniciar_juego():
	juego_activo = true
	participantes = []
	
	# Recopilamos al jugador y a los NPCs
	var jugadores = get_tree().get_nodes_in_group("player")
	var npcs = get_tree().get_nodes_in_group("npcs")
	
	participantes.append_array(jugadores)
	participantes.append_array(npcs)
	
	# Selección aleatoria del primer perseguidor
	participantes.shuffle()
	persecutor = participantes[0]
	
	print("--- [MINIJUGO] ¡El perseguidor inicial es: ", persecutor.name, "! ---")
	emit_signal("persecutor_cambiado", persecutor)
	
	# Poner a todos en animación 'run'
	for p in participantes:
		_reproducir_animacion(p, "run")

func _physics_process(delta):
	if not juego_activo or not is_instance_valid(persecutor): return
	
	# Lógica del Perseguidor NPC
	if persecutor != get_tree().get_first_node_in_group("player"):
		var presa_mas_cercana: Node = _obtener_objetivo_mas_cercano(persecutor)
		if presa_mas_cercana:
			_mover_npc_hacia(persecutor, presa_mas_cercana.global_position, delta)
			
			if persecutor.global_position.distance_to(presa_mas_cercana.global_position) <= distancia_toque:
				_transferir_toque(persecutor, presa_mas_cercana)

	# Lógica de HUIDA para los demás NPCs que no son el perseguidor
	for p in participantes:
		if p != persecutor and p != get_tree().get_first_node_in_group("player") and is_instance_valid(p):
			var dist_al_persecutor = p.global_position.distance_to(persecutor.global_position)
			if dist_al_persecutor < 8.0:
				var dir_huida = (p.global_position - persecutor.global_position).normalized()
				_mover_npc_hacia(p, p.global_position + dir_huida * 3.0, delta)
			else:
				_reproducir_animacion(p, "run")

	# Si el JUGADOR es el perseguidor, detectamos si toca a un NPC
	var jugador = get_tree().get_first_node_in_group("player")
	if persecutor == jugador:
		for npc in npcs_en_juego():
			if jugador.global_position.distance_to(npc.global_position) <= distancia_toque:
				_transferir_toque(jugador, npc)
				break

func _transferir_toque(de_nodo: Node, a_nodo: Node):
	print("--- [MINIJUGO] ", de_nodo.name, " tocó a ", a_nodo.name, "! ---")
	
	# Animaciones Touch y Hurted
	_reproducir_animacion(de_nodo, "touch")
	_reproducir_animacion(a_nodo, "hurted")
	
	persecutor = a_nodo
	emit_signal("persecutor_cambiado", persecutor)
	
	# Pausa breve de reacción (efecto dramático)
	juego_activo = false
	await get_tree().create_timer(0.6).timeout
	juego_activo = true
	
	# Volver a correr
	_reproducir_animacion(de_nodo, "run")
	_reproducir_animacion(a_nodo, "run")

func _mover_npc_hacia(npc: Node, destino: Vector3, delta: float):
	var dir = (destino - npc.global_position)
	dir.y = 0 # Mantener en plano 3D horizontal
	if dir.length() > 0.1:
		npc.global_position += dir.normalized() * velocidad_carrera_npc * delta
		_orientar_sprite(npc, dir.x < 0)
		_reproducir_animacion(npc, "run")

func _orientar_sprite(nodo: Node, flip: bool):
	var sprite = nodo.find_child("AnimatedSprite3D", true, false)
	if not sprite: sprite = nodo.find_child("Sprite3D", true, false)
	if sprite and "flip_h" in sprite:
		sprite.flip_h = flip

func _reproducir_animacion(nodo: Node, anim_nombre: String):
	var sprite = nodo.find_child("AnimatedSprite3D", true, false)
	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation(anim_nombre):
		if sprite.animation != anim_nombre:
			sprite.play(anim_nombre)

func _obtener_objetivo_mas_cercano(desde_nodo: Node) -> Node:
	var mas_cercano: Node = null
	var min_dist = 9999.0
	for p in participantes:
		if p != desde_nodo and is_instance_valid(p):
			var d = desde_nodo.global_position.distance_to(p.global_position)
			if d < min_dist:
				min_dist = d
				mas_cercano = p
	return mas_cercano

func npcs_en_juego() -> Array[Node]:
	var res: Array[Node] = []
	for p in participantes:
		if p != get_tree().get_first_node_in_group("player") and is_instance_valid(p):
			res.append(p)
	return res
