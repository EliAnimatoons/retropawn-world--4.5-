# script_mundo_playa.gd
extends Node3D

var cuadro_negro: ColorRect

# --- CÁMARA DINÁMICA ---
@onready var camara: Camera3D = $Camera3D 
@export var cam_velocidad_suavizado: float = 5.0
@export var cam_distancia_minima_z: float = 6.0
@export var cam_distancia_maxima_z: float = 14.0
@export var cam_margen_zoom: float = 0.8

# --- CONFIGURACIÓN ATRAPADITAS ---
@export var musica_atrapaditas: AudioStream
@export var distancia_toque: float = 1.5 

var limite_min_x: float = -15.0
var limite_max_x: float = 15.0
var limite_min_z: float = -6.0
var limite_max_z: float = 6.0

var persecutor: Node = null
var participantes: Array[Node] = []
var juego_activo: bool = false
var musica_player: AudioStreamPlayer = null

var en_cooldown_toque: bool = false
var nodos_aturdidos: Array[Node] = [] 
var victima_inmune: Node = null 

func _ready():
	add_to_group("nivel_con_carrera")
	cuadro_negro = find_child("ColorRect", true, false)
	if cuadro_negro:
		cuadro_negro.modulate.a = 0.0

	# --- DETECTAR LÍMITES EXACTOS DESDE ZonaPlaya ---
	var zona = find_child("ZonaPlaya", true, false)
	if zona:
		var col = zona.find_child("CollisionShape3D", true, false)
		if col and col.shape is BoxShape3D:
			var ext = col.shape.size / 2.0
			limite_min_x = zona.global_position.x - ext.x
			limite_max_x = zona.global_position.x + ext.x
			limite_min_z = zona.global_position.z - ext.z
			limite_max_z = zona.global_position.z + ext.z
			print("[MINIJUEGO] Límites de ZonaPlaya aplicados con éxito.")

	_iniciar_timer_atrapaditas()

func _physics_process(delta):
	actualizar_camara_tutorial(delta)
	
	if juego_activo and is_instance_valid(persecutor):
		_procesar_logica_atrapaditas(delta)

	# Jaula matemática absoluta para el jugador (Sketch)
	var jugador = get_tree().get_first_node_in_group("player")
	if is_instance_valid(jugador):
		jugador.global_position.x = clamp(jugador.global_position.x, limite_min_x, limite_max_x)
		jugador.global_position.z = clamp(jugador.global_position.z, limite_min_z, limite_max_z)

	# Antigravedad de seguridad para que ningún NPC corra flotando en el aire
	for p in participantes:
		if is_instance_valid(p) and p != jugador:
			if p.global_position.y > 0.5 or p.global_position.y < -1.0:
				p.global_position.y = 0.0 # Ajusta este 0.0 si la altura de tu suelo varía

# --- LÓGICA DEL MINIJUEGO ---

func _iniciar_timer_atrapaditas():
	await get_tree().create_timer(15.0).timeout 
	iniciar_secuencia_minijuego()

func iniciar_secuencia_minijuego():
	_cambiar_musica()
	await _mostrar_contador_ui()
	_iniciar_juego()

func _cambiar_musica():
	var musica_actual = find_child("*beachday*", true, false)
	if not musica_actual:
		musica_actual = find_child("*Theme*", true, false)
		
	if musica_actual and musica_actual is AudioStreamPlayer:
		var tw = create_tween()
		tw.tween_property(musica_actual, "volume_db", -80.0, 1.0)
		tw.tween_callback(func():
			if is_instance_valid(musica_actual): musica_actual.stop()
		)
		
	if musica_atrapaditas:
		musica_player = AudioStreamPlayer.new()
		musica_player.stream = musica_atrapaditas
		musica_player.name = "huntergame_player"
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
	
	var es_ingles = TranslationServer.get_locale().begins_with("en")
	var texto_correr = "¡A CORRER!" if not es_ingles else "RUN!"
	
	var textos = ["3", "2", "1", texto_correr]
	for t in textos:
		label.text = t
		label.scale = Vector2(0.5, 0.5)
		var tw = create_tween().set_parallel(true)
		tw.tween_property(label, "scale", Vector2(1.2, 1.2), 0.4).set_trans(Tween.TRANS_BACK)
		await get_tree().create_timer(0.8).timeout
		
	canvas.queue_free()

