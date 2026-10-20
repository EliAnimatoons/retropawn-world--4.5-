extends Node2D

# Configuración
@export var velocidad_mov = 150.0 
@export var ritmo_pasos = 0.35 

@onready var puntos = $PuntosNiveles.get_children()
@onready var jugador = $JugadorMapa  
@onready var anim_player = $JugadorMapa/AnimatedSprite2D 
@onready var sonido_select = $SonidoSelect
@onready var camara = $Camera2D
@onready var sonido_error = $SonidoError 
@onready var sonido_pasos = $SonidoPasos
@onready var musica_fondo = $MusicaFondo 

@onready var punto_logros = $PuntosNiveles/Logros 
@onready var punto_shop = $PuntosNiveles/shop2
@onready var punto_house = $PuntosNiveles/housemark

var seleccionado = false
var prefijo = "" 
var puede_entrar_a = -1
var sobre_logros = false 
var sobre_shop = false
var sobre_house = false
var timer_pasos = 0.0 

# --- Personajes sin sprite de mapa propio: usan el prefijo de otro personaje ---
var fallback_prefijos = {
	"plasticsketch": "sketch"  # <--- cuando tenga su sprite, eliminar esta línea
}

# --- RUTAS CORREGIDAS según tus archivos reales ---
var videos_niveles = {
	1: "res://videos/Cinematic1.ogv",
	2: "res://videos/Cinematic2.ogv"
}

var rutas_niveles = [
	"res://scenes/mundotutorial.tscn",
	"res://scenes/mundo1.tscn",
	"res://scenes/mundo2.tscn",
	"res://scenes/mundo3.tscn",
	"res://scenes/mundo4.tscn",
	"res://scenes/mundo5.tscn",
	"res://scenes/mundo6.tscn",
	"res://scenes/mundo7.tscn"
]

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	if GameManager.personaje_elegido == "":
		GameManager.personaje_elegido = "sketch"

	# Si el personaje no tiene sprite de mapa, usar el fallback definido arriba
	var elegido = GameManager.personaje_elegido
	prefijo = fallback_prefijos.get(elegido, elegido)

	if anim_player:
		anim_player.play("idle" + prefijo)
	
	# --- POSICIÓN GUARDADA: si volvió de un nivel, aparece donde estaba ---
	if GameManager.tiene_posicion_guardada:
		jugador.global_position = GameManager.posicion_mapa
		GameManager.tiene_posicion_guardada = false
	else:
		# Primera vez entrando al mapa: aparece en el último nivel desbloqueado
		var nivel_inicio = ProgresoJuego.nivel_desbloqueado
		if puntos.size() > nivel_inicio:
			var punto_inicio = puntos[nivel_inicio]
			if punto_inicio.name != "Logros" and punto_inicio.name != "shop2" and punto_inicio.name != "housemark":
				jugador.global_position = punto_inicio.position
	
	camara.position = jugador.position
	actualizar_visual_candados()

func actualizar_visual_candados():
	for i in range(puntos.size()):
		if puntos[i].name == "Logros" or puntos[i].name == "shop2" or puntos[i].name == "housemark": 
			continue
		var candado = puntos[i].get_node_or_null("Sprite2D")
		if i <= ProgresoJuego.nivel_desbloqueado:
			if candado: candado.queue_free()
			puntos[i].modulate = Color(1, 1, 1)
		else:
			if candado: candado.visible = true
			puntos[i].modulate = Color(0.3, 0.3, 0.3)

func _physics_process(delta): 
	if is_instance_valid(jugador):
		if not is_finite(jugador.global_position.x) or not is_finite(jugador.global_position.y):
			print("VIGILANTE: Error de realidad detectado en el Mapa. Castigando...")
			Cargador.ir_a_escena("res://scenes/CapaCastigo.tscn")
			return

	if seleccionado: 
		jugador.velocity = Vector2.ZERO
		return
	
	GameManager.posicion_mapa = jugador.global_position
	
	manejar_movimiento_fisico(delta)
	verificar_proximidad_puntos()
	
	camara.position = jugador.position
	var tiempo = Time.get_ticks_msec() / 1000.0
	camara.offset = Vector2(sin(tiempo * 0.8) * 5, cos(tiempo * 0.5) * 5)

