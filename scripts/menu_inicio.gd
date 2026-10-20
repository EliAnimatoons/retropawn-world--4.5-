extends Node3D

@onready var btn_start = $UI/Contenedor/BtnStart
@onready var sprite_start = $UI/Contenedor/BtnStart/SpriteAnimado
@onready var btn_options = $UI/Contenedor/BtnOptions
@onready var sprite_options = $UI/Contenedor/BtnOptions/SpriteAnimado
@onready var btn_new_game = $UI/Contenedor/BtnNewGame 
@onready var sprite_new_game = $UI/Contenedor/BtnNewGame/SpriteAnimado
@onready var btn_tienda = $UI/Contenedor/BotonTienda
@onready var sprite_tienda = $UI/Contenedor/BotonTienda/SpriteAnimado
@onready var btn_museum = $UI/Contenedor/BtnMuseum
@onready var sprite_museum = $UI/Contenedor/BtnMuseum/SpriteAnimado

# TÍTULO DEL JUEGO
@onready var sprite_titulo = $UI/TituloJuego

@onready var musica = $MusicaMenu
@onready var sonido_hover = $SonidoHover
@onready var sonido_seleccion = $SonidoSeleccion
@onready var luz_trueno = $LuzRelampago
@onready var timer_trueno = $LuzRelampago/Timer
@onready var timer_proximo = $LuzRelampago/TimerSiguienteRayo

# LA CÁMARA MAESTRA
@onready var camara_maestra = $CamaraCentro

# REFERENCIAS A LAS CÁMARAS DE DESTINO
@onready var camara_nivel1 = $DECORACION_3D/ZonaNivel1/CamaraNivel1
@onready var camara_opciones = $DECORACION_3D/ZonaOpciones/CamaraOpciones
@onready var camara_tienda = $DECORACION_3D/ZonaTienda/CamaraTienda
@onready var camara_museo = $DECORACION_3D/ZonaMuseum/CamaraMuseo

# VARIABLES DE ESCALA ORIGINAL
var escala_orig_start : Vector2
var escala_orig_options : Vector2
var escala_orig_new_game : Vector2
var escala_orig_tienda : Vector2
var escala_orig_museum : Vector2 
var escala_orig_titulo : Vector2

# Resguardo de coordenadas del centro
var pos_centro_original : Vector3
var rot_centro_original : Vector3

# VARIABLES PARA LA RESPIRACIÓN SUAVE (Idle Sway)
var tiempo_respiracion : float = 0.0
var en_el_centro : bool = true

# Variable para bloquear los hovers una vez que se hace click en algo definitivo
var ya_se_hizo_click : bool = false

# PALETAS DE COLORES (Día y Noche)
var CIELO_TOP_DIA = Color("#660000")
var CIELO_BOT_DIA = Color("#cc0000")
var CIELO_NUBE_DIA = Color("#220000")

var CIELO_TOP_NOCHE = Color("#1a0000")
var CIELO_BOT_NOCHE = Color("#330000")
var CIELO_NUBE_NOCHE = Color("#0a0000")

# Colores cálidos para sub-escenas
var CIELO_TOP_CALIDO = Color("#5a2a18")  
var CIELO_BOT_CALIDO = Color("#9e4b2b")  
var CIELO_NUBE_CALIDO = Color("#2a1208") 

func _ready():
	escala_orig_museum = sprite_museum.scale
	escala_orig_start = sprite_start.scale
	escala_orig_options = sprite_options.scale
	escala_orig_new_game = sprite_new_game.scale
	escala_orig_tienda = sprite_tienda.scale
	escala_orig_titulo = sprite_titulo.scale
	
	_setup_botones()
	
	sprite_museum.position = btn_museum.size / 2
	sprite_museum.play("idle")
	
	luz_trueno.visible = false
	timer_proximo.timeout.connect(_on_intentar_trueno)
	timer_proximo.start(randf_range(2.0, 5.0))
	
	musica.volume_db = -40 
	musica.play()
	create_tween().tween_property(musica, "volume_db", -10.0, 3.0)
	
	configurar_cielo_automatico()
	
	camara_maestra.make_current()
	pos_centro_original = camara_maestra.global_position
	rot_centro_original = camara_maestra.global_rotation
	
	_animar_caida_titulo()