func _iniciar_juego():
	juego_activo = true
	participantes = []
	
	var jugadores = get_tree().get_nodes_in_group("player")
	var npcs = get_tree().get_nodes_in_group("npcs")

	participantes.append_array(jugadores)
	participantes.append_array(npcs)
	
	if participantes.is_empty(): return

	participantes.shuffle()
	persecutor = participantes[0]
	
	for p in participantes:
		_forzar_animacion_universal(p, "run")
		
	var nombre_limpio = persecutor.name.replace("NPC_", "").replace("NPC", "")
	var es_ingles = TranslationServer.get_locale().begins_with("en")
	var msg = ("¡" + nombre_limpio + " la paga!") if not es_ingles else (nombre_limpio + " is it!")
	_mostrar_anuncio_inicio_buscador(msg)

func _mostrar_anuncio_inicio_buscador(texto: String):
	var canvas = CanvasLayer.new()
	canvas.layer = 101
	add_child(canvas)
	
	var label = Label.new()
	label.text = texto
	label.set_anchors_preset(Control.PRESET_CENTER)
	label.add_theme_font_size_override("font_size", 54)
	label.modulate = Color(1, 0.2, 0.2, 1)
	canvas.add_child(label)
	
	var tw = create_tween()
	tw.tween_property(label, "scale", Vector2(1.4, 1.4), 0.3).set_trans(Tween.TRANS_BACK)
	tw.tween_property(label, "scale", Vector2(1.0, 1.0), 0.2)
	await get_tree().create_timer(2.5).timeout
	
	var fade = create_tween()
	fade.tween_property(label, "modulate:a", 0.0, 0.5)
	await fade.finished
	canvas.queue_free()

func _procesar_logica_atrapaditas(delta: float):
	var jugador = get_tree().get_first_node_in_group("player")
	var limites = [limite_min_x, limite_max_x, limite_min_z, limite_max_z]
	if not is_instance_valid(jugador): return 

	# 1. PERSEGUIDOR ES NPC
	if persecutor != jugador and not persecutor in nodos_aturdidos:
		var objetivo_perseguido = _obtener_objetivo_prioritario(persecutor, jugador)
		if is_instance_valid(objetivo_perseguido):
			if persecutor.has_method("mover_hacia"):
				persecutor.mover_hacia(objetivo_perseguido.global_position, delta, limites)
			
			if not en_cooldown_toque and persecutor.global_position.distance_to(objetivo_perseguido.global_position) <= distancia_toque:
				_transferir_toque(persecutor, objetivo_perseguido)
		else:
			if persecutor.has_method("mover_aleatorio"):
				persecutor.mover_aleatorio(delta, limites)

	# 2. PERSEGUIDOR ES EL JUGADOR (Sketch)
	elif persecutor == jugador:
		if not en_cooldown_toque and not jugador in nodos_aturdidos:
			for npc in _obtener_npcs_en_juego():
				if npc == victima_inmune: continue
				if jugador.global_position.distance_to(npc.global_position) <= distancia_toque:
					_transferir_toque(jugador, npc)
					break

	# 3. HUIDA Y MOVIMIENTO DE LOS DEMÁS NPCs
	for p in participantes:
		if p != persecutor and p != jugador and is_instance_valid(p) and not p in nodos_aturdidos:
			var dist = p.global_position.distance_to(persecutor.global_position)
			if dist < 8.0:
				var dir_huida = (p.global_position - persecutor.global_position).normalized()
				if p.has_method("mover_hacia"):
					p.mover_hacia(p.global_position + dir_huida * 5.0, delta, limites)
			else:
				if p.has_method("mover_aleatorio"):
					p.mover_aleatorio(delta, limites)

func _transferir_toque(de_nodo: Node, a_nodo: Node):
	en_cooldown_toque = true
	
	if not de_nodo in nodos_aturdidos: nodos_aturdidos.append(de_nodo)
	if not a_nodo in nodos_aturdidos: nodos_aturdidos.append(a_nodo)
	
	print("--- [MINIJUEGO] ", de_nodo.name, " tocó a ", a_nodo.name, "! ---")
	
	_forzar_animacion_universal(de_nodo, "touch")
	_forzar_animacion_universal(a_nodo, "hurted")
	
	var ex_persecutor = de_nodo
	persecutor = a_nodo
	victima_inmune = ex_persecutor
	
	await get_tree().create_timer(1.8).timeout
	
	nodos_aturdidos.erase(ex_persecutor)
	if is_instance_valid(ex_persecutor): 
		_forzar_animacion_universal(ex_persecutor, "run")
	
	await get_tree().create_timer(0.5).timeout
	
	en_cooldown_toque = false
	nodos_aturdidos.erase(persecutor)
	if is_instance_valid(persecutor): 
		_forzar_animacion_universal(persecutor, "run")

	await get_tree().create_timer(3.0).timeout
	if victima_inmune == ex_persecutor:
		victima_inmune = null

