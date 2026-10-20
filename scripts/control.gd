extends Control

# --- SISTEMA DE PÁGINAS ---
var pagina_actual = 1
const TOTAL_PAGINAS = 3

@onready var p1 = $Pagina1
@onready var p2 = $Pagina2
@onready var p3 = $Pagina3
@onready var btn_pasar = $Pasar
@onready var sonido_pagina = $SonidoPagina

# --- BOTONES EN PÁGINA 1 (Canónicos) ---
@onready var boton_sketch        = $Pagina1/BotonSketch
@onready var boton_max           = $Pagina1/BotonMax
@onready var boton_jane          = $Pagina1/BotonJane
@onready var boton_nubbe         = $Pagina1/BotonNubbe
@onready var boton_chosmix       = $Pagina1/BotonChosmix

# --- BOTONES EN PÁGINA 2 (Memes) ---
@onready var boton_prepucin      = $Pagina2/BotonPrepucin 
@onready var boton_plasticsketch = $Pagina2/BotonPlastic

# --- BOTONES EN PÁGINA 3 (Colaboraciones) ---
@onready var boton_alloy         = $Pagina3/BotonAlloy
@onready var boton_tankman       = $Pagina3/BotonTankman

# --- SPRITES SEPARADOS DE CADA PERSONAJE ---
@onready var sprite_sketch        = $SpriteSketch
@onready var sprite_max           = $SpriteMax
@onready var sprite_jane          = $SpriteJane
@onready var sprite_prepucin      = $SpritePrepucin
@onready var sprite_nubbe         = $SpriteNubbe
@onready var sprite_plasticsketch = $SpritePlastic
@onready var sprite_chosmix       = $SpriteChosmix
@onready var sprite_alloy         = $SpriteAlloy
@onready var sprite_tankman       = $SpriteTankman

@onready var label_historia = $LabelHistoria

# --- CAPAS DE COLOR Y TRANSICIÓN ---
@onready var fondo_oscuro   = $FondoOscuro
@onready var fundido_negro  = $FundidoNegro

# --- NODOS DE SELECCIÓN ---
@onready var flecha = $FlechaSeleccion
@onready var marco  = $MarcoBlanco

# --- CÁMARA ---
@onready var camara = $Camera2D

# --- SONIDOS Y MÚSICA ADAPTATIVA ---
@onready var musica_tema      = $Theme
@onready var tema_sketch      = $ThemeSketch
@onready var tema_max         = $ThemeMax
@onready var tema_jane        = $ThemeJane
@onready var tema_prepucin    = $ThemePrepucin
@onready var tema_nubbe       = $ThemeNubbe
@onready var tema_plasticsketch = $ThemePlastic
@onready var tema_chosmix     = $ThemeChosmix
@onready var tema_alloy       = $ThemeAlloy
@onready var tema_tankman     = $ThemeTankman

@onready var sonido_hover      = $SonidoHover
@onready var sonido_click      = $SonidoSeleccion
@onready var sonido_bloqueado = $SonidoBloqueado
@onready var sonido_plastic   = $SonidoPlastic

var escala_base = Vector2(0.5, 0.5)
var bloqueado   = false 
var tiempo      = 0.0 

# Variables de la cámara
var pos_inicial_camara: Vector2
var zoom_inicial_camara: Vector2
var posicion_objetivo_camara: Vector2
var zoom_objetivo_camara: Vector2

# Juiciness: Control del Shake
var shake_amount = 0.0
var shake_decay = 0.9

# Controladores de Tweens activos
var tw_camara: Tween
var tw_sketch: Tween
var tw_pagina: Tween
var tw_musica: Tween

var dic_stems = {}

