extends Control

# Referencias a tus fondos y nodos
@onready var background: ColorRect = $Background
@onready var backgrounds: AnimatedSprite2D = $Backgrounds

@onready var score_1: Sprite2D = $Score1
@onready var score_2: Sprite2D = $Score2
@onready var character: AnimatedSprite2D = $"Sketch points"

@onready var camera: Camera2D = $Camera2D

# Labels de estadísticas
@onready var label_tiempo: Label = $LabelTiempo
@onready var label_kills: Label = $LabelKills
@onready var label_parrys: Label = $LabelParrys
@onready var label_puntaje: Label = $LabelPuntaje

# 🔘 TU BOTÓN DE CONTINUAR (Button o TextureButton).
# Arrastralo en el Inspector a este campo. Si lo dejás vacío, el script busca un nodo
# llamado "BotonContinuar" en la escena.
@export var boton_continuar: BaseButton
# Solo para botones de texto (Button). Si tu botón es una imagen, dejalo apagado.
@export var usar_texto_en_boton: bool = false

# Referencias a tus 3 AudioStreamPlayer individuales
@onready var music_a: AudioStreamPlayer = $"music A"
@onready var music_b: AudioStreamPlayer = $"music B"
@onready var music_c: AudioStreamPlayer = $"music C"

# 🔊 SONIDOS (arrastrá los archivos desde el Sistema de Archivos al Inspector)
@export_group("Sonidos")
@export var sonido_rango_a: AudioStream    # gritos y aplausos
@export var sonido_rango_b: AudioStream    # aplausos
@export var sonido_rango_c: AudioStream    # abucheo
@export var sonido_continuar: AudioStream  # "enter" / "okay" al apretar el botón
@export var volumen_sonido_rango_db: float = 0.0
@export var volumen_sonido_continuar_db: float = 0.0
# Máximo de espera antes de cambiar de escena, para que el sonido de continuar se escuche
@export var espera_max_sonido_salida: float = 0.8
@export_group("")

# Tiempos ajustables
@export var slide_duration: float = 0.6
@export var fade_duration: float = 1.0

# 🎛️ CONTROLES DE ZOOM EN EL INSPECTOR
@export var character_zoom: Vector2 = Vector2(1.3, 1.3)
@export var normal_zoom: Vector2 = Vector2(1.0, 1.0)

# 🌊 CONTROLES DE MOVIMIENTO / PANEO DE CÁMARA
@export var enable_camera_sway: bool = true
@export var sway_distance: float = 18.0
@export var sway_time: float = 3.5

# 🔢 CONTEO ANIMADO DE LOS NÚMEROS
@export_group("Conteo animado")
@export var duracion_conteo: float = 0.9          # tiempo, kills y parrys
@export var duracion_conteo_puntaje: float = 1.4  # puntaje total
@export_group("")

# Escena a la que se vuelve al terminar
@export var ruta_escena_salida: String = "res://scenes/MapaNiveles.tscn"

# =========================================================
# 🌐 TEXTOS (se eligen con ProgresoJuego.idioma: en, es, ja, id)
# =========================================================
const TEXTOS := {
	"en": {"tiempo": "TIME",   "kills": "KILLS", "parrys": "PARRIES", "puntaje": "SCORE",   "continuar": "CONTINUE"},
	"es": {"tiempo": "TIEMPO", "kills": "KILLS", "parrys": "PARRYS",  "puntaje": "PUNTAJE", "continuar": "CONTINUAR"},
	"ja": {"tiempo": "タイム",  "kills": "撃破数",  "parrys": "パリィ",   "puntaje": "スコア",   "continuar": "続ける"},
	"id": {"tiempo": "WAKTU",  "kills": "KILL",  "parrys": "PARRY",   "puntaje": "SKOR",    "continuar": "LANJUTKAN"},
}

func _t(clave: String) -> String:
	var idioma: String = str(ProgresoJuego.idioma)
	var d: Dictionary = TEXTOS.get(idioma, TEXTOS["en"])
	return str(d[clave])

# =========================================================
# 🏆 FÓRMULA DE PUNTAJE
# =========================================================
# Objetivos por nivel, por ÍNDICE (0 = tutorial, 1 = mundo1, 2 = mundo2, 3 = mundo3).
# AJUSTALOS jugando cada nivel.
const PARAMS_NIVELES := {
	0: {"tiempo_par": 90.0,  "kills": 5,  "parrys": 2},
	1: {"tiempo_par": 180.0, "kills": 15, "parrys": 5},
	2: {"tiempo_par": 150.0, "kills": 10, "parrys": 4},
	3: {"tiempo_par": 150.0, "kills": 10, "parrys": 4},
}
const PARAMS_DEFAULT := {"tiempo_par": 120.0, "kills": 10, "parrys": 3}

