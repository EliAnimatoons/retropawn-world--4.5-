extends Control

var accion_a_cambiar = ""

@onready var boton_idioma = $BotonIdioma
@onready var boton_shaders = $BtnShaders 

@onready var slider_musica = %HSliderMusica
@onready var slider_efectos = %HSliderEfectos
@onready var slider_resolucion = %HSliderResolucion # <--- El slider de resolución

@onready var label_music_title = %LabelMusic
@onready var label_effects_title = %LabelEffects
@onready var label_resolucion_title = %LabelResolucion # <--- Label opcional para ver el %

func _ready():
	actualizar_interfaz_idioma() 
	
	# Sincronizar sliders con los valores guardados
	if slider_musica: 
		slider_musica.value = ProgresoJuego.vol_musica
	if slider_efectos: 
		slider_efectos.value = ProgresoJuego.vol_efectos
	if slider_resolucion:
		slider_resolucion.value = ProgresoJuego.escala_3d
		if not slider_resolucion.value_changed.is_connected(_on_h_slider_resolucion_value_changed):
			slider_resolucion.value_changed.connect(_on_h_slider_resolucion_value_changed)
	
	# Aplicar la resolución al entrar a la escena
	aplicar_resolucion_3d(ProgresoJuego.escala_3d)

	if boton_shaders:
		if boton_shaders.pressed.is_connected(_on_boton_shaders_pressed):
			boton_shaders.pressed.disconnect(_on_boton_shaders_pressed)
		boton_shaders.pressed.connect(_on_boton_shaders_pressed)
		actualizar_texto_shaders()

	if has_node("VBoxContainer"):
		for boton in $VBoxContainer.get_children():
			if boton is Button:
				if boton.name == "BtnVolver":
					if not boton.pressed.is_connected(_on_volver_pressed):
						boton.pressed.connect(_on_volver_pressed)
				else:
					if not boton.pressed.is_connected(_on_boton_config_pressed):
						boton.pressed.connect(_on_boton_config_pressed.bind(boton))
					actualizar_texto_boton(boton)

func _on_h_slider_resolucion_value_changed(value: float) -> void:
	var escala: float = value
	
	# Si en el Inspector el slider va de 25 a 100, lo convertimos a decimal (0.25 a 1.0)
	if value > 2.0:
		escala = value / 100.0
		
	ProgresoJuego.escala_3d = escala
	aplicar_resolucion_3d(escala)
	actualizar_texto_resolucion()

func aplicar_resolucion_3d(valor: float) -> void:
	# Ajusta la resolución interna del motor 3D
	get_viewport().scaling_3d_scale = valor

func actualizar_texto_resolucion() -> void:
	if not label_resolucion_title: return
	var porcentaje = int(ProgresoJuego.escala_3d * 100)
	
	if ProgresoJuego.idioma == "en":
		label_resolucion_title.text = "3D RESOLUTION: " + str(porcentaje) + "%"
	elif ProgresoJuego.idioma == "es":
		label_resolucion_title.text = "RESOLUCIÓN 3D: " + str(porcentaje) + "%"
	elif ProgresoJuego.idioma == "ja":
		label_resolucion_title.text = "3D解像度: " + str(porcentaje) + "%"

func _on_h_slider_musica_value_changed(value: float) -> void:
	var bus_index = AudioServer.get_bus_index("Musica")
	if bus_index != -1:
		AudioServer.set_bus_volume_db(bus_index, linear_to_db(value))
		AudioServer.set_bus_mute(bus_index, value < 0.01)
	ProgresoJuego.vol_musica = value

func _on_h_slider_efectos_value_changed(value: float) -> void:
	var bus_index = AudioServer.get_bus_index("Efectos")
	if bus_index != -1:
		AudioServer.set_bus_volume_db(bus_index, linear_to_db(value))
		AudioServer.set_bus_mute(bus_index, value < 0.01)
	ProgresoJuego.vol_efectos = value

func _on_slider_drag_ended(_value_changed: bool) -> void:
	ProgresoJuego.guardar_partida()

func actualizar_interfaz_idioma():
	if ProgresoJuego.idioma == "en":
		boton_idioma.text = "Language: English"
		if label_music_title: label_music_title.text = "MUSIC"
		if label_effects_title: label_effects_title.text = "EFFECTS"
		if has_node("VBoxContainer/BtnVolver"): $VBoxContainer/BtnVolver.text = "Back"
	elif ProgresoJuego.idioma == "es":
		boton_idioma.text = "Idioma: Español"
		if label_music_title: label_music_title.text = "MÚSICA"
		if label_effects_title: label_effects_title.text = "EFECTOS"
		if has_node("VBoxContainer/BtnVolver"): $VBoxContainer/BtnVolver.text = "Volver"
	elif ProgresoJuego.idioma == "ja":
		boton_idioma.text = "言語: 日本語"
		if label_music_title: label_music_title.text = "音楽"
		if label_effects_title: label_effects_title.text = "効果音"
		if has_node("VBoxContainer/BtnVolver"): $VBoxContainer/BtnVolver.text = "戻る"
	
	actualizar_texto_shaders()
	actualizar_texto_resolucion()
	
	if has_node("VBoxContainer"):
		for boton in $VBoxContainer.get_children():
			if boton is Button and boton.name != "BtnVolver":
				actualizar_texto_boton(boton)

