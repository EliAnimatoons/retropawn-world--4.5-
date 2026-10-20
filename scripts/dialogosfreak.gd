extends Control

signal terminado

# --- 1. DECLARACIÓN DE VARIABLES (ARRIBA DE TODO) ---
var frases = []      #
var indice = 0       #
var escribiendo = false

@onready var cara = $Cara
@onready var label = $RichTextLabel
@onready var sonido_voz = $VozSonido
@onready var fondo = $Fondo

# --- 2. FUNCIONES DEL SISTEMA ---

func _ready():
	hide() # Empezamos ocultos

func iniciar_charla_directa(lista):
	frases = lista
	indice = 0
	show()
	mostrar_frase()

func mostrar_frase():
	# Ahora Godot ya sabe qué es "frases" porque lo leyó arriba
	if indice < frases.size():
		escribiendo = true
		label.text = frases[indice]
		label.visible_ratio = 0
		
		var tween = create_tween()
		tween.tween_property(label, "visible_ratio", 1.0, 0.8)
		
		if cara: cara.play("talk") 
		if sonido_voz: sonido_voz.play()
		
		await tween.finished
		escribiendo = false
		if cara: cara.play("idle")
	else:
		cerrar()

func _input(event):
	if not visible: return
	
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("ataque"):
		if escribiendo:
			label.visible_ratio = 1.0 
		else:
			indice += 1
			mostrar_frase()

func cerrar():
	hide()
	emit_signal("terminado")
