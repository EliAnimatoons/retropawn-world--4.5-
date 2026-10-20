extends Node3D

const JUGADOR_SRC = preload("res://scenes/sketch.tscn")
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
@export var probabilidad_thomas: float = 0.0001
var tiempo_camara_maldita: float = 0.0

@export_group("Configuración Tormenta")
@export var sonido_tormenta: AudioStream = preload("res://sonidos/SonidoTrueno.mp3")
@export var activar_tormenta_siempre: bool = true

# --- SISTEMA DE TIEMPO DEL NIVEL ---
@export_group("Configuración Tiempo")
@export var tiempo_maximo_nivel: float = 60.0 # Cuántos segundos dura el nivel
var tiempo_restante: float = 0.0
var tiempo_agotado: bool = false

# --- RISAS DE ENEMIGOS DURANTE EL COLAPSO ---
@export_group("Risas de Enemigos (Colapso)")
@export var frames_risa_enemigos: SpriteFrames
@export var intervalo_min_risa: float = 4.0
@export var intervalo_max_risa: float = 9.0

var _risas_activas: bool = false
var _timer_risa: float = 0.0
var _proxima_risa: float = 0.0
var _sprite_risa_actual: AnimatedSprite3D = null

var reproductor_tormenta: AudioStreamPlayer
var luz_sol: DirectionalLight3D
var world_env_ref: WorldEnvironment
var timer_relampago: float = 0.0
var proximo_relampago: float = 3.0
var en_fase_relampago: bool = false
var color_sol_original: Color
var energia_sol_original: float

# Guardamos el estado justo antes de empezar el tinte del colapso
var _colapso_visualmente_iniciado: bool = false
var _color_luz_pre_colapso: Color
var _energia_luz_pre_colapso: float
var _ambiente_pre_colapso: Color = Color(0.05, 0.05, 0.1)

func _ready():

	# Inicializamos el tiempo
	tiempo_restante = tiempo_maximo_nivel

	# Desmutear Música y Efectos al arrancar (por si reinicias el nivel tras morir en el colapso)
	var bus_mus = AudioServer.get_bus_index("Musica")
	if bus_mus != -1: AudioServer.set_bus_mute(bus_mus, false)

	var bus_efectos = AudioServer.get_bus_index("Efectos")
	if bus_efectos != -1: AudioServer.set_bus_mute(bus_efectos, false)

	# Preparar el Trigger Final usando set_deferred por seguridad
	var trigger_final = find_child("TriggerFinal", true, false) as Area3D
	if trigger_final:
		trigger_final.visible = false
		trigger_final.set_deferred("monitoring", false)
		trigger_final.set_deferred("monitorable", false)
		if not trigger_final.body_entered.is_connected(_on_trigger_final_body_entered):
			trigger_final.body_entered.connect(_on_trigger_final_body_entered)

	luz_sol = find_child("DirectionalLight3D", true, false) as DirectionalLight3D
	world_env_ref = find_child("WorldEnvironment", true, false) as WorldEnvironment

	if luz_sol:
		color_sol_original = luz_sol.light_color
		energia_sol_original = luz_sol.light_energy

	configurar_audio_tormenta()
	evaluar_spawn_thomas_antony()

	if not ProgresoJuego.thomas_antony_activado and activar_tormenta_siempre:
		preparar_cielo_tormenta()

	var intro = load("res://scenes/IntroNivel.tscn").instantiate()
	add_child(intro)
	intro.configurar("ZONE 0", "Zone by EliAnimatoons")

	var player = get_tree().get_first_node_in_group("player")
	if player:
		player.set_physics_process(false)
		await get_tree().create_timer(3.5).timeout
		if not tiempo_agotado:
			player.set_physics_process(true)

	# --- ARRANCA EL CRONÓMETRO DEL SCORE (después de la intro) ---
	EstadisticasNivel.iniciar_nivel()

	cuadro_negro = find_child("ColorRect", true, false)
	if cuadro_negro:
		cuadro_negro.modulate.a = 0.0

	if ProgresoJuego.max_desbloqueado:
		var jaula = find_child("*Jaula*", true, false)
		if jaula: jaula.queue_free()
		var max_npc = find_child("*Max_NPC*", true, false)
		if max_npc: max_npc.queue_free()

func detener_musica_nivel():
	# Busca el nodo de música de fondo
	var musica_bg = get_node_or_null("soundtrack background")
	if musica_bg and musica_bg is AudioStreamPlayer:
		musica_bg.stop()