var historias = {
	"es": {
		"sketch":        "Sketch\nClase: Centinela.",
		"max":           "Max\nClase: Tanque.",
		"jane":          "Jane\nClase: Defensor.",
		"prepucin":      "Prepucin\nClase: Desconocida",
		"nubbe":         "Nubbe\nClase: Centinela Híbrido.",
		"plasticsketch": "Plastic Sketch\nClase: Desconocida.",
		"chosmix":       "Chosmix\nClase: Tanque Hibrido.",
		"alloy":         "Alloy\nClase: Desconocida.",
		"tankman":       "Tankman\nClase: Desconocida."
	},
	"en": {
		"sketch":        "Sketch\nClass: Sentinel.",
		"max":           "Max\nClass: Tank.",
		"jane":          "Jane\nClass: Defender.",
		"prepucin":      "Forerat\nClass: Unknown",
		"nubbe":         "Nubbe\nClass: Hybrid Sentinel.",
		"plasticsketch": "Plastic Sketch\nClass: Unknown.",
		"chosmix":       "Chosmix\nClass: Hybrid Tank.",
		"alloy":         "Alloy\nClass: Unknown.",
		"tankman":       "Tankman\nClass: Unknown."
	},
	"ja": {
		"sketch":        "スケッチ\nクラス：センチネル",
		"max":           "マックス\nクラス：タンク",
		"jane":          "ジェーン\nクラス：ディフェンダー",
		"prepucin":      "プレプシン\nクラス：不明",
		"nubbe":         "ヌッベ\nクラス：ハイブリッドセンチネル",
		"plasticsketch": "プラスチックスケッチ\nクラス：不明",
		"chosmix":       "コスミックス\nクラス：不明",
		"alloy":         "アロイ\nクラス：不明",
		"tankman":       "タンクマン\nクラス：不明"
	}
}

var sprites_personajes = {}
var posicion_inicial_label: Vector2
var lista_botones = []

