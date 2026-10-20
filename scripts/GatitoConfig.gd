extends AnimatedSprite2D

var atrapado = false
var puede_atrapar = true
var diversion_actual = 0.0
var diversion_maxima = 100.0

@onready var barra = $BarraDiversion
@onready var label_chat = $LabelHora
@onready var cooldown_timer = Timer.new()
var posicion_original : Vector2

func _ready():
	posicion_original = position
	barra.visible = false
	barra.max_value = diversion_maxima
	add_child(cooldown_timer)
	cooldown_timer.wait_time = 5.0 
	cooldown_timer.one_shot = true
	cooldown_timer.timeout.connect(func(): puede_atrapar = true)
	
	# Sumamos 1 cada vez que entras para que Meow sepa que es una visita nueva
	ProgresoJuego.entradas_a_config += 1
	ProgresoJuego.guardar_partida() 
	
	var entradas = ProgresoJuego.entradas_a_config
	
	if entradas >= 7:
		self.visible = false
		var final_msg = "I left with my master, Final.exe!"
		if ProgresoJuego.idioma == "es": final_msg = "¡Me fui con mi amo, Final.exe!"
		elif ProgresoJuego.idioma == "ja": final_msg = "主人のFinal.exeと共に行ったよ…"
		label_chat.text = final_msg
		return
		
	play("start")
	manejar_eventos_terror(entradas)


func actualizar_idioma_gato():
	manejar_eventos_terror(ProgresoJuego.entradas_a_config)

func manejar_eventos_terror(n):
	var lang = ProgresoJuego.idioma
	match n:
		1:
			label_chat.text = "Hello... player?" if lang == "en" else ("Hola... ¿jugador?" if lang == "es" else "こんにちは…プレイヤーさん？")
			get_tree().create_timer(2.5).timeout.connect(func(): 
				var name_msg = "Ugh, I'll know your real name soon..."
				if lang == "es": name_msg = "Ush, ya sabré tu nombre real..."
				elif lang == "ja": name_msg = "ふん、すぐに君の本当の名前を突き止めるから…"
				label_chat.text = name_msg)
		2:
			modulate = Color(0, 5, 0)
			var time_msg = "Excuse me? Do you know what time it is?"
			if lang == "es": time_msg = "¿Disculpa? ¿Sabes qué hora es?"
			elif lang == "ja": time_msg = "ちょっと、今何時か分かってるの？"
			label_chat.text = time_msg
		3:
			label_chat.text = "Hi again! You're back!" if lang == "en" else ("¡Hola de nuevo! ¡Volviste!" if lang == "es" else "また会ったね！戻ってきたんだ！")
		4:
			ejecutar_susto_ventana()
		5:
			var owner_msg = "I am Meow.exe! Final.exe is my owner!"
			if lang == "es": owner_msg = "¡Yo soy Meow.exe! Final.exe mi dueño!"
			elif lang == "ja": owner_msg = "僕はMeow.exe！Final.exeが僕の主人だ！"
			label_chat.text = owner_msg
			modulate = Color(2, 2, 2)
		6:
			ejecutar_final_terror()

func ejecutar_susto_ventana():
	var desktop_msg = "Let me see your desktop better..."
	if ProgresoJuego.idioma == "es": desktop_msg = "Déjame ver mejor tu escritorio..."
	elif ProgresoJuego.idioma == "ja": desktop_msg = "君のデスクトップをもっとよく見せて…"
	label_chat.text = desktop_msg
	
	await get_tree().create_timer(2.0).timeout
	var ventana = get_window()
	ventana.mode = Window.MODE_WINDOWED
	ventana.mode = Window.MODE_MINIMIZED
	await get_tree().create_timer(1.0).timeout
	ventana.mode = Window.MODE_WINDOWED
	
	var tremble_msg = "TREMBLE WITH FEAR!"
	if ProgresoJuego.idioma == "es": tremble_msg = "¡TIEMBLA DE MIEDO!"
	elif ProgresoJuego.idioma == "ja": tremble_msg = "恐怖で震えろ！"
	label_chat.text = tremble_msg
	
	var ventana_id = ventana.get_window_id()
	var pos_actual = DisplayServer.window_get_position(ventana_id)
	for i in 30:
		var offset = Vector2i(randi_range(-25, 25), randi_range(-25, 25))
		DisplayServer.window_set_position(pos_actual + offset, ventana_id)
		await get_tree().create_timer(0.03).timeout
	DisplayServer.window_set_position(pos_actual, ventana_id)