func configurar_cielo_automatico():
	var env_node = get_node_or_null("WorldEnvironment")
	if not env_node: return
	var mat = env_node.environment.sky.sky_material
	if not mat: return
	
	var noise_shape = FastNoiseLite.new()
	noise_shape.seed = randi()
	noise_shape.frequency = 0.012
	
	var tex_shape = NoiseTexture2D.new()
	tex_shape.seamless = true
	tex_shape.noise = noise_shape
	await tex_shape.changed
	
	var curve = Curve.new()
	curve.add_point(Vector2(0, 0))
	curve.add_point(Vector2(0.5, 1))
	curve.add_point(Vector2(1, 0))
	var curve_tex = CurveTexture.new()
	curve_tex.curve = curve
	
	mat.set_shader_parameter("cloud_shape_sampler", tex_shape)
	mat.set_shader_parameter("cloud_curves", curve_tex)
	
	var hora = Time.get_time_dict_from_system().hour
	var es_dia = hora >= 6 and hora < 20
	
	if es_dia:
		_actualizar_colores_cielo(CIELO_TOP_DIA, CIELO_BOT_DIA, CIELO_NUBE_DIA)
		mat.set_shader_parameter("stars_intensity", 0.0)
		mat.set_shader_parameter("is_night", false)
	else:
		_actualizar_colores_cielo(CIELO_TOP_NOCHE, CIELO_BOT_NOCHE, CIELO_NUBE_NOCHE)
		mat.set_shader_parameter("stars_intensity", 1.0)
		mat.set_shader_parameter("is_night", true)

func _setup_botones():
	sprite_start.position = btn_start.size / 2
	sprite_options.position = btn_options.size / 2
	sprite_new_game.position = btn_new_game.size / 2
	sprite_tienda.position = btn_tienda.size / 2
	for s in [sprite_start, sprite_options, sprite_new_game, sprite_tienda]: s.play("idle")
	
	btn_start.pressed.connect(func(): _cambiar_escena("res://scenes/personajes.tscn", sprite_start))
	btn_options.pressed.connect(func(): _cambiar_escena("res://scenes/config_controles.tscn", sprite_options))
	btn_tienda.pressed.connect(func(): _cambiar_escena("res://scenes/tienda.tscn", sprite_tienda))
	btn_museum.pressed.connect(func(): _cambiar_escena("res://scenes/museum.tscn", sprite_museum))
	btn_new_game.pressed.connect(_on_click_new_game)
	
	# HOVERS MODIFICADOS (Pasan su propio sprite para destacar)
	btn_start.mouse_entered.connect(func(): _on_hover_boton(sprite_start, escala_orig_start, camara_nivel1))
	btn_options.mouse_entered.connect(func(): _on_hover_boton(sprite_options, escala_orig_options, camara_opciones))
	btn_new_game.mouse_entered.connect(func(): _on_hover_boton(sprite_new_game, escala_orig_new_game, camara_nivel1))
	btn_tienda.mouse_entered.connect(_on_hover_tienda) 
	btn_museum.mouse_entered.connect(func(): _on_hover_boton(sprite_museum, escala_orig_museum, camara_museo))

	btn_start.mouse_exited.connect(func(): _on_exit_boton(sprite_start, escala_orig_start))
	btn_options.mouse_exited.connect(func(): _on_exit_boton(sprite_options, escala_orig_options))
	btn_new_game.mouse_exited.connect(func(): _on_exit_boton(sprite_new_game, escala_orig_new_game))
	btn_tienda.mouse_exited.connect(_on_exit_tienda) 
	btn_museum.mouse_exited.connect(func(): _on_exit_boton(sprite_museum, escala_orig_museum))

func _on_hover_boton(sprite_nodo, escala_original, camara_destino):
	if ya_se_hizo_click: return
	_zoom_in(sprite_nodo, escala_original)
	_regular_opacidad_botones(sprite_nodo) # 🌟 Atenúa los demás
	if camara_destino:
		_teletransportar_camara(camara_destino.global_position, camara_destino.global_rotation, false)

func _on_exit_boton(sprite_nodo, escala_original):
	if ya_se_hizo_click: return
	_zoom_out(sprite_nodo, escala_original)
	_regular_opacidad_botones(null) # 🌟 Restaura la opacidad de todos
	_teletransportar_camara(pos_centro_original, rot_centro_original, true)

func _on_hover_tienda():
	if ya_se_hizo_click: return
	if sonido_hover: sonido_hover.play()
	var t = create_tween().set_parallel(true)
	t.tween_property(sprite_tienda, "modulate", Color(2.0, 2.0, 2.0), 0.1)
	t.tween_property(sprite_tienda, "scale", escala_orig_tienda * 1.15, 0.1)
	_regular_opacidad_botones(sprite_tienda) # 🌟 Atenúa los demás
	if camara_tienda:
		_teletransportar_camara(camara_tienda.global_position, camara_tienda.global_rotation, false)

