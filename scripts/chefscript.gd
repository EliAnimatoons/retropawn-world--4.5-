extends Node2D

@onready var music = $AudioStreamPlayer
@onready var sfx_corte = $SfxCorte
@onready var sfx_rata = $SfxRata 
@onready var sfx_coin = get_node_or_null("SfxCoin") 
@onready var manos = $Manos
@onready var zona_corte = $ZonaCorte
@onready var spawn_point = $SpawnPoint
@onready var contenedor = $ContenedorVegetales
@onready var label_score = $Label
@onready var label_count = $LabelCount 
@onready var guia = $Guia 
@onready var barra_vida = $BarraVida 

@export var texturas_vegetales : Array[Texture2D] 

var bpm = 170.0
var spb = 60.0 / bpm 
var hit_margin = 0.18
var score = 0
var best_score = 0 
var lives = 10
var playback_speed = 1.0
var game_active = false
var is_game_over = false
var ultima_mano_der = false

# --- LÓGICA DE DINERO ---
var monedas_pagadas_esta_ronda = 0 

var notas_activas = []
var track_duration = 90.0 
var next_note_time = 0.0

var timeline = [
	{"start": 0.0,    "end": 22.58,  "interval": 2}, 
	{"start": 22.58,  "end": 45.17,  "interval": 1}, 
	{"start": 45.17,  "end": 64.94,  "interval": 2}, 
	{"start": 64.94,  "end": 67.76,  "interval": 4}, 
	{"start": 67.76,  "end": 90.0,   "interval": 1}  
]

var lang = "en"
var texts = {
	"es": {
		"score": "Puntos: ", "best": "Mejor: ", "go": "¡A COCINAR!",
		"ko": "¡K.O.!\nCortes: %d\nVelocidad: x%.2f\nCLICK REINICIAR", 
		"new_record": "\n★ ¡NUEVO RÉCORD! ★",
		"pay": "+10 Retrorbes!"
	},
	"en": {
		"score": "Score: ", "best": "Best: ", "go": "COOK!",
		"ko": "K.O.!\nChops: %d\nSpeed: x%.2f\nCLICK TO RESTART", 
		"new_record": "\n★ NEW RECORD! ★",
		"pay": "+10 Retrorbs!"
	},
	"ja": {
		"score": "スコア: ", "best": "自己ベスト: ", "go": "料理開始！",
		"ko": "ノックアウト！\nカット数: %d\nスピード: x%.2f\nクリックで再開", 
		"new_record": "\n★ ニューレコード！ ★",
		"pay": "+10 レトロオーブ！"
	}
}

func _ready():
	lang = ProgresoJuego.idioma if "idioma" in ProgresoJuego else "en"
	if barra_vida:
		barra_vida.max_value = lives
		barra_vida.value = lives
	reset_game_values()

func reset_game_values():
	score = 0
	lives = 10
	playback_speed = 1.0
	is_game_over = false
	monedas_pagadas_esta_ronda = 0 
	notas_activas.clear()
	for n in contenedor.get_children(): n.queue_free()
	if barra_vida:
		barra_vida.value = lives
		barra_vida.modulate = Color.WHITE
	update_ui()
	start_countdown()

# --- NUEVA FUNCIÓN DE PAGO ---
func check_payment_logic():
	var pagos_que_deberia_tener = floor(score / 1000)
	
	if pagos_que_deberia_tener > monedas_pagadas_esta_ronda:
		var cantidad_a_pagar = (pagos_que_deberia_tener - monedas_pagadas_esta_ronda) * 10
		
		ProgresoJuego.monedas += cantidad_a_pagar
		monedas_pagadas_esta_ronda = pagos_que_deberia_tener
		
		if sfx_coin: sfx_coin.play()
		create_feedback_label(texts[lang]["pay"], Color.GREEN_YELLOW)
		
		ProgresoJuego.guardar_partida()

func realizar_acierto(indice):
	var nota = notas_activas.pop_at(indice)
	if is_instance_valid(nota["node"]):
		score += 10
		check_payment_logic() 
		
		sfx_corte.play()
		update_ui()
		var tw = create_tween()
		tw.tween_property(nota["node"], "scale", Vector2(2, 0.1), 0.07)
		tw.parallel().tween_property(nota["node"], "modulate:a", 0, 0.07)
		tw.tween_callback(nota["node"].queue_free)

func create_feedback_label(txt, color):
	var l = Label.new()
	l.text = txt
	l.modulate = color
	l.scale = Vector2(1.2, 1.2)
	l.position = zona_corte.position + Vector2(randf_range(-50, 50), -50)
	add_child(l)
	var tw = create_tween()
	tw.tween_property(l, "position:y", l.position.y - 100, 0.5)
	tw.parallel().tween_property(l, "modulate:a", 0, 0.5)
	tw.tween_callback(l.queue_free)

