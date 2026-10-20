extends Area3D

@onready var camara_principal = get_viewport().get_camera_3d()
var activado = false

# --- IMPORTANTE ---
@export var escena_logro_universal : PackedScene 

func _ready():
	# Sellar pozo si ya se desbloqueó en ProgresoJuego
	if ProgresoJuego.rata_pelada_desbloqueada:
		sellar_pozo()
		set_process(false)
	print("--- RADAR DEL POZO INICIADO ---")

func _process(_delta):
	if activado: return
	
	var todos_los_tachos = get_tree().get_nodes_in_group("tachos")
	
	for tacho in todos_los_tachos:
		var distancia = global_position.distance_to(tacho.global_position)
		
		# Si un tacho está cerca, activamos el secreto sin importar el personaje
		if distancia < 1.8:
			var player = get_tree().get_first_node_in_group("player")
			if player:
				# ELIMINADA LA RESTRICCIÓN DE NOMBRE "SKETCH"
				activar_secreto(tacho)
				break

func activar_secreto(tacho):
	activado = true
	var player = get_tree().get_first_node_in_group("player")
	
	if player: 
		player.set_physics_process(false)
		if camara_principal.has_method("set_enabled"):
			camara_principal.set_enabled(false) 

	# Centrar y desactivar colisiones del tacho para la caída
	tacho.global_position.x = global_position.x
	tacho.global_position.z = global_position.z
	tacho.set_collision_layer_value(1, false)
	tacho.set_collision_mask_value(1, false)

	if has_node("SonidoCaida"):
		$SonidoCaida.play()

	var tween = create_tween()
	tween.set_parallel(true)
	
	var cam_final_y = camara_principal.global_position.y - 15.0
	var tacho_final_y = tacho.global_position.y - 25.0
	
	# Caída lineal de 8 segundos
	tween.tween_property(camara_principal, "global_position:y", cam_final_y, 8.0).set_trans(Tween.TRANS_LINEAR)
	tween.tween_property(tacho, "global_position:y", tacho_final_y, 8.0).set_trans(Tween.TRANS_LINEAR)
	tween.tween_callback(func(): camara_principal.look_at(tacho.global_position))
	
	tween.set_parallel(false)
	
	# El Impacto en el fondo
	tween.tween_callback(func(): 
		if has_node("SonidoCaida"): $SonidoCaida.stop()
		tacho.visible = false
		reproducir_grito_rata()
		if has_node("HumoImpacto"): $HumoImpacto.emitting = true
	)
	
	# Tiempos de espera para el banner
	tween.tween_interval(1.5)
	tween.tween_callback(mostrar_banner_desbloqueo)
	
	# Devolver control y sellar
	tween.tween_interval(3.5)
	tween.tween_callback(func():
		if player: player.set_physics_process(true)
		if camara_principal.has_method("set_enabled"):
			camara_principal.set_enabled(true)
		sellar_pozo()
	)

func reproducir_grito_rata():
	if has_node("SonidoRata"):
		$SonidoRata.play()
		print("SISTEMA: ¡Grito de Prepucín ejecutado!")

func mostrar_banner_desbloqueo():
	ProgresoJuego.rata_pelada_desbloqueada = true
	ProgresoJuego.otorgar_logro("logro_forerat_rescatado")
	print("---------------------------")
	print("LOGRO MOSTRADO EN UI")
	print("---------------------------")

func sellar_pozo():
	if has_node("TablasVisual"):
		get_node("TablasVisual").visible = true
	set_process(false)