func manejar_movimiento_fisico(delta):
	var direccion = Vector2.ZERO
	direccion.x = Input.get_axis("izquierda", "derecha")
	direccion.y = Input.get_axis("arriba", "abajo")
	
	if direccion != Vector2.ZERO:
		jugador.velocity = direccion.normalized() * velocidad_mov
		timer_pasos -= delta
		if timer_pasos <= 0:
			reproducir_sonido_paso()
			timer_pasos = ritmo_pasos 
		if anim_player:
			anim_player.play("walk" + prefijo)
			anim_player.flip_h = direccion.x < 0
	else:
		jugador.velocity = Vector2.ZERO
		timer_pasos = 0.0 
		if anim_player:
			anim_player.play("idle" + prefijo)

	jugador.move_and_slide()

func reproducir_sonido_paso():
	if sonido_pasos:
		sonido_pasos.pitch_scale = randf_range(0.9, 1.1)
		sonido_pasos.play()

func verificar_proximidad_puntos():
	puede_entrar_a = -1 
	sobre_logros = false
	sobre_shop = false
	sobre_house = false
	
	for i in range(puntos.size()):
		if puntos[i].name == "Logros" or puntos[i].name == "shop2" or puntos[i].name == "housemark": 
			continue
		var distancia = jugador.global_position.distance_to(puntos[i].position)
		if distancia < 50.0:
			if i <= ProgresoJuego.nivel_desbloqueado:
				puede_entrar_a = i
			else:
				if Input.is_action_just_pressed("ui_accept"):
					bloqueado_efecto()
					
	if punto_logros:
		if jugador.global_position.distance_to(punto_logros.position) < 50.0:
			sobre_logros = true
	if punto_shop:
		if jugador.global_position.distance_to(punto_shop.position) < 50.0:
			sobre_shop = true
	if punto_house:
		if jugador.global_position.distance_to(punto_house.position) < 50.0:
			sobre_house = true

func _input(event):
	if seleccionado: return
	if event.is_action_pressed("ui_accept"):
		if puede_entrar_a != -1:
			var ruta_nivel = rutas_niveles[puede_entrar_a]
			ejecutar_seleccion(ruta_nivel)
			await get_tree().create_timer(1.3).timeout
			
			GameManager.tiene_posicion_guardada = true
			
			if videos_niveles.has(puede_entrar_a):
				GameManager.video_pendiente = load(videos_niveles[puede_entrar_a])
				GameManager.nivel_tras_video = ruta_nivel
				Cargador.ir_a_escena("res://videos/video.tscn")
			else:
				Cargador.ir_a_escena(ruta_nivel)

		elif sobre_logros:
			GameManager.tiene_posicion_guardada = true
			ejecutar_seleccion("res://scenes/escenalogros.tscn")
			await get_tree().create_timer(1.3).timeout
			Cargador.ir_a_escena("res://scenes/escenalogros.tscn")

		elif sobre_shop:
			GameManager.tiene_posicion_guardada = true
			ejecutar_seleccion("res://scenes/shop2.tscn")
			await get_tree().create_timer(1.3).timeout
			Cargador.ir_a_escena("res://scenes/shop2.tscn")

		elif sobre_house:
			GameManager.tiene_posicion_guardada = true
			ejecutar_seleccion("res://scenes/housemark.tscn")
			await get_tree().create_timer(1.3).timeout
			Cargador.ir_a_escena("res://scenes/housemark.tscn")

func ejecutar_seleccion(_ruta_destino):
	seleccionado = true
	if anim_player:
		anim_player.play("select" + prefijo) 
	if sonido_select: 
		sonido_select.play()
	
	if musica_fondo:
		var tw_vinilo = create_tween().set_parallel(true)
		tw_vinilo.tween_property(musica_fondo, "pitch_scale", 0.01, 1.0)
		tw_vinilo.tween_property(musica_fondo, "volume_db", -80.0, 1.0)
	
	var tween_zoom = create_tween()
	tween_zoom.tween_property(camara, "zoom", Vector2(2.5, 2.5), 0.8)
	
	await get_tree().create_timer(1.2).timeout 
	
	if musica_fondo:
		musica_fondo.stop()
		musica_fondo.pitch_scale = 1.0
		musica_fondo.volume_db = 0.0

func bloqueado_efecto():
	if sonido_error: sonido_error.play()
	var t = create_tween()
	t.tween_property(camara, "offset:x", 10.0, 0.05)
	t.tween_property(camara, "offset:x", -10.0, 0.05)
	t.tween_property(camara, "offset:x", 0.0, 0.05)
