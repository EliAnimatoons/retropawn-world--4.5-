extends Node3D

# --- Precarga de Escenas ---
const JUGADOR_1_SRC = preload("res://scenes/Sketch.tscn")
const JUGADOR_2_SRC = preload("res://scenes/Max.tscn")

# Se eliminaron: minioneye.tscn y aqua_glitcher.tscn
@export var escenas_enemigos: Array[PackedScene] = [
	preload("res://scenes/Minion.tscn"),
	preload("res://scenes/MinionAlacran.tscn"),
	preload("res://scenes/minion_bomba.tscn")
]

# --- NUEVOS NODOS DE POSICIÓN ---
@onready var pos_jugador_1 = $PosicionesInicio/Pos_Jugador1
@onready var pos_jugador_2 = $PosicionesInicio/Pos_Jugador2
@onready var pos_chica = $PosicionesInicio/Pos_Chica

# --- Nodos ---
@onready var sprite_chica = $Chica/SpriteChica
@onready var timer_horda = $TimerHorda
@onready var barra_vida_chica = $UI/VidaChicaBarra
@onready var label_tiempo = $UI/TiempoLabel
@onready var label_anuncio = $UI/AnuncioLabel
@onready var spawn_points = $SpawnPoints.get_children()

# --- CONFIGURACIÓN DE CÁMARA DINÁMICA ---
@onready var camara: Camera3D = $Camera3D # Asegurate de que tu nodo de cámara se llame exactamente así
@export var cam_velocidad_suavizado: float = 5.0 # Qué tan rápido / jugosa responde la cámara
@export var cam_distancia_minima_z: float = 6.0  # El zoom máximo cuando están pegados
@export var cam_distancia_maxima_z: float = 14.0 # El alejamiento máximo para no romper el mapa
@export var cam_margen_zoom: float = 0.8         # Multiplicador para ajustar qué tanto se aleja al separarse

# --- Variables de Estado ---
enum EstadoJuego { COOPERATIVO, DUELO, GAME_OVER }
var estado_actual = EstadoJuego.COOPERATIVO

var vida_chica: float = 100.0
var tiempo_spawn: float = 2.0 
var cronometro_spawn: float = 0.0

var j1_instancia: CharacterBody3D
var j2_instancia: CharacterBody3D

func _ready():
	# Inicializar UI
	barra_vida_chica.value = vida_chica
	label_anuncio.text = ""
	
	# Instanciar Jugadores
	j1_instancia = JUGADOR_1_SRC.instantiate()
	j2_instancia = JUGADOR_2_SRC.instantiate()
	
	add_child(j1_instancia)
	add_child(j2_instancia)
	
	# --- INYECCIÓN MÁGICA DE CONTROLES ---
	j1_instancia.sufijo_control = "" 
	j2_instancia.sufijo_control = "_p2"
	
	# --- POSICIONAR PERSONAJES (CORREGIDO) ---
	# Tomamos la posición del marcador que ajustaste visualmente en el editor
	j1_instancia.global_position = pos_jugador_1.global_position
	j2_instancia.global_position = pos_jugador_2.global_position
	$Chica.global_position = pos_chica.global_position
	
	# --- FIX PIES HUNDIDOS: Un empujoncito extra de seguridad ---
	# Esto asegura que el CharacterBody3D no empiece "adentro" de la colisión del suelo
	j1_instancia.global_position.y += 0.1
	j2_instancia.global_position.y += 0.1
	
	sprite_chica.play("idle")
	
func _process(delta):
	match estado_actual:
		EstadoJuego.COOPERATIVO:
			actualizar_UI_coop()
			manejar_spawns(delta)
			if timer_horda.is_stopped() or timer_horda.time_left <= 0:
				iniciar_duelo()
				
		EstadoJuego.DUELO:
			label_tiempo.text = "¡DUELO A MUERTE!"
			verificar_ganador_duelo()

func _physics_process(delta):
	# Ejecutamos el control de la cámara en el frame físico para evitar tironeos (stuttering)
	actualizar_camara_dinamica(delta)

