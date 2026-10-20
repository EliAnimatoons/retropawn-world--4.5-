extends Control

@onready var label_texto = $Label
@onready var sonido_voz = $AudioStreamPlayer # El sonido tipo Undertale

var texto_completo = ""
var indice_caracter = 0
var velocidad_texto = 0.05 # Velocidad de la escritura
var ya_termino_todo = false # Para evitar llamadas dobles a la salida

func _ready():
	# CONFIGURACIÓN VISUAL
	if label_texto:
		label_texto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label_texto.custom_minimum_size.x = 600 
	
	label_texto.text = ""
	configurar_mensaje()
	comenzar_escritura()
	
	# --- ¡OTORGAR LOGRO POR ROMPER LA REALIDAD! ---
	if not ProgresoJuego.logro_glitch_vacio:
		ProgresoJuego.otorgar_logro("logro_glitch_vacio")
	# -----------------------------------------------
	
	# --- TEMPORIZADOR GLOBAL DE SEGURIDAD (2min 10s = 130 segundos) ---
	get_tree().create_timer(130.0).timeout.connect(volver_al_mapa)

func configurar_mensaje():
	var personaje = GameManager.personaje_elegido.to_lower()
	var lang = ProgresoJuego.idioma # Detectamos el idioma ("es" o "en")
	
	if lang == "es":
		match personaje:
			"sketch":
				texto_completo = "Meow.exe: ¡Hola Sketch! ¿Sabías que aquí me encierran para que no asesine a nadie? Qué loco JAJAJA."
			"max":
				texto_completo = "Meow.exe: ¡Todo tiene consecuencias! Pero para ti no hay... relájate e hidrátate con este espacio 'Frutiger Aero'... Max..."
			"jane":
				texto_completo = "Meow.exe: ¡SAQUÉ PREMIO! ¿En serio, programador? ¡Gracias por traerme a Jane aquí! No eres tan malo después de todo jejeje."
			"prepucin":
				texto_completo = "Meow.exe: ¡Vaya insecto asqueroso! ¡¿Y TE TIENEN QUE METER AQUÍ CONMIGO?! ¡Malditos programadores! Por eso los odio... a ellos y a ti... Prepucin..."
			_:
				texto_completo = "Vaya... parece que alguien rompió la realidad de forma muy extraña."
	else:
		# --- VERSIÓN EN INGLÉS ---
		match personaje:
			"sketch":
				texto_completo = "Meow.exe: Hi Sketch! Did you know they lock me in here so I don't murder anyone? How crazy, HAHAHA."
			"max":
				texto_completo = "Meow.exe: Everything has consequences! But for you, there are none... relax and hydrate with this 'Frutiger Aero' space... Max..."
			"jane":
				texto_completo = "Meow.exe: I HIT THE JACKPOT! Seriously, programmer? Thanks for bringing Jane here! You're not so bad after all, hehehe."
			"prepucin":
				texto_completo = "Meow.exe: What a disgusting insect! AND THEY HAVE TO PUT YOU IN HERE WITH ME?! Damn programmers! That's why I hate them... them and you... ForeRat..."
			_:
				texto_completo = "Well... it seems someone broke reality in a very strange way."

func comenzar_escritura():
	indice_caracter = 0
	label_texto.text = ""
	
	var timer = get_tree().create_timer(velocidad_texto)
	timer.timeout.connect(_on_timer_timeout)

func _on_timer_timeout():
	if indice_caracter < texto_completo.length():
		label_texto.text += texto_completo[indice_caracter]
		indice_caracter += 1
		
		if sonido_voz:
			sonido_voz.pitch_scale = randf_range(0.8, 1.2)
			sonido_voz.play()
		
		get_tree().create_timer(velocidad_texto).timeout.connect(_on_timer_timeout)
	else:
		esperar_despues_de_leer()

func esperar_despues_de_leer():
	# Espera 30 segundos después de que el texto termine de escribirse
	await get_tree().create_timer(200.0).timeout
	volver_al_mapa()

func volver_al_mapa():
	if not ya_termino_todo:
		ya_termino_todo = true
		print("CapaCastigo: Volviendo al mapa de niveles.")
		get_tree().change_scene_to_file("res://scenes/MapaNiveles.tscn")

func _input(event):
	if event.is_action_pressed("ui_accept") and indice_caracter < texto_completo.length():
		indice_caracter = texto_completo.length()
		label_texto.text = texto_completo
		# Al saltar el texto, ya empieza a correr el tiempo de 30s para salir
		esperar_despues_de_leer()