@export_group("Fórmula de puntaje")
@export var peso_tiempo: float = 0.35
@export var peso_kills: float = 0.40
@export var peso_parrys: float = 0.25
@export var umbral_a: float = 75.0
@export var umbral_b: float = 40.0
@export var factor_tiempo_maximo: float = 3.0

@export_group("Prueba (solo si corrés esta escena sola)")
@export var prueba_tiempo: float = 100.0
@export var prueba_kills: int = 8
@export var prueba_parrys: int = 3
@export var prueba_indice_nivel: int = 1
@export_group("")

var default_camera_pos: Vector2
var current_rank: String = "A"
var resultado: Dictionary = {}

var _tiempo_real: float = 0.0
var _kills_real: int = 0
var _parrys_real: int = 0

var _secuencia: Tween
var _secuencia_iniciada: bool = false
var _conteo_terminado: bool = false
var _puede_salir: bool = false
var _saliendo: bool = false
var _t_inicio_ms: int = 0

func _ready() -> void:
	# En los niveles el mouse puede estar oculto: acá lo necesitamos para el botón
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	default_camera_pos = camera.position

	if not character.animation_finished.is_connected(_on_character_animation_finished):
		character.animation_finished.connect(_on_character_animation_finished)

	var e: Node = get_node_or_null("/root/EstadisticasNivel")
	var indice: int = prueba_indice_nivel

	if e == null or not bool(e.get("datos_listos")):
		# Modo prueba: no toca el progreso del juego
		_tiempo_real = prueba_tiempo
		_kills_real = prueba_kills
		_parrys_real = prueba_parrys
	else:
		_tiempo_real = float(e.get("tiempo"))
		_kills_real = int(e.get("kills"))
		_parrys_real = int(e.get("parrys"))
		indice = int(e.get("indice_nivel"))
		_aplicar_progreso(indice)

	resultado = calcular_resultado(_tiempo_real, _kills_real, _parrys_real, indice)

	print("Puntaje: ", resultado["puntaje"], " | Rango: ", resultado["rango"],
		" | tiempo: ", snappedf(_tiempo_real, 0.1), " s | kills: ", _kills_real,
		" | parrys: ", _parrys_real)

	for l in [label_tiempo, label_kills, label_parrys, label_puntaje]:
		l.modulate.a = 0.0

	_preparar_boton()

	var nombre_personaje: String = str(GameManager.personaje_elegido).capitalize()
	setup_score_screen(resultado["rango"], nombre_personaje)

# =========================================================
# BOTÓN CONTINUAR (el que armás vos en la escena)
# =========================================================
func _preparar_boton() -> void:
	if boton_continuar == null:
		boton_continuar = find_child("BotonContinuar", true, false) as BaseButton

	if boton_continuar == null:
		push_warning("Score: no hay botón de continuar. Asignalo en el Inspector o nombralo 'BotonContinuar'. Mientras tanto se puede salir con la tecla de aceptar.")
		return

	if usar_texto_en_boton and boton_continuar is Button:
		(boton_continuar as Button).text = _t("continuar")
	elif boton_continuar is Button:
		# Botón de imagen: sin el fondo gris por defecto de Godot
		(boton_continuar as Button).flat = true

	# Sin recuadro de foco (el contorno feo). La tecla de aceptar igual funciona.
	boton_continuar.focus_mode = Control.FOCUS_NONE

	# Arranca oculto; aparece cuando termina el conteo
	boton_continuar.visible = false
	if not boton_continuar.pressed.is_connected(_salir):
		boton_continuar.pressed.connect(_salir)

# =========================================================
# PROGRESO: desbloquea el siguiente nivel (antes lo hacía cada mundo)
# =========================================================
func _aplicar_progreso(indice: int) -> void:
	if indice < 0:
		return
	if ProgresoJuego.nivel_desbloqueado == indice:
		ProgresoJuego.nivel_desbloqueado = indice + 1
		print("Nivel ", indice + 1, " desbloqueado.")
	ProgresoJuego.guardar_partida()

