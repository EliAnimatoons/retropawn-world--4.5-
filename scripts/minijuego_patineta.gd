extends Control

var puntos = 0
var proximo_hito = 1000 
var juego_activo = true
var velocidad_mundo = 400.0 

@onready var jugador = $Jugador
@onready var puntos_label = $Labels/PuntosLabel
@onready var best_score_label = $Labels/BestScoreLabel 
@onready var timer_spawn = $TimerSpawn
@onready var musica = $MusicaFondo 
@onready var sonido_muerte = $SonidoMuerte 
@onready var sonido_puntos = $SonidoPuntos 
@onready var sfx_coin = get_node_or_null("SfxCoin") # <--- Nodo para el sonido de moneda
@onready var fondo = $Background 

var tex_moneda = preload("res://evoluciones minion/coin.png")
var lista_minions = [
	preload("res://evoluciones minion/minionskateboard.png"),
	preload("res://evoluciones minion/minionskateboard2.png"),
	preload("res://evoluciones minion/minionskateboard3.png"),
	preload("res://evoluciones minion/minionskateboard4.png"),
	preload("res://evoluciones minion/minionskateboard5.png"),
	preload("res://evoluciones minion/minionskateboard6.png")
]

func _ready():
	jugador.position = Vector2(150, 510) 
	timer_spawn.wait_time = 2.5 
	timer_spawn.start()
	
	if has_node("Labels/BestScoreLabel"):
		best_score_label.text = "Best: " + str(int(ProgresoJuego.best_score_patineta))
	
	musica.pitch_scale = 0.5
	musica.play()
	actualizar_ui()

func _process(delta):
	if not juego_activo: return
	
	puntos += delta * 15
	velocidad_mundo += delta * 8 
	
	var nuevo_pitch = remap(puntos, 0, 5000, 0.5, 1.0)
	musica.pitch_scale = clamp(nuevo_pitch, 0.5, 1.0)
	
	if puntos >= proximo_hito:
		llegada_a_hito()
		
	var factor_noche = clamp(puntos / 6000.0, 0.0, 0.7) 
	fondo.modulate = Color(1.0 - factor_noche, 1.0 - factor_noche, 1.0 - (factor_noche * 0.5))
	
	timer_spawn.wait_time = max(0.8, 2.5 - (velocidad_mundo / 800.0))
	actualizar_ui()

func llegada_a_hito():
	proximo_hito += 1000
	if sonido_puntos:
		sonido_puntos.play()
	var tw = create_tween()
	tw.tween_property(puntos_label, "scale", Vector2(1.5, 1.5), 0.1)
	tw.tween_property(puntos_label, "scale", Vector2(1.0, 1.0), 0.1)

# --- SISTEMA DE SPAWN MIXTO ---
func _on_timer_spawn_timeout():
	if not juego_activo: return
	
	# 70% de probabilidad de obstáculo, 30% de moneda
	if randf() > 0.3:
		crear_obstaculo()
	else:
		crear_moneda()

func crear_obstaculo():
	var obs = Sprite2D.new()
	obs.texture = lista_minions[randi() % lista_minions.size()]
	obs.top_level = true 
	obs.z_index = 100
	obs.add_to_group("obstaculos")
	
	var angulos = [0, 90, 180, 270]
	var rot = angulos[randi() % angulos.size()]
	obs.rotation_degrees = rot + randf_range(-10, 10)
	
	var altura_final = 530
	if rot == 90 or rot == 270: altura_final = 555 
	
	obs.position = Vector2(1350, altura_final)
	obs.scale = Vector2(0.8, 0.8) 
	add_child(obs) 
	
	mover_objeto(obs)

func crear_moneda():
	var coin = Sprite2D.new()
	coin.texture = tex_moneda
	coin.modulate = Color.YELLOW # Para que brille si usas un icono blanco
	coin.top_level = true
	coin.z_index = 90
	coin.add_to_group("monedas")
	
	# Las monedas aparecen a una altura que se puede agarrar saltando o en el suelo
	var altura = 510 if randf() > 0.5 else 400
	coin.position = Vector2(1350, altura)
	coin.scale = Vector2(0.5, 0.5)
	add_child(coin)
	
	mover_objeto(coin)

func mover_objeto(obj):
	var tw = create_tween()
	# Calculamos el tiempo basado en la velocidad actual del mundo
	tw.tween_property(obj, "position:x", -300, 1600.0 / velocidad_mundo)
	tw.tween_callback(obj.queue_free)

func actualizar_ui():
	puntos_label.text = "Score: " + str(int(puntos))

func finalizar_juego():
	juego_activo = false
	var tw_m = create_tween()
	tw_m.tween_property(musica, "pitch_scale", 0.01, 0.6).set_trans(Tween.TRANS_CIRC).set_ease(Tween.EASE_OUT)
	
	if sonido_muerte: sonido_muerte.play()
	
	if puntos > ProgresoJuego.best_score_patineta:
		ProgresoJuego.best_score_patineta = puntos
	
	ProgresoJuego.guardar_partida()
