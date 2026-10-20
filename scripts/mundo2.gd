extends Node3D

var cuadro_negro: ColorRect
var _terminado: bool = false

# --- NODOS DE INTERFAZ ---
@onready var burbujas_pantalla = $CanvasLayer/BurbujasShader 
@onready var pantalla_agua = $CanvasLayer/aqua 
@onready var sonido_ambiente_agua = $frutigermusic 

func _ready():
	# 1. INTRO DEL NIVEL
	var intro = load("res://scenes/IntroNivel.tscn").instantiate()
	add_child(intro)
	intro.configurar("FRUTIGER SCIENCE", "level 2 by Nubbe") # Nombre de tu nivel
	
	# 2. CONGELAR PLAYER AL INICIO
	var player = get_tree().get_first_node_in_group("player")
	if player:
		player.set_physics_process(false)
		await get_tree().create_timer(3.5).timeout
		player.set_physics_process(true)
	
	# --- ARRANCA EL CRONÓMETRO DEL SCORE (después de la intro) ---
	EstadisticasNivel.iniciar_nivel()
	
	# 3. PREPARAR INTERFAZ Y FADEOUT
	if burbujas_pantalla: burbujas_pantalla.visible = false
	if pantalla_agua: pantalla_agua.visible = false
	
	# Buscamos el ColorRect para el FadeOut (Asegúrate que se llame ColorRect en la escena)
	cuadro_negro = find_child("ColorRect", true, false) 
	if cuadro_negro:
		cuadro_negro.modulate.a = 0.0
		cuadro_negro.show() # Lo dejamos listo
	else:
		print("¡ERROR: No encontré el ColorRect para el FadeOut!")

	# Resetear efectos de audio por si venimos de otro nivel
	AudioServer.set_bus_effect_enabled(0, 0, false)

# --- INYECCIÓN DE SEGURIDAD (Vigilante de la Realidad) ---
func _process(_delta):
	var p = get_tree().get_first_node_in_group("player")
	if is_instance_valid(p):
		if not is_finite(p.global_position.x) or p.global_position.y < -30.0:
			print("VIGILANTE: Error de realidad detectado. Castigando...")
			Cargador.ir_a_escena("res://scenes/CapaCastigo.tscn")

# --- LÓGICA DE INMERSIÓN ---
func entrar_al_agua():
	# Ya NO activamos burbujas_pantalla aquí para no chocar con el MinionEYE
	if pantalla_agua: pantalla_agua.visible = true
	if sonido_ambiente_agua and not sonido_ambiente_agua.playing:
		sonido_ambiente_agua.play()
	# Efecto de audio (Reverberación/Lowpass)
	AudioServer.set_bus_effect_enabled(0, 0, true)

func salir_del_agua():
	# Si el jugador sale del agua, forzamos que se quiten las burbujas por seguridad
	if burbujas_pantalla: burbujas_pantalla.visible = false
	if pantalla_agua: pantalla_agua.visible = false
	AudioServer.set_bus_effect_enabled(0, 0, false)

# --- FINAL DEL NIVEL: ahora va al SCORE (el score desbloquea el siguiente nivel) ---
func _on_trigger_final_body_entered(body):
	if _terminado: return
	if body.is_in_group("player"):
		_terminado = true
		print("¡Final de Mundo 2 alcanzado!")
		
		EstadisticasNivel.finalizar_nivel(2)          # índice 2 = mundo 2
		ProgresoJuego.finalizar_nivel_exitosamente()  # monedas, rescates y logros (necesita este nivel cargado)
		
		# Detenemos al jugador
		body.set_physics_process(false)
		
		# --- EL FADEOUT ---
		if cuadro_negro:
			var tween = create_tween()
			tween.tween_property(cuadro_negro, "modulate:a", 1.0, 3.0)
			await tween.finished
		
		# Cambio de escena al Score
		EstadisticasNivel.ir_al_score()

# --- CONEXIONES DE ÁREA ---
func _on_area_agua_body_entered(body):
	if body.is_in_group("player"): entrar_al_agua()

func _on_area_agua_body_exited(body):
	if body.is_in_group("player"): salir_del_agua()
