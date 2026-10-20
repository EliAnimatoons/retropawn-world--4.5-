extends Node3D

@onready var camara = $Camera3D
@onready var flash_blanco = $CanvasLayer/ColorRect
@onready var dialogo_box = $CanvasLayer/CuadroDialogo
@onready var angel = $AngelRevividor
@onready var luz_angel = $AngelRevividor/OmniLight3D

# NUEVOS NODOS PARA EL RETRY
@onready var letrero_retry = $LetreroRetry
@onready var luz_retry = $LetreroRetry/LuzRetry

# NODOS DE AUDIO
@onready var sonido_viento = $SonidoViento
@onready var musica_gameover = $MusicaGameOver
@onready var sonido_okay = $SonidoOkay

var suavizado = 5.0
var ya_presionado = false 
var puede_revivir = false 

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	# Estado inicial
	flash_blanco.modulate.a = 1.0
	angel.modulate.a = 0.0
	luz_angel.light_energy = 0
	
	# Letrero escondido abajo
	letrero_retry.position.y = -5.0 
	letrero_retry.modulate.a = 0.0
	luz_retry.light_energy = 0
	
	sonido_viento.play()
	
	var t = create_tween().set_parallel(true)
	t.tween_property(flash_blanco, "modulate:a", 0.0, 4.0) 
	t.tween_property(angel, "modulate:a", 1.0, 3.0)
	t.tween_property(luz_angel, "light_energy", 3.0, 3.0)
	
	await t.finished
	preparar_dialogos()

func _process(delta):
	var m_pos = get_viewport().get_mouse_position()
	var s_size = get_viewport().get_visible_rect().size
	var rel_x = (m_pos.x - s_size.x / 2) / (s_size.x / 2)
	var rel_y = (m_pos.y - s_size.y / 2) / (s_size.y / 2)
	
	var destino = Vector3(rel_x * 0.7, -rel_y * 0.7, camara.position.z)
	camara.position = camara.position.lerp(destino, suavizado * delta)
	
	if puede_revivir and not ya_presionado:
		var tiempo = Time.get_ticks_msec() / 1000.0
		luz_retry.light_energy = 2.0 + sin(tiempo * 15.0) * 1.0

func preparar_dialogos():
	var frases = []
	var idioma = ProgresoJuego.idioma if "idioma" in ProgresoJuego else "en"
	
	if idioma == "es":
		frases = ["Final.exe: ¡Te vuelvo a revivir! ¡Tranquilo!"]
	elif idioma == "ja":
		frases = ["Final.exe：また生き返らせてやるよ！安心しろ！"]
	else:
		frases = ["Final.exe: I'm bringing u back! Don't worry!"]
	
	if not dialogo_box.terminado.is_connected(_al_terminar_dialogo):
		dialogo_box.terminado.connect(_al_terminar_dialogo)
	
	dialogo_box.iniciar_charla(frases)

func _al_terminar_dialogo():
	var t_audio = create_tween()
	t_audio.tween_property(sonido_viento, "volume_db", -40, 2.0)
	
	await get_tree().create_timer(0.5).timeout
	
	# --- EXPLICACIÓN DEL ARREGLO ---
	# Creamos el tween de entrada del letrero
	var t_retry = create_tween().set_parallel(true)
	t_retry.tween_property(letrero_retry, "position:y", 2.5, 1.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t_retry.tween_property(letrero_retry, "modulate:a", 1.0, 0.5)
	
	sonido_viento.stop()
	musica_gameover.play()
	
	# ¡IMPORTANTE! Esperamos a que la animación termine ANTES de habilitar el botón
	await t_retry.finished
	puede_revivir = true # Ahora el jugador ya puede presionar Enter sin romper nada
	print("Letrero en posición. Control habilitado.")

func _input(event):
	if event.is_action_pressed("ui_accept") and puede_revivir and not ya_presionado:
		ya_presionado = true
		revivir()

func revivir():
	if sonido_okay:
		sonido_okay.play()
	
	var t_final = create_tween().set_parallel(true)
	# Brillo extremo de confirmación
	t_final.tween_property(letrero_retry, "modulate", Color(5, 5, 5, 1), 0.2) 
	# El letrero baja (se va)
	t_final.tween_property(letrero_retry, "position:y", -5.0, 0.8).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN).set_delay(0.2)
	
	t_final.tween_property(musica_gameover, "volume_db", -40, 1.5)
	t_final.tween_property(flash_blanco, "modulate", Color.BLACK, 1.5) 
	t_final.tween_property(angel, "modulate:a", 0.0, 1.0)
	t_final.tween_property(luz_angel, "light_energy", 0.0, 1.0)
	t_final.tween_property(luz_retry, "light_energy", 0.0, 0.5)
	
	# Esperar a que el sonido termine o un tiempo prudente
	if sonido_okay and sonido_okay.playing:
		await sonido_okay.finished
	else:
		await get_tree().create_timer(1.5).timeout
	
	# Cambio de escena seguro
	var ruta_destino = ProgresoJuego.ultima_ruta_nivel
	if ruta_destino == "" or ruta_destino == "res://":
		ruta_destino = "res://scenes/MapaNiveles.tscn"
	
	if ResourceLoader.exists(ruta_destino):
		get_tree().change_scene_to_file(ruta_destino)
	else:
		get_tree().change_scene_to_file("res://scenes/SeleccionPersonajes.tscn")