func start_countdown():
	game_active = false
	music.stop()
	label_count.show()
	label_count.text = texts[lang]["go"]
	await get_tree().create_timer(1.0).timeout
	label_count.hide()
	next_note_time = (spb / playback_speed) * 4
	music.pitch_scale = playback_speed
	music.play()
	game_active = true

func _process(_delta):
	if not game_active or is_game_over: return
	var current_time = (music.get_playback_position() + AudioServer.get_time_since_last_mix()) - AudioServer.get_output_latency()
	
	if current_time >= (track_duration / playback_speed):
		playback_speed += 0.1
		start_countdown()
		return

	actualizar_guia(current_time)
	
	if current_time > next_note_time - (1.0 / playback_speed):
		spawn_vegetal(next_note_time)
		actualizar_proxima_nota(current_time)
		
	if notas_activas.size() > 0:
		if current_time > notas_activas[0]["time"] + hit_margin:
			var nota_pasada = notas_activas.pop_front()
			if not nota_pasada["es_rata"]:
				take_damage()

func take_damage():
	lives -= 1
	if barra_vida:
		var tw_b = create_tween()
		tw_b.tween_property(barra_vida, "value", lives, 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		barra_vida.modulate = Color.RED
		create_tween().tween_property(barra_vida, "modulate", Color.WHITE, 0.3)
	update_ui()
	var tw = create_tween()
	tw.tween_property(self, "position", Vector2(randf_range(-5,5), randf_range(-5,5)), 0.05)
	tw.tween_property(self, "position", Vector2.ZERO, 0.05)
	if lives <= 0: game_over_state()

func update_ui():
	label_score.text = texts[lang]["score"] + str(score) + "\n" + texts[lang]["best"] + str(best_score)

func actualizar_guia(t):
	if notas_activas.size() > 0:
		var diff = notas_activas[0]["time"] - t
		if diff > 0 and diff < (0.5 / playback_speed):
			var s = diff / (0.5 / playback_speed)
			guia.scale = Vector2(s * 2, s * 2)
			guia.modulate.a = 1.0 - s
			guia.show()
		else: guia.hide()

func spawn_vegetal(target_time):
	var veg = Sprite2D.new()
	var tex = texturas_vegetales.pick_random()
	veg.texture = tex
	var es_rata = tex.resource_path.get_file() == "prepucincomida.png"
	contenedor.add_child(veg)
	veg.position = spawn_point.position
	notas_activas.append({"time": target_time, "node": veg, "es_rata": es_rata})
	var tw = create_tween()
	tw.tween_property(veg, "position", zona_corte.position, 1.0 / playback_speed)
	tw.tween_callback(limpiar_vegetal.bind(veg))

func limpiar_vegetal(v):
	if is_instance_valid(v): v.queue_free()

func actualizar_proxima_nota(t):
	var interval = get_current_interval(t * playback_speed)
	if interval <= 0: 
		next_note_time = t + (spb * 2) / playback_speed 
	else: 
		next_note_time += (spb * interval) / playback_speed

func get_current_interval(t):
	for s in timeline:
		if t >= s["start"] and t < s["end"]: return s["interval"]
	return 2

func _input(event):
	if is_game_over and event.is_pressed():
		reset_game_values()
	elif game_active and event.is_pressed() and not event.is_echo():
		if event is InputEventMouseButton or event.is_action("ui_accept"):
			chequear_hit()

func chequear_hit():
	manos.play("corte_der" if ultima_mano_der else "corte_izq")
	ultima_mano_der = !ultima_mano_der
	var current_time = (music.get_playback_position() + AudioServer.get_time_since_last_mix()) - AudioServer.get_output_latency()
	var hit_exitoso = false
	
	for i in range(notas_activas.size()):
		var diff = abs(current_time - notas_activas[i]["time"])
		if diff <= hit_margin:
			if notas_activas[i]["es_rata"]:
				cortar_rata(i)
			else:
				realizar_acierto(i)
			hit_exitoso = true
			break
			
	if not hit_exitoso: take_damage() 
	get_tree().create_timer(0.1).timeout.connect(func(): if is_instance_valid(manos): manos.play("idle"))

func cortar_rata(indice):
	var nota = notas_activas.pop_at(indice)
	if is_instance_valid(nota["node"]):
		sfx_rata.play() 
		take_damage()
		var tw = create_tween()
		tw.tween_property(nota["node"], "modulate", Color.DARK_VIOLET, 0.1)
		tw.tween_property(nota["node"], "scale", Vector2.ZERO, 0.1)
		tw.tween_callback(nota["node"].queue_free)

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
	var msg = texts[lang]["ko"] % [score, playback_speed]
	if es_nuevo_record: msg += texts[lang]["new_record"]
	await get_tree().create_timer(0.5).timeout
	label_count.text = msg
	label_count.show()
	ProgresoJuego.guardar_partida()
