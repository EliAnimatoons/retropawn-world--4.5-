extends Area3D

@export var trigger_final: Area3D
@export var punto_inicio_salida: Marker3D
@export var lista_muros: Array[Node3D]
@export var tiempo_escape: float = 60.0
@export var musica_escape: AudioStream
@export var umbral_manos_segundos: float = 60.0 # (viejo, ya no se usa: ahora cuenta el tiempo transcurrido)
@export var segundos_para_manos: float = 60.0 # NUEVO: segundos DESDE QUE ARRANCA el colapso para que aparezcan las manos

var colapso_iniciado: bool = false
var tiempo_restante: float = 0.0
var mundo_nivel: Node = null
var hud_ref: Node = null
var _manos_disparadas: bool = false # NUEVO
var _tiempo_transcurrido: float = 0.0 # NUEVO: cuánto pasó desde que arrancó el colapso

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	
	for muro in lista_muros:
		if is_instance_valid(muro):
			muro.visible = false
			muro.process_mode = Node.PROCESS_MODE_DISABLED

func _on_body_entered(body: Node) -> void:
	if colapso_iniciado: return
	
	if body.is_in_group("player"):
		iniciar_colapso()

func iniciar_colapso() -> void:
	colapso_iniciado = true
	tiempo_restante = tiempo_escape
	_manos_disparadas = false
	_tiempo_transcurrido = 0.0 # NUEVO
	print("¡ALERTA! SECUENCIA DE ESCAPE INICIADA")

	var mundo = get_tree().current_scene
	mundo_nivel = mundo
	if mundo and mundo.has_method("detener_musica_nivel"):
		mundo.detener_musica_nivel()

	var bus_efectos = AudioServer.get_bus_index("Efectos")
	if bus_efectos != -1:
		AudioServer.set_bus_mute(bus_efectos, true)

	if musica_escape:
		var audio_player = get_node_or_null("AudioEscape") as AudioStreamPlayer
		if not audio_player:
			audio_player = AudioStreamPlayer.new()
			audio_player.name = "AudioEscape"
			add_child(audio_player)
		
		audio_player.bus = "SuperSong"
		audio_player.stream = musica_escape
		audio_player.play()

	if is_instance_valid(trigger_final):
		if is_instance_valid(punto_inicio_salida):
			trigger_final.global_position = punto_inicio_salida.global_position
		
		trigger_final.visible = true
		trigger_final.set_deferred("monitoring", true)
		trigger_final.set_deferred("monitorable", true)
		
		for child in trigger_final.get_children():
			if child is CollisionShape3D or child is CollisionPolygon3D:
				child.set_deferred("disabled", false)

		if mundo and mundo.has_method("_on_trigger_final_body_entered"):
			if not trigger_final.body_entered.is_connected(mundo._on_trigger_final_body_entered):
				trigger_final.body_entered.connect(mundo._on_trigger_final_body_entered)

	for muro in lista_muros:
		if is_instance_valid(muro):
			muro.visible = true
			muro.process_mode = Node.PROCESS_MODE_INHERIT

	var huds = get_tree().get_nodes_in_group("hud")
	if huds.size() > 0:
		hud_ref = huds[0]
		if hud_ref.has_method("mostrar_temporizador_colapso"):
			hud_ref.mostrar_temporizador_colapso(tiempo_escape)
		if hud_ref.has_method("detonar_hud_final"):
			hud_ref.detonar_hud_final()

	if mundo:
		mundo.add_to_group("nivel_con_carrera")

	if mundo and mundo.has_method("preparar_tinte_colapso"):
		mundo.preparar_tinte_colapso()

func _process(delta: float) -> void:
	if not colapso_iniciado: return
	tiempo_restante -= delta
	_tiempo_transcurrido += delta # NUEVO
	
	if mundo_nivel and mundo_nivel.has_method("actualizar_tiempo_colapso"):
		var intensidad = 1.0 - clamp(tiempo_restante / tiempo_escape, 0.0, 1.0)
		mundo_nivel.actualizar_tiempo_colapso(intensidad)

	if hud_ref and hud_ref.has_method("actualizar_timer_colapso"):
		hud_ref.actualizar_timer_colapso(tiempo_restante)

	# NUEVO: cuando pasó 1 minuto (o lo que pongas en segundos_para_manos) desde que arrancó
	# el colapso, aparecen las manos una sola vez
	if not _manos_disparadas and _tiempo_transcurrido >= segundos_para_manos:
		_manos_disparadas = true
		# Por si el HUD no estaba cargado al iniciar el colapso, lo buscamos de nuevo
		if not is_instance_valid(hud_ref):
			var huds = get_tree().get_nodes_in_group("hud")
			if huds.size() > 0:
				hud_ref = huds[0]
		if hud_ref and hud_ref.has_method("mostrar_manos_costado"):
			hud_ref.mostrar_manos_costado()

	if tiempo_restante <= 0.0:
		colapso_iniciado = false
		jugador_murio_por_tiempo()

func jugador_murio_por_tiempo() -> void:
	print("¡TIEMPO AGOTADO! El nivel colapsó.")
	
	var audio_player = get_node_or_null("AudioEscape") as AudioStreamPlayer
	if audio_player:
		audio_player.stop()
		
	var jugadores = get_tree().get_nodes_in_group("player")
	for p in jugadores:
		if is_instance_valid(p) and p.has_method("morir_jugador"):
			p.morir_jugador()
