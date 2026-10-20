extends Node2D

@onready var music = $AudioStreamPlayer
@onready var punch_bag = $Saco
@onready var guide = $Guia
@onready var label_score = $Label
@onready var label_lives = $Vidas
@onready var label_count = $LabelCount
@onready var hands = $Manos 

# --- NUEVOS NODOS PARA EL PAGO ---
# Asegúrate de tener un AudioStreamPlayer llamado "SfxCoin" con el sonido de moneda
@onready var sfx_coin = get_node_or_null("SfxCoin") 

var score = 0
var best_score = 0 
var lives = 10
var game_active = false
var is_game_over = false
var playback_speed = 1.0
var original_bag_scale : Vector2

# --- LÓGICA DE DINERO ---
var monedas_pagadas_esta_ronda = 0 # Para saber cuántas veces ya cobramos los 1000 pts

var last_damage_time = 0.0
var damage_cooldown = 0.15 

var midi_raw_pattern = [
	0.857, 1.714, 2.571, 3.428, 4.285, 5.142, 5.999, 6.428, 6.856,
	7.713, 8.570, 9.427, 10.284, 11.141, 11.998, 12.855, 13.284, 13.712,
	14.569, 15.426, 16.283, 17.140, 17.997, 18.854, 19.711, 20.140, 20.568,
	21.425, 22.282, 23.139, 23.996, 24.853, 25.710, 26.567, 26.996, 27.424,
	28.281, 29.138, 29.995, 30.852, 31.709, 32.566, 33.423, 33.852, 34.280
]

var snare_queue = []
var track_duration = 34.28
var hit_margin = 0.18 

var lang = "en" 
var texts = {
	"es": {
		"go": "¡DALE!", "score": "Puntos: ", "best": "Mejor: ", "lives": "Vidas: ",
		"perfect": "¡PERFECTO!", "good": "BIEN", "miss": "¡MISS!", "spam": "¡SPAM!",
		"ko": "¡K.O.!", "restart": "\nCLICK PARA REINICIAR", "speed": "\nVelocidad: ",
		"new_record": "\n★ ¡NUEVO RÉCORD! ★", "pay": "+10 Retrorbes!"
	},
	"en": {
		"go": "GO!", "score": "Score: ", "best": "Best: ", "lives": "Lives: ",
		"perfect": "PERFECT!", "good": "GOOD", "miss": "MISS!", "spam": "SPAM!",
		"ko": "K.O.!", "restart": "\nCLICK TO RESTART", "speed": "\nSpeed: ",
		"new_record": "\n★ NEW RECORD! ★", "pay": "+10 Retrorbs!"
	},
	"ja": {
		"go": "いくぞ！", "score": "スコア: ", "best": "自己ベスト: ", "lives": "ライフ: ",
		"perfect": "パーフェクト！", "good": "よし！", "miss": "ミス！", "spam": "連打禁止！",
		"ko": "ノックアウト！", "restart": "\nクリックでリスタート", "speed": "\nスピード: ",
		"new_record": "\n★ ニューレコード！ ★", "pay": "+10 レトロオーブ！"
	}
}

func _ready():
	lang = ProgresoJuego.idioma
	original_bag_scale = punch_bag.scale
	hands.animation_finished.connect(_on_hands_finished)
	reset_game_values()

func reset_game_values():
	score = 0
	lives = 10
	playback_speed = 1.0
	is_game_over = false
	monedas_pagadas_esta_ronda = 0 # Reseteamos el contador de pagos
	snare_queue.clear()
	update_ui()
	start_countdown()

func _on_button_pressed(): # Por si tienes un botón de salida
	ProgresoJuego.guardar_partida()

func check_hit():
	hands.play("punch punch" if randf() > 0.5 else "punch punch 2")
	var current_time = music.get_playback_position() + AudioServer.get_time_since_last_mix()
	if snare_queue.size() > 0:
		var diff = abs(current_time - snare_queue[0])
		if diff <= hit_margin:
			var points = 10
			if diff < 0.08:
				create_feedback_label(texts[lang]["perfect"], Color.GOLD)
				points = 20
			else:
				create_feedback_label(texts[lang]["good"], Color.CYAN)
			
			score += points
			check_payment_logic() # <--- CHEQUEAMOS SI TOCA PAGAR
			
			snare_queue.remove_at(0)
			play_bag_effect(true)
			update_ui()
		else:
			take_damage("GHOST")
			play_bag_effect(false)
	else:
		take_damage("GHOST")