# =========================================================
# CÁLCULO DE PUNTAJE Y RANGO
# =========================================================
func calcular_resultado(tiempo: float, kills: int, parrys: int, indice: int) -> Dictionary:
	var p: Dictionary = PARAMS_NIVELES.get(indice, PARAMS_DEFAULT)

	var tiempo_par: float = p["tiempo_par"]
	var exceso: float = maxf(tiempo - tiempo_par, 0.0)
	var margen: float = maxf(tiempo_par * (factor_tiempo_maximo - 1.0), 0.001)
	var s_tiempo: float = 100.0 * clampf(1.0 - exceso / margen, 0.0, 1.0)

	var kills_obj: float = maxf(float(p["kills"]), 1.0)
	var parrys_obj: float = maxf(float(p["parrys"]), 1.0)
	var s_kills: float = 100.0 * clampf(float(kills) / kills_obj, 0.0, 1.0)
	var s_parrys: float = 100.0 * clampf(float(parrys) / parrys_obj, 0.0, 1.0)

	var suma_pesos: float = maxf(peso_tiempo + peso_kills + peso_parrys, 0.001)
	var total: float = (s_tiempo * peso_tiempo + s_kills * peso_kills + s_parrys * peso_parrys) / suma_pesos

	var rango: String = "C"
	if total >= umbral_a:
		rango = "A"
	elif total >= umbral_b:
		rango = "B"

	return {
		"rango": rango,
		"puntaje": roundi(total),
		"tiempo": s_tiempo,
		"kills": s_kills,
		"parrys": s_parrys,
	}

# =========================================================
# PANTALLA DE RESULTADOS
# =========================================================
func setup_score_screen(rank: String, character_name: String) -> void:
	current_rank = rank

	camera.position = character.position
	camera.zoom = character_zoom

	if rank == "A":
		background.visible = true
		backgrounds.visible = false
		background.modulate = Color(0, 0, 0, 1)
	else:
		background.visible = false
		backgrounds.visible = true
		backgrounds.modulate = Color(0, 0, 0, 1)
		if backgrounds.sprite_frames and backgrounds.sprite_frames.has_animation(rank):
			backgrounds.play(rank)

	_setup_character_animation(rank)
	_animate_score_sprites()

func _setup_character_animation(rank: String) -> void:
	if character.sprite_frames and character.sprite_frames.has_animation(rank):
		character.play(rank)
	else:
		push_warning("La animación '" + rank + "' no existe para este personaje.")
		_on_character_animation_finished()

## CUANDO TERMINA LA ANIMACIÓN DEL PERSONAJE
func _on_character_animation_finished() -> void:
	if _secuencia_iniciada:
		return

	var tween: Tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	if current_rank == "A":
		tween.tween_property(background, "modulate", Color(1, 1, 1, 1), fade_duration)
	else:
		tween.tween_property(backgrounds, "modulate", Color(1, 1, 1, 1), fade_duration)

	tween.tween_property(camera, "zoom", normal_zoom, fade_duration)
	tween.tween_property(camera, "position", default_camera_pos, fade_duration)

	_play_rank_music(current_rank)

	if enable_camera_sway:
		tween.chain().tween_callback(func():
			var sway_tween = create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			sway_tween.tween_property(camera, "position:x", default_camera_pos.x + sway_distance, sway_time * 0.5)
			sway_tween.tween_property(camera, "position:x", default_camera_pos.x - sway_distance, sway_time)
			sway_tween.tween_property(camera, "position:x", default_camera_pos.x, sway_time * 0.5)
		)

	_mostrar_estadisticas()

# =========================================================
# 🔢 ESTADÍSTICAS CON CONTEO ANIMADO
# =========================================================
func _mostrar_estadisticas() -> void:
	_secuencia_iniciada = true
	_t_inicio_ms = Time.get_ticks_msec()

	_set_tiempo(0.0)
	_set_kills(0.0)
	_set_parrys(0.0)
	_set_puntaje(0.0)

	# Una por una: aparece el label, el número sube desde 0 y hace un "pop"
	_secuencia = create_tween()
	_agregar_conteo(label_tiempo, _set_tiempo, _tiempo_real, duracion_conteo)
	_agregar_conteo(label_kills, _set_kills, float(_kills_real), duracion_conteo)
	_agregar_conteo(label_parrys, _set_parrys, float(_parrys_real), duracion_conteo)
	_agregar_conteo(label_puntaje, _set_puntaje, float(resultado["puntaje"]), duracion_conteo_puntaje)
	_secuencia.tween_callback(_terminar_secuencia)

func _agregar_conteo(label: Label, setter: Callable, hasta: float, duracion: float) -> void:
	_secuencia.tween_property(label, "modulate:a", 1.0, 0.2)
	_secuencia.tween_method(setter, 0.0, hasta, duracion)
	_secuencia.tween_callback(_pop.bind(label))
	_secuencia.tween_interval(0.2)

