extends Node3D

var cuadro_negro: ColorRect
var _terminado: bool = false

func _ready():
	# 1. Registrar la ruta de este nivel actual de forma dinámica
	ProgresoJuego.ultima_ruta_nivel = scene_file_path

	add_to_group("nivel_con_carrera") # <--- Con esto Sketch sabrá que aquí sí puede correr
	add_to_group("nivel_con_gravedad") # (Si también quieres habilitarle el salto)
	
	# 2. Instanciar la introducción del nivel
	var intro = load("res://scenes/IntroNivel.tscn").instantiate()
	add_child(intro)
	intro.configurar("JUST ICE!", "level 3 by Nubbe")
	
	# 3. CONECTAR AL ÁRBOL DE ESCENAS (El Vigilante de Spawns)
	# Cada vez que un nodo entre a la escena, el mundo va a revisar si es el jugador
	get_tree().node_added.connect(_on_nodo_creado_en_el_mundo)
	
	# Guardar el checkpoint base si es la primera vez que entra
	var player = get_tree().get_first_node_in_group("player")
	if player:
		if not ProgresoJuego.usar_checkpoint_al_cargar:
			ProgresoJuego.posicion_checkpoint_guardada = player.global_position
			print("Primer ingreso al nivel. Checkpoint base guardado en: ", player.global_position)
		else:
			# Si por alguna razón el jugador ya existía en la escena desde el editor, lo acomodamos
			_acomodar_jugador_en_checkpoint(player)
	
	# Desactivamos procesos temporalmente por la intro
	if player:
		player.set_physics_process(false)
		await get_tree().create_timer(3.5).timeout
		if is_instance_valid(player):
			player.set_physics_process(true)
	
	# --- ARRANCA EL CRONÓMETRO DEL SCORE (después de la intro) ---
	EstadisticasNivel.iniciar_nivel()
	
	# 4. Configurar el ColorRect para los fundidos a negro
	cuadro_negro = find_child("ColorRect", true, false)
	if cuadro_negro:
		cuadro_negro.modulate.a = 0.0
	else:
		print("¡ERROR FATAL: No encontré ningún ColorRect en la escena!")

	# 5. Lógica de persistencia de desbloqueos en el mapa
	if ProgresoJuego.max_desbloqueado:
		var jaula = find_child("*Jaula*", true, false)
		if jaula: jaula.queue_free()
		var max_npc = find_child("*Max_NPC*", true, false)
		if max_npc: max_npc.queue_free()

# --- FUNCIÓN POLICÍA: Detecta cuándo spawnea CUALQUIER personaje ---
func _on_nodo_creado_en_el_mundo(nodo: Node):
	# Si el nodo que acaba de nacer pertenece al grupo "player"...
	if nodo.is_in_group("player") and ProgresoJuego.usar_checkpoint_al_cargar:
		# Lo acomodamos inmediatamente sin importar qué personaje sea (sketch, max, rata, etc.)
		_acomodar_jugador_en_checkpoint(nodo)

func _acomodar_jugador_en_checkpoint(jugador: Node3D):
	# Le damos un process_frame de ventaja para ganarle al Spawner original
	await get_tree().process_frame
	if is_instance_valid(jugador):
		jugador.global_position = ProgresoJuego.posicion_checkpoint_guardada
		
		# Frenamos en seco cualquier fuerza física vieja
		if "velocity" in jugador:
			jugador.velocity = Vector3.ZERO
		if "linear_velocity" in jugador:
			jugador.linear_velocity = Vector3.ZERO
			
		print("🎯 [MUNDO 3]: Se detectó la aparición de ", jugador.name, ". Reubicado en Checkpoint: ", jugador.global_position)

func _process(_delta):
	var p = get_tree().get_first_node_in_group("player")
	if is_instance_valid(p):
		if not is_finite(p.global_position.x) or not is_finite(p.global_position.y) or not is_finite(p.global_position.z):
			print("VIGILANTE: Error de realidad detectado. Activando Game Over.")
			call_deferred("activar_game_over")
			return
		
		if p.global_position.y < -30.0:
			print("El jugador se cayó del mapa. Transicionando al Game Over...")
			call_deferred("activar_game_over")
			return

func activar_game_over():
	ProgresoJuego.usar_checkpoint_al_cargar = true
	get_tree().change_scene_to_file("res://scenes/GameOver.tscn")

func actualizar_checkpoint(nueva_posicion: Vector3):
	ProgresoJuego.posicion_checkpoint_guardada = nueva_posicion
	ProgresoJuego.usar_checkpoint_al_cargar = true
	print("¡Nuevo checkpoint intermedio guardado en: ", nueva_posicion, "!")

# --- FINAL DEL NIVEL: ahora va al SCORE (el score desbloquea el siguiente nivel) ---
func _on_trigger_final_body_entered(body):
	if _terminado: return
	if body.is_in_group("player"):
		_terminado = true
		print("¡Final del mundo 3 alcanzado!")
		ProgresoJuego.usar_checkpoint_al_cargar = false
		ProgresoJuego.posicion_checkpoint_guardada = Vector3.ZERO
		
		EstadisticasNivel.finalizar_nivel(3)          # índice 3 = mundo 3
		ProgresoJuego.finalizar_nivel_exitosamente()  # monedas, rescates y logros (necesita este nivel cargado)
		body.set_physics_process(false)
		
		if cuadro_negro:
			var tween = create_tween()
			tween.tween_property(cuadro_negro, "modulate:a", 1.0, 3.0)
			await tween.finished
		
		EstadisticasNivel.ir_al_score()

func _on_zona_instructor_body_entered(_body: Node3D) -> void:
	pass

func _on_timer_letras_timeout() -> void:
	pass
