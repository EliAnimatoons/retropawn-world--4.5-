extends Control

var pagina_actual = 1
@onready var p1 = $Pagina1
@onready var p2 = $Pagina2
@onready var p3 = $Pagina3
@onready var btn_pasar = $Pasar
@onready var label_info = $Pagina3/LabelInfo 


@onready var cofre_animado = $Pagina2/CofreAnimado
@onready var animacion_llave = $AnimacionLlave
@onready var particulas_monedas = $Pagina2/ParticulasMonedas
@onready var sonido_monedas = $Pagina2/SonidoMonedas
@onready var sonido_victoria = $Pagina2/SonidoVictoria
@onready var luz_victoria = $Pagina2/LuzVictoria
@onready var sonido_pagina = $SonidoPagina


var escala_original = Vector2(0.05, 0.05)

var descripciones = {
	"Sensor1": {
		"es": "Desbloquea los personajes.", 
		"en": "Unlock the characters.",
		"ja": "全キャラクターをアンロックする。"
	},
	"Sensor2": {
		"es": "Explota una bomba en el Liderminion.", 
		"en": "Explode a bomb on the Liderminion.",
		"ja": "リーダーミニオンに爆弾を炸裂させる。"
	},
	"Sensor3": {
		"es": "Finaliza RetroPawnWORLD.", 
		"en": "Finish RetroPawnWORLD.",
		"ja": "RetroPawnWORLDをクリアする。"
	},
	"Sensor4": {
		"es": "Molesta a Meow/Batz.", 
		"en": "Annoy Meow/Batz.",
		"ja": "ミャオやバッツを困らせる。"
	},
	"Sensor5": {
		"es": "¡Bienvenidos a RetroPawnWORLD!", 
		"en": "Welcome to RetroPawnWORLD!",
		"ja": "RetroPawnWORLDへようこそ！"
	},
	"Sensor6": {
		"es": "Cazador de minions.", 
		"en": "Minion hunter.",
		"ja": "ミニオンハンター。"
	},
	"Sensor7": {
		"es": "Resuelve el puzzle del tutorial.", 
		"en": "Solve the tutorial puzzle.",
		"ja": "チュートリアルのパズルを解く。"
	},
	"Sensor8": {
		"es": "Desbloquea a Sketch.", 
		"en": "Unlock Sketch.",
		"ja": "スケッチをアンロックする。"
	},
	"Sensor9": {
		"es": "Haz 5 parry seguidos", 
		"en": "Pull off a perfect combo of 5 parries in a row",
		"ja": "5回連続で完璧なパリィを決める。"
	},
	"Sensor10": {
		"es": "cae al vacio del juego, papu", 
		"en": "fall into the bottomless void",
		"ja": "果てしない虚無に落ちる。"
	},
	"Sensor11": {
		"es": "Compra todas las pociones de la tienda", 
		"en": "Buy all the potions from the shop",
		"ja": "ショップのポーションを全て購入する。"
	},
	"Sensor12": {
		"es": "Lleva el tacho de basura hasta el final del nvl", 
		"en": "Take the trash can to the end of the lvl",
		"ja": "ゴミ箱をレベルの最後まで運ぶ。"
	}
}

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	if label_info:
		label_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label_info.custom_minimum_size.x = 450 
		label_info.pivot_offset = label_info.custom_minimum_size / 2
	
	if luz_victoria: 
		luz_victoria.modulate.a = 0 # Luz invisible al inicio
	
	pagina_actual = 1
	actualizar_visibilidad_paginas()
	actualizar_texto_descripcion_default()
	inicializar_estante()
	conectar_sensores_invisibles() 
	
	get_tree().create_timer(0.5).timeout.connect(verificar_logros)

func conectar_sensores_invisibles():
	var contenedor_sensores = $Pagina3.get_node_or_null("ContenedorSensores")
	if contenedor_sensores:
		for sensor in contenedor_sensores.get_children():
			if sensor is Control:
				if not sensor.mouse_entered.is_connected(_on_sensor_hover):
					sensor.mouse_entered.connect(_on_sensor_hover.bind(sensor.name))
				if not sensor.mouse_exited.is_connected(actualizar_texto_descripcion_default):
					sensor.mouse_exited.connect(actualizar_texto_descripcion_default)
				sensor.mouse_filter = Control.MOUSE_FILTER_STOP

func _on_sensor_hover(nombre_sensor: String):
	var lang = ProgresoJuego.idioma if "idioma" in ProgresoJuego else "en"
	if descripciones.has(nombre_sensor):
		label_info.text = descripciones[nombre_sensor][lang]

func actualizar_texto_descripcion_default():
	if not label_info: return
	var lang = ProgresoJuego.idioma if "idioma" in ProgresoJuego else "en"
	if lang == "es":
		label_info.text = "Pasa el cursor por las insignias para ver como conseguirlas!"
	elif lang == "ja":
		label_info.text = "バッジにカーソルを合わせて獲得方法を確認しよう！"
	else:
		label_info.text = "Hover over the badges to see how to get them!"

func actualizar_visibilidad_paginas():
	if p1: p1.visible = (pagina_actual == 1)
	if p2: p2.visible = (pagina_actual == 2)
	if p3: p3.visible = (pagina_actual == 3)

func _on_pasar_pressed():
	if sonido_pagina:
		sonido_pagina.play()
		
	pagina_actual += 1
	if pagina_actual > 3: pagina_actual = 1
	actualizar_visibilidad_paginas()

func inicializar_estante():
	for p in [p1, p2, p3]:
		if p:
			var cont = p.get_node_or_null("ContenedorLogros")
			if cont:
				for insignia in cont.get_children():
					insignia.modulate = Color(0, 0, 0, 1)
					insignia.scale = escala_original