func _pop(label: Label) -> void:
	label.pivot_offset = label.size / 2.0
	var tw: Tween = create_tween()
	tw.tween_property(label, "scale", Vector2(1.25, 1.25), 0.08)
	tw.tween_property(label, "scale", Vector2.ONE, 0.12)

func _set_tiempo(v: float) -> void:
	var total: int = int(v)
	label_tiempo.text = "%s: %02d:%02d" % [_t("tiempo"), total / 60, total % 60]

func _set_kills(v: float) -> void:
	label_kills.text = "%s: %d" % [_t("kills"), roundi(v)]

func _set_parrys(v: float) -> void:
	label_parrys.text = "%s: %d" % [_t("parrys"), roundi(v)]

func _set_puntaje(v: float) -> void:
	label_puntaje.text = "%s: %d" % [_t("puntaje"), roundi(v)]

# Salta la animación y muestra los valores finales
func _saltar_conteo() -> void:
	if _secuencia and _secuencia.is_valid():
		_secuencia.kill()
	_set_tiempo(_tiempo_real)
	_set_kills(float(_kills_real))
	_set_parrys(float(_parrys_real))
	_set_puntaje(float(resultado["puntaje"]))
	for l in [label_tiempo, label_kills, label_parrys, label_puntaje]:
		l.modulate.a = 1.0
		l.scale = Vector2.ONE
	_terminar_secuencia()

func _terminar_secuencia() -> void:
	if _conteo_terminado:
		return
	_conteo_terminado = true
	_puede_salir = true

	# Suena el efecto del rango justo cuando aparece el puntaje final
	_reproducir_sonido_rango()

	if boton_continuar:
		boton_continuar.modulate.a = 0.0
		boton_continuar.visible = true
		create_tween().tween_property(boton_continuar, "modulate:a", 1.0, 0.3)

# =========================================================
# 🔊 SONIDOS
# =========================================================
func _reproducir(stream: AudioStream, volumen_db: float) -> AudioStreamPlayer:
	if stream == null:
		return null
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.volume_db = volumen_db
	if AudioServer.get_bus_index("Efectos") != -1:
		p.bus = "Efectos"
	add_child(p)
	p.finished.connect(p.queue_free)
	p.play()
	return p

func _reproducir_sonido_rango() -> void:
	match current_rank:
		"A":
			_reproducir(sonido_rango_a, volumen_sonido_rango_db)
		"B":
			_reproducir(sonido_rango_b, volumen_sonido_rango_db)
		_:
			_reproducir(sonido_rango_c, volumen_sonido_rango_db)

# =========================================================
# MÚSICA Y SPRITES
# =========================================================
func _play_rank_music(rank: String) -> void:
	music_a.stop()
	music_b.stop()
	music_c.stop()

	if rank == "A":
		music_a.play()
	elif rank == "B":
		music_b.play()
	elif rank == "C":
		music_c.play()

func _animate_score_sprites() -> void:
	var viewport_size: Vector2 = get_viewport_rect().size

	var target_score1_pos: Vector2 = score_1.position
	var target_score2_pos: Vector2 = score_2.position

	score_1.position.x = -400
	score_2.position.x = viewport_size.x + 400

	var tween: Tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	tween.tween_property(score_1, "position:x", target_score1_pos.x, slide_duration)
	tween.tween_property(score_2, "position:x", target_score2_pos.x, slide_duration)

# =========================================================
# ENTRADA Y SALIDA AL MAPA
# =========================================================
func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_accept"):
		return
	if _conteo_terminado:
		if _puede_salir:
			_salir()
	elif _secuencia_iniciada and Time.get_ticks_msec() - _t_inicio_ms > 700:
		# Primer toque: saltea el conteo. Segundo toque: sale.
		get_viewport().set_input_as_handled()
		_saltar_conteo()

func _salir() -> void:
	if _saliendo or not _puede_salir:
		return
	_saliendo = true

	var e: Node = get_node_or_null("/root/EstadisticasNivel")
	if e:
		e.call("limpiar")

	# Suena el "okay" y esperamos un momento para que se escuche antes de cambiar de escena
	if sonido_continuar != null:
		_reproducir(sonido_continuar, volumen_sonido_continuar_db)
		var espera: float = clampf(sonido_continuar.get_length(), 0.15, espera_max_sonido_salida)
		await get_tree().create_timer(espera).timeout

	Cargador.ir_a_escena(ruta_escena_salida)