func _obtener_objetivo_prioritario(desde_nodo: Node, jugador: Node) -> Node:
	if desde_nodo == victima_inmune:
		return _obtener_objetivo_mas_cercano(desde_nodo)
		
	if is_instance_valid(jugador) and jugador != victima_inmune:
		var dist_al_jugador = desde_nodo.global_position.distance_to(jugador.global_position)
		if dist_al_jugador < 12.0 and randf() < 0.75:
			return jugador
			
	return _obtener_objetivo_mas_cercano(desde_nodo)

func _obtener_objetivo_mas_cercano(desde_nodo: Node) -> Node:
	var mas_cercano: Node = null
	var min_dist = 9999.0
	for p in participantes:
		if p != desde_nodo and p != victima_inmune and is_instance_valid(p):
			var d = desde_nodo.global_position.distance_to(p.global_position)
			if d < min_dist:
				min_dist = d
				mas_cercano = p
	return mas_cercano

func _obtener_npcs_en_juego() -> Array[Node]:
	var res: Array[Node] = []
	var jugador = get_tree().get_first_node_in_group("player")
	for p in participantes:
		if p != jugador and is_instance_valid(p):
			res.append(p)
	return res

func _forzar_animacion_universal(nodo: Node, tipo: String):
	if not is_instance_valid(nodo): return
	
	if nodo.has_method("reproducir_animacion"):
		nodo.reproducir_animacion(tipo)
		return

	var sprite = null
	if nodo.has_node("AnimatedSprite3D"):
		sprite = nodo.get_node("AnimatedSprite3D")
	elif nodo.has_node("AnimatedSprite2D"):
		sprite = nodo.get_node("AnimatedSprite2D")
	else:
		sprite = nodo.find_child("*AnimatedSprite*", true, false)
		
	if not sprite and (nodo is AnimatedSprite3D or nodo is AnimatedSprite2D):
		sprite = nodo

	if sprite and sprite.sprite_frames:
		var anims_posibles = [tipo]
		if tipo == "run":
			anims_posibles = ["run", "walk", "caminar", "correr"]
		elif tipo == "touch":
			anims_posibles = ["touch", "attack", "golpe", "hit", "run"]
		elif tipo == "hurted" or tipo == "hurt":
			anims_posibles = ["hurted", "hurt", "daño", "hit", "damage"]

		for anim in anims_posibles:
			if sprite.sprite_frames.has_animation(anim):
				if sprite.animation != anim:
					sprite.play(anim)
				break

func actualizar_camara_tutorial(delta: float):
	if not camara: return
	var objetivos: Array[Vector3] = []
	for p in get_tree().get_nodes_in_group("player"):
		if is_instance_valid(p): objetivos.append(p.global_position)
	if objetivos.is_empty(): return

	var suma = Vector3.ZERO
	for pos in objetivos: suma += pos
	var punto_medio = suma / float(objetivos.size())
	
	var dist_max_x = 0.0
	var dist_max_y = 0.0
	for pos in objetivos:
		var diff = (pos - punto_medio).abs()
		if diff.x > dist_max_x: dist_max_x = diff.x
		if diff.y > dist_max_y: dist_max_y = diff.y
	var mayor_distancia = max(dist_max_x * 2.0, dist_max_y * 2.0)
	
	var destino_camara = camara.global_position
	destino_camara.x = punto_medio.x
	destino_camara.y = punto_medio.y + 1.5
	var objetivo_z = punto_medio.z + cam_distancia_minima_z + (mayor_distancia * cam_margen_zoom)
	destino_camara.z = clamp(objetivo_z, punto_medio.z + cam_distancia_minima_z, punto_medio.z + cam_distancia_maxima_z)
	
	camara.global_position = camara.global_position.lerp(destino_camara, cam_velocidad_suavizado * delta)
