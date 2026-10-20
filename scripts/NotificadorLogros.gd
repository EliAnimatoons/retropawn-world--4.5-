extends CanvasLayer

@onready var panel_cartel = $PanelCartel

@onready var icono_logro: TextureRect = $PanelCartel/MarginContainer/HBoxPrincipal/HBoxContainer/TextureRect
@onready var titulo_label: Label = $PanelCartel/MarginContainer/HBoxPrincipal/VBoxContainer/TituloLabel
@onready var nombre_label: Label = $PanelCartel/MarginContainer/HBoxPrincipal/VBoxContainer/NombreLabel
@onready var desc_label: Label = $PanelCartel/MarginContainer/HBoxPrincipal/VBoxContainer/DescLabel

# Agregá un nodo AudioStreamPlayer llamado "SonidoLogro" como hijo de este CanvasLayer,
# y asignale tu audio "achievement" en el campo Stream del Inspector.
@onready var sonido_logro: AudioStreamPlayer = $SonidoLogro


var posicion_oculto: Vector2
var posicion_visible: Vector2
var visualizando: bool = false
var cola_logros: Array = []

const RELACION_LOGROS = {
	"logro_fisica_inestable":     {"insignia": "Insignia7",  "sensor": "Sensor7"},
	"lider_derrotado":            {"insignia": "Insignia2",  "sensor": "Sensor2"},
	"logro_batz_enojado":         {"insignia": "Insignia12", "sensor": "Sensor4"},
	"logro_meow_exe":             {"insignia": "Insignia11", "sensor": "Sensor4"},
	"juego_terminado":            {"insignia": "Insignia10", "sensor": "Sensor3"},
	"logro_glitch_vacio":         {"insignia": "Insignia18", "sensor": "Sensor10"},
	"logro_parry_master":         {"insignia": "Insignia19", "sensor": "Sensor9"},
	"logro_mejor_cliente":        {"insignia": "Insignia20", "sensor": "Sensor11"},
	"logro_tacho_final":          {"insignia": "Insignia21", "sensor": "Sensor12"},
	"logro_bienvenida":           {"insignia": "Insignia17", "sensor": "Sensor5"},
	"logro_sketch_desbloqueado":  {"insignia": "Insignia16", "sensor": "Sensor8"},
	"logro_nubbe_rescatado":      {"insignia": "Insignia3",  "sensor": "Sensor1"},
	"logro_max_rescatado":        {"insignia": "Insignia13", "sensor": "Sensor1"},
	"logro_jane_rescatada":       {"insignia": "Insignia14", "sensor": "Sensor1"},
	"logro_forerat_rescatado":    {"insignia": "insigniaforerat", "sensor": "Sensor13"}
}

var descripciones = {
	"Sensor1": {"es": "Desbloquea los personajes.", "en": "Unlock the characters.", "ja": "全キャラクターをアンロックする。"},
	"Sensor2": {"es": "Explota una bomba en el Liderminion.", "en": "Explode a bomb on the Liderminion.", "ja": "リーダーミニオンに爆弾を炸裂させる。"},
	"Sensor3": {"es": "Finaliza RetroPawnWORLD.", "en": "Finish RetroPawnWORLD.", "ja": "RetroPawnWORLDをクリアする。"},
	"Sensor4": {"es": "Molesta a Meow/Batz.", "en": "Annoy Meow/Batz.", "ja": "ミャオやバッツを困らせる。"},
	"Sensor5": {"es": "¡Bienvenidos a RetroPawnWORLD!", "en": "Welcome to RetroPawnWORLD!", "ja": "RetroPawnWORLDへようこそ！"},
	"Sensor6": {"es": "Cazador de minions.", "en": "Minion hunter.", "ja": "ミニオンハンター。"},
	"Sensor7": {"es": "Resuelve el puzzle del tutorial.", "en": "Solve the tutorial puzzle.", "ja": "チュートリアルのパズルを解く。"},
	"Sensor8": {"es": "Desbloquea a Sketch.", "en": "Unlock Sketch.", "ja": "スケッチをアンロックする。"},
	"Sensor9": {"es": "Haz 5 parry seguidos", "en": "Pull off a perfect combo of 5 parries in a row", "ja": "5回連続で完璧なパリィを決める。"},
	"Sensor10": {"es": "cae al vacio del juego, papu", "en": "fall into the bottomless void", "ja": "果てしない虚無に落ちる。"},
	"Sensor11": {"es": "Compra todas las pociones de la tienda", "en": "Buy all the potions from the shop", "ja": "ショップのポーションを全て購入する。"},
	"Sensor12": {"es": "Lleva el tacho de basura hasta el final del nvl", "en": "Take the trash can to the end of the lvl", "ja": "ゴミ箱をレベルの最後まで運ぶ。"},
	"Sensor13": {"es": "Arroja el tacho de basura al vacío y rescata a Forerat.", "en": "Throw the trash can into the void and rescue Forerat.", "ja": "ゴミ箱を虚無に投げ込んでフォレネズミを救出する。"}
}