func verificar_logros():
	actualizar_insignia("Insignia1", true)
	actualizar_insignia("Insignia2", ProgresoJuego.max_desbloqueado)
	actualizar_insignia("Insignia3", ProgresoJuego.jane_desbloqueada)
	actualizar_insignia("Insignia4", "michael_desbloqueado" in ProgresoJuego and ProgresoJuego.michael_desbloqueado)
	actualizar_insignia("Insignia5", "bazombie_desbloqueado" in ProgresoJuego and ProgresoJuego.bazombie_desbloqueado)
	actualizar_insignia("Insignia6", "blitzy_desbloqueado" in ProgresoJuego and ProgresoJuego.blitzy_desbloqueado)
	actualizar_insignia("Insignia7", ProgresoJuego.logro_fisica_inestable)
	actualizar_insignia("Insignia8", "nubbe_desbloqueado" in ProgresoJuego and ProgresoJuego.nubbe_desbloqueado)
	actualizar_insignia("Insignia9", true)
	actualizar_insignia("Insignia10", "juego_terminado" in ProgresoJuego and ProgresoJuego.juego_terminado)
	actualizar_insignia("Insignia11", "logro_meow_exe" in ProgresoJuego and ProgresoJuego.logro_meow_exe)
	actualizar_insignia("Insignia12", "logro_batz_enojado" in ProgresoJuego and ProgresoJuego.logro_batz_enojado)
	
	var muertes = ProgresoJuego.total_minions_muertos if "total_minions_muertos" in ProgresoJuego else 0
	actualizar_insignia("Insignia13", muertes >= 50)
	actualizar_insignia("Insignia14", muertes >= 100)
	actualizar_insignia("Insignia15", muertes >= 150)
	actualizar_insignia("Insignia16", muertes >= 200)
	actualizar_insignia("Insignia17", ProgresoJuego.rata_pelada_desbloqueada)
	actualizar_insignia("Insignia18", ProgresoJuego.logro_glitch_vacio)
	actualizar_insignia("Insignia19", ProgresoJuego.logro_parry_master)
	actualizar_insignia("Insignia20", "logro_mejor_cliente" in ProgresoJuego and ProgresoJuego.logro_mejor_cliente)
	actualizar_insignia("Insignia21", "logro_tacho_final" in ProgresoJuego and ProgresoJuego.logro_tacho_final)
	
	actualizar_estado_cofre()

func actualizar_insignia(nombre_nodo: String, desbloqueado: bool):
	var nodo = null
	if p1: nodo = p1.get_node_or_null("ContenedorLogros/" + nombre_nodo)
	if not nodo and p2: nodo = p2.get_node_or_null("ContenedorLogros/" + nombre_nodo)
	if not nodo and p3: nodo = p3.get_node_or_null("ContenedorLogros/" + nombre_nodo)
	
	if not nodo: return 
	
	if desbloqueado:
		if nodo.modulate == Color(0, 0, 0, 1):
			animar_desbloqueo(nodo)
		else:
			nodo.modulate = Color(1, 1, 1, 1)
	else:
		nodo.modulate = Color(0, 0, 0, 1)

func animar_desbloqueo(nodo: Node):
	var tween = create_tween().set_parallel(true)
	tween.tween_property(nodo, "modulate", Color(1, 1, 1, 1), 0.5)
	var tween_scale = create_tween().set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tween_scale.tween_property(nodo, "scale", escala_original * 1.2, 0.3)
	tween_scale.tween_property(nodo, "scale", escala_original, 0.2)

func actualizar_estado_cofre():
	var total = 0
	for i in range(1, 22):
		var n = null
		if p1: n = p1.get_node_or_null("ContenedorLogros/Insignia" + str(i))
		if not n and p2: n = p2.get_node_or_null("ContenedorLogros/Insignia" + str(i))
		if not n and p3: n = p3.get_node_or_null("ContenedorLogros/Insignia" + str(i))
		
		if n and n.modulate == Color(1, 1, 1, 1): 
			total += 1
	
	if total >= 20 and not ProgresoJuego.recompensa_insignias_obtenida:
		ejecutar_secuencia_final()
	
	if cofre_animado:
		if total >= 20 or ProgresoJuego.recompensa_insignias_obtenida: 
			cofre_animado.play("opened")
		else: 
			cofre_animado.play("closed")

func ejecutar_secuencia_final():
	ProgresoJuego.recompensa_insignias_obtenida = true
	
	if animacion_llave:
		animacion_llave.visible = true
		animacion_llave.modulate.a = 0
		animacion_llave.scale = Vector2(0, 0)
		
		var tween = create_tween().set_parallel(true)
		tween.tween_property(animacion_llave, "modulate:a", 1.0, 0.5)
		tween.tween_property(animacion_llave, "scale", Vector2(1.5, 1.5), 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		
		await get_tree().create_timer(1.5).timeout
		
		var tween_out = create_tween().set_parallel(true)
		tween_out.tween_property(animacion_llave, "modulate:a", 0, 0.5)
		tween_out.tween_property(animacion_llave, "scale", Vector2(2, 2), 0.5)
	
	pagina_actual = 2
	actualizar_visibilidad_paginas()
	
	if cofre_animado:
		cofre_animado.play("opened")
		if luz_victoria:
			create_tween().tween_property(luz_victoria, "modulate:a", 0.4, 0.5)
		if particulas_monedas:
			particulas_monedas.amount = 50 
			particulas_monedas.emitting = true
		if sonido_victoria: sonido_victoria.play()
		if sonido_monedas: sonido_monedas.play()
			
		ProgresoJuego.monedas += 50000 
		ProgresoJuego.guardar_partida()

func _on_boton_volver_pressed():
	get_tree().change_scene_to_file("res://scenes/MapaNiveles.tscn")
