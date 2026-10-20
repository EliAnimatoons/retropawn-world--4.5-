extends Node

@export_group("Referencias de Escena")
@export var personaje_base : Area3D 
@export var marcador_puntos : Node3D 
@export var mundo_pivot : Node3D 
@export var camara_principal : Camera3D

@export_group("Sonidos")
@export var lista_musica_ambiente : Array[AudioStream]
@export var win_player : AudioStreamPlayer 
@export var loss_player : AudioStreamPlayer 
@onready var bg_music_player = AudioStreamPlayer.new()

@export_group("Interfaz")
@export var pantalla_victoria : Control
@export var pantalla_derrota : Control
@export var label_resultado : Label
@export var boton_accion : Button
@export var label_tiempo : Label
@export var label_ronda : Label
@export var lupa_animada : AnimatedSprite2D 
@export var foto_0 : TextureRect
@export var foto_9 : TextureRect

@export_group("Dificultad")
@export var poblacion_total = 25 
@export var tiempo_inicial = 40.0
@export var reduccion_por_ronda = 2.0
@export var tiempo_minimo = 10.0
@export var castigo_tiempo = 2.0 

@export_group("Efecto Noche (Ronda 7+)")
@export var linterna : SpotLight3D 
@export var sol : DirectionalLight3D 
@export var world_env : WorldEnvironment 

@export_group("Configuración Zoom")
@export var fov_normal = 75.0
@export var fov_zoom = 30.0
@export var velocidad_zoom = 8.0

var ronda_actual = 1 
var objetivos_pendientes = []
var juego_detenido = false
var tiempo_restante = 0.0
var idioma_actual = "es"
var fov_deseado = 75.0

func _ready():
	add_child(bg_music_player)
	if not marcador_puntos or not mundo_pivot: 
		print("ERROR: Referencias faltantes")
		return
	
	if pantalla_victoria: pantalla_victoria.hide()
	if pantalla_derrota: pantalla_derrota.hide()
	if linterna: linterna.hide()
	if lupa_animada: lupa_animada.hide()
	
	fov_deseado = fov_normal
	generar_ronda()

func _input(event):
	if juego_detenido: return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			fov_deseado = clamp(fov_deseado - 5, fov_zoom, fov_normal)
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			fov_deseado = clamp(fov_deseado + 5, fov_zoom, fov_normal)

func _process(delta):
	if not juego_detenido:
		tiempo_restante -= delta
		if label_tiempo: 
			label_tiempo.text = str(ceil(tiempo_restante))
		if tiempo_restante <= 0: 
			_finalizar_ronda(false)
		
		_gestionar_zoom_y_lupa(delta)
		
		if ronda_actual >= 7 and linterna and linterna.visible:
			_apuntar_linterna()

func _gestionar_zoom_y_lupa(delta):
	if not camara_principal: return
	var usando_zoom = Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
	
	if usando_zoom:
		camara_principal.fov = lerp(camara_principal.fov, fov_zoom, velocidad_zoom * delta)
	else:
		camara_principal.fov = lerp(camara_principal.fov, fov_deseado, velocidad_zoom * delta)
	
	if camara_principal.fov < 45.0 and not juego_detenido:
		if lupa_animada:
			lupa_animada.show()
			lupa_animada.play("default")
			lupa_animada.global_position = get_viewport().get_mouse_position()
			Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	else:
		if lupa_animada: lupa_animada.hide()
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _apuntar_linterna():
	var mouse_pos = get_viewport().get_mouse_position()
	var ray_direction = camara_principal.project_ray_normal(mouse_pos)
	linterna.global_position = camara_principal.global_position
	linterna.look_at(camara_principal.global_position + ray_direction * 10.0)

func generar_ronda():
	juego_detenido = false
	fov_deseado = fov_normal
	
	# Fix del error de Nil: aseguramos que los valores existan antes del cálculo
	var reduccion = reduccion_por_ronda if reduccion_por_ronda != null else 2.0
	tiempo_restante = max(tiempo_minimo, tiempo_inicial - (ronda_actual * reduccion))
	
	if label_ronda:
		match idioma_actual:
			"es": label_ronda.text = "RONDA: " + str(ronda_actual)
			"jp": label_ronda.text = "ラウンド: " + str(ronda_actual)
			_: label_ronda.text = "ROUND: " + str(ronda_actual)
	
	_reproducir_musica_aleatoria()
	_gestionar_iluminacion_noche()
	_set_mapa_visible(true)
	
	for p in get_tree().get_nodes_in_group("clones"): 
		p.queue_free()
	
	_configurar_objetivos()

func _configurar_objetivos():
	if foto_0: 
		foto_0.show()
		foto_0.modulate.a = 1.0
	if foto_9: 
		foto_9.hide()
		foto_9.modulate.a = 1.0
	
	objetivos_pendientes = [0]
	if ronda_actual >= 5:
		objetivos_pendientes.append(9)
		if foto_9: foto_9.show()
	
	var puntos = marcador_puntos.get_children()
	puntos.shuffle()
	
	var lista_ids = [0]
	if ronda_actual >= 5: lista_ids.append(9)
	while lista_ids.size() < min(poblacion_total, puntos.size()):
		lista_ids.append(randi_range(1, 8))
	lista_ids.shuffle()
	
	for i in range(lista_ids.size()):
		if i >= puntos.size(): break
		var clon = personaje_base.duplicate()
		clon.add_to_group("clones")
		clon.show()
		mundo_pivot.add_child(clon)
		clon.global_position = puntos[i].global_position
		
		var sprite = clon.get_node("AnimatedSprite3D")
		sprite.play(str(lista_ids[i]))
		
		# IMPORTANTE: No usamos modulate negro aquí para que la linterna funcione
		sprite.modulate = Color.WHITE

		clon.input_event.connect(func(_cam, event, _pos, _norm, _shape): 
			if not juego_detenido and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				_comprobar_objetivo(lista_ids[i])
		)

