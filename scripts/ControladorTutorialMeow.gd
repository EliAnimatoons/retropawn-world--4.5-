extends Area3D

var minion_escena = preload("res://scenes/Minion.tscn")
@onready var dialogo_ui = get_tree().current_scene.find_child("Dialogos")
@onready var barreras = get_tree().current_scene.find_child("BarrerasTutorial")

var minions_totales_restantes = 10
var minions_en_pantalla = 0
var tutorial_parry_fase = 0 
var spawn_en_progreso = false

func _ready():
	tutorial_parry_fase = 0
	if barreras:
		barreras.hide()
		for hijo in barreras.get_children():
			if hijo is StaticBody3D:
				hijo.process_mode = PROCESS_MODE_DISABLED
	
	if not body_entered.is_connected(_on_jugador_entra):
		body_entered.connect(_on_jugador_entra)

func _on_jugador_entra(body):
	if body.is_in_group("player") and body.character_name == "Sketch" and not ProgresoJuego.tutorial_completado:
		if body_entered.is_connected(_on_jugador_entra):
			body_entered.disconnect(_on_jugador_entra)
		iniciar_evento(body)

func iniciar_evento(player):
	if not is_inside_tree(): return
	player.tutorial_bloqueo = true
	
	var t = create_tween()
	t.tween_property(player.sprite, "modulate:a", 0.0, 0.2)
	await t.finished
	
	if not is_inside_tree(): return
	player.global_position = global_position + Vector3(0, 0.5, 0)
	
	t = create_tween()
	t.tween_property(player.sprite, "modulate:a", 1.0, 0.2)
	
	if barreras:
		barreras.show()
		for hijo in barreras.get_children():
			if hijo is StaticBody3D: hijo.process_mode = PROCESS_MODE_INHERIT
	
	tutorial_parry_fase = 0
	await spawnear_minions(3)
	
	if dialogo_ui and is_inside_tree():
		var texto = "¡Vaya! Veamos si realmente lo sabes..."
		if ProgresoJuego.idioma == "en":
			texto = "Well! Let's see if you really know..."
		
		dialogo_ui.iniciar_charla([texto])
		await dialogo_ui.terminado
	
	if not is_inside_tree(): return
	player.tutorial_bloqueo = false
	tutorial_parry_fase = 1
	descongelar_uno_solo()

func spawnear_minions(cantidad):
	if not is_inside_tree() or spawn_en_progreso: return
	spawn_en_progreso = true
	
	for i in range(cantidad):
		if not is_inside_tree(): break
		if minions_totales_restantes > 0:
			var m = minion_escena.instantiate()
			m.tutorial_congelado = (tutorial_parry_fase < 3)
			get_tree().current_scene.add_child(m)
			
			var offset = Vector3(randf_range(-1,1), 0, randf_range(-1,1))
			var n_spawn = (minions_en_pantalla % 3) + 1
			var spawn_point = get_tree().current_scene.find_child("Spawn" + str(n_spawn), true, false)
			
			m.global_position = (spawn_point.global_position if spawn_point else global_position) + offset
			
			if m.has_signal("ataque_inminente"):
				m.ataque_inminente.connect(_on_minion_ataca)
			m.tree_exited.connect(_on_minion_muere)
			
			minions_en_pantalla += 1
			minions_totales_restantes -= 1
			await get_tree().create_timer(0.1).timeout
	
	spawn_en_progreso = false

func descongelar_uno_solo():
	if not is_inside_tree(): return
	for e in get_tree().get_nodes_in_group("enemy"):
		if is_instance_valid(e) and "tutorial_congelado" in e:
			if e.tutorial_congelado:
				e.tutorial_congelado = false
				return 

func _on_minion_ataca(minion_ref):
	if not is_inside_tree(): return
	if tutorial_parry_fase == 1 or tutorial_parry_fase == 2:
		Engine.time_scale = 0.0
		var msg = "¡Hazle parry para bloquear su ataque!"
		if ProgresoJuego.idioma == "en":
			msg = "Perform a parry to block its attack!"
		
		if dialogo_ui:
			dialogo_ui.iniciar_charla([msg])
			await dialogo_ui.terminado
		
		Engine.time_scale = 1.0
		if not is_inside_tree(): return
		
		var player = get_tree().get_first_node_in_group("player")
		if player: await player.parry_realizado
		
		tutorial_parry_fase += 1
		if tutorial_parry_fase == 3:
			var final_msg = "¡Ahora lucha!" if ProgresoJuego.idioma == "es" else "Now fight!"
			if dialogo_ui: dialogo_ui.iniciar_charla([final_msg])
			descongelar_todos()
		else:
			descongelar_uno_solo()

func descongelar_todos():
	if not is_inside_tree(): return
	for e in get_tree().get_nodes_in_group("enemy"):
		if is_instance_valid(e) and "tutorial_congelado" in e:
			e.tutorial_congelado = false

func _on_minion_muere():
	if not is_inside_tree(): return
	minions_en_pantalla -= 1
	_revisar_oleada_seguro()

func _revisar_oleada_seguro():
	# Blindaje contra error de "null tree"
	if not is_inside_tree() or get_tree() == null: return
	
	await get_tree().process_frame
	
	# Chequeo post-await
	if not is_inside_tree() or get_tree() == null: return
	
	if tutorial_parry_fase >= 3:
		if minions_totales_restantes > 0 and minions_en_pantalla < 3 and not spawn_en_progreso:
			spawnear_minions(1)
	
	if minions_totales_restantes <= 0 and minions_en_pantalla <= 0:
		finalizar_tutorial()

func finalizar_tutorial():
	ProgresoJuego.tutorial_completado = true
	if barreras and is_instance_valid(barreras): 
		barreras.queue_free()
	queue_free()
