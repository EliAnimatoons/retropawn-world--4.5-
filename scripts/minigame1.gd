extends Control

var total_clicks = 0
var stage = 0
var click_multiplier = 1
var auto_click_power = 0 
var upgrade_mult_cost = 100
var upgrade_fetito_cost = 250

# --- LÓGICA DE DINERO ANTICHEAT ---
var last_paid_stage = 0 

@export var minion_textures : Array[Texture2D] 

@onready var main_button = $Button
@onready var score_label = $LabelScore
@onready var stage_label = $LabelStage
@onready var sfx_evo = $SfxEvo
@onready var sfx_coin = get_node_or_null("SfxCoin") 
@onready var flash_layer = $FlashLayer 
@onready var feto_layer = $FetoLayer 

# --- METAS ESCALADAS (Ajustadas para que las 13 imágenes se sientan bien) ---
var goals = [
	0, 50, 150, 300, 500, 750, 1000, 1400, 1900, 2500, # 1-10
	3500, 5000, 7000, 9500, 12500, 16000, 20000, 25000, 31000, 38000, # 11-20
	46000, 55000, 65000, 77000, 90000, 105000, 120000, 135000, 145000, 150000, 160000 # 21-31
]

var lang = "en"
var texts = {
	"en": {
		"level": "Level: ", "final": "MUTATION: ", "clicks": "Clicks: ",
		"mult": "Mult x%d (%d)", "feto": "Fetus (+5/s) (%d)",
		"reward": "+%d Retrorbs!"
	},
	"es": {
		"level": "Nivel: ", "final": "MUTACIÓN: ", "clicks": "Clics: ",
		"mult": "Mult x%d (%d)", "feto": "Fetito (+5/s) (%d)",
		"reward": "+%d Retrorbes!"
	},
	"ja": {
		"level": "レベル: ", "final": "突然変異: ", "clicks": "クリック: ",
		"mult": "倍率 x%d (%d)", "feto": "胎児 (+5/秒) (%d)",
		"reward": "+%d レトロオーブ！"
	}
}

func _ready():
	if "idioma" in ProgresoJuego: lang = ProgresoJuego.idioma
	else: lang = "en" # Default to English if not found
	
	flash_layer.modulate.a = 0
	
	# CARGAR DATOS GUARDADOS
	total_clicks = ProgresoJuego.clicker_total_clicks
	upgrade_mult_cost = ProgresoJuego.clicker_mult_cost
	upgrade_fetito_cost = ProgresoJuego.clicker_feto_cost
	click_multiplier = ProgresoJuego.clicker_click_multiplier
	auto_click_power = ProgresoJuego.clicker_auto_power
	stage = ProgresoJuego.clicker_stage
	
	last_paid_stage = stage
	
	var num_fetitos = auto_click_power / 5
	for i in range(num_fetitos):
		spawn_fetito_visual(true)

	var timer = Timer.new()
	timer.wait_time = 1.0
	timer.autostart = true
	timer.timeout.connect(_on_auto_click_timeout)
	add_child(timer)
	
	update_ui()
	refresh_minion_image()

func _on_auto_click_timeout():
	if auto_click_power > 0:
		total_clicks += auto_click_power
		process_click_logic(false)
		save_to_progreso()

func save_to_progreso():
	ProgresoJuego.clicker_total_clicks = total_clicks
	ProgresoJuego.clicker_mult_cost = upgrade_mult_cost
	ProgresoJuego.clicker_feto_cost = upgrade_fetito_cost
	ProgresoJuego.clicker_click_multiplier = click_multiplier
	ProgresoJuego.clicker_auto_power = auto_click_power
	ProgresoJuego.clicker_stage = stage
	ProgresoJuego.guardar_partida()

func _on_button_pressed():
	total_clicks += (1 * click_multiplier)
	process_click_logic(true)

func process_click_logic(with_text: bool):
	check_evolution()
	update_ui()
	if with_text:
		animate_button()
		spawn_click_text(1 * click_multiplier, false)
	
	if stage >= goals.size() - 5:
		aplicar_deformacion_extra()

func _on_btn_mult_pressed():
	if total_clicks >= upgrade_mult_cost:
		total_clicks -= upgrade_mult_cost
		click_multiplier += 1
		upgrade_mult_cost = int(upgrade_mult_cost * 2.0)
		update_ui()
		save_to_progreso()

func _on_btn_fetito_pressed():
	if total_clicks >= upgrade_fetito_cost:
		total_clicks -= upgrade_fetito_cost
		auto_click_power += 5 
		upgrade_fetito_cost = int(upgrade_fetito_cost * 2.5)
		spawn_fetito_visual(false)
		update_ui()
		save_to_progreso()