func _on_exit_tienda():
	if ya_se_hizo_click: return
	var t = create_tween().set_parallel(true)
	t.tween_property(sprite_tienda, "modulate", Color(1, 1, 1), 0.1)
	t.tween_property(sprite_tienda, "scale", escala_orig_tienda, 0.1)
	_regular_opacidad_botones(null) # 🌟 Restaura la opacidad de todos
	_teletransportar_camara(pos_centro_original, rot_centro_original, true)

# 🌟 NUEVA FUNCIÓN: Pone medio transparentes a los botones que NO tienen el foco
func _regular_opacidad_botones(sprite_activo):
	var t = create_tween().set_parallel(true)
	var lista_sprites = [sprite_start, sprite_options, sprite_new_game, sprite_tienda, sprite_museum]
	
	for s in lista_sprites:
		if s == null: continue
		if sprite_activo == null:
			# Si nadie está activo, todos vuelven a ser 100% visibles
			t.tween_property(s, "modulate:a", 1.0, 0.15)
		else:
			# El activo se queda al 100%, los demás bajan a 0.4 (medio transparentes)
			var opacidad_destino = 1.0 if s == sprite_activo else 0.4
			t.tween_property(s, "modulate:a", opacidad_destino, 0.15)

func _teletransportar_camara(nueva_pos: Vector3, nueva_rot: Vector3, volver_al_centro: bool):
	en_el_centro = volver_al_centro
	camara_maestra.global_position = nueva_pos
	camara_maestra.global_rotation = nueva_rot
	
	if volver_al_centro:
		var hora = Time.get_time_dict_from_system().hour
		if hora >= 6 and hora < 20:
			_actualizar_colores_cielo(CIELO_TOP_DIA, CIELO_BOT_DIA, CIELO_NUBE_DIA)
		else:
			_actualizar_colores_cielo(CIELO_TOP_NOCHE, CIELO_BOT_NOCHE, CIELO_NUBE_NOCHE)
	else:
		_actualizar_colores_cielo(CIELO_TOP_CALIDO, CIELO_BOT_CALIDO, CIELO_NUBE_CALIDO)

func _actualizar_colores_cielo(top: Color, bot: Color, nube: Color):
	var env_node = get_node_or_null("WorldEnvironment")
	if env_node and env_node.environment.sky:
		var mat = env_node.environment.sky.sky_material
		if mat:
			mat.set_shader_parameter("top_color", Vector3(top.r, top.g, top.b))
			mat.set_shader_parameter("bottom_color", Vector3(bot.r, bot.g, bot.b))
			mat.set_shader_parameter("clouds_light_color", Vector3(nube.r, nube.g, nube.b))

func _process(delta):
	if not en_el_centro:
		tiempo_respiracion += delta
		var sway_x = sin(tiempo_respiracion * 1.2) * 0.0008
		var sway_y = cos(tiempo_respiracion * 0.9) * 0.0005
		camara_maestra.rotate_y(sway_x)
		camara_maestra.rotate_x(sway_y)

func _cambiar_escena(ruta, sprite_elegido):
	ya_se_hizo_click = true 
	desactivar_botones()
	
	sprite_elegido.modulate = Color(10, 10, 10)
	if sonido_seleccion: sonido_seleccion.play()
	
	var t_ocultar = create_tween().set_parallel(true)
	if sprite_start != sprite_elegido: t_ocultar.tween_property(sprite_start, "modulate:a", 0.0, 0.25)
	if sprite_options != sprite_elegido: t_ocultar.tween_property(sprite_options, "modulate:a", 0.0, 0.25)
	if sprite_new_game: t_ocultar.tween_property(sprite_new_game, "modulate:a", 0.0, 0.25)
	if sprite_tienda != sprite_elegido: t_ocultar.tween_property(sprite_tienda, "modulate:a", 0.0, 0.25)
	if sprite_museum != sprite_elegido: t_ocultar.tween_property(sprite_museum, "modulate:a", 0.0, 0.25)
	
	create_tween().tween_property(musica, "volume_db", -80.0, 0.5)
	if sonido_seleccion: await sonido_seleccion.finished
	Cargador.ir_a_escena(ruta)

func _zoom_in(node, original_scale):
	if sonido_hover: sonido_hover.play()
	create_tween().tween_property(node, "scale", original_scale * 1.15, 0.1)