func _ready():
	if ProgresoJuego.has_signal("logro_desbloqueado"):
		if not ProgresoJuego.logro_desbloqueado.is_connected(_on_logro_recibido):
			ProgresoJuego.logro_desbloqueado.connect(_on_logro_recibido)

	# Esperamos un frame para que los containers calculen su tamaño real
	# a partir del contenido (ícono + 3 labels), en vez de forzar un alto fijo
	# que los aplastaba a 0px y los hacía "invisibles".
	await get_tree().process_frame

	panel_cartel.custom_minimum_size.x = 440
	panel_cartel.size = panel_cartel.get_combined_minimum_size()
	if panel_cartel.size.x < 440:
		panel_cartel.size.x = 440

	var ancho_cartel = panel_cartel.size.x
	posicion_oculto = panel_cartel.position + Vector2(ancho_cartel + 150, 0)
	posicion_visible = panel_cartel.position

	panel_cartel.position = posicion_oculto

func _on_logro_recibido(id_logro: String):
	cola_logros.append(id_logro)
	if not visualizando:
		_procesar_siguiente()

func _procesar_siguiente():
	if cola_logros.is_empty():
		visualizando = false
		return

	visualizando = true
	var id_actual = cola_logros.pop_front()

	if not ProgresoJuego.LOGROS_MAPA.has(id_actual) or not RELACION_LOGROS.has(id_actual):
		_procesar_siguiente()
		return

	var lang = ProgresoJuego.idioma if "idioma" in ProgresoJuego else "en"
	var datos_globales = ProgresoJuego.LOGROS_MAPA[id_actual]
	var datos_relacion = RELACION_LOGROS[id_actual]

	# ASIGNACIÓN DE TEXTOS SEGURA
	titulo_label.text = "¡LOGRO DESBLOQUEADO!" if lang == "es" else ("ACHIEVEMENT UNLOCKED!" if lang == "en" else "実績解除！")

	if datos_globales.has("titulo") and datos_globales["titulo"].has(lang):
		nombre_label.text = datos_globales["titulo"][lang]
	else:
		nombre_label.text = id_actual

	var sensor_id = datos_relacion["sensor"]
	if descripciones.has(sensor_id) and descripciones[sensor_id].has(lang):
		desc_label.text = descripciones[sensor_id][lang]
	else:
		desc_label.text = "Achievement unlocked successfully."

	# CARGA DEL ICONO
	var nombre_insignia = datos_relacion["insignia"]
	var ruta_icono = "res://iconostienda/" + nombre_insignia + ".png"

	if ResourceLoader.exists(ruta_icono):
		icono_logro.texture = load(ruta_icono)
	else:
		icono_logro.texture = null
		print("⚠️ No se encontró la imagen para: ", nombre_insignia)

	# SONIDO DE LOGRO DESBLOQUEADO
	if sonido_logro and sonido_logro.stream:
		sonido_logro.play()

	# Forzamos que el contenedor recalcule tamaños con el nuevo texto/ícono
	# (por si un logro tiene texto más largo que el anterior).
	panel_cartel.reset_size()
	await get_tree().process_frame
	if panel_cartel.size.x < 440:
		panel_cartel.size.x = 440

	# ANIMACIÓN
	var tween = create_tween().set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tween.tween_property(panel_cartel, "position", posicion_visible, 0.6)
	tween.tween_interval(3.5)
	tween.tween_property(panel_cartel, "position", posicion_oculto, 0.5).set_ease(Tween.EASE_IN)
	tween.finished.connect(_procesar_siguiente)

# TEST DE PRUEBA CON LA TECLA T
func _input(event):
	if event is InputEventKey and event.pressed and event.keycode == KEY_T:
		print("🚀 Activando prueba de logro con la tecla T...")
		_on_logro_recibido("logro_glitch_vacio")
