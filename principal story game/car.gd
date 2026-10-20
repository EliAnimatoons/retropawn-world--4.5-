# car.gd
extends Node3D

signal secuencia_completa

enum Estado { ESPERANDO, EVENTO_INICIADO, VIAJANDO }
var estado_actual: Estado = Estado.ESPERANDO

@export var interior_auto_ui: CanvasLayer
@export var mapa_3d: Node3D
@export var punto_puerta: Node3D

@export var sonido_bocina_stream: AudioStream
@export var sonido_motor_stream: AudioStream

@export var ruta_escena_playa: String = "res://principal story game/Beachday.tscn"
@export var duracion_viaje_segundos: float = 30.0

# --- TRANSICIÓN CON SHADER ---
@export var shader_transicion: Shader
@export var mascara_transicion: Texture2D

var audio_bocina: AudioStreamPlayer
var audio_motor: AudioStreamPlayer

var npcs_en_escena: Array[Node] = []
var npcs_subidos: int = 0
var jugador: Node = null
var sketch_subido: bool = false
var salida_iniciada: bool = false

func _ready():
	print("--- [AUTO] Inicializando script del auto... ---")
	
	audio_bocina = AudioStreamPlayer.new()
	audio_bocina.name = "AudioBocinaAuto"
	if sonido_bocina_stream:
		audio_bocina.stream = sonido_bocina_stream
	add_child(audio_bocina)
	
	audio_motor = AudioStreamPlayer.new()
	audio_motor.name = "AudioMotorAuto"
	if sonido_motor_stream:
		audio_motor.stream = sonido_motor_stream
	add_child(audio_motor)

	var timer_check = Timer.new()
	timer_check.wait_time = 1.0
	timer_check.autostart = true
	add_child(timer_check)
	timer_check.timeout.connect(_comprobar_si_todos_hablaron)

func _comprobar_si_todos_hablaron():
	if estado_actual != Estado.ESPERANDO: return
	var npcs = get_tree().get_nodes_in_group("npcs")
	if npcs.size() == 0: return
	
	var todos_listos = true
	for npc in npcs:
		if "ya_hablo_una_vez" in npc and not npc.ya_hablo_una_vez:
			todos_listos = false
			break
			
	if todos_listos:
		print("--- [AUTO] Todos los NPCs hablaron. Iniciando evento final. ---")
		estado_actual = Estado.EVENTO_INICIADO
		activar_evento_final()

func activar_evento_final():
	await get_tree().create_timer(2.5).timeout
	_reproducir_sonido(audio_bocina)
	mostrar_letrero_automatico()

func mostrar_letrero_automatico():
	print("--- [AUTO] Mostrando letrero de viaje... ---")
	var canvas = CanvasLayer.new()
	add_child(canvas)
	
	var panel = Panel.new()
	panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	panel.custom_minimum_size = Vector2(0, 150)
	panel.position.y -= 150
	canvas.add_child(panel)
	
	var label = Label.new()
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	label.add_theme_font_size_override("font_size", 24)
	
	var idioma = ProgresoJuego.idioma if "idioma" in ProgresoJuego else "es"
	if idioma == "es":
		label.text = "*¡BIP! ¡BIP!*\n¡Los amigos se van a un viaje a la playa!\n¡Les esperan unas excelentes vacaciones!"
	elif idioma == "en":
		label.text = "*BEEP! BEEP!*\nThe friends are going on a trip to the beach!\nAn amazing vacation awaits!"
	else:
		label.text = "＊プップー！＊\nみんなでビーチへ出発！\n最高の休暇が待っている！"
		
	panel.add_child(label)
	
	await get_tree().create_timer(4.5).timeout
	canvas.queue_free()
	_silenciar_musica_nivel()
	_iniciar_caminata_todos()

func _silenciar_musica_nivel():
	var musica_nivel = get_tree().current_scene.find_child("Day1theme", true, false)
	if musica_nivel and musica_nivel is AudioStreamPlayer:
		print("--- [AUTO] Muteando la música principal Day1theme... ---")
		var tw = create_tween()
		tw.tween_property(musica_nivel, "volume_db", -80.0, 1.5)
		tw.tween_callback(func(): musica_nivel.stop())

func _iniciar_caminata_todos():
	jugador = get_tree().get_first_node_in_group("player")
	var npcs_brutos = get_tree().get_nodes_in_group("npcs")
	
	npcs_en_escena = []
	for n in npcs_brutos:
		if n != jugador:
			npcs_en_escena.append(n)
			
	print("--- [AUTO] Caminata iniciada. Total NPCs a subir: ", npcs_en_escena.size(), " ---")
	
	var pos_puerta = punto_puerta.global_position if punto_puerta else Vector3.ZERO
	
	if is_instance_valid(jugador):
		jugador.set_physics_process(false)
		_mover_sketch_jugador(pos_puerta, global_position)
		
	for npc in npcs_en_escena:
		if is_instance_valid(npc) and npc.has_method("caminar_hacia_destino"):
			npc.caminar_hacia_destino(global_position, pos_puerta, _on_npc_llego_al_auto)
		else:
			print("⚠️ [AUTO] Nodo no caminante detectado. Omitiendo...")
			_on_npc_llego_al_auto(null)

	_iniciar_timer_seguridad_salida()