func configurar_audio_tormenta():
	reproductor_tormenta = AudioStreamPlayer.new()
	reproductor_tormenta.name = "AudioTormentaAterrradora"
	add_child(reproductor_tormenta)

	if sonido_tormenta:
		reproductor_tormenta.stream = sonido_tormenta
		reproductor_tormenta.volume_db = -2.0
		reproductor_tormenta.play()

func preparar_cielo_tormenta():
	if world_env_ref and world_env_ref.environment:
		world_env_ref.environment.ambient_light_color = Color(0.05, 0.05, 0.1)
	if luz_sol:
		luz_sol.light_color = Color(0.2, 0.25, 0.35)
		luz_sol.light_energy = 0.25

func evaluar_spawn_thomas_antony():
	var thomas_npc = find_child("ThomasAntonyNpc", true, false)
	if not ProgresoJuego.thomas_antony_activado:
		if randf() < probabilidad_thomas:
			ProgresoJuego.thomas_antony_activado = true

	if thomas_npc:
		if ProgresoJuego.thomas_antony_activado:
			thomas_npc.visible = true
			aplicar_efectos_mundo_maldito()
		else:
			thomas_npc.queue_free()

func aplicar_efectos_mundo_maldito():
	if world_env_ref and world_env_ref.environment:
		world_env_ref.environment.background_mode = Environment.BG_COLOR
		world_env_ref.environment.background_color = Color.BLACK
		world_env_ref.environment.ambient_light_color = Color(0.2, 0.05, 0.05)
	if luz_sol:
		luz_sol.light_color = Color(0.5, 0.1, 0.1)
		luz_sol.light_energy = 0.4
	var nodo_shader = find_child("shader", true, false)
	if nodo_shader:
		nodo_shader.modulate = Color(1.0, 0.1, 0.1, 1.0)

func _process(delta):
	procesar_efecto_relampagos(delta)
	_process_risas_enemigos(delta) # risas de enemigos durante el colapso

	if not j2_conectado:
		if Input.is_action_just_pressed("ui_accept_p2") or Input.is_joy_button_pressed(1, JOY_BUTTON_A):
			spawnear_jugador_2()

	var jugadores = get_tree().get_nodes_in_group("player")
	for p in jugadores:
		if is_instance_valid(p):
			if not is_finite(p.global_position.x) or not is_finite(p.global_position.y) or not is_finite(p.global_position.z):
				Cargador.ir_a_escena("res://scenes/CapaCastigo.tscn")
				return
			if p.global_position.y < -30.0:
				Cargador.ir_a_escena("res://scenes/CapaCastigo.tscn")
				return

func procesar_efecto_relampagos(delta: float):
	if not luz_sol: return
	timer_relampago += delta
	if timer_relampago >= proximo_relampago and not en_fase_relampago:
		ejecutar_relampago_violento()

func ejecutar_relampago_violento():
	en_fase_relampago = true
	var color_original_actual = luz_sol.light_color
	var energia_original_actual = luz_sol.light_energy
	var num_parpadeos = randi_range(2, 5)
	for i in range(num_parpadeos):
		luz_sol.light_color = Color(1.2, 1.3, 1.6)
		luz_sol.light_energy = randf_range(4.0, 8.0)
		await get_tree().create_timer(randf_range(0.03, 0.08)).timeout
		luz_sol.light_energy = 0.05
		await get_tree().create_timer(randf_range(0.02, 0.06)).timeout
	luz_sol.light_color = color_original_actual
	luz_sol.light_energy = energia_original_actual
	timer_relampago = 0.0
	proximo_relampago = randf_range(4.0, 10.0)
	en_fase_relampago = false

func _physics_process(delta):
	actualizar_camara_tutorial(delta)
	if ProgresoJuego.thomas_antony_activado and camara:
		tiempo_camara_maldita += delta * 2.0
		camara.rotation.z = sin(tiempo_camara_maldita) * 0.08
		camara.rotation.x += cos(tiempo_camara_maldita * 0.7) * 0.04 * delta

func spawnear_jugador_2():
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

func actualizar_camara_tutorial(delta: float):
	if not camara: return
	var objetivos: Array[Vector3] = []
	var jugadores = get_tree().get_nodes_in_group("player")
	for p in jugadores:
		if is_instance_valid(p) and ("health" in p and p.health > 0):
			objetivos.append(p.global_position)
		elif is_instance_valid(p):
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

