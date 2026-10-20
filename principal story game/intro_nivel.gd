extends Node3D

var cuadro_negro: ColorRect


# --- CONFIGURACIÓN DE CÁMARA DINÁMICA (Estilo Castle Crashers) ---
@onready var camara: Camera3D = $Camera3D 
@export var cam_velocidad_suavizado: float = 5.0
@export var cam_distancia_minima_z: float = 6.0
@export var cam_distancia_maxima_z: float = 14.0
@export var cam_margen_zoom: float = 0.8

func _ready():
	# Tu lógica original del cuadro negro para el final del nivel
	cuadro_negro = find_child("ColorRect", true, false)
	
	if cuadro_negro:
		cuadro_negro.modulate.a = 0.0
	else:
		print("¡ERROR FATAL: No encontré ningún ColorRect en la escena!")


	# 2. INYECCIÓN DE SEGURIDAD ANTI-BUG
	var jugadores = get_tree().get_nodes_in_group("player")
	for p in jugadores:
		if is_instance_valid(p):
			if not is_finite(p.global_position.x) or not is_finite(p.global_position.y) or not is_finite(p.global_position.z):
				print("VIGILANTE: Error de realidad detectado. Castigando...")
				Cargador.ir_a_escena("res://scenes/CapaCastigo.tscn")
				return
			
			if p.global_position.y < -30.0:
				Cargador.ir_a_escena("res://scenes/CapaCastigo.tscn")
				return

func _physics_process(delta):
	# Manejo de la cámara dinámica compartida
	actualizar_camara_tutorial(delta)


func actualizar_camara_tutorial(delta: float):
	if not camara: return
	
	var objetivos: Array[Vector3] = []
	var jugadores = get_tree().get_nodes_in_group("player")
	
	for p in jugadores:
		if is_instance_valid(p):
			objetivos.append(p.global_position)
			
	if objetivos.is_empty(): return

	var suma_posiciones = Vector3.ZERO
	for pos in objetivos:
		suma_posiciones += pos
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

func _on_trigger_final_body_entered(body):
	if body.is_in_group("player") and cuadro_negro:
		print("¡Final del nivel alcanzado!")
		
		if ProgresoJuego.nivel_desbloqueado == 0:
			ProgresoJuego.nivel_desbloqueado = 1
		
		ProgresoJuego.finalizar_nivel_exitosamente() 
		
		for p in get_tree().get_nodes_in_group("player"):
			if is_instance_valid(p):
				p.set_physics_process(false)
		
		var tween = create_tween()
		tween.tween_property(cuadro_negro, "modulate:a", 1.0, 3.0)
		
		await tween.finished
		Cargador.ir_a_escena("res://scenes/MapaNiveles.tscn")