func _iniciar_timer_seguridad_salida():
	await get_tree().create_timer(10.0).timeout
	if not salida_iniciada:
		print("⚠️ [AUTO] TIEMPO LÍMITE: Forzando la salida por retraso de personajes.")
		salida_iniciada = true
		animar_salida_auto()

func _mover_sketch_jugador(pos_puerta: Vector3, pos_final: Vector3):
	var tween = create_tween()
	var sprite = jugador.find_child("AnimatedSprite3D", true, false)
	if not sprite:
		sprite = jugador.find_child("Sprite3D", true, false)
		
	if sprite and "sprite_frames" in sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation("walk"):
		sprite.play("walk")

	var orientar_sketch = func(destino: Vector3):
		if sprite and "flip_h" in sprite:
			sprite.flip_h = (destino.x < jugador.global_position.x)

	if pos_puerta != Vector3.ZERO:
		orientar_sketch.call(pos_puerta)
		var dist1 = jugador.global_position.distance_to(pos_puerta)
		tween.tween_property(jugador, "global_position", pos_puerta, dist1 / 3.0)
		
		tween.tween_callback(func(): orientar_sketch.call(pos_final))
		
		var dist2 = pos_puerta.distance_to(pos_final)
		tween.tween_property(jugador, "global_position", pos_final, dist2 / 3.0)
	else:
		orientar_sketch.call(pos_final)
		var dist = jugador.global_position.distance_to(pos_final)
		tween.tween_property(jugador, "global_position", pos_final, dist / 3.0)
		
	tween.tween_callback(func():
		if is_instance_valid(jugador):
			jugador.hide()
		sketch_subido = true
		_verificar_si_estan_todos_listos()
	)

func _on_npc_llego_al_auto(npc_node: Node):
	if is_instance_valid(npc_node):
		npc_node.queue_free()
	npcs_subidos += 1
	print("--- [AUTO] NPC subió. Contador: ", npcs_subidos, " / ", npcs_en_escena.size(), " ---")
	_verificar_si_estan_todos_listos()

func _verificar_si_estan_todos_listos():
	if npcs_subidos >= npcs_en_escena.size() and sketch_subido and not salida_iniciada:
		salida_iniciada = true
		print("--- [AUTO] ¡Todos a bordo! El auto arranca en 0.8s... ---")
		await get_tree().create_timer(0.8).timeout
		animar_salida_auto()

func animar_salida_auto():
	print("--- [AUTO] Ejecutando animar_salida_auto() de Derecha a Izquierda ---")
	_reproducir_sonido(audio_motor)

	if "freeze" in self:
		set("freeze", true)
	for child in get_children():
		if child is CollisionShape3D:
			child.disabled = true

	var pos_origen = global_position
	var pos_retroceso = pos_origen + Vector3(1.5, 0, 0)
	var pos_salida = pos_origen - Vector3(40.0, 0, 0)

	var tw = create_tween().set_parallel(false)
	
	tw.tween_property(self, "global_position", pos_retroceso, 0.6)\
	  .set_trans(Tween.TRANS_SINE)\
	  .set_ease(Tween.EASE_IN_OUT)
	  
	tw.tween_interval(0.2)
	
	tw.tween_property(self, "global_position", pos_salida, 2.2)\
	  .set_trans(Tween.TRANS_QUAD)\
	  .set_ease(Tween.EASE_IN)
	  
	tw.tween_callback(iniciar_escena_viaje)

func _reproducir_sonido(reproductor: AudioStreamPlayer):
	if reproductor and reproductor.stream:
		reproductor.play()
	else:
		for child in get_children():
			if (child is AudioStreamPlayer or child is AudioStreamPlayer3D) and child.has_method("play"):
				if child.stream != null:
					child.play()
					break

func iniciar_escena_viaje():
	print("--- [AUTO] Entrada a iniciar_escena_viaje() ---")
	estado_actual = Estado.VIAJANDO
	
	if mapa_3d: 
		print("--- [AUTO] Ocultando Mapa3D ---")
		mapa_3d.hide()
	else:
		print("⚠️ [AUTO] Alerta: mapa_3d no está asignado en el Inspector!")
		
	if interior_auto_ui: 
		print("--- [AUTO] Mostrando InteriorAutoUI ---")
		interior_auto_ui.show()
	else:
		print("❌ [AUTO] ERROR CRÍTICO: interior_auto_ui es NULL/No asignado en el Inspector!")
		
	emit_signal("secuencia_completa")
	_secuencia_viaje_hacia_playa()

