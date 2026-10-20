extends Control

@onready var label_monedas = $LabelMonedas 
@onready var sprite_vendedor = $VendedorSprite 
@onready var label_dialogo = $RichTextLabel 
@onready var timer_texto = $TimerTexto 
@onready var sonido_voz = get_node_or_null("SonidoVoz")
@onready var sonido_compra = $SonidoCompra 
@onready var musica = $MusicaTienda

# Botones de Minijuegos
@onready var btn_mini1 = $BtnMinigame1
@onready var btn_mini2 = $BtnMinigame2
@onready var btn_mini3 = $BtnMinigame3
@onready var btn_mini4 = $BtnMinigame4

var precios = {"mini1": 250, "mini2": 1000, "mini3": 500, "mini4": 550}
var escenas_mini = {
	"mini1": "res://scenes/minigame.tscn",
	"mini2": "res://scenes/main_clicker.tscn",
	"mini3": "res://scenes/chef_ritmico.tscn",
	"mini4": "res://scenes/minijuego_patineta.tscn"
}

# 🌟 Registro local de seguridad para evitar que el spam gaste dinero dos veces
var juegos_comprados = {
	"mini1": false,
	"mini2": false,
	"mini3": false,
	"mini4": false
}

var idle_elegido = ""
var personaje_actual = ""

# Control de clics exactos
var ultimo_id_cliqueado = ""
var clicks_en_actual = 0

var dialogos = {
	"en": {
		"retrorbs": "Retrorbs: ",
		"welcome": "Meow... Meow... Welcome to the shop, ",
		"gone": "... He's gone.",
		"no_money": "You're too poor for this!",
		"bought": "Purchased! Click again to play.",
		"sketch": "Oh! Sketch... B-but, you were running the shop a moment ago! I don't get you...",
		"max": "Max... You're the most skilled of all! Want to become a digital assassin with me?",
		"jane": "JANE! I mean... Jane~, I'd kill for you...",
		"prepucin": "(Dammit! It's him...) I hate you..."
	},
	"es": {
		"retrorbs": "Retrorbes: ",
		"welcome": "Meow... Meow... Bienvenido a la tienda, ",
		"gone": "... Se ha ido.",
		"no_money": "¡Eres muy pobre para esto!",
		"bought": "¡Comprado! Toca de nuevo para jugar.",
		"sketch": "¡Oh! Sketch... P-pero, ¡hace un momento atendías el local tú!",
		"max": "Max... ¡Eres el personaje más hábil! ¿Quisieras ser un asesino digital conmigo?",
		"jane": "JANE! digo... Jane~, Mataría por ti...",
		"prepucin": "(¡Maldición! Es él...) Te odio..."
	},
	"ja": {
		"retrorbs": "レトロオーブ: ",
		"welcome": "ミャー…ミャー… いらっしゃいませ、",
		"gone": "…行ってしまった。",
		"no_money": "お金が足りないよ！",
		"bought": "購入済み！もう一度押して遊ぼう。",
		"sketch": "おや！スケッチ…さっきまで君が店番してたじゃないか！",
		"max": "マックス…君は最高だ！僕と一緒にデジタルアサシンにならないか？",
		"jane": "ジェーン！というか…ジェーン～、君のためなら誰だって消せるよ。",
		"prepucin": "（ちっ！あいつだ…）大嫌いだよ…"
	}
}

func _ready():
	self.modulate.a = 0
	personaje_actual = GameManager.personaje_elegido.to_lower()
	
	# Sincronizamos las compras reales del guardado con el registro local
	for id in precios.keys():
		if ProgresoJuego.get(id) == true:
			juegos_comprados[id] = true
			
	actualizar_ui_monedas()
	actualizar_visual_botones()
	
	var random_id = randi_range(1, 3)
	idle_elegido = "idle" + str(random_id)
	
	create_tween().tween_property(self, "modulate:a", 1.0, 1.0)
	aparecer_vendedor()
	
	btn_mini1.pressed.connect(func(): gestionar_compra("mini1"))
	btn_mini2.pressed.connect(func(): gestionar_compra("mini2"))
	btn_mini3.pressed.connect(func(): gestionar_compra("mini3"))
	btn_mini4.pressed.connect(func(): gestionar_compra("mini4"))