func ejecutar_final_terror():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	atrapado = true
	var capa = get_tree().current_scene.find_child("CapaTerror", true, false)
	var cara_gato = get_tree().current_scene.find_child("CaraGato", true, false)
	var musica = get_tree().current_scene.find_child("MusicaConfig", true, false)
	
	if musica:
		musica.pitch_scale = 0.3
		var t_audio = create_tween().set_loops()
		t_audio.tween_property(musica, "pitch_scale", 0.2, 0.6)
		t_audio.tween_property(musica, "pitch_scale", 0.4, 0.6)
	
	if capa:
		capa.visible = true
		if cara_gato:
			cara_gato.modulate.a = 0
			var t_cara = create_tween()
			t_cara.tween_property(cara_gato, "modulate:a", 1.0, 8.0)
	
	modulate = Color(15, 0, 0)
	label_chat.modulate = Color(15, 0, 0)
	
	var adios = "BYE, "
	if ProgresoJuego.idioma == "es": adios = "ADIÓS, "
	elif ProgresoJuego.idioma == "ja": adios = "さようなら、"
	label_chat.text = adios + OS.get_environment("USERNAME").to_upper()
	
	# --- LOGRO DIGITAL SERIAL KILLER ---
	if "logro_meow_exe" in ProgresoJuego:
		ProgresoJuego.logro_meow_exe = true
	
	ProgresoJuego.entradas_a_config = 7
	ProgresoJuego.guardar_partida() 
	
	await get_tree().create_timer(12.0).timeout
	get_tree().quit()

func _process(delta):
	if visible and ProgresoJuego.entradas_a_config == 2:
		mostrar_hora_en_directo()

	if diversion_actual > 0 and not atrapado:
		diversion_actual -= 10.0 * delta
		barra.value = diversion_actual

	if atrapado:
		if ProgresoJuego.entradas_a_config < 6:
			Input.set_mouse_mode(Input.MOUSE_MODE_CONFINED_HIDDEN)
			get_viewport().warp_mouse(global_position)
		position = posicion_original + Vector2(randf_range(-4, 4), randf_range(-4, 4))
		return

	if visible:
		var mouse_pos = get_local_mouse_position()
		actualizar_mirada(mouse_pos)
		if puede_atrapar and mouse_pos.length() < 45: 
			empezar_juego()

func actualizar_mirada(pos):
	if atrapado: return
	if pos.y < -30: play("up")
	elif pos.y > 30: play("down")
	elif pos.x < -30: play("left")
	elif pos.x > 30: play("right")
	else: play("idle")

func empezar_juego():
	atrapado = true
	puede_atrapar = false
	barra.visible = true
	play("grab")

func mostrar_hora_en_directo():
	var t = Time.get_time_dict_from_system()
	var prefix = "Your time by chance is: "
	if ProgresoJuego.idioma == "es": prefix = "Tu hora de casualidad es: "
	elif ProgresoJuego.idioma == "ja": prefix = "君の現在の時刻は: "
	label_chat.text = prefix + "%02d:%02d:%02d" % [t.hour, t.minute, t.second]

func _input(event):
	if visible and atrapado and event is InputEventMouseButton and event.pressed:
		if ProgresoJuego.entradas_a_config >= 6: return
		diversion_actual += 20.0
		barra.value = diversion_actual
		var shake = create_tween()
		shake.tween_property(self, "position:x", posicion_original.x + 20, 0.03)
		shake.tween_property(self, "position:x", posicion_original.x - 20, 0.03)
		shake.tween_property(self, "position:x", posicion_original.x, 0.03)
		if diversion_actual >= diversion_maxima:
			soltar_gato()

func soltar_gato():
	atrapado = false
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	position = posicion_original
	play("idle")
	diversion_actual = 0
	barra.visible = false
	cooldown_timer.start()