func _ready():
	if fondo_oscuro:
		fondo_oscuro.visible = true
		fondo_oscuro.modulate.a = 0.0
		fondo_oscuro.color = Color.BLACK
	
	if fundido_negro: 
		fundido_negro.visible = true
		fundido_negro.modulate.a = 1.0
		if fundido_negro.material:
			fundido_negro.material.set_shader_parameter("luminance_cutoff", 0.0)
			var tw_entrada = create_tween()
			tw_entrada.tween_property(fundido_negro.material, "shader_parameter/luminance_cutoff", 1.0, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	
	if flecha: flecha.hide()
	if marco:  marco.hide()
	
	if label_historia:
		label_historia.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label_historia.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		posicion_inicial_label = label_historia.position
	
	if camara:
		pos_inicial_camara = camara.position
		zoom_inicial_camara = camara.zoom
		posicion_objetivo_camara = pos_inicial_camara
		zoom_objetivo_camara = zoom_inicial_camara
	
	sprites_personajes = {
		"sketch":        sprite_sketch,
		"max":           sprite_max,
		"jane":          sprite_jane,
		"prepucin":      sprite_prepucin,
		"nubbe":         sprite_nubbe,
		"plasticsketch": sprite_plasticsketch,
		"chosmix":       sprite_chosmix,
		"alloy":         sprite_alloy,
		"tankman":       sprite_tankman
	}
	
	# Mapeo de Nodos de Audio por Personaje
	dic_stems = {
		"sketch":        tema_sketch,
		"max":           tema_max,
		"jane":          tema_jane,
		"prepucin":      tema_prepucin,
		"nubbe":         tema_nubbe,
		"plasticsketch": tema_plasticsketch,
		"chosmix":       tema_chosmix,
		"alloy":         tema_alloy,
		"tankman":       tema_tankman
	}
	
	lista_botones = [
		boton_sketch,
		boton_max,
		boton_jane,
		boton_nubbe,
		boton_chosmix,
		boton_prepucin,
		boton_plasticsketch,
		boton_alloy,
		boton_tankman
	]
	
	for nombre_pj in sprites_personajes:
		var spr = sprites_personajes[nombre_pj]
		if spr:
			if nombre_pj == "sketch":
				spr.visible = true
				spr.modulate.a = 1.0
				spr.play("idlesketch")
			else:
				spr.visible = false
				spr.modulate.a = 0.0

	_configurar_hover(boton_sketch,        "sketch")
	_configurar_hover(boton_max,           "max")
	_configurar_hover(boton_jane,          "jane")
	_configurar_hover(boton_nubbe,         "nubbe")
	_configurar_hover(boton_chosmix,       "chosmix")
	_configurar_hover(boton_prepucin,      "prepucin")
	_configurar_hover(boton_plasticsketch, "plasticsketch")
	_configurar_hover(boton_alloy,         "alloy")
	_configurar_hover(boton_tankman,       "tankman")
	
	for btn in lista_botones:
		if btn: btn.scale = escala_base
	
	pagina_actual = 1
	_inicializar_paginas_instantaneo()
	actualizar_estado_bloqueo()
	_iniciar_musica_sincronizada()

# --- SISTEMA DE MÚSICA ADAPTATIVA ---

func _iniciar_musica_sincronizada():
	if musica_tema:
		musica_tema.volume_db = 0.0
		musica_tema.play()
	
	# Iniciamos todos los temas al mismo tiempo en silencio
	for pj in dic_stems:
		var audio_player = dic_stems[pj]
		if audio_player:
			audio_player.volume_db = -80.0
			audio_player.play(0.0)

func _cambiar_stem_musica(nombre_pj_activo: String):
	# Cancelamos cualquier tween activo de música para evitar retrasos
	if tw_musica: tw_musica.kill()
	
	if nombre_pj_activo != "":
		# AL ENTRAR A UN PERSONAJE:
		# 1. Bajamos el Theme principal a un volumen de fondo (ej. -12 dB o -18 dB)
		#    Si prefieres que se calle por completo al instante sin fadeout, usa -80.0 directo.
		if musica_tema:
			musica_tema.volume_db = -15.0 
		
		# 2. Activamos el tema del personaje AL INSTANTE (sin fadeout/fadein)
		for pj in dic_stems:
			var audio_player = dic_stems[pj]
			if audio_player:
				audio_player.volume_db = 0.0 if pj == nombre_pj_activo else -80.0
	else:
		# AL SALIR DEL PERSONAJE:
		# 1. Restauramos el Theme principal a su volumen normal de golpe
		if musica_tema:
			musica_tema.volume_db = 0.0
		
		# 2. Silenciamos instantáneamente todos los temas de personajes
		for pj in dic_stems:
			var audio_player = dic_stems[pj]
			if audio_player:
				audio_player.volume_db = -80.0

func _set_mouse_interactable(nodo_pagina: Control, activo: bool):
	if not nodo_pagina: return
	nodo_pagina.visible = activo
	for child in nodo_pagina.get_children():
		if child is Control:
			child.mouse_filter = Control.MOUSE_FILTER_STOP if activo else Control.MOUSE_FILTER_IGNORE

func _inicializar_paginas_instantaneo():
	var paginas = [p1, p2, p3]
	for i in range(paginas.size()):
		var pag = paginas[i]
		if pag:
			var es_actual = ((i + 1) == pagina_actual)
			_set_mouse_interactable(pag, es_actual)
			if es_actual:
				pag.modulate.a = 1.0
				pag.scale = Vector2.ONE
			else:
				pag.modulate.a = 0.0

func _on_pasar_pressed():
	if bloqueado: return
	
	if sonido_pagina: sonido_pagina.play()
	if marco: marco.hide()
	if flecha: flecha.hide()
	
	posicion_objetivo_camara = pos_inicial_camara
	zoom_objetivo_camara = zoom_inicial_camara
	
	var paginas = [p1, p2, p3]
	var pagina_anterior = paginas[pagina_actual - 1]
	
	if pagina_anterior:
		_set_mouse_interactable(pagina_anterior, false)
	
	pagina_actual += 1
	if pagina_actual > TOTAL_PAGINAS: 
		pagina_actual = 1
		
	var pagina_nueva = paginas[pagina_actual - 1]
	
	shake_amount = 6.0
	
	if tw_pagina: tw_pagina.kill()
	tw_pagina = create_tween().set_parallel(true)
	
	if pagina_anterior:
		tw_pagina.tween_property(pagina_anterior, "modulate:a", 0.0, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw_pagina.tween_property(pagina_anterior, "scale", Vector2(0.85, 0.85), 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		
	if pagina_nueva:
		pagina_nueva.visible = true
		pagina_nueva.modulate.a = 0.0
		pagina_nueva.scale = Vector2(1.15, 1.15)
		
		tw_pagina.tween_property(pagina_nueva, "modulate:a", 1.0, 0.25).set_delay(0.1)
		tw_pagina.tween_property(pagina_nueva, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(0.1)
		
		tw_pagina.chain().tween_callback(func(): _set_mouse_interactable(pagina_nueva, true))

# --- PROCESO PRINCIPAL ---

func _process(delta):
	if flecha and flecha.visible:
		tiempo += delta * 7
		flecha.offset.y = sin(tiempo) * 4
		
	if camara and not bloqueado:
		var tamano_pantalla = get_viewport_rect().size
		var mouse_pos = get_viewport().get_mouse_position()
		var relacion_mouse = (mouse_pos / tamano_pantalla) - Vector2(0.5, 0.5)
		var offset_mouse = relacion_mouse * 45.0
		var pos_final_con_mouse = posicion_objetivo_camara + offset_mouse
		camara.position = camara.position.lerp(pos_final_con_mouse, delta * 5.0)
		camara.zoom = camara.zoom.lerp(zoom_objetivo_camara, delta * 5.0)
	
	if camara and shake_amount > 0.1:
		camara.offset = Vector2(
			randf_range(-shake_amount, shake_amount),
			randf_range(-shake_amount, shake_amount)
		)
		shake_amount = lerp(shake_amount, 0.0, shake_decay * delta * 10)
	elif camara:
		camara.offset = Vector2.ZERO
		
	if label_historia and camara:
		var desfase_camara = camara.position - pos_inicial_camara
		label_historia.position = posicion_inicial_label + desfase_camara
		var escala_inversa = Vector2.ONE / (camara.zoom / zoom_inicial_camara)
		label_historia.scale = escala_inversa

func _configurar_hover(boton, nombre_pj):
	if boton:
		if not boton.mouse_entered.is_connected(_on_hover):
			boton.mouse_entered.connect(_on_hover.bind(boton, nombre_pj))
		if not boton.mouse_exited.is_connected(_on_exit):
			boton.mouse_exited.connect(_on_exit.bind(boton, nombre_pj))

func actualizar_estado_bloqueo():
	if boton_max:           boton_max.modulate          = Color(1,1,1) if ProgresoJuego.max_desbloqueado          else Color(0.15,0.15,0.15)
	if boton_jane:          boton_jane.modulate         = Color(1,1,1) if ProgresoJuego.jane_desbloqueada         else Color(0.15,0.15,0.15)
	if boton_nubbe:         boton_nubbe.modulate        = Color(1,1,1) if ProgresoJuego.nubbe_desbloqueado        else Color(0.15,0.15,0.15)
	if boton_plasticsketch: boton_plasticsketch.modulate= Color(1,1,1) if ProgresoJuego.plasticsketch_desbloqueado else Color(0.15,0.15,0.15)
	if boton_chosmix:       boton_chosmix.modulate      = Color(1,1,1) if ProgresoJuego.chosmix_desbloqueado      else Color(0.15,0.15,0.15)
	if boton_alloy:         boton_alloy.modulate        = Color(1,1,1) if ProgresoJuego.alloy_desbloqueado        else Color(0.15,0.15,0.15)
	if boton_tankman:       boton_tankman.modulate      = Color(1,1,1) if ProgresoJuego.tankman_desbloqueado      else Color(0.15,0.15,0.15)
	if boton_prepucin:
		boton_prepucin.visible = ProgresoJuego.rata_pelada_desbloqueada

func _on_hover(boton, nombre_pj):
	if bloqueado: return
	if sonido_hover: sonido_hover.play()
	
	# Transición suave: Apaga Theme y activa la canción del personaje
	_cambiar_stem_musica(nombre_pj)
	
	if marco:
		marco.show()
		marco.global_position = boton.global_position + (boton.size * escala_base / 2) + Vector2(0, -15)
	
	if flecha:
		flecha.show()
		flecha.global_position = Vector2(boton.global_position.x + (boton.size.x * escala_base.x / 2), boton.global_position.y - 20)
	
	var spr = sprites_personajes.get(nombre_pj)
	if spr:
		spr.visible = true
		var anim_idle = "idle" + nombre_pj
		if spr.sprite_frames.has_animation(anim_idle):
			spr.play(anim_idle)
		else:
			spr.play("idle")
		var tw_vis = create_tween().set_parallel(true)
		tw_vis.tween_property(spr, "modulate:a", 1.0, 0.2)
		
		if camara and nombre_pj != "sketch":
			posicion_objetivo_camara = pos_inicial_camara.lerp(spr.position, 0.3)
			zoom_objetivo_camara = zoom_inicial_camara * 1.15
			
		if (nombre_pj == "jane" or nombre_pj == "max") and sprite_sketch:
			if tw_sketch: tw_sketch.kill()
			tw_sketch = create_tween()
			tw_sketch.tween_property(sprite_sketch, "modulate:a", 0.0, 0.2)
	
	if label_historia:
		var lang = ProgresoJuego.idioma 
		var lang_final = lang if lang in historias else "en"
		label_historia.text = historias[lang_final][nombre_pj]
		label_historia.modulate.a = 0
		create_tween().tween_property(label_historia, "modulate:a", 1.0, 0.2)

func _on_exit(_boton, nombre_pj):
	if bloqueado: return
	if marco: marco.hide()
	if flecha: flecha.hide()
	
	# Transición suave: Apaga canción del personaje y reactiva Theme principal
	_cambiar_stem_musica("")
	
	if nombre_pj != "sketch":
		var spr = sprites_personajes.get(nombre_pj)
		if spr:
			var tw_exit = create_tween()
			tw_exit.tween_property(spr, "modulate:a", 0.0, 0.15)
			await tw_exit.finished
			if not bloqueado and spr.modulate.a == 0.0:
				spr.visible = false

	if camara and nombre_pj != "sketch":
		posicion_objetivo_camara = pos_inicial_camara
		zoom_objetivo_camara = zoom_inicial_camara
		
	if (nombre_pj == "jane" or nombre_pj == "max") and sprite_sketch:
		if tw_sketch: tw_sketch.kill()
		tw_sketch = create_tween()
		tw_sketch.tween_property(sprite_sketch, "modulate:a", 1.0, 0.2)

# --- BOTONES SELECCIÓN ---

func _on_boton_sketch_pressed():        _seleccionar_personaje("sketch",        true)
func _on_boton_max_pressed():           _seleccionar_personaje("max",           ProgresoJuego.max_desbloqueado)
func _on_boton_jane_pressed():          _seleccionar_personaje("jane",          ProgresoJuego.jane_desbloqueada)
func _on_boton_prepucin_pressed():      _seleccionar_personaje("prepucin",      ProgresoJuego.rata_pelada_desbloqueada)
func _on_boton_nubbe_pressed():         _seleccionar_personaje("nubbe",         ProgresoJuego.nubbe_desbloqueado)
func _on_boton_plastic_pressed():       _seleccionar_personaje("plasticsketch", ProgresoJuego.plasticsketch_desbloqueado)
func _on_boton_chosmix_pressed():       _seleccionar_personaje("chosmix",       ProgresoJuego.chosmix_desbloqueado)
func _on_boton_alloy_pressed():         _seleccionar_personaje("alloy",         ProgresoJuego.alloy_desbloqueado)
func _on_boton_tankman_pressed():       _seleccionar_personaje("tankman",       ProgresoJuego.tankman_desbloqueado)

func _seleccionar_personaje(nombre, esta_desbloqueado):
	if bloqueado: return
	
	if esta_desbloqueado:
		bloqueado = true 
		if marco: marco.hide()
		if flecha: flecha.hide()
		
		GameManager.personaje_elegido = nombre
		if nombre == "sketch" and not ProgresoJuego.logro_sketch_desbloqueado:
			ProgresoJuego.otorgar_logro("logro_sketch_desbloqueado")
		
		shake_amount = 16.0 
		
		# Efecto vinilo tanto en el tema principal como en la canción activa
		var tw_vinyl = create_tween().set_parallel(true)
		if musica_tema and musica_tema.playing:
			tw_vinyl.tween_property(musica_tema, "pitch_scale", 0.01, 0.8).set_trans(Tween.TRANS_CIRC).set_ease(Tween.EASE_IN)
			tw_vinyl.tween_property(musica_tema, "volume_db", -40.0, 0.8)
		
		for pj in dic_stems:
			var stem = dic_stems[pj]
			if stem and stem.playing:
				tw_vinyl.tween_property(stem, "pitch_scale", 0.01, 0.8).set_trans(Tween.TRANS_CIRC).set_ease(Tween.EASE_IN)
				tw_vinyl.tween_property(stem, "volume_db", -40.0, 0.8)
		
		var spr_elegido = sprites_personajes.get(nombre)
		
		if label_historia:
			create_tween().tween_property(label_historia, "modulate:a", 0.0, 0.1)
			
		for btn in lista_botones:
			if btn:
				create_tween().tween_property(btn, "modulate:a", 0.0, 0.15)
				
		if btn_pasar:
			create_tween().tween_property(btn_pasar, "modulate:a", 0.0, 0.15)
			
		for n_pj in sprites_personajes:
			if n_pj != nombre and sprites_personajes[n_pj]:
				var spr_otro = sprites_personajes[n_pj]
				create_tween().tween_property(spr_otro, "modulate:a", 0.0, 0.1)
		
		if spr_elegido:
			spr_elegido.visible = true
			spr_elegido.modulate.a = 1.0
			spr_elegido.modulate = Color(1.8, 1.8, 1.8)
			var tw_brillo = create_tween()
			tw_brillo.tween_property(spr_elegido, "modulate", Color(1.0, 1.0, 1.0), 0.25)
			var anim_selected = nombre + "selected"
			if spr_elegido.sprite_frames.has_animation(anim_selected):
				spr_elegido.play(anim_selected)
			else:
				spr_elegido.play("selected")
		
		if nombre == "prepucin":
			var p = AudioStreamPlayer.new()
			add_child(p)
			p.stream = load("res://sonidos/prepucin select.mp3")
			p.play()
		elif nombre == "plasticsketch":
			if sonido_plastic: sonido_plastic.play()
		else:
			if sonido_click: sonido_click.play()
		
		if fondo_oscuro:
			var tw_faro = create_tween()
			tw_faro.tween_property(fondo_oscuro, "modulate:a", 0.85, 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		
		await get_tree().create_timer(1.1).timeout 
		
		if fundido_negro and fundido_negro.material:
			var tw_cierre = create_tween()
			tw_cierre.tween_property(fundido_negro.material, "shader_parameter/luminance_cutoff", 0.0, 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
			await tw_cierre.finished
			
		if musica_tema: musica_tema.stop()
		for pj in dic_stems:
			if dic_stems[pj]: dic_stems[pj].stop()
			
		await get_tree().create_timer(0.3).timeout 
		Cargador.ir_a_escena("res://scenes/MapaNiveles.tscn")
		
	else:
		if sonido_bloqueado: sonido_bloqueado.play()
		var btn = null
		match nombre:
			"plasticsketch": btn = boton_plasticsketch
			"chosmix":       btn = boton_chosmix
			"alloy":         btn = boton_alloy
			"tankman":       btn = boton_tankman
			"sketch":        btn = boton_sketch
			"max":           btn = boton_max
			"jane":          btn = boton_jane
			"nubbe":         btn = boton_nubbe
			"prepucin":      btn = boton_prepucin
		if btn: sacudir_boton(btn)

func sacudir_boton(boton):
	var pos_original = boton.position
	var t = create_tween()
	t.tween_property(boton, "position:x", pos_original.x + 8, 0.05)
	t.tween_property(boton, "position:x", pos_original.x - 8, 0.05)
	t.tween_property(boton, "position:x", pos_original.x, 0.05)
