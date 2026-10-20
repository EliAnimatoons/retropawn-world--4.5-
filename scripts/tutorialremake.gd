extends Node3D

# Avisa cuando termina la intro "TRUE TUTORIAL" (el TutorialManager espera esta señal para hablar)
signal intro_terminada

const DOODLE_SRC = preload("res://player2all/doodle.tscn")
const ESCENA_HUD_SRC = preload("res://scenes/hud.tscn")

var cuadro_negro: ColorRect
var j2_instancia: CharacterBody3D = null
var j2_conectado: bool = false
var _terminado: bool = false

@onready var camara: Camera3D = $Camera3D
@export var cam_velocidad_suavizado: float = 5.0
@export var cam_distancia_minima_z: float = 6.0
@export var cam_distancia_maxima_z: float = 14.0
@export var cam_margen_zoom: float = 0.8

var tiempo_agotado: bool = false

var luz_sol: DirectionalLight3D
var world_env_ref: WorldEnvironment

# Estado de luz justo antes de empezar el tinte del colapso (base del lerp)
var _color_luz_pre_colapso: Color = Color.WHITE
var _energia_luz_pre_colapso: float = 1.0
var _ambiente_pre_colapso: Color = Color(0.05, 0.05, 0.1)


func _ready() -> void:
	# Desmutear Música y Efectos al arrancar (por si reinicias el nivel tras morir en el colapso)
	var bus_mus = AudioServer.get_bus_index("Musica")
	if bus_mus != -1: AudioServer.set_bus_mute(bus_mus, false)

	var bus_efectos = AudioServer.get_bus_index("Efectos")
	if bus_efectos != -1: AudioServer.set_bus_mute(bus_efectos, false)

	# Preparar el Trigger Final (apagado hasta que arranque el colapso)
	var trigger_final = find_child("TriggerFinal", true, false) as Area3D
	if trigger_final:
		trigger_final.visible = false
		trigger_final.set_deferred("monitoring", false)
		trigger_final.set_deferred("monitorable", false)
		if not trigger_final.body_entered.is_connected(_on_trigger_final_body_entered):
			trigger_final.body_entered.connect(_on_trigger_final_body_entered)

	luz_sol = find_child("DirectionalLight3D", true, false) as DirectionalLight3D
	world_env_ref = find_child("WorldEnvironment", true, false) as WorldEnvironment

	cuadro_negro = find_child("ColorRect", true, false)
	if cuadro_negro:
		cuadro_negro.modulate.a = 0.0

	if ProgresoJuego.max_desbloqueado:
		var jaula = find_child("*Jaula*", true, false)
		if jaula: jaula.queue_free()
		var max_npc = find_child("*Max_NPC*", true, false)
		if max_npc: max_npc.queue_free()

	# Intro del nivel
	var intro = load("res://scenes/IntroNivel.tscn").instantiate()
	add_child(intro)
	intro.configurar("TRUE TUTORIAL", "tutorial by EliAnimatoons")

	var player = get_tree().get_first_node_in_group("player")
	if player:
		player.set_physics_process(false)
		await get_tree().create_timer(3.5).timeout
		if not tiempo_agotado and is_instance_valid(player):
			player.set_physics_process(true)

	# Cronómetro del score (después de la intro)
	EstadisticasNivel.iniciar_nivel()

	# Ahora sí puede empezar a hablar el tutorial
	intro_terminada.emit()


func detener_musica_nivel() -> void:
	var musica_bg = get_node_or_null("soundtrack background")
	if musica_bg and musica_bg is AudioStreamPlayer:
		musica_bg.stop()


func _process(_delta: float) -> void:
	if not j2_conectado:
		if Input.is_action_just_pressed("ui_accept_p2") or Input.is_joy_button_pressed(1, JOY_BUTTON_A):
			spawnear_jugador_2()

	# Seguro anti-caída / anti-NaN
	for p in get_tree().get_nodes_in_group("player"):
		if is_instance_valid(p):
			if not p.global_position.is_finite():
				Cargador.ir_a_escena("res://scenes/CapaCastigo.tscn")
				return
			if p.global_position.y < -30.0:
				Cargador.ir_a_escena("res://scenes/CapaCastigo.tscn")
				return


func _physics_process(delta: float) -> void:
	actualizar_camara_tutorial(delta)


# =====================================================================
# JUGADOR 2
# =====================================================================
func spawnear_jugador_2() -> void:
	var j1 = get_tree().get_first_node_in_group("player")
	if not is_instance_valid(j1): return

	j2_conectado = true
	j2_instancia = DOODLE_SRC.instantiate()

	if "sufijo_input" in j2_instancia:
		j2_instancia.sufijo_input = "_p2"
	elif "sufijo_control" in j2_instancia:
		j2_instancia.sufijo_control = "_p2"

	add_child(j2_instancia)
	var pos_marker = get_node_or_null("Pos_P2_Tutorial")
	if pos_marker:
		j2_instancia.global_position = pos_marker.global_position
	else:
		j2_instancia.global_position = j1.global_position + Vector3(1.5, 0.5, 0)

	if not j2_instancia.is_in_group("player"):
		j2_instancia.add_to_group("player")
	if ESCENA_HUD_SRC:
		var hud_p2 = ESCENA_HUD_SRC.instantiate()
		add_child(hud_p2)
		hud_p2.player_ref = j2_instancia
		var modulo2 = hud_p2.get_node_or_null("ModuloJugador")
		if modulo2:
			modulo2.position.x = 800