func check_evolution():
	var next_goal = 0
	if stage + 1 < goals.size():
		next_goal = goals[stage + 1]
	else:
		# Escalado infinito si pasan del nivel 31
		next_goal = int(goals[-1] * pow(1.25, stage - (goals.size() - 2)))

	if total_clicks >= next_goal:
		stage += 1
		refresh_minion_image()
		trigger_big_flash()
		if sfx_evo: sfx_evo.play()
		
		if stage > last_paid_stage:
			var reward = 5 
			if stage >= 13: reward = 15 # Aumentamos recompensa tras agotar imágenes únicas
			if stage >= 31: reward = 50 # Recompensa gorda por llegar al final de la lista
			
			ProgresoJuego.monedas += reward
			last_paid_stage = stage
			
			if sfx_coin: sfx_coin.play()
			spawn_click_text(reward, true)
		
		save_to_progreso()

func refresh_minion_image():
	# Si tenemos 13 texturas, esto las recorrerá en orden (stage 0 al 12)
	if stage < minion_textures.size():
		main_button.icon = minion_textures[stage]
		main_button.modulate = Color.WHITE
		main_button.rotation = 0
		stage_label.text = texts[lang]["level"] + str(stage + 1)
	else:
		# A partir de la imagen 14, entra en modo aleatorio/glitch
		var random_img = randi() % minion_textures.size()
		main_button.icon = minion_textures[random_img]
		# Colores aleatorios para indicar que es una "Mutación"
		main_button.modulate = Color(randf_range(0.4, 1.0), randf_range(0.4, 1.0), randf_range(0.4, 1.0), 1.0)
		main_button.rotation_degrees = randf_range(-10, 10)
		stage_label.text = texts[lang]["final"] + str(stage - (minion_textures.size() - 1))

func update_ui():
	score_label.text = texts[lang]["clicks"] + str(total_clicks)
	if has_node("BtnMult"): 
		$BtnMult.text = texts[lang]["mult"] % [click_multiplier + 1, upgrade_mult_cost]
	if has_node("BtnFetito"): 
		$BtnFetito.text = texts[lang]["feto"] % [upgrade_fetito_cost]

func animate_button():
	var tw = create_tween()
	main_button.pivot_offset = main_button.size / 2
	tw.tween_property(main_button, "scale", Vector2(0.9, 0.9), 0.05)
	tw.tween_property(main_button, "scale", Vector2(1.0, 1.0), 0.05)

func aplicar_deformacion_extra():
	main_button.pivot_offset = main_button.size / 2
	var random_scale = randf_range(0.95, 1.05)
	main_button.scale = Vector2(random_scale, 2.0 - random_scale)

func trigger_big_flash():
	flash_layer.modulate = Color(1, 1, 1, 1) 
	flash_layer.show()
	var tw = create_tween()
	tw.tween_interval(0.1)
	tw.tween_property(flash_layer, "modulate:a", 0.0, 0.8)

func spawn_click_text(val, is_coin: bool):
	var label = Label.new()
	
	if is_coin:
		label.text = texts[lang]["reward"] % val
		label.add_theme_color_override("font_color", Color.GREEN_YELLOW)
		label.scale = Vector2(1.5, 1.5)
	else:
		label.text = "+" + str(val)
		if stage >= minion_textures.size():
			label.add_theme_color_override("font_color", Color(randf(), randf(), randf(), 1))
		else:
			label.add_theme_color_override("font_color", Color.YELLOW)
		
	label.position = get_global_mouse_position() + Vector2(randf_range(-30, 30), -20)
	add_child(label)
	
	var tw = create_tween()
	tw.set_parallel(true)
	tw.tween_property(label, "position", label.position + Vector2(0, -100), 0.6)
	tw.tween_property(label, "modulate:a", 0.0, 0.6)
	tw.chain().tween_callback(label.queue_free)

func spawn_fetito_visual(silent: bool):
	var fetito = Sprite2D.new()
	# Asegúrate de que la ruta sea correcta
	fetito.texture = load("res://evoluciones minion/fetus minion.png") 
	fetito.hframes = 2  
	fetito.vframes = 3  
	fetito.scale = Vector2.ZERO
	
	fetito.global_position = Vector2(randf_range(100, 1100), randf_range(100, 600))
	feto_layer.add_child(fetito)

	if not silent and has_node("SfxPop"): $SfxPop.play()
	
	var tw = create_tween()
	tw.tween_property(fetito, "scale", Vector2(0.8, 0.8), 0.3).set_trans(Tween.TRANS_BACK)
	
	var angle = randf() * PI * 2
	var radius = randf_range(150, 400)
	var center = Vector2(500, 300)
	var target_pos = center + Vector2(cos(angle), sin(angle)) * radius
	tw.tween_property(fetito, "global_position", target_pos, 0.8).set_trans(Tween.TRANS_SINE)

	var anim_timer = Timer.new()
	anim_timer.wait_time = randf_range(0.1, 0.2)
	anim_timer.timeout.connect(func():
		if is_instance_valid(fetito):
			fetito.frame = (fetito.frame + 1) % 6
	)
	add_child(anim_timer)
	anim_timer.start()