func aparecer_vendedor():
	sprite_vendedor.play(idle_elegido)
	if idle_elegido == "idle3":
		procesar_dialogo_meow_exe()
	else:
		label_dialogo.text = ""

func procesar_dialogo_meow_exe():
	var lang = ProgresoJuego.idioma
	var nombre_display = GameManager.personaje_elegido.capitalize()
	var texto_final = dialogos[lang]["welcome"] + nombre_display + ". " + dialogos[lang][personaje_actual]
	mostrar_texto_progresivo(texto_final)
	if personaje_actual == "prepucin":
		await get_tree().create_timer(2.0).timeout
		huir_por_enojo()

func huir_por_enojo():
	sprite_vendedor.play(["idle1", "idle2"].pick_random())
	var tw = create_tween()
	tw.tween_property(sprite_vendedor, "modulate:a", 0.0, 0.5)
	await tw.finished
	mostrar_texto_progresivo(dialogos[ProgresoJuego.idioma]["gone"])

func gestionar_compra(id: String):
	# Verificamos de forma segura usando nuestro registro local y el guardado
	var ya_comprado = juegos_comprados[id] or (ProgresoJuego.get(id) == true)
	
	# Si cambia de botón, reseteamos el conteo de clics
	if ultimo_id_cliqueado != id:
		ultimo_id_cliqueado = id
		clicks_en_actual = 0
	
	if ya_comprado:
		clicks_en_actual += 1
		# Al 2do clic (o más si hacen spam), entra directo al juego sin gastar nada
		if clicks_en_actual >= 2:
			clicks_en_actual = 0
			Cargador.ir_a_escena(escenas_mini[id])
		else:
			mostrar_texto_progresivo(dialogos[ProgresoJuego.idioma]["bought"])
	else:
		if ProgresoJuego.monedas >= precios[id]:
			ProgresoJuego.monedas -= precios[id]
			juegos_comprados[id] = true # 🌟 Se marca como comprado al instante localmente
			ProgresoJuego.set(id, true) 
			if sonido_compra: sonido_compra.play()
			ProgresoJuego.guardar_partida()
			actualizar_ui_monedas()
			actualizar_visual_botones()
			
			clicks_en_actual = 1
			mostrar_texto_progresivo(dialogos[ProgresoJuego.idioma]["bought"])
		else:
			mostrar_texto_progresivo(dialogos[ProgresoJuego.idioma]["no_money"])

func actualizar_visual_botones():
	var botones_nodos = {
		"mini1": btn_mini1, 
		"mini2": btn_mini2, 
		"mini3": btn_mini3, 
		"mini4": btn_mini4
	}
	
	for id in botones_nodos.keys():
		var boton = botones_nodos[id]
		var estado = juegos_comprados[id] or (ProgresoJuego.get(id) == true)
		if estado == true:
			boton.modulate = Color(0.5, 1.2, 0.5)
		else:
			boton.modulate = Color(1, 1, 1)

func actualizar_ui_monedas():
	label_monedas.text = dialogos[ProgresoJuego.idioma]["retrorbs"] + str(ProgresoJuego.monedas)

func mostrar_texto_progresivo(texto: String):
	if idle_elegido != "idle3":
		return
		
	label_dialogo.text = texto
	label_dialogo.visible_characters = 0
	timer_texto.start()

func _on_timer_texto_timeout():
	if idle_elegido != "idle3": return
	
	if label_dialogo.visible_characters < label_dialogo.text.length():
		label_dialogo.visible_characters += 1
		if sonido_voz:
			sonido_voz.pitch_scale = randf_range(0.8, 1.1)
			sonido_voz.play()
	else:
		timer_texto.stop()

func _on_boton_volver_pressed():
	var tw = create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.8)
	await tw.finished
	Cargador.ir_a_escena("res://scenes/MapaNiveles.tscn")

func _input(event):
	if event is InputEventKey and event.pressed and event.keycode == KEY_M:
		ProgresoJuego.monedas += 500
		actualizar_ui_monedas()