# =====================================================================
# CÁMARA
# =====================================================================
func actualizar_camara_tutorial(delta: float) -> void:
	if not camara: return
	var objetivos: Array[Vector3] = []
	for p in get_tree().get_nodes_in_group("player"):
		if is_instance_valid(p):
			objetivos.append(p.global_position)

	if objetivos.is_empty(): return
	var suma_posiciones = Vector3.ZERO
	for pos in objetivos: suma_posiciones += pos
	var punto_medio = suma_posiciones / objetivos.size()

	var dist_max_x = 0.0
	var dist_max_y = 0.0
	for pos in objetivos:
		var diff = (pos - punto_medio).abs()
		if diff.x > dist_max_x: dist_max_x = diff.x
		if diff.y > dist_max_y: dist_max_y = diff.y
	var mayor_distancia = max(dist_max_x * 2.0, dist_max_y * 2.0)

	var destino_camara = camara.global_position
	destino_camara.x = punto_medio.x
	destino_camara.y = punto_medio.y + 1.5
	var objetivo_z = punto_medio.z + cam_distancia_minima_z + (mayor_distancia * cam_margen_zoom)
	destino_camara.z = clamp(objetivo_z, punto_medio.z + cam_distancia_minima_z, punto_medio.z + cam_distancia_maxima_z)
	camara.global_position = camara.global_position.lerp(destino_camara, cam_velocidad_suavizado * delta)


# =====================================================================
# FINAL DEL NIVEL -> SCORE
# =====================================================================
func _on_trigger_final_body_entered(body) -> void:
	if _terminado: return
	if body.is_in_group("player"):
		_terminado = true

		var bus_efectos = AudioServer.get_bus_index("Efectos")
		if bus_efectos != -1: AudioServer.set_bus_mute(bus_efectos, false)

		ProgresoJuego.thomas_antony_activado = false

		EstadisticasNivel.finalizar_nivel(0)          # índice 0 = tutorial
		ProgresoJuego.finalizar_nivel_exitosamente()  # monedas, rescates y logros

		for p in get_tree().get_nodes_in_group("player"):
			if is_instance_valid(p):
				p.set_physics_process(false)

		if cuadro_negro:
			var tween = create_tween()
			tween.tween_property(cuadro_negro, "modulate:a", 1.0, 3.0)
			await tween.finished

		EstadisticasNivel.ir_al_score()


# Por si algo todavía lo llama
func ejecutar_game_over_por_tiempo() -> void:
	if tiempo_agotado: return
	tiempo_agotado = true

	var jugadores = get_tree().get_nodes_in_group("player")
	for p in jugadores:
		if is_instance_valid(p):
			p.set_physics_process(false)

	if cuadro_negro:
		var tween = create_tween()
		tween.tween_property(cuadro_negro, "modulate:a", 1.0, 1.5)
		await tween.finished

	for p in jugadores:
		if is_instance_valid(p) and p.has_method("morir_jugador"):
			p.morir_jugador()
			return

	Cargador.ir_a_escena("res://scenes/CapaCastigo.tscn")


# =====================================================================
# COLAPSO (lo llama trigger_colapso.gd)
# =====================================================================
func preparar_tinte_colapso() -> void:
	if luz_sol:
		_color_luz_pre_colapso = luz_sol.light_color
		_energia_luz_pre_colapso = luz_sol.light_energy
	if world_env_ref and world_env_ref.environment:
		_ambiente_pre_colapso = world_env_ref.environment.ambient_light_color


func actualizar_tiempo_colapso(tiempo: float) -> void:
	var intensidad = clamp(tiempo, 0.0, 1.0)
	var pulso = sin(Time.get_ticks_msec() * 0.015) * 0.5 + 0.5

	if luz_sol:
		luz_sol.light_color = _color_luz_pre_colapso.lerp(Color(0.8, 0.05, 0.05), intensidad)
		luz_sol.light_energy = lerp(_energia_luz_pre_colapso, 0.25, intensidad) * (1.0 - pulso * 0.15)

	if world_env_ref and world_env_ref.environment:
		world_env_ref.environment.background_mode = Environment.BG_COLOR
		world_env_ref.environment.background_color = Color.BLACK
		var color_ambiente_maldito = Color(0.3, 0.02, 0.02)
		world_env_ref.environment.ambient_light_color = _ambiente_pre_colapso.lerp(color_ambiente_maldito, intensidad + pulso * 0.1)

	var nodo_shader = find_child("shader", true, false)
	if nodo_shader:
		nodo_shader.visible = true
		nodo_shader.modulate = Color(1.0, 1.0, 1.0).lerp(Color(1.0, 0.1, 0.1, 1.0), intensidad + pulso * 0.2)

	var hud_actual = get_tree().get_first_node_in_group("hud")
	if hud_actual and hud_actual.has_method("actualizar_intensidad_colapso"):
		hud_actual.actualizar_intensidad_colapso(intensidad)