func _secuencia_viaje_hacia_playa():
	print("--- [AUTO] Buscando música, fondo y luz interior... ---")
	var musica_auto: AudioStreamPlayer = null
	var fondo_carretera: CanvasItem = null
	var luz_auto: Node = null
	
	# Buscar nodos en la UI
	if interior_auto_ui:
		musica_auto = interior_auto_ui.find_child("CarTheme", true, false) as AudioStreamPlayer
		fondo_carretera = interior_auto_ui.find_child("FondoCarretera", true, false) as CanvasItem
		luz_auto = interior_auto_ui.find_child("light", true, false)

	# 1. EFECTO PARPADEO DE LUZ VIEJA (light)
	if luz_auto:
		_animar_parpadeo_luz_vieja(luz_auto)

	# 2. EFECTO DE ANOCHECER (Modular FondoCarretera)
	if fondo_carretera:
		print("--- [AUTO] Iniciando transición a la noche en FondoCarretera... ---")
		var tw_noche = create_tween()
		tw_noche.tween_property(fondo_carretera, "modulate", Color(0.15, 0.18, 0.35, 1.0), 28.0)\
				.set_trans(Tween.TRANS_SINE)\
				.set_ease(Tween.EASE_IN_OUT)

	# 3. INICIAR MÚSICA
	if musica_auto and musica_auto.stream:
		print("--- [AUTO] Reproduciendo CarTheme... ---")
		musica_auto.volume_db = 0.0
		musica_auto.play()

	# 4. TIEMPO DE VIAJE (26s antes del fadeout)
	await get_tree().create_timer(26.0).timeout

	# 5. FADEOUT DE MÚSICA (Últimos 4s)
	if musica_auto and musica_auto.playing:
		print("--- [AUTO] Aplicando Fadeout a la música CarTheme... ---")
		var tw_audio = create_tween()
		tw_audio.tween_property(musica_auto, "volume_db", -80.0, 4.0)\
				 .set_trans(Tween.TRANS_SINE)\
				 .set_ease(Tween.EASE_IN)

	await get_tree().create_timer(4.0).timeout

	# 6. TRANSICIÓN DE CAMBIO DE ESCENA CON SHADER
	print("--- [AUTO] Viaje finalizado. Iniciando transición con Shader... ---")
	
	var ruta_final = ruta_escena_playa
	if not ResourceLoader.exists(ruta_final):
		if ResourceLoader.exists("res://scenes/Beachday.tscn"):
			ruta_final = "res://scenes/Beachday.tscn"
		elif ResourceLoader.exists("res://Beachday.tscn"):
			ruta_final = "res://Beachday.tscn"
		else:
			print("❌ [AUTO] ERROR CRÍTICO: No se pudo encontrar Beachday.tscn")
			return

	# Ejecutar animación del Shader antes de cambiar de escena
	await _ejecutar_transicion_shader()

	if musica_auto:
		musica_auto.stop()
		
	get_tree().change_scene_to_file(ruta_final)

# --- FUNCIÓN DE PARPADEO DE LUZ ---
func _animar_parpadeo_luz_vieja(luz: Node):
	luz.hide()
	await get_tree().create_timer(0.3).timeout
	
	# Secuencia rápida de falso contacto / encendido viejo
	var parpadeos = [0.08, 0.15, 0.05, 0.2, 0.06]
	for t in parpadeos:
		luz.visible = !luz.visible
		await get_tree().create_timer(t).timeout
		
	luz.show() # Queda encendida finalmente

# --- FUNCIÓN DE TRANSICIÓN SHADER ---
func _ejecutar_transicion_shader():
	var canvas_trans = CanvasLayer.new()
	canvas_trans.layer = 100 # Encima de todo
	add_child(canvas_trans)
	
	var rect = ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.color = Color.BLACK # Fondo base por si acaso
	
	if shader_transicion:
		var mat = ShaderMaterial.new()
		mat.shader = shader_transicion
		mat.set_shader_parameter("luminance_cutoff", 0.0)
		mat.set_shader_parameter("invert", false)
		if mascara_transicion:
			mat.set_shader_parameter("mask_texture", mascara_transicion)
			
		rect.material = mat
		canvas_trans.add_child(rect)
		
		var tw = create_tween()
		tw.tween_property(mat, "2d_uniform/luminance_cutoff", 1.0, 1.5)\
		  .set_trans(Tween.TRANS_SINE)\
		  .set_ease(Tween.EASE_IN_OUT)
		await tw.finished
	else:
		# Fallback por si no asignaste el shader en el Inspector todavía
		print("⚠️ [AUTO] Shader no asignado en el Inspector. Usando Fade a Negro clásico...")
		rect.color = Color(0, 0, 0, 0)
		canvas_trans.add_child(rect)
		var tw = create_tween()
		tw.tween_property(rect, "color:a", 1.0, 1.2)
		await tw.finished
