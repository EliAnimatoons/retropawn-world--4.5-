# DialogoSimple.gd
extends Control

signal terminado

@onready var texto_label: RichTextLabel = $RichTextLabel
@onready var timer_letras: Timer = $Timer
@onready var voz: AudioStreamPlayer = $VozSonido

var frases: Array[String] = []
var indice: int = 0
var interactuando: bool = false

func _ready():
	self.hide()
	timer_letras.wait_time = 0.04
	if not timer_letras.timeout.is_connected(_on_timer_timeout):
		timer_letras.timeout.connect(_on_timer_timeout)

func mostrar_dialogo(lista_frases: Array[String]):
	frases = lista_frases
	indice = 0
	self.show()
	
	# --- CONGELAR JUGADORES ---
	for p in get_tree().get_nodes_in_group("player"):
		if is_instance_valid(p):
			p.set_physics_process(false) # Detiene el movimiento del jugador
			
	escribir_frase()

func escribir_frase():
	if indice < frases.size():
		texto_label.text = frases[indice]
		texto_label.visible_characters = 0
		timer_letras.start()
	else:
		finalizar()

func _on_timer_timeout():
	if texto_label.visible_characters < texto_label.text.length():
		texto_label.visible_characters += 1
		if voz:
			var car = texto_label.text[texto_label.visible_characters - 1]
			if car not in [" ", ".", ",", "!", "?", "¡", "¿"]:
				voz.pitch_scale = randf_range(1.1, 1.3)
				voz.play()
	else:
		timer_letras.stop()

func _unhandled_input(event):
	if not self.visible: return
	
	# CAMBIADO "interactuar" POR "salto" / "ui_accept"
	if event.is_action_pressed("salto") or event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		if texto_label.visible_characters < texto_label.text.length():
			texto_label.visible_characters = texto_label.text.length()
			timer_letras.stop()
		else:
			indice += 1
			escribir_frase()

func finalizar():
	self.hide()
	
	# --- DESCONGELAR JUGADORES ---
	for p in get_tree().get_nodes_in_group("player"):
		if is_instance_valid(p):
			p.set_physics_process(true) # Reactiva el movimiento del jugador
			
	emit_signal("terminado")