func _gestionar_iluminacion_noche():
	if ronda_actual >= 7:
		if sol: sol.light_energy = 0.0
		if world_env:
			world_env.environment.background_mode = Environment.BG_COLOR
			world_env.environment.background_color = Color.BLACK
			world_env.environment.ambient_light_energy = 0.0
		if linterna: 
			linterna.show()
			linterna.light_energy = 15.0
	else:
		if sol: sol.light_energy = 1.0
		if world_env:
			world_env.environment.background_mode = Environment.BG_SKY
			world_env.environment.ambient_light_energy = 1.0
		if linterna: linterna.hide()

func _comprobar_objetivo(id_clickeado):
	if id_clickeado in objetivos_pendientes:
		objetivos_pendientes.erase(id_clickeado)
		if id_clickeado == 0 and foto_0: foto_0.modulate.a = 0.3
		if id_clickeado == 9 and foto_9: foto_9.modulate.a = 0.3
		if objetivos_pendientes.size() == 0: 
			_finalizar_ronda(true)
	else:
		tiempo_restante -= castigo_tiempo
		if loss_player and not loss_player.playing: loss_player.play()
		if label_tiempo:
			var tw = create_tween()
			tw.tween_property(label_tiempo, "modulate", Color.RED, 0.1)
			tw.tween_property(label_tiempo, "modulate", Color.WHITE, 0.1)

func _finalizar_ronda(ganaste: bool):
	if juego_detenido: return 
	juego_detenido = true # FIX: Era jenido_detenido antes
	
	if lupa_animada: lupa_animada.hide()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	var tween = create_tween()
	tween.tween_property(bg_music_player, "pitch_scale", 0.01, 1.2)
	tween.finished.connect(func(): bg_music_player.stop())
	
	if sol: sol.light_energy = 1.0
	if linterna: linterna.hide()
	
	_revelar_objetivos() 
	_actualizar_textos_ui(ganaste)
	
	if ganaste:
		_crear_confeti()
		if win_player: win_player.play()
		await get_tree().create_timer(2.0).timeout
		if pantalla_victoria: pantalla_victoria.show()
		ronda_actual += 1
	else:
		if loss_player: loss_player.play()
		await get_tree().create_timer(2.0).timeout
		if pantalla_derrota: pantalla_derrota.show()

func _revelar_objetivos():
	_set_mapa_visible(false)
	for clon in get_tree().get_nodes_in_group("clones"):
		var sprite = clon.get_node("AnimatedSprite3D")
		sprite.modulate = Color.WHITE
		if sprite.animation == "0": continue
		if ronda_actual >= 5 and sprite.animation == "9": continue
		clon.queue_free()

func _reproducir_musica_aleatoria():
	if lista_musica_ambiente.size() > 0:
		bg_music_player.stream = lista_musica_ambiente.pick_random()
		bg_music_player.pitch_scale = 1.0
		bg_music_player.play()

func _set_mapa_visible(valor: bool):
	var casas = mundo_pivot.get_node_or_null("houses")
	var arboles = mundo_pivot.get_node_or_null("Arbol_Base")
	if casas: casas.visible = valor
	if arboles: arboles.visible = valor

func _actualizar_textos_ui(ganaste: bool):
	var l = label_resultado
	var b = boton_accion
	if not l or not b: return
	if ganaste:
		match idioma_actual:
			"es": l.text = "¡LOS ENCONTRASTE!"; b.text = "CONTINUAR"
			"jp": l.text = "見つけた！"; b.text = "次へ"
			_: l.text = "YOU FOUND THEM!"; b.text = "CONTINUE"
	else:
		match idioma_actual:
			"es": l.text = "¡TIEMPO AGOTADO!"; b.text = "REINTENTAR"
			"jp": l.text = "時間切れ！"; b.text = "リトライ"
			_: l.text = "TIME'S UP!"; b.text = "RETRY"

func _crear_confeti():
	for i in range(20):
		var p = ColorRect.new()
		p.color = Color(randf(), randf(), randf()) 
		p.custom_minimum_size = Vector2(10, 10)
		p.position = Vector2(randf_range(0, 1000), -50)
		get_tree().root.add_child(p)
		var t = create_tween()
		t.tween_property(p, "position:y", 800, randf_range(1.5, 3.0))
		t.finished.connect(func(): p.queue_free())

func _on_boton_continuar_pressed():
	if pantalla_victoria: pantalla_victoria.hide()
	generar_ronda()

func _on_boton_reintentar_pressed():
	if pantalla_derrota: pantalla_derrota.hide()
	ronda_actual = 1 
	generar_ronda()
