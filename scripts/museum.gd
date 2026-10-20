extends Control

@onready var jugador = $JugadorMuseo
@onready var anim_player = $JugadorMuseo/AnimatedSprite2D
@onready var camara = $Camera2D
@onready var musica_fondo = $MusicaFondo
@onready var sonido_pasos = $SonidoPasos
@onready var dialogo_freak = $Dialogos 

@onready var interactuables = $Interactuables.get_children()

@export var velocidad_mov = 140.0
@export var fuerza_salto = -350.0  # Fuerza del salto
@export var gravedad = 980.0       # Fuerza de gravedad
@export var ritmo_pasos = 0.35

var prefijo = ""
var timer_pasos = 0.0
var interactuable_cercano = null
var en_dialogo = false

# --- DIÁLOGOS DE FREAK ---
var dialogos_freak = {
	"es": [
		"Oh... ¡Otro jugador más aquí?",
		"En fin! Yo soy Freak! Soy el personal del museo!",
		"Aquí puedes tener más conocimiento sobre el juego...",
		"Los personajes, la historia, los enemigos...",
		"¡Todo está expuesto aquí para quien quiera saber!",
		"En fin! Investigalo por tu cuenta!",
		"Yo no soy quien para hablar contigo! blegh!"
	],
	"en": [
		"Oh... Another player here?",
		"Whatever! I'm Freak! I'm the museum staff!",
		"Here you can learn more about the game...",
		"The characters, the story, the enemies...",
		"Everything is on display for those who want to know!",
		"Anyway! Explore it yourself!",
		"I'm not the one to be talking to you! blegh!"
	],
	"ja": [
		"あ…またプレイヤーか？",
		"まあいいや！僕はフリーク！博物館のスタッフだよ！",
		"ここではゲームについてもっと知ることができるよ…",
		"キャラクター、ストーリー、敵…",
		"知りたい人のためにすべて展示してあるんだ！",
		"まあ！自分で調べてよ！",
		"僕は君と話す立場じゃないんだから！べーっ！"
	]
}

# --- DIÁLOGOS DE DESARROLLADORES (CARTELITOS) ---
var dialogos_carteles = {
	"bt1": {
		"es": ["BetaTester1 del juego."],
		"en": ["Game's BetaTester1."],
		"ja": ["ゲームのベータテスター1。"]
	},
	"bt2": {
		"es": ["BetaTester2 del juego."],
		"en": ["Game's BetaTester2."],
		"ja": ["ゲームのベータテスター2。"]
	},
	"santrix": {
		"es": ["Santrix, ideas y artista."],
		"en": ["Santrix, ideas and artist."],
		"ja": ["サントリックス、アイデアとアーティスト。"]
	},
	"batz": {
		"es": ["Batz, artista."],
		"en": ["Batz, artist."],
		"ja": ["バッツ、アーティスト。"]
	},
	"blitzy": {
		"es": ["Blitzy, invitado del juego."],
		"en": ["Blitzy, game guest."],
		"ja": ["ブリッツィ、ゲームのゲスト。"]
	},
	"pompe": {
		"es": ["Pompe, ideas y artista."],
		"en": ["Pompe, ideas and artist."],
		"ja": ["ポンペ、アイデアとアーティスト。"]
	},
	"nubbe": {
		"es": ["Nubbe, ideas, artista y músico."],
		"en": ["Nubbe, ideas, artist and musician."],
		"ja": ["ヌッベ、アイデア、アーティスト、ミュージシャン。"]
	},
	"eli": {
		"es": ["Eli: Historia, artista, músico y programador.", "¡El genio y cabeza que carga con todo el juego!"],
		"en": ["Eli: Story, artist, musician, and programmer.", "The mastermind who carries the whole game!"],
		"ja": ["エリ：ストーリー、アーティスト、ミュージシャン、プログラマー。", "プロジェクト全体の黒幕！"]
	}
}

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	prefijo = GameManager.personaje_elegido if GameManager.personaje_elegido != "" else "sketch"
	
	if anim_player:
		anim_player.play("idle" + prefijo)
	if jugador:
		camara.position = jugador.position
	if dialogo_freak:
		dialogo_freak.terminado.connect(_on_dialogo_terminado)
	if musica_fondo:
		musica_fondo.volume_db = -40
		musica_fondo.play()
		create_tween().tween_property(musica_fondo, "volume_db", -8.0, 2.0)

