extends Control

@onready var label_dialogo = $RichTextLabel 
@onready var sprite_mark = $MarkSprite 
@onready var timer_texto = $TimerTexto
@onready var contenedor_opciones = $HBoxContainer # Según tu imagen
@onready var btn_si = $HBoxContainer/BtnSi
@onready var btn_no = $HBoxContainer/BtnNo
@onready var sonido_voz = get_node_or_null("SonidoVoz") # Añade este nodo!

var indice_dialogo = 0
var lista_dialogos = []
var esperando_eleccion = false
var animacion_actual = "default"
var animacion_habla = "defaulttalk"

# --- DICCIONARIO DE TEXTOS ---
var textos = {
	"es": {
		"hola": "¡Hola %s! Un gusto ver al ciudadano ejemplar de RetroPawnWORLD!",
		"jane_extra": "¡JANEEE! Qué bueno verte! Me alegra ver a alguien conocido aquí! Déjame adivinar... ¿Un glitch en tu mundo te trajo aquí? JAJAJAJA, ¡Maldito Final.exe!",
		"pregunta": "En fin... Si entraste aquí es porque quieres escuchar mi historia, ¿no?",
		"no_opcion": "Oh... ¡Bueno! De todos modos puedes regresar aquí cuando quieras un poco de historia de viejos JAJAJAJA.",
		"si_opcion": "¡Vamos! Yo vengo de 'Cosmic World'. En mi mundo soy un oficial de policía junto a Michael. Ambos luchamos contra criminales.",
		"historia_1": "Entramos a RetroPawnWORLD en busca de un asesino en serie llamado 'Meow.exe'. Por lo visto... ¡Fue una trampa más de Final.exe!",
		"historia_2": "Si logras ver a Meow.exe ¡avísanos! Es muy peligroso. Se lo ha condenado por la muerte de 4 programadores y aun así logró escapar.",
		"historia_3": "En fin... Te cuento cómo perdí mi diente y ojo. En Cosmic World hubo una explosión en un laboratorio muy reconocido.",
		"historia_4": "El experimento salió mal y entes galácticos escaparon de ese portal. Ahora solo nosotros podemos detenerlos con la gran ciencia.",
		"despedida": "¡Ten cuidado ahí fuera!"
	},
	"en": { "hola": "Hello %s!...", "jane_extra": "JANEEE!...", "pregunta": "Anyway... hear my story?", "no_opcion": "Oh... Well!...", "si_opcion": "Let's go!...", "historia_1": "...", "historia_2": "...", "historia_3": "...", "historia_4": "...", "despedida": "..." }
}

func _ready():
	contenedor_opciones.hide()
	var personaje_nombre = GameManager.personaje_elegido.capitalize()
	
	# Configuración inicial de animaciones
	animacion_actual = "default"
	animacion_habla = "defaulttalk"
	sprite_mark.play(animacion_actual)
	
	preparar_introduccion(personaje_nombre)
	avanzar_dialogo()
	
	btn_si.pressed.connect(_on_elegir_si)
	btn_no.pressed.connect(_on_elegir_no)

func preparar_introduccion(nombre):
	var lang = ProgresoJuego.idioma
	if GameManager.personaje_elegido.to_lower() == "jane":
		lista_dialogos.append(textos[lang]["jane_extra"])
	else:
		lista_dialogos.append(textos[lang]["hola"] % nombre)
	lista_dialogos.append(textos[lang]["pregunta"])

func avanzar_dialogo():
	if esperando_eleccion: return
	
	if indice_dialogo < lista_dialogos.size():
		var texto = lista_dialogos[indice_dialogo]
		
		# Cambiar a animación de pregunta si toca
		if texto == textos[ProgresoJuego.idioma]["pregunta"]:
			animacion_actual = "question"
			animacion_habla = "question" # O si tienes una de habla para pregunta
			esperando_eleccion = true
		
		mostrar_texto(texto)
		indice_dialogo += 1
	else:
		Cargador.ir_a_escena("res://scenes/MapaNiveles.tscn")

func mostrar_texto(t: String):
	label_dialogo.text = t
	label_dialogo.visible_characters = 0
	sprite_mark.play(animacion_habla) # Empieza a hablar
	timer_texto.start()

func _on_timer_texto_timeout():
	if label_dialogo.visible_characters < label_dialogo.text.length():
		label_dialogo.visible_characters += 1
		
		# Efecto Undertale: Sonido cada 2 caracteres para que no sature
		if label_dialogo.visible_characters % 2 == 0 and sonido_voz:
			sonido_voz.pitch_scale = randf_range(0.9, 1.1)
			sonido_voz.play()
	else:
		timer_texto.stop()
		sprite_mark.play(animacion_actual) # Deja de hablar y vuelve a pose fija
		if esperando_eleccion:
			contenedor_opciones.show()

func _input(event):
	if event.is_action_pressed("ui_accept"):
		if label_dialogo.visible_characters < label_dialogo.text.length():
			label_dialogo.visible_characters = label_dialogo.text.length()
		elif not esperando_eleccion:
			avanzar_dialogo()

func _on_elegir_si():
	var lang = ProgresoJuego.idioma
	esperando_eleccion = false
	contenedor_opciones.hide()
	
	# Cambiamos a animaciones felices
	animacion_actual = "feliz"
	animacion_habla = "feliztalk"
	
	lista_dialogos.append(textos[lang]["si_opcion"])
	lista_dialogos.append(textos[lang]["historia_1"])
	lista_dialogos.append(textos[lang]["historia_2"])
	lista_dialogos.append(textos[lang]["historia_3"])
	lista_dialogos.append(textos[lang]["historia_4"])
	lista_dialogos.append(textos[lang]["despedida"])
	avanzar_dialogo()

func _on_elegir_no():
	var lang = ProgresoJuego.idioma
	esperando_eleccion = false
	contenedor_opciones.hide()
	
	# Cambiamos a animaciones serias
	animacion_actual = "serio"
	animacion_habla = "serio" # Mark serio no mueve mucho la boca si quieres
	
	lista_dialogos.append(textos[lang]["no_opcion"])
	avanzar_dialogo()
