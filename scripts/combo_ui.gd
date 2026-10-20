extends CanvasLayer

@onready var label = $ComboControl/Label
@onready var audio_player = $ComboControl/AudioStreamPlayer

var combo_actual = 0
var tiempo_limite = 4.0 
var timer_combo : SceneTreeTimer
var tween_actual : Tween 

var combos = [
	{"texto": "RETROKILL!", "sonido": "res://sonidos/combo1.mp3"},
	{"texto": "DOBLEKILL!", "sonido": "res://sonidos/combo2.mp3"},
	{"texto": "TRIPLEKILL!", "sonido": "res://sonidos/combo3.mp3"},
	{"texto": "KILLING SPREE!", "sonido": "res://sonidos/combo4.mp3"},
	{"texto": "MEGA KILL!", "sonido": "res://sonidos/combo5.mp3"},
	{"texto": "M-M-MONSTER KILL!", "sonido": "res://sonidos/combo6.mp3"},
	{"texto": "CARNAGE!", "sonido": "res://sonidos/combo7.mp3"},
	{"texto": "CHAOTIC!", "sonido": "res://sonidos/combo8.mp3"}
]

func _ready():
	label.text = ""
	add_to_group("combo_manager")
	label.pivot_offset = label.size / 2

func registrar_muerte():
	combo_actual += 1
	var indice = clamp(combo_actual - 1, 0, combos.size() - 1)
	
	mostrar_combo(combos[indice])
	
	if timer_combo: 
		timer_combo.timeout.disconnect(_on_timeout)
	
	timer_combo = get_tree().create_timer(tiempo_limite)
	timer_combo.timeout.connect(_on_timeout)

func mostrar_combo(datos):
	if tween_actual:
		tween_actual.kill()
	
	# --- 1. CONFIGURACIÓN DE TEXTO Y COLOR POR RANGO ---
	label.text = datos.texto
	label.visible = true
	label.modulate.a = 1.0 # Reset del alpha para que no empiece invisible
	
	# Definimos colores épicos según el nivel de combo
	if combo_actual <= 2:
		label.modulate = Color.WHITE # Retro/Doble
	elif combo_actual <= 4:
		label.modulate = Color.CYAN # Triple/Spree
	elif combo_actual <= 6:
		label.modulate = Color.GOLD # Mega/Monster
	else:
		label.modulate = Color.RED # Carnage/Chaotic (Peligro!)

	# --- 2. CAMERA SHAKE (Si el combo es alto) ---
	if combo_actual >= 4:
		# Intensidad proporcional al combo
		var intensidad = clamp(combo_actual * 2.0, 10.0, 25.0)
		get_tree().call_group("camera", "shake", 0.2, intensidad)

	# --- 3. POSICIONAMIENTO ---
	var screen_size = get_viewport().get_visible_rect().size
	var pos_x = randf_range(screen_size.x * 0.3, screen_size.x * 0.7)
	var pos_y_inicio = screen_size.y * 0.5 
	var pos_y_salto = pos_y_inicio - 150
	var pos_y_caida = screen_size.y + 300 
	
	label.global_position = Vector2(pos_x, pos_y_inicio)
	label.rotation = randf_range(-0.2, 0.2) # Un poquito de rotación inicial
	label.scale = Vector2(0.3, 0.3)
	
	# Sonido
	if FileAccess.file_exists(datos.sonido):
		audio_player.stream = load(datos.sonido)
		audio_player.play()
	
	# --- 4. ANIMACIÓN CON TWEEN ---
	tween_actual = create_tween()
	
	# Fase A: Pop-Up violento
	tween_actual.set_parallel(true)
	tween_actual.tween_property(label, "global_position:y", pos_y_salto, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween_actual.tween_property(label, "scale", Vector2(1.6, 1.6), 0.2).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	
	# Fase B: Pausa dramática
	tween_actual.set_parallel(false)
	var tiempo_espera = 0.4 if combo_actual < 6 else 0.8 # Los combos grandes duran más en pantalla
	tween_actual.tween_interval(tiempo_espera)
	
	# Fase C: Caída con desvanecimiento
	tween_actual.set_parallel(true)
	tween_actual.tween_property(label, "global_position:y", pos_y_caida, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween_actual.tween_property(label, "rotation", randf_range(-1.5, 1.5), 0.5)
	tween_actual.tween_property(label, "modulate:a", 0.0, 0.5)
	
	# Al terminar la caída, limpiamos el texto por las dudas
	tween_actual.set_parallel(false)
	tween_actual.tween_callback(func(): label.text = "")

func _on_timeout():
	combo_actual = 0
	label.text = ""
	print("Combo reseteado")