func _physics_process(delta):
	if en_dialogo:
		# Aplicar gravedad incluso en diálogo por si está en el aire
		if not jugador.is_on_floor():
			jugador.velocity.y += gravedad * delta
		else:
			jugador.velocity.x = 0
		
		jugador.move_and_slide()
		verificar_distancia_cierre()
		return

	manejar_movimiento(delta)
	verificar_proximidad_interactuables()
	camara.position = jugador.position

func manejar_movimiento(delta):
	# --- GRAVEDAD ---
	if not jugador.is_on_floor():
		jugador.velocity.y += gravedad * delta

	# --- SALTO ---
	if Input.is_action_just_pressed("arriba") and jugador.is_on_floor():
		jugador.velocity.y = fuerza_salto

	# --- MOVIMIENTO LATERAL ---
	var dir_x = Input.get_axis("izquierda", "derecha")

	if dir_x != 0:
		jugador.velocity.x = dir_x * velocidad_mov
		
		# Animación caminar (solo si está en el suelo)
		if anim_player and jugador.is_on_floor():
			anim_player.play("walk" + prefijo)
			anim_player.flip_h = dir_x < 0
		
		# Sonido de pasos
		if jugador.is_on_floor():
			timer_pasos -= delta
			if timer_pasos <= 0:
				if sonido_pasos:
					sonido_pasos.pitch_scale = randf_range(0.9, 1.1)
					sonido_pasos.play()
				timer_pasos = ritmo_pasos
	else:
		# Frenado suave
		jugador.velocity.x = move_toward(jugador.velocity.x, 0, velocidad_mov)
		if anim_player and jugador.is_on_floor():
			anim_player.play("idle" + prefijo)

	# --- ANIMACIÓN DE SALTO (Opcional) ---
	if not jugador.is_on_floor() and anim_player:
		# Aquí podrías poner una animación de salto si la tenés
		pass

	jugador.move_and_slide()

func verificar_proximidad_interactuables():
	var interactuable_anterior = interactuable_cercano
	interactuable_cercano = null
	
	for obj in interactuables:
		if not is_instance_valid(obj): continue
		var dist = jugador.global_position.distance_to(obj.global_position)
		if dist < 70.0:
			interactuable_cercano = obj
			break
	
	if interactuable_anterior != interactuable_cercano:
		if interactuable_anterior and interactuable_anterior.has_method("resaltar"):
			interactuable_anterior.resaltar(false)
		if interactuable_cercano and interactuable_cercano.has_method("resaltar"):
			interactuable_cercano.resaltar(true)

func verificar_distancia_cierre():
	if interactuable_cercano:
		var dist = jugador.global_position.distance_to(interactuable_cercano.global_position)
		if dist > 95.0: # Un poquito más de margen para que no se cierre tan brusco
			_cerrar_dialogo_forzado()

func _input(event):
	if en_dialogo: return

	var presiono_interactuar = (
		event.is_action_pressed("ui_accept") or
		event.is_action_pressed("ataque")
	)

	if presiono_interactuar and interactuable_cercano != null:
		_interactuar_con(interactuable_cercano)

	if event.is_action_pressed("ui_cancel"):
		_volver_al_mapa()

func _interactuar_con(obj):
	if not dialogo_freak: return
	en_dialogo = true
	
	if anim_player:
		anim_player.play("touch" + prefijo) #
	
	var idioma = ProgresoJuego.idioma if ProgresoJuego.idioma in ["es", "en", "ja"] else "en"
	var id_nodo = obj.name.to_lower()

	var lista = []
	if id_nodo == "freak":
		lista = dialogos_freak.get(idioma, dialogos_freak["en"])
	elif dialogos_carteles.has(id_nodo):
		lista = dialogos_carteles[id_nodo].get(idioma, dialogos_carteles[id_nodo]["en"])
	
	if lista.size() > 0:
		# Esta es la línea 219 que tiraba error:
		dialogo_freak.iniciar_charla_directa(lista) 
	else:
		dialogo_freak.iniciar_charla_directa(["..."])

func _cerrar_dialogo_forzado():
	# Llamá al método de cerrar de tu sistema de diálogos
	if dialogo_freak and dialogo_freak.has_method("cerrar"):
		dialogo_freak.cerrar()
	en_dialogo = false

func _on_dialogo_terminado():
	en_dialogo = false

func _volver_al_mapa():
	if musica_fondo:
		create_tween().tween_property(musica_fondo, "volume_db", -80.0, 0.5)
	await get_tree().create_timer(0.5).timeout
	Cargador.ir_a_escena("res://menu_inicio.tscn")