func actualizar_texto_boton(boton):
	var accion = boton.name.replace("Btn", "").to_lower()
	var eventos = InputMap.action_get_events(accion)
	var nombre_accion = ""
	match accion:
		"arriba": 
			if ProgresoJuego.idioma == "es": nombre_accion = "Arriba"
			elif ProgresoJuego.idioma == "ja": nombre_accion = "上"
			else: nombre_accion = "Up"
		"abajo": 
			if ProgresoJuego.idioma == "es": nombre_accion = "Abajo"
			elif ProgresoJuego.idioma == "ja": nombre_accion = "下"
			else: nombre_accion = "Down"
		"izquierda": 
			if ProgresoJuego.idioma == "es": nombre_accion = "Izquierda"
			elif ProgresoJuego.idioma == "ja": nombre_accion = "左"
			else: nombre_accion = "Left"
		"derecha": 
			if ProgresoJuego.idioma == "es": nombre_accion = "Derecha"
			elif ProgresoJuego.idioma == "ja": nombre_accion = "右"
			else: nombre_accion = "Right"
		"salto": 
			if ProgresoJuego.idioma == "es": nombre_accion = "Salto"
			elif ProgresoJuego.idioma == "ja": nombre_accion = "ジャンプ"
			else: nombre_accion = "Jump"
		"ataque": 
			if ProgresoJuego.idioma == "es": nombre_accion = "Ataque"
			elif ProgresoJuego.idioma == "ja": nombre_accion = "攻撃"
			else: nombre_accion = "Attack"
		"parry": 
			if ProgresoJuego.idioma == "es": nombre_accion = "Parry"
			elif ProgresoJuego.idioma == "ja": nombre_accion = "パリィ"
			else: nombre_accion = "Parry"
		_: nombre_accion = accion.capitalize() 
	
	if eventos.size() > 0:
		boton.text = nombre_accion + ": " + eventos[0].as_text()
	else:
		var no_key_text = "No key"
		if ProgresoJuego.idioma == "es": no_key_text = "Sin tecla"
		elif ProgresoJuego.idioma == "ja": no_key_text = "キーなし"
		boton.text = nombre_accion + ": " + no_key_text

func _on_boton_config_pressed(boton):
	accion_a_cambiar = boton.name.replace("Btn", "").to_lower()
	var press_text = "Press a key..."
	if ProgresoJuego.idioma == "es": press_text = "Presiona una tecla..."
	elif ProgresoJuego.idioma == "ja": press_text = "キーを押して..."
	boton.text = press_text

func _input(event):
	if accion_a_cambiar != "" and event is InputEventKey and event.is_pressed():
		_re_mapear_accion(accion_a_cambiar, event)
		accion_a_cambiar = ""

func _re_mapear_accion(accion, nuevo_evento):
	InputMap.action_erase_events(accion)
	InputMap.action_add_event(accion, nuevo_evento)
	var nombre_boton = "Btn" + accion.capitalize()
	if has_node("VBoxContainer/" + nombre_boton):
		actualizar_texto_boton(get_node("VBoxContainer/" + nombre_boton))

func _on_volver_pressed():
	ProgresoJuego.guardar_partida()
	Cargador.ir_a_escena("res://menu_inicio.tscn")

func _on_boton_idioma_pressed():
	if ProgresoJuego.idioma == "en":
		ProgresoJuego.idioma = "es"
	elif ProgresoJuego.idioma == "es":
		ProgresoJuego.idioma = "ja"
	else:
		ProgresoJuego.idioma = "en"
	ProgresoJuego.guardar_partida()
	actualizar_interfaz_idioma()
	var gato = get_parent().find_child("Gatito", true, false)
	if gato and gato.has_method("actualizar_idioma_gato"):
		gato.actualizar_idioma_gato()

func _on_boton_shaders_pressed():
	ProgresoJuego.shaders_activos = !ProgresoJuego.shaders_activos
	get_tree().call_group("post_process_nodes", "update_shader_status", ProgresoJuego.shaders_activos)
	actualizar_texto_shaders()
	ProgresoJuego.guardar_partida()

func actualizar_texto_shaders():
	if not boton_shaders: return
	var etiqueta = ""
	var estado = ""
	if ProgresoJuego.idioma == "en":
		etiqueta = "Visual Effects: "
		estado = "ON" if ProgresoJuego.shaders_activos else "OFF"
	elif ProgresoJuego.idioma == "es":
		etiqueta = "Efectos Visuales: "
		estado = "Activados" if ProgresoJuego.shaders_activos else "Desactivados"
	elif ProgresoJuego.idioma == "ja":
		etiqueta = "ビジュアルエフェクト: "
		estado = "オン" if ProgresoJuego.shaders_activos else "オフ"
	boton_shaders.text = etiqueta + estado