func _zoom_out(node, original_scale):
	create_tween().tween_property(node, "scale", original_scale, 0.1)

func _on_click_new_game():
	ProgresoJuego.borrar_progreso() # 🌟 Esto ya limpia las variables y borra el archivo real
	Engine.time_scale = 1.0
	
	if sonido_seleccion: 
		sonido_seleccion.play()
	
	sprite_new_game.modulate = Color(10, 10, 10)
	await get_tree().create_timer(0.2).timeout
	sprite_new_game.modulate = Color(1, 1, 1)
	print("Partida borrada. El tutorial está disponible de nuevo.")

func desactivar_botones():
	for b in [btn_start, btn_options, btn_new_game, btn_tienda, btn_museum]: b.disabled = true

func _on_intentar_trueno():
	if randf() < 0.7: lanzar_relampago()
	timer_proximo.start(randf_range(1.5, 4.0))

func lanzar_relampago():
	var env_node = get_node_or_null("WorldEnvironment")
	if not env_node: return
	var mat = env_node.environment.sky.sky_material
	luz_trueno.visible = true
	mat.set_shader_parameter("lightning_flash", 1.0)
	if has_node("SonidoTrueno"): $SonidoTrueno.play()
	await get_tree().create_timer(0.1).timeout
	luz_trueno.visible = false
	mat.set_shader_parameter("lightning_flash", 0.0)
	await get_tree().create_timer(0.06).timeout
	luz_trueno.visible = true
	mat.set_shader_parameter("lightning_flash", 1.0)
	await get_tree().create_timer(0.04).timeout
	luz_trueno.visible = false
	mat.set_shader_parameter("lightning_flash", 0.0)

func _animar_caida_titulo():
	var posicion_final = sprite_titulo.position
	sprite_titulo.position.y -= 1000.0
	var t = create_tween()
	
	t.tween_property(sprite_titulo, "position:y", posicion_final.y, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	
	t.chain().set_parallel(true)
	t.tween_property(sprite_titulo, "scale:x", escala_orig_titulo.x * 1.35, 0.08)
	t.tween_property(sprite_titulo, "scale:y", escala_orig_titulo.y * 0.60, 0.08)
	
	t.chain().set_parallel(true)
	t.tween_property(sprite_titulo, "scale:x", escala_orig_titulo.x * 0.85, 0.08)
	t.tween_property(sprite_titulo, "scale:y", escala_orig_titulo.y * 1.15, 0.08)
	
	t.chain().tween_property(sprite_titulo, "scale", escala_orig_titulo, 0.25).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	t.chain().tween_callback(_animar_entrada_botones)

func _animar_entrada_botones():
	desactivar_botones()
	
	var destino_start = sprite_start.position
	var destino_options = sprite_options.position
	var destino_new_game = sprite_new_game.position
	var destino_tienda = sprite_tienda.position
	var destino_museum = sprite_museum.position
	
	sprite_start.position.x -= 1200.0
	sprite_options.position.x += 1200.0
	sprite_new_game.position.x -= 1200.0
	sprite_tienda.position.x += 1200.0
	sprite_museum.position.x -= 1200.0
	
	var t = create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	t.tween_property(sprite_start, "position:x", destino_start.x, 0.7).set_delay(0.0)
	t.tween_property(sprite_options, "position:x", destino_options.x, 0.7).set_delay(0.1)
	t.tween_property(sprite_new_game, "position:x", destino_new_game.x, 0.7).set_delay(0.2)
	t.tween_property(sprite_tienda, "position:x", destino_tienda.x, 0.7).set_delay(0.3)
	t.tween_property(sprite_museum, "position:x", destino_museum.x, 0.7).set_delay(0.4)
	
	await t.finished
	btn_start.disabled = false
	btn_options.disabled = false
	btn_new_game.disabled = false
	btn_tienda.disabled = false
	btn_museum.disabled = false

func _input(event):
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_1: cambiar_escena("res://scenes/minigame.tscn")
			KEY_2: cambiar_escena("res://scenes/main_clicker.tscn")
			KEY_3: cambiar_escena("res://scenes/chef_ritmico.tscn")
			KEY_4: cambiar_escena("res://scenes/minijuego_patineta.tscn")

func cambiar_escena(ruta):
	print("Intentando ir a: ", ruta)
	if ResourceLoader.exists(ruta):
		Cargador.ir_a_escena(ruta)
	else:
		print("LA RUTA NO EXISTE: ", ruta)