# --- SISTEMA DE CÁMARA ESTILO CASTLE CRASHERS (CORREGIDO) ---
func actualizar_camara_dinamica(delta: float):
	if not camara: return
	
	var objetivos: Array[Vector3] = []
	
	# Filtro limpio: Si el jugador existe, no estamos en Game Over y tiene vida, la cámara lo sigue
	if is_instance_valid(j1_instancia) and estado_actual != EstadoJuego.GAME_OVER:
		if j1_instancia.health > 0:
			objetivos.append(j1_instancia.global_position)
			
	if is_instance_valid(j2_instancia) and estado_actual != EstadoJuego.GAME_OVER:
		if j2_instancia.health > 0:
			objetivos.append(j2_instancia.global_position)
			
	# Si ambos murieron o no hay objetivos, nos enfocamos en la chica para que la cámara no quede flotando en la nada
	if objetivos.is_empty():
		if $Chica:
			objetivos.append($Chica.global_position)
		else:
			return

	# 1. Calcular el Punto Medio
	var suma_posiciones = Vector3.ZERO
	for pos in objetivos:
		suma_posiciones += pos
	var punto_medio = suma_posiciones / objetivos.size()
	
	# 2. Calcular las distancias máximas para el Zoom
	var dist_max_x = 0.0
	var dist_max_y = 0.0
	
	for pos in objetivos:
		var diff = (pos - punto_medio).abs()
		if diff.x > dist_max_x: dist_max_x = diff.x
		if diff.y > dist_max_y: dist_max_y = diff.y
	
	var mayor_distancia = max(dist_max_x * 2.0, dist_max_y * 2.0)
	
	# 3. Posición de destino
	var destino_camara = camara.global_position
	destino_camara.x = punto_medio.x
	destino_camara.y = punto_medio.y + 1.5 
	
	var objetivo_z = punto_medio.z + cam_distancia_minima_z + (mayor_distancia * cam_margen_zoom)
	destino_camara.z = clamp(objetivo_z, punto_medio.z + cam_distancia_minima_z, punto_medio.z + cam_distancia_maxima_z)
	
	# 4. Movimiento Suave
	camara.global_position = camara.global_position.lerp(destino_camara, cam_velocidad_suavizado * delta)

func actualizar_UI_coop():
	label_tiempo.text = "Tiempo restante: " + str(int(timer_horda.time_left)) + "s"
	barra_vida_chica.value = vida_chica

func manejar_spawns(delta):
	cronometro_spawn += delta
	if cronometro_spawn >= tiempo_spawn:
		cronometro_spawn = 0.0
		spawnear_enemigo()
		
		if timer_horda.time_left < 20:
			tiempo_spawn = 1.0 
		elif timer_horda.time_left < 40:
			tiempo_spawn = 1.5

func spawnear_enemigo():
	if escenas_enemigos.is_empty(): return
	
	var enemigo_al_azar = escenas_enemigos.pick_random()
	var enemigo_instancia = enemigo_al_azar.instantiate()
	var punto_spawn = spawn_points.pick_random()
	
	add_child(enemigo_instancia)
	enemigo_instancia.global_position = punto_spawn.global_position + Vector3(0, 0.1, 0)
	
	if enemigo_instancia.has_method("definir_objetivo"):
		enemigo_instancia.definir_objetivo(pos_chica.global_position)

func herir_chica(cantidad: float):
	if estado_actual != EstadoJuego.COOPERATIVO: return
	
	vida_chica -= cantidad
	sprite_chica.play("hurt")
	
	await get_tree().create_timer(0.5).timeout
	if estado_actual == EstadoJuego.COOPERATIVO:
		sprite_chica.play("idle")
		
	if vida_chica <= 0:
		game_over()

func game_over():
	estado_actual = EstadoJuego.GAME_OVER
	get_tree().call_group("enemigos", "queue_free") 
	label_anuncio.text = "¡GAME OVER!\nLa chica fue derrotada."

func iniciar_duelo():
	estado_actual = EstadoJuego.DUELO
	get_tree().call_group("enemigos", "queue_free")
	
	label_anuncio.text = "¡LA CHICA ESTÁ A SALVO!\n¡PELEEN POR ELLA!"
	sprite_chica.play("idle")
	
	if j1_instancia.has_method("activar_modo_versus"):
		j1_instancia.activar_modo_versus()
	if j2_instancia.has_method("activar_modo_versus"):
		j2_instancia.activar_modo_versus()

func verificar_ganador_duelo():
	# FIX: Cambiado .vida por .health para que coincida con tus scripts de Sketch y Max
	if j1_instancia.health <= 0:
		terminar_partida("¡JUGADOR 2 GANA LA CHICA!")
	elif j2_instancia.health <= 0:
		terminar_partida("¡JUGADOR 1 GANA LA CHICA!")

func terminar_partida(mensaje: String):
	estado_actual = EstadoJuego.GAME_OVER
	label_anuncio.text = mensaje
	sprite_chica.play("win")