# --- NUEVA FUNCIÓN DE PAGO ---
func check_payment_logic():
	# Calculamos cuántas veces 1000 puntos tenemos
	var pagos_que_deberia_tener = floor(score / 1000)
	
	if pagos_que_deberia_tener > monedas_pagadas_esta_ronda:
		var cantidad_a_pagar = (pagos_que_deberia_tener - monedas_pagadas_esta_ronda) * 10
		
		# Pagamos al Singleton
		ProgresoJuego.monedas += cantidad_a_pagar
		monedas_pagadas_esta_ronda = pagos_que_deberia_tener
		
		# Efectos visuales y de sonido
		if sfx_coin: sfx_coin.play()
		create_feedback_label(texts[lang]["pay"], Color.GREEN_YELLOW)
		
		# Guardamos automáticamente para que no pierda la plata si cierra el juego
		ProgresoJuego.guardar_partida()

# --- EL RESTO DEL SCRIPT SIGUE IGUAL ---
func start_countdown():
	game_active = false
	music.stop()
	snare_queue = midi_raw_pattern.duplicate()
	label_count.show()
	for i in range(3, 0, -1):
		label_count.text = str(i)
		await get_tree().create_timer(0.8).timeout
	label_count.text = texts[lang]["go"]
	await get_tree().create_timer(0.4).timeout
	label_count.hide()
	game_active = true
	music.pitch_scale = playback_speed
	music.play()

func _process(_delta):
	if not game_active or is_game_over: return
	var current_time = (music.get_playback_position() + AudioServer.get_time_since_last_mix()) - AudioServer.get_output_latency()
	if current_time >= (track_duration / playback_speed) + 0.5:
		playback_speed += 0.1
		start_countdown()
		return
	if snare_queue.size() > 0 and current_time > snare_queue[0] + hit_margin:
		snare_queue.remove_at(0)
		create_feedback_label(texts[lang]["miss"], Color.RED)
		take_damage("MISS")
	update_visual_guide(current_time)

func _input(event):
	if is_game_over and event.is_pressed():
		reset_game_values()
	elif game_active and event.is_pressed() and not event.is_echo():
		if event is InputEventMouseButton or event.is_action("ui_accept"):
			check_hit()

func take_damage(type):
	var now = Time.get_ticks_msec() / 1000.0
	if type == "GHOST":
		if now - last_damage_time < damage_cooldown: return
		last_damage_time = now
		create_feedback_label(texts[lang]["spam"], Color.ORANGE_RED)
	lives -= 1
	screen_shake()
	update_ui()
	if lives <= 0: game_over_state()

func game_over_state():
	game_active = false
	is_game_over = true
	
	var tw_music = create_tween()
	tw_music.tween_property(music, "pitch_scale", 0.01, 0.8).set_trans(Tween.TRANS_CIRC).set_ease(Tween.EASE_OUT)
	tw_music.tween_callback(music.stop)

	var es_nuevo_record = false
	if score > best_score:
		best_score = score
		es_nuevo_record = true
		
	var final_msg = texts[lang]["ko"] 
	if es_nuevo_record: final_msg += texts[lang]["new_record"]
	final_msg += "\n" + texts[lang]["score"] + str(score)
	final_msg += texts[lang]["speed"] + "x%.2f" % playback_speed
	final_msg += texts[lang]["restart"]
	
	label_count.text = final_msg
	label_count.show()
	ProgresoJuego.guardar_partida()

func update_ui():
	label_score.text = texts[lang]["score"] + str(score) + "\n" + texts[lang]["best"] + str(best_score)
	label_lives.text = texts[lang]["lives"] + str(lives)

func create_feedback_label(txt, color):
	var l = Label.new()
	l.text = txt
	l.modulate = color
	# Hacemos que el texto de pago sea un poco más grande
	if "+10" in txt or "レトロオーブ" in txt: l.scale = Vector2(1.5, 1.5)
	l.position = punch_bag.position + Vector2(randf_range(-50, 50), -100)
	add_child(l)
	var tw = create_tween()
	tw.tween_property(l, "position:y", l.position.y - 80, 0.4)
	tw.parallel().tween_property(l, "modulate:a", 0, 0.4)
	tw.tween_callback(l.queue_free)

func screen_shake():
	var tw = create_tween()
	for i in range(4):
		tw.tween_property(self, "position", Vector2(randf_range(-5, 5), randf_range(-5, 5)), 0.05)
	tw.tween_property(self, "position", Vector2.ZERO, 0.05)

func play_bag_effect(hit):
	var tw = create_tween()
	if hit:
		punch_bag.scale = original_bag_scale * Vector2(1.2, 0.8)
		tw.tween_property(punch_bag, "scale", original_bag_scale, 0.1)
	else:
		punch_bag.modulate = Color.RED
		tw.tween_property(punch_bag, "modulate", Color.WHITE, 0.2)

func _on_hands_finished():
	if game_active: hands.play("punch idle")

func update_visual_guide(time):
	if snare_queue.size() > 0:
		var next_hit = snare_queue[0]
		var look_ahead = 0.4 / playback_speed
		if time > next_hit - look_ahead and time < next_hit:
			var p = (next_hit - time) / look_ahead
			guide.scale = Vector2(p * 3, p * 3)
			guide.modulate.a = 1.0 - p
			guide.show()
		else: guide.hide()
