extends AnimatedSprite2D

var gravedad = 1800
var velocidad_salto = -850
var velocidad_y = 0
var esta_en_suelo = true
var altura_suelo = 510

func _process(delta):
	var padre = get_parent()
	if not padre.juego_activo: return 
	
	if (Input.is_action_just_pressed("ui_accept") or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)) and esta_en_suelo:
		velocidad_y = velocidad_salto
		esta_en_suelo = false
		rotation_degrees = -15 

	velocidad_y += gravedad * delta
	position.y += velocidad_y * delta

	if position.y >= altura_suelo:
		position.y = altura_suelo
		if not esta_en_suelo:
			esta_en_suelo = true
			rotation_degrees = 0
			scale = Vector2(1.2, 0.8)
			create_tween().tween_property(self, "scale", Vector2(1, 1), 0.1)
		velocidad_y = 0
	
	if not esta_en_suelo and velocidad_y > 0:
		rotation_degrees = 15
	
	check_colision()

func check_colision():
	var padre = get_parent()
	if not padre.juego_activo: return

	# 1. CHEQUEAR OBSTÁCULOS (MUERTE)
	for obs in get_tree().get_nodes_in_group("obstaculos"):
		if global_position.distance_to(obs.global_position) < 70:
			morir_epicamente()
			return

	# 2. CHEQUEAR MONEDAS (DINERO)
	for coin in get_tree().get_nodes_in_group("monedas"):
		if global_position.distance_to(coin.global_position) < 60:
			recolectar_moneda(coin)

func recolectar_moneda(coin):
	var padre = get_parent()
	
	# Evitamos que la moneda se agarre dos veces
	coin.remove_from_group("monedas")
	
	# Efecto visual de desaparición
	var tw = create_tween().set_parallel(true)
	tw.tween_property(coin, "position:y", coin.position.y - 100, 0.3)
	tw.tween_property(coin, "modulate:a", 0, 0.3)
	tw.tween_property(coin, "scale", Vector2.ZERO, 0.3)
	tw.chain().tween_callback(coin.queue_free)
	
	# Pago y Sonido
	ProgresoJuego.monedas += 1
	if padre.sfx_coin: 
		padre.sfx_coin.play()

func morir_epicamente():
	var padre = get_parent()
	padre.finalizar_juego() 
	
	var tw = create_tween().set_parallel(true)
	tw.tween_property(self, "position", position + Vector2(600, -1000), 1.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "rotation_degrees", 2000, 1.5)
	tw.tween_property(self, "scale", Vector2.ZERO, 1.5)
	
	await get_tree().create_timer(2.0).timeout
	get_tree().reload_current_scene()