# --- FINAL DEL NIVEL: ahora va al SCORE (el score desbloquea el siguiente nivel) ---
func _on_trigger_final_body_entered(body):
	if _terminado: return
	if body.is_in_group("player"):
		_terminado = true

		# Restaurar el bus de efectos al ganar para que no quede silenciado en la UI
		var bus_efectos = AudioServer.get_bus_index("Efectos")
		if bus_efectos != -1: AudioServer.set_bus_mute(bus_efectos, false)

		ProgresoJuego.thomas_antony_activado = false

		EstadisticasNivel.finalizar_nivel(0)          # índice 0 = tutorial
		ProgresoJuego.finalizar_nivel_exitosamente()  # monedas, rescates y logros (necesita este nivel cargado)

		for p in get_tree().get_nodes_in_group("player"):
			if is_instance_valid(p):
				p.set_physics_process(false)

		if cuadro_negro:
			var tween = create_tween()
			tween.tween_property(cuadro_negro, "modulate:a", 1.0, 3.0)
			await tween.finished

		EstadisticasNivel.ir_al_score()

func _on_zona_instructor_body_entered(_body: Node3D) -> void: pass
func _on_timer_letras_timeout() -> void: pass

# --- FUNCIÓN DE MUERTE POR TIEMPO ---
func ejecutar_game_over_por_tiempo():
	if tiempo_agotado: return # evita que esto se dispare más de una vez
	tiempo_agotado = true

	# Congelar a los jugadores
	var jugadores = get_tree().get_nodes_in_group("player")
	for p in jugadores:
		if is_instance_valid(p):
			p.set_physics_process(false)

	# Transición a negro opcional
	if cuadro_negro:
		var tween = create_tween()
		tween.tween_property(cuadro_negro, "modulate:a", 1.0, 1.5)
		await tween.finished

	for p in jugadores:
		if is_instance_valid(p) and p.has_method("morir_jugador"):
			p.morir_jugador()
			return

	Cargador.ir_a_escena("res://scenes/CapaCastigo.tscn")

# Llamado por trigger_colapso.gd (Area3D) en el momento exacto en que
# arranca la secuencia de escape, para guardar el color/ambiente actual como
# base del lerp.
func preparar_tinte_colapso():
	_colapso_visualmente_iniciado = true
	iniciar_secuencia_risas() # arranca las apariciones de enemigos riéndose
	if luz_sol:
		_color_luz_pre_colapso = luz_sol.light_color
		_energia_luz_pre_colapso = luz_sol.light_energy
	if world_env_ref and world_env_ref.environment:
		_ambiente_pre_colapso = world_env_ref.environment.ambient_light_color

func actualizar_tiempo_colapso(tiempo: float):
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

# ====================================================================
# --- RISAS DE ENEMIGOS DURANTE EL COLAPSO ---
# ====================================================================
func iniciar_secuencia_risas() -> void:
	_risas_activas = true
	_timer_risa = 0.0
	_proxima_risa = randf_range(intervalo_min_risa, intervalo_max_risa)

func _process_risas_enemigos(delta: float) -> void:
	if not _risas_activas or not camara or not frames_risa_enemigos:
		return
	_timer_risa += delta
	if _timer_risa >= _proxima_risa:
		_timer_risa = 0.0
		_proxima_risa = randf_range(intervalo_min_risa, intervalo_max_risa)
		_mostrar_risa_enemigo()

func _mostrar_risa_enemigo() -> void:
	if _sprite_risa_actual and is_instance_valid(_sprite_risa_actual):
		_sprite_risa_actual.queue_free()

	var sprite = AnimatedSprite3D.new()
	sprite.sprite_frames = frames_risa_enemigos
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.no_depth_test = true
	camara.add_child(sprite)
	sprite.position = Vector3(randf_range(-1.5, 1.5), randf_range(-0.5, 0.5), -3.0)
	sprite.modulate.a = 0.0
	_sprite_risa_actual = sprite

	if sprite.sprite_frames and sprite.sprite_frames.has_animation("default"):
		sprite.play("default")

	var tw = create_tween()
	tw.tween_property(sprite, "modulate:a", 1.0, 0.15)
	tw.tween_interval(1.0)
	tw.tween_property(sprite, "modulate:a", 0.0, 0.3)
	await tw.finished
	if is_instance_valid(sprite):
		sprite.queue_free()
	if _sprite_risa_actual == sprite:
		_sprite_risa_actual = null
