extends Control

# ===========================================================
# NODOS RAÍZ
# ===========================================================
@onready var label_monedas    = $LabelMonedas
@onready var label_dialogo    = $RichTextLabel
@onready var timer_texto      = $TimerTexto
@onready var sonido_compra    = $SonidoCompra
@onready var musica           = $MusicaTienda

@onready var sonido_voz       = get_node_or_null("SonidoVoz")
@onready var filtro_noche     = get_node_or_null("FiltroNoche")
@onready var luz_lampara      = get_node_or_null("LuzLampara")
@onready var luciernagas      = get_node_or_null("Luciernagas")
@onready var boton_cambiar_pagina = get_node_or_null("BotonCambiarPagina")

@onready var pagina1 = get_node_or_null("Pagina1")
@onready var pagina2 = get_node_or_null("Pagina2")
@onready var pagina3 = get_node_or_null("Pagina3")

# ===========================================================
# PAGINA 1
# ===========================================================
@onready var sprite_batz  = $Pagina1/BatzSprite
@onready var boton_panza  = $Pagina1/BotonPanza
@onready var boton_soda   = $Pagina1/BotonSoda

@onready var boton_ecto        = get_node_or_null("Pagina1/BotonEcto")
@onready var boton_reloj       = get_node_or_null("Pagina1/BotonReloj")
@onready var boton_vida        = get_node_or_null("Pagina1/BotonVida")
@onready var boton_fuerza      = get_node_or_null("Pagina1/BotonFuerza")
@onready var boton_velocidad   = get_node_or_null("Pagina1/BotonVelocidad")
@onready var boton_extra_money = get_node_or_null("Pagina1/BotonExtraMoney")
@onready var boton_shield      = get_node_or_null("Pagina1/BotonShield")
@onready var boton_poison      = get_node_or_null("Pagina1/BotonPoison")

# ===========================================================
# PAGINA 2 — Tienda rotativa
# ===========================================================
@onready var boton_dios        = get_node_or_null("Pagina2/BotonDios")
@onready var boton_skin_max    = get_node_or_null("Pagina2/BotonSkinMax")
@onready var boton_skin_neko   = get_node_or_null("Pagina2/BotonSkinNeko")
@onready var boton_skin_lionel = get_node_or_null("Pagina2/BotonSkinLionel")
@onready var boton_skin_papper = get_node_or_null("Pagina2/BotonSkinPapper")

@onready var chicle_slot1 = get_node_or_null("Pagina2/ChicleSlot1")
@onready var chicle_slot2 = get_node_or_null("Pagina2/ChicleSlot2")
@onready var chicle_slot3 = get_node_or_null("Pagina2/ChicleSlot3")
@onready var chicle_slot4 = get_node_or_null("Pagina2/ChicleSlot4")

@onready var boton_regalo_monedas = get_node_or_null("Pagina2/BotonRegaloMonedas")
@onready var boton_regalo_item    = get_node_or_null("Pagina2/BotonRegaloItem")

# ===========================================================
# PAGINA 3 — Vestidor
# ===========================================================
@onready var vestidor_max     = get_node_or_null("Pagina3/VestidorMax")
@onready var vestidor_neko    = get_node_or_null("Pagina3/VestidorNeko")
@onready var vestidor_lionel  = get_node_or_null("Pagina3/VestidorLionel")
@onready var vestidor_papper  = get_node_or_null("Pagina3/VestidorPapper")
@onready var vestidor_default = get_node_or_null("Pagina3/VestidorDefault")

# ===========================================================
# POSICIONES DE LOS SLOTS DE SKIN EN PÁGINA 2
# ─────────────────────────────────────────────────────────
# Presioná M en el juego para activar el modo ajuste visual.
# Usá las teclas de dirección para mover el slot seleccionado.
# Tab alterna entre slot izquierdo y derecho.
# Cuando queden bien, anotá los valores que imprime la consola
# y reemplazá los números de SLOT_IZQ y SLOT_DER abajo.
# ─────────────────────────────────────────────────────────
var SLOT_IZQ := Vector2(160, 230)
var SLOT_DER := Vector2(445, 230)

var _debug_slots: bool = false
var _debug_slot_activo: int = 0

# ===========================================================
# VARIABLES
# ===========================================================
var skin_prefix: String = "Batz"
var escala_original_batz: Vector2
var pagina_actual: int = 1

var skins_disponibles: Array  = []
var chicles_disponibles: Array = []
var chicle_disponible: String = "chicle_comun"
var hay_oferta_rara: bool = false

var skin_pendiente_equipar: String = ""

# ===========================================================
# FRASES
# ===========================================================
var frases = {
	"en": ["Hi traveler! need something?", "I like Vocaloid!", "Just passing by or want to chat?", "The shop has a 2x1 on items!", "I wish I wasn't a poorly made sprite..."],
	"es": ["¡Hola viajero! ¿necesitas algo?", "¡Me gusta Vucaloid!", "¿Estas de paso o quieres charlar?", "¡La tienda tiene un 2x1 en articulos!", "Quisiera no ser un sprite mal hecho..."],
	"ja": ["こんにちは旅人さん！何か必要？", "ボーカロイドが好きなんだ！", "おしゃべりしに来たの？", "今ならアイテムが2つで1つ分だよ！", "出来の悪いスプライトじゃなきゃよかったのに…"]
}
var frases_enojada = {
	"en": ["Hey! don't do that!", "Stop, please...", "Aaaah~~", "IT HURTS!"],
	"es": ["¡Hey! ¡no hagas eso!", "Detente, por favor...", "Aaaah~~", "¡ME DUELE!"],
	"ja": ["ちょっと！やめてよ！", "お願い、やめて…", "あああ～～", "痛いよ！"]
}
var frases_muy_enojada = {
	"en": ["WHAT DID I TELL YOU!", "NOOO!", "I'm kicking you out!"],
	"es": ["¡QUE TE DIJE!", "¡NOOOO!", "¡Voy a sacarte, eh!"],
	"ja": ["言ったでしょ！", "やだあああ！", "もう追い出すよ！"]
}
var frases_gracias = {
	"en": ["Thanks for the Retrorbs, traveler!", "Thanks... whatever your name is.", "Tax payment LMAO"],
	"es": ["¡Gracias por los Retrorbes, viajero!", "Gracias... Como te llames.", "Vaya pago de impuestos LMAO"],
	"ja": ["レトロオーブをありがとう、旅人さん！", "ありがto…名前なんだっけ。", "税金の支払い完了、ワロタw"]
}
var frases_pobre = {
	"en": ["Come back when you're not poor... XD", "Your mother has more money :/", "Poor and ugly! GET OUT!"],
	"es": ["Vuelve cuando no seas pobre... XD", "Tu madre tiene mas dinero :/", "¡Encima de pobre, feo! LARGATE!"],
	"ja": ["貧乏じゃなくなったらまたおいで…w", "君のママの方がお金持ってるよ :/", "貧乏でブサイク！出てけ！"]
}
var nombres_skin = {
	"max":     {"en": "Classic Max",   "es": "Max Clásico",   "ja": "クラシック・マックス"},
	"neko":    {"en": "Neko Maid",     "es": "Neko Maid",     "ja": "ネコメイド"},
	"lionel":  {"en": "Lionel",        "es": "Lionel",        "ja": "リオネル"},
	"papper":  {"en": "PapperBatz",    "es": "PapperBatz",    "ja": "ペーパーバッツ"},
	"default": {"en": "Original Batz", "es": "Batz Original", "ja": "オリジナルバッツ"},
}


# ===========================================================
# READY
# ===========================================================

func _ready():
	escala_original_batz = sprite_batz.scale

	generar_inventario_del_dia()
	actualizar_prefix_skin()
	actualizar_ui_monedas()
	verificar_item_comprado()
	verificar_hora_tienda()

	timer_texto.timeout.connect(_on_timer_texto_timeout)

	if not boton_panza.pressed.is_connected(_on_boton_panza_pressed):
		boton_panza.pressed.connect(_on_boton_panza_pressed)

	if boton_regalo_monedas:
		boton_regalo_monedas.pressed.connect(_on_boton_regalo_monedas_pressed)
	if boton_regalo_item:
		boton_regalo_item.pressed.connect(_on_boton_regalo_item_pressed)

	_conectar_vestidor()

	pagina_actual = 1
	actualizar_paginas()

	if ProgresoJuego.expulsado_una_vez:
		var frases_perdon = {
			"en": ["I'll let you pass, just for being a hero...", "Your behavior was nasty.", "You're the savior, enter..."],
			"es": ["Te dejaré pasar, solo por ser un héroe...", "Tu comportamiento estuvo feo.", "Eres el salvador, entra de nuevo..."],
			"ja": ["ヒーローだから特別に入れてあげるけど…", "さっきの態度は最悪だったよ。", "救世主さん、入っていいよ…"]
		}
		mostrar_texto_progresivo(frases_perdon[ProgresoJuego.idioma].pick_random())
		ProgresoJuego.expulsado_una_vez = false
		ProgresoJuego.enojo_batz = 0
		ProgresoJuego.guardar_partida()
	else:
		decir_frase_aleatoria()


func _conectar_vestidor():
	if vestidor_max:     vestidor_max.pressed.connect(func():     _on_vestidor_skin_pressed("max"))
	if vestidor_neko:    vestidor_neko.pressed.connect(func():    _on_vestidor_skin_pressed("neko"))
	if vestidor_lionel:  vestidor_lionel.pressed.connect(func():  _on_vestidor_skin_pressed("lionel"))
	if vestidor_papper:  vestidor_papper.pressed.connect(func():  _on_vestidor_skin_pressed("papper"))
	if vestidor_default: vestidor_default.pressed.connect(func(): _on_vestidor_skin_pressed("default"))


# ===========================================================
# INVENTARIO DIARIO
# ===========================================================

func generar_inventario_del_dia():
	var fecha = Time.get_date_dict_from_system()
	var semilla_dia = fecha.day + fecha.month * 31 + fecha.year * 365
	seed(semilla_dia)

	var todas_las_skins = ["max", "neko", "lionel", "papper"]
	todas_las_skins.shuffle()
	skins_disponibles = [todas_las_skins[0], todas_las_skins[1]]

	chicle_disponible = "dios" if randf() < 0.1 else "chicle_comun"
	chicles_disponibles = _generar_chicles_del_dia()
	hay_oferta_rara = (randi() % 100 < 5)


func _generar_chicles_del_dia() -> Array:
	var pool = ["extra_money", "shield", "poison", "chicle_comun", "chicle_comun"]
	if chicle_disponible == "dios":
		pool.append("dios")
	pool.shuffle()
	return pool.slice(0, min(4, pool.size()))


# ===========================================================
# REGALOS DIARIOS
# ===========================================================

func _get_fecha_str() -> String:
	var f = Time.get_date_dict_from_system()
	return "%d-%d-%d" % [f.year, f.month, f.day]

func _ya_reclamo_hoy(clave: String) -> bool:
	return ProgresoJuego.get(clave) == _get_fecha_str()

func _marcar_reclamado_hoy(clave: String):
	ProgresoJuego.set(clave, _get_fecha_str())
	ProgresoJuego.guardar_partida()

func actualizar_visual_regalos():
	if boton_regalo_monedas:
		var reclamado = _ya_reclamo_hoy("ultimo_dia_regalo_monedas")
		boton_regalo_monedas.disabled = reclamado
		boton_regalo_monedas.modulate = Color(0.4, 0.4, 0.4) if reclamado else Color(1.2, 1.0, 0.3)

	if boton_regalo_item:
		var fecha = Time.get_date_dict_from_system()
		seed(fecha.day * 7 + fecha.month * 13 + fecha.year)
		var hay_regalo_item = randf() < 0.10
		boton_regalo_item.visible = hay_regalo_item
		if hay_regalo_item:
			var reclamado = _ya_reclamo_hoy("ultimo_dia_regalo_item")
			boton_regalo_item.disabled = reclamado
			boton_regalo_item.modulate = Color(0.4, 0.4, 0.4) if reclamado else Color(0.5, 1.0, 1.2)

func _on_boton_regalo_monedas_pressed():
	if _ya_reclamo_hoy("ultimo_dia_regalo_monedas"):
		mostrar_texto_progresivo({"en": "Come back tomorrow for more!", "es": "¡Vuelve mañana por más!", "ja": "明日また来てね！"}[ProgresoJuego.idioma])
		return
	ProgresoJuego.monedas += 5
	_marcar_reclamado_hoy("ultimo_dia_regalo_monedas")
	actualizar_ui_monedas_con_efecto(ProgresoJuego.monedas)
	actualizar_visual_regalos()
	mostrar_texto_progresivo({"en": "Here, 5 free Retrorbs! Come back tomorrow!", "es": "¡Toma, 5 Retrorbes gratis! ¡Vuelve mañana!", "ja": "はい、5レトロオーブ！明日また来てね！"}[ProgresoJuego.idioma])
	if sonido_compra: sonido_compra.play()

func _on_boton_regalo_item_pressed():
	if _ya_reclamo_hoy("ultimo_dia_regalo_item"):
		mostrar_texto_progresivo({"en": "Already claimed today!", "es": "¡Ya lo reclamaste hoy!", "ja": "今日はもう受け取ったよ！"}[ProgresoJuego.idioma])
		return

	var posibles = []
	if not ProgresoJuego.tiene_batido_ectoplasma: posibles.append("ecto")
	if not ProgresoJuego.get("tiene_shield"):     posibles.append("shield")
	if not ProgresoJuego.tiene_reloj_arena:       posibles.append("reloj")

	if posibles.is_empty():
		ProgresoJuego.monedas += 50
		_marcar_reclamado_hoy("ultimo_dia_regalo_item")
		actualizar_ui_monedas_con_efecto(ProgresoJuego.monedas)
		actualizar_visual_regalos()
		mostrar_texto_progresivo({"en": "You have everything! Here's 50R.O instead!", "es": "¡Ya tienes todo! ¡Toma 50 Retrorbes!", "ja": "全部持ってるね！代わりに50R.O！"}[ProgresoJuego.idioma])
		return

	posibles.shuffle()
	var item_ganado = posibles[0]
	match item_ganado:
		"ecto":   ProgresoJuego.tiene_batido_ectoplasma = true
		"shield": ProgresoJuego.tiene_shield = true
		"reloj":  ProgresoJuego.tiene_reloj_arena = true

	_marcar_reclamado_hoy("ultimo_dia_regalo_item")
	ProgresoJuego.guardar_partida()
	verificar_item_comprado()
	actualizar_visual_regalos()
	if sonido_compra: sonido_compra.play()

	var nombres_item = {
		"ecto":  {"en": "Ghost Smoothie",   "es": "Batido de Ectoplasma", "ja": "ゴーストスムージー"},
		"shield":{"en": "Shield",           "es": "Escudo",               "ja": "シールド"},
		"reloj": {"en": "Broken Hourglass", "es": "Reloj de Arena Roto",  "ja": "壊れた砂時計"},
	}
	var nombre = nombres_item[item_ganado][ProgresoJuego.idioma]
	mostrar_texto_progresivo({"en": "Lucky! You got " + nombre + " for free!", "es": "¡Suerte! ¡Te regalé " + nombre + "!", "ja": "ラッキー！" + nombre + "をプレゼント！"}[ProgresoJuego.idioma])


# ===========================================================
# SISTEMA DE PÁGINAS
# ===========================================================

func _on_boton_cambiar_pagina_pressed():
	pagina_actual = (pagina_actual % 3) + 1
	actualizar_paginas()
	var msgs = {
		1: {"en": "Here are the potions!", "es": "¡Aquí están las pociones!", "ja": "ポーションはここだよ！"},
		2: {"en": "Here are today's skins!", "es": "¡Las skins de hoy!", "ja": "今日のスキンはこれだよ！"},
		3: {"en": "The fitting room!", "es": "¡El vestidor!", "ja": "試着室！"},
	}
	mostrar_texto_progresivo(msgs[pagina_actual][ProgresoJuego.idioma])

func actualizar_paginas():
	if pagina1: pagina1.visible = (pagina_actual == 1)
	if pagina2: pagina2.visible = (pagina_actual == 2)
	if pagina3: pagina3.visible = (pagina_actual == 3)

	match pagina_actual:
		2:
			actualizar_stock_especial()
			actualizar_visual_regalos()
		3:
			actualizar_vestidor()

	if boton_cambiar_pagina:
		boton_cambiar_pagina.text = "➜"


# ===========================================================
# PÁGINA 2: TIENDA ROTATIVA
# ===========================================================

func actualizar_stock_especial():
	if boton_skin_max:    boton_skin_max.visible    = false
	if boton_skin_neko:   boton_skin_neko.visible   = false
	if boton_skin_lionel: boton_skin_lionel.visible = false
	if boton_skin_papper: boton_skin_papper.visible = false
	if boton_dios:        boton_dios.visible        = false

	var botones_skin = {
		"max":    boton_skin_max,
		"neko":   boton_skin_neko,
		"lionel": boton_skin_lionel,
		"papper": boton_skin_papper,
	}
	var props_skin = {
		"max":    "tiene_skin_max",
		"neko":   "tiene_skin_neko",
		"lionel": "tiene_skin_lionel",
		"papper": "tiene_skin_papper",
	}

	var slots_pos = [SLOT_IZQ, SLOT_DER]
	for i in range(skins_disponibles.size()):
		var skin_id = skins_disponibles[i]
		var boton   = botones_skin.get(skin_id)
		var prop    = props_skin.get(skin_id)
		if not boton or not prop: continue
		boton.position = slots_pos[i]
		boton.visible  = true
		var ya_tiene   = ProgresoJuego.get(prop) == true
		boton.modulate = Color(0.5, 0.5, 0.5) if ya_tiene else Color(1, 1, 1)
		boton.disabled = ya_tiene

	if chicle_disponible == "dios" and boton_dios:
		boton_dios.visible = true

	# --- CHICLES: texto dinámico + conexiones limpias ---
	var nombres_chicle = {
		"extra_money":  {"en": "Extra Money\n1000 R.O", "es": "Extra Money\n1000 R.O", "ja": "エクストラマネー\n1000 R.O"},
		"shield":       {"en": "Shield\n1000 R.O",      "es": "Escudo\n1000 R.O",      "ja": "シールド\n1000 R.O"},
		"poison":       {"en": "Poison\n4550 R.O",      "es": "Veneno\n4550 R.O",      "ja": "ポイズン\n4550 R.O"},
		"dios":         {"en": "Primordial\n5000 R.O",  "es": "Esencia\n5000 R.O",     "ja": "始原\n5000 R.O"},
		"chicle_comun": {"en": "Gum\n5 R.O",            "es": "Chicle\n5 R.O",         "ja": "ガム\n5 R.O"},
	}

	var slots = [chicle_slot1, chicle_slot2, chicle_slot3, chicle_slot4]
	for i in range(slots.size()):
		var slot = slots[i]
		if not slot: continue

		if i < chicles_disponibles.size():
			var tipo = chicles_disponibles[i]
			slot.visible = true

			# Texto con nombre y precio
			var nombre_data = nombres_chicle.get(tipo, {"en": tipo, "es": tipo, "ja": tipo})
			slot.text = nombre_data.get(ProgresoJuego.idioma, nombre_data["en"])

			# Oscurecer si ya lo tiene
			var ya = _ya_tiene_chicle(tipo)
			slot.modulate = Color(0.4, 0.4, 0.4) if ya else Color(1, 1, 1)
			slot.disabled = ya

			# Desconectar callables viejos antes de reconectar
			var conexiones = slot.pressed.get_connections()
			for con in conexiones:
				slot.pressed.disconnect(con["callable"])

			# Reconectar con el tipo correcto capturado en la lambda
			var tipo_capturado = tipo
			slot.pressed.connect(func(): _comprar_chicle_dinamico(tipo_capturado))
		else:
			slot.visible = false

func _ya_tiene_chicle(tipo: String) -> bool:
	match tipo:
		"extra_money": return ProgresoJuego.get("tiene_extra_money") == true
		"shield":      return ProgresoJuego.get("tiene_shield") == true
		"poison":      return ProgresoJuego.get("tiene_poison") == true
		"dios":        return ProgresoJuego.tiene_despertar_dios
		_:             return false

# ─────────────────────────────────────────────────────────
# COMPRA DE CHICLES DINÁMICA
# ─────────────────────────────────────────────────────────
func _comprar_chicle_dinamico(tipo: String):
	var costos = {
		"extra_money":  1000,
		"shield":       1000,
		"poison":       4550,
		"dios":         5000,
		"chicle_comun": 5,
	}
	var costo = costos.get(tipo, 0)

	# Chicle común: solo decoración
	if tipo == "chicle_comun":
		if ProgresoJuego.monedas >= costo:
			ProgresoJuego.monedas -= costo
			ProgresoJuego.guardar_partida()
			actualizar_ui_monedas_con_efecto(ProgresoJuego.monedas)
			if sonido_compra: sonido_compra.play()
			mostrar_texto_progresivo({"en": "Enjoy the gum!", "es": "¡Disfruta el chicle!", "ja": "ガムどうぞ！"}[ProgresoJuego.idioma])
		else:
			mostrar_texto_progresivo(frases_pobre[ProgresoJuego.idioma].pick_random())
			vibrar_batz()
		return

	# Ya lo tiene
	if _ya_tiene_chicle(tipo):
		mostrar_texto_progresivo({"en": "You already have that!", "es": "¡Ya tienes eso!", "ja": "それはもう持ってるよ！"}[ProgresoJuego.idioma])
		return

	# Sin plata
	if ProgresoJuego.monedas < costo:
		mostrar_texto_progresivo(frases_pobre[ProgresoJuego.idioma].pick_random())
		vibrar_batz()
		return

	# Compra exitosa
	ProgresoJuego.monedas -= costo
	match tipo:
		"extra_money": ProgresoJuego.set("tiene_extra_money", true)
		"shield":      ProgresoJuego.set("tiene_shield",      true)
		"poison":      ProgresoJuego.set("tiene_poison",      true)
		"dios":        ProgresoJuego.tiene_despertar_dios = true

	ProgresoJuego.guardar_partida()
	actualizar_ui_monedas_con_efecto(ProgresoJuego.monedas)
	verificar_item_comprado()
	actualizar_stock_especial()
	if sonido_compra: sonido_compra.play()
	mostrar_texto_progresivo(frases_gracias[ProgresoJuego.idioma].pick_random())


# ===========================================================
# PÁGINA 3: VESTIDOR
# ===========================================================

func actualizar_vestidor():
	var skins_vestidor = {
		"default": {"nodo": vestidor_default, "prop": ""},
		"max":     {"nodo": vestidor_max,     "prop": "tiene_skin_max"},
		"neko":    {"nodo": vestidor_neko,    "prop": "tiene_skin_neko"},
		"lionel":  {"nodo": vestidor_lionel,  "prop": "tiene_skin_lionel"},
		"papper":  {"nodo": vestidor_papper,  "prop": "tiene_skin_papper"},
	}
	for skin_id in skins_vestidor:
		var datos = skins_vestidor[skin_id]
		var nodo  = datos["nodo"]
		var prop  = datos["prop"]
		if not nodo: continue
		var desbloqueada = (prop == "") or (ProgresoJuego.get(prop) == true)
		if desbloqueada:
			nodo.disabled = false
			nodo.modulate = Color(1.3, 1.3, 0.5) if _es_skin_equipada(skin_id) else Color(1, 1, 1)
		else:
			nodo.disabled = true
			nodo.modulate = Color(0.3, 0.3, 0.3)

func _es_skin_equipada(skin_id: String) -> bool:
	match skin_id:
		"max":     return ProgresoJuego.get("skin_max_equipada") == true
		"neko":    return ProgresoJuego.get("skin_neko_equipada") == true
		"lionel":  return ProgresoJuego.get("skin_lionel_equipada") == true
		"papper":  return ProgresoJuego.get("skin_papper_equipada") == true
		"default":
			return not (
				ProgresoJuego.get("skin_max_equipada") or
				ProgresoJuego.get("skin_neko_equipada") or
				ProgresoJuego.get("skin_lionel_equipada")
			)
	return false

func _on_vestidor_skin_pressed(skin_id: String):
	if skin_id == "papper":
		_equipar_skin("papper")
		skin_pendiente_equipar = ""
		return

	var nombre = nombres_skin[skin_id][ProgresoJuego.idioma]

	if skin_pendiente_equipar != skin_id:
		skin_pendiente_equipar = skin_id
		if _es_skin_equipada(skin_id):
			mostrar_texto_progresivo({"en": nombre + " is on. Press again to remove it.", "es": nombre + " está puesta. Presiona otra vez para quitarla.", "ja": nombre + "は装備中。もう一度で外せるよ。"}[ProgresoJuego.idioma])
		else:
			mostrar_texto_progresivo({"en": "Equip " + nombre + "? (press again!)", "es": "¿Equipar " + nombre + "? (¡presiona otra vez!)", "ja": nombre + "を装備する？（もう一度！）"}[ProgresoJuego.idioma])
		await get_tree().create_timer(3.0).timeout
		if skin_pendiente_equipar == skin_id:
			skin_pendiente_equipar = ""
	else:
		_equipar_skin(skin_id)
		skin_pendiente_equipar = ""

func _equipar_skin(skin_id: String):
	if skin_id == "papper":
		var estaba = ProgresoJuego.get("skin_papper_equipada") == true
		ProgresoJuego.set("skin_papper_equipada", not estaba)
		ProgresoJuego.guardar_partida()
		actualizar_prefix_skin()
		actualizar_vestidor()
		if not estaba:
			mostrar_texto_progresivo({"en": "PapperBatz equipped on Batz!", "es": "¡PapperBatz equipada en Batz!", "ja": "ペーパーバッツをバッツに装備！"}[ProgresoJuego.idioma])
		else:
			mostrar_texto_progresivo({"en": "Back to normal Batz!", "es": "¡Batz vuelve a su look normal!", "ja": "バッツが元の見た目に戻ったよ！"}[ProgresoJuego.idioma])
		return

	var era_la_misma = _es_skin_equipada(skin_id)
	ProgresoJuego.set("skin_max_equipada",    false)
	ProgresoJuego.set("skin_neko_equipada",   false)
	ProgresoJuego.set("skin_lionel_equipada", false)

	if era_la_misma:
		ProgresoJuego.guardar_partida()
		actualizar_prefix_skin()
		actualizar_vestidor()
		verificar_item_comprado()
		mostrar_texto_progresivo({"en": "Back to the original look!", "es": "¡De vuelta al look original!", "ja": "元の見た目に戻ったよ！"}[ProgresoJuego.idioma])
		return

	match skin_id:
		"max":    ProgresoJuego.set("skin_max_equipada",    true)
		"neko":   ProgresoJuego.set("skin_neko_equipada",   true)
		"lionel": ProgresoJuego.set("skin_lionel_equipada", true)
		"default": pass

	ProgresoJuego.guardar_partida()
	actualizar_prefix_skin()
	actualizar_vestidor()
	verificar_item_comprado()
	var nombre = nombres_skin[skin_id][ProgresoJuego.idioma]
	mostrar_texto_progresivo({"en": nombre + " equipped!", "es": "¡" + nombre + " equipada!", "ja": nombre + "装備完了！"}[ProgresoJuego.idioma])


# ===========================================================
# SKIN Y HORA
# ===========================================================

func actualizar_prefix_skin():
	skin_prefix = "Papper" if ProgresoJuego.get("skin_papper_equipada") else "Batz"
	sprite_batz.play(skin_prefix + "idle")

func verificar_hora_tienda():
	var hora = Time.get_time_dict_from_system().hour
	var es_noche = hora >= 20 or hora < 6
	if filtro_noche: filtro_noche.visible = es_noche
	if luz_lampara:  luz_lampara.visible  = es_noche
	if luciernagas:  luciernagas.emitting = es_noche
	musica.pitch_scale = 0.85 if es_noche else 1.0
	if es_noche:
		get_tree().create_timer(1.0).timeout.connect(func():
			mostrar_texto_progresivo({"en": "It's late, traveler...", "es": "Es tarde, viajero...", "ja": "もう遅いよ、旅人さん…"}[ProgresoJuego.idioma]))

func _process(_delta):
	if luz_lampara and luz_lampara.visible:
		luz_lampara.energy = lerp(luz_lampara.energy, randf_range(0.8, 1.3), 0.1)


# ===========================================================
# UI Y MONEDAS
# ===========================================================

func actualizar_ui_monedas():
	var lang_texto = {"en": "Retrorbs: ", "es": "Retrorbes: ", "ja": "レトロオーブ: "}
	label_monedas.text = lang_texto[ProgresoJuego.idioma] + str(ProgresoJuego.monedas)

func actualizar_ui_monedas_con_efecto(valor_final: int):
	var lang_texto = {"en": "Retrorbs: ", "es": "Retrorbes: ", "ja": "レトロオーブ: "}
	var prefijo = lang_texto[ProgresoJuego.idioma]
	var partes = label_monedas.text.split(": ")
	var cuenta_visual = int(partes[1]) if partes.size() > 1 else 0
	var tween = create_tween()
	tween.tween_method(func(v): label_monedas.text = prefijo + str(v), cuenta_visual, valor_final, 0.5)


# ===========================================================
# VERIFICAR ITEMS COMPRADOS
# ===========================================================

func verificar_item_comprado():
	if boton_soda:        boton_soda.modulate        = Color(0.3,0.3,0.3) if ProgresoJuego.tiene_mejora_parry       else Color(1,1,1)
	if boton_ecto:        boton_ecto.modulate         = Color(0.3,0.3,0.3) if ProgresoJuego.tiene_batido_ectoplasma  else Color(1,1,1)
	if boton_reloj:       boton_reloj.modulate        = Color(0.3,0.3,0.3) if ProgresoJuego.tiene_reloj_arena        else Color(1,1,1)
	if boton_vida:        boton_vida.modulate         = Color(0.3,0.3,0.3) if ProgresoJuego.tiene_mejora_vida        else Color(1,1,1)
	if boton_fuerza:      boton_fuerza.modulate       = Color(0.3,0.3,0.3) if ProgresoJuego.tiene_mejora_fuerza      else Color(1,1,1)
	if boton_velocidad:   boton_velocidad.modulate    = Color(0.3,0.3,0.3) if ProgresoJuego.tiene_mejora_vel         else Color(1,1,1)
	if boton_dios:        boton_dios.modulate         = Color(0.3,0.3,0.3) if ProgresoJuego.tiene_despertar_dios     else Color(1,1,1)
	if boton_extra_money: boton_extra_money.modulate  = Color(0.3,0.3,0.3) if ProgresoJuego.get("tiene_extra_money") else Color(1,1,1)
	if boton_shield:      boton_shield.modulate       = Color(0.3,0.3,0.3) if ProgresoJuego.get("tiene_shield")      else Color(1,1,1)
	if boton_poison:      boton_poison.modulate       = Color(0.3,0.3,0.3) if ProgresoJuego.get("tiene_poison")      else Color(1,1,1)

	# 🏆 LOGRO: THE BEST CUSTOMER
	var tiene_todas_las_pociones = (
		ProgresoJuego.tiene_mejora_vida and
		ProgresoJuego.tiene_mejora_fuerza and
		ProgresoJuego.tiene_mejora_vel and
		ProgresoJuego.tiene_mejora_parry and
		ProgresoJuego.tiene_batido_ectoplasma and
		ProgresoJuego.tiene_reloj_arena
	)
	if tiene_todas_las_pociones and not ProgresoJuego.logro_mejor_cliente:
		ProgresoJuego.otorgar_logro("logro_mejor_cliente")


# ===========================================================
# DIÁLOGO
# ===========================================================

func decir_frase_aleatoria():
	mostrar_texto_progresivo(frases[ProgresoJuego.idioma].pick_random())

func mostrar_texto_progresivo(texto: String):
	label_dialogo.text = texto
	label_dialogo.visible_characters = 0
	sprite_batz.play(skin_prefix + "talk")
	timer_texto.start()

func _on_timer_texto_timeout():
	if label_dialogo.visible_characters < label_dialogo.text.length():
		label_dialogo.visible_characters += 1
		if sonido_voz:
			var c = label_dialogo.text[label_dialogo.visible_characters - 1]
			if c != " " and c != ".":
				sonido_voz.pitch_scale = randf_range(0.9, 1.2)
				sonido_voz.play()
	else:
		timer_texto.stop()
		sprite_batz.play(skin_prefix + "idle")


# ===========================================================
# HOVER
# ===========================================================

func _on_boton_soda_mouse_entered():
	mostrar_texto_progresivo({"en": "ParryHeal: Heals you on Parry. Cost 10R.O", "es": "ParryHeal: Te cura al hacer Parry. Costo 10R.O", "ja": "パリィヒール：パリィで回復する。10R.O"}[ProgresoJuego.idioma])
func _on_boton_ecto_mouse_entered():
	mostrar_texto_progresivo({"en": "Ghost Smoothie: Insane Speed & Defense. Cost 25R.O", "es": "Batido de Ectoplasma: Velocidad y Defensa Insanas. Costo 25R.O", "ja": "ゴーストスムージー：超スピードと防御。25R.O"}[ProgresoJuego.idioma])
func _on_boton_reloj_mouse_entered():
	mostrar_texto_progresivo({"en": "Broken Hourglass: Slows time in danger. Cost 75R.O", "es": "Reloj de Arena Roto: Ralentiza el tiempo en peligro. Costo 75R.O", "ja": "壊れた砂時計：ピンチの時に時間を遅くする。75R.O"}[ProgresoJuego.idioma])
func _on_boton_vida_mouse_entered():
	mostrar_texto_progresivo({"en": "Health Potion: +50 Max HP Forever. Cost 100R.O", "es": "Poción de Vida: +50 HP Max Permanente. Costo 100R.O", "ja": "ライフポーション：最大HP+50。100R.O"}[ProgresoJuego.idioma])
func _on_boton_fuerza_mouse_entered():
	mostrar_texto_progresivo({"en": "Strength Potion: x1.5 Damage Forever. Cost 100R.O", "es": "Poción de Fuerza: x1.5 Daño Permanente. Costo 100R.O", "ja": "力のポーション：ダメージ1.5倍。100R.O"}[ProgresoJuego.idioma])
func _on_boton_velocidad_mouse_entered():
	mostrar_texto_progresivo({"en": "Speed Potion: Walk faster Forever. Cost 100R.O", "es": "Poción de Velocidad: Camina más rápido siempre. Costo 100R.O", "ja": "素早さのポーション：移動速度アップ。100R.O"}[ProgresoJuego.idioma])
func _on_boton_dios_mouse_entered():
	mostrar_texto_progresivo({"en": "PRIMORDIAL ESSENCE: Become the God of RetropawnWorld. Cost 5000R.O", "es": "ESENCIA PRIMORDIAL: Conviertete en el Dios de RetropawnWorld. Costo 5000R.O", "ja": "始原のエッセンス：世界の神になる。5000R.O"}[ProgresoJuego.idioma])
func _on_boton_extra_money_mouse_entered():
	mostrar_texto_progresivo({"en": "Extra Money: Enemies drop x2 Retrorbs! Cost 1000R.O", "es": "Extra Money: ¡Enemigos sueltan x2 Retrorbes! Costo 1000R.O", "ja": "エクストラマネー：敵のドロップ2倍！1000R.O"}[ProgresoJuego.idioma])
func _on_boton_shield_mouse_entered():
	mostrar_texto_progresivo({"en": "Shield: Absorbs 5 hits before breaking. Cost 1000R.O", "es": "Escudo: Absorbe 5 golpes antes de romperse. Costo 1000R.O", "ja": "シールド：5回攻撃を吸収する。1000R.O"}[ProgresoJuego.idioma])
func _on_boton_poison_mouse_entered():
	mostrar_texto_progresivo({"en": "Poison: Hits poison enemies for 10s. Cost 4550R.O", "es": "Veneno: Los golpes envenenan por 10s. Costo 4550R.O", "ja": "ポイズン：10秒間毒を付与。4550R.O"}[ProgresoJuego.idioma])

func _on_boton_skin_max_mouse_entered():
	var ya = ProgresoJuego.get("tiene_skin_max")
	mostrar_texto_progresivo({"en": "Classic Max — OWNED" if ya else "Classic Max. Cost 250R.O", "es": "Max Clásico — OBTENIDA" if ya else "Max Clásico. Costo 250R.O", "ja": "クラシック・マックス — 所持済" if ya else "クラシック・マックス。250R.O"}[ProgresoJuego.idioma])
func _on_boton_skin_neko_mouse_entered():
	var ya = ProgresoJuego.get("tiene_skin_neko")
	mostrar_texto_progresivo({"en": "Neko Maid — OWNED" if ya else "Neko Maid. Cost 500R.O", "es": "Neko Maid — OBTENIDA" if ya else "Neko Maid. Costo 500R.O", "ja": "ネコメイド — 所持済" if ya else "ネコメイド。500R.O"}[ProgresoJuego.idioma])
func _on_boton_skin_lionel_mouse_entered():
	var ya = ProgresoJuego.get("tiene_skin_lionel")
	mostrar_texto_progresivo({"en": "Lionel — OWNED" if ya else "Lionel. Cost 600R.O", "es": "Lionel — OBTENIDA" if ya else "Lionel. Costo 600R.O", "ja": "リオネル — 所持済" if ya else "リオネル。600R.O"}[ProgresoJuego.idioma])
func _on_boton_skin_papper_mouse_entered():
	var ya = ProgresoJuego.get("tiene_skin_papper")
	mostrar_texto_progresivo({"en": "PapperBatz — OWNED" if ya else "PapperBatz. Cost 400R.O", "es": "PapperBatz — OBTENIDA" if ya else "PapperBatz. Costo 400R.O", "ja": "ペーパーバッツ — 所持済" if ya else "ペーパーバッツ。400R.O"}[ProgresoJuego.idioma])

func _on_vestidor_max_mouse_entered():
	mostrar_texto_progresivo({"en": "Classic Max — tap to equip/remove!", "es": "Max Clásico — ¡toca para equipar/quitar!", "ja": "クラシック・マックス — タップして装備/解除！"}[ProgresoJuego.idioma])
func _on_vestidor_neko_mouse_entered():
	mostrar_texto_progresivo({"en": "Neko Maid — tap to equip/remove!", "es": "Neko Maid — ¡toca para equipar/quitar!", "ja": "ネコメイド — タップして装備/解除！"}[ProgresoJuego.idioma])
func _on_vestidor_lionel_mouse_entered():
	mostrar_texto_progresivo({"en": "Lionel — tap to equip/remove!", "es": "Lionel — ¡toca para equipar/quitar!", "ja": "リオネル — タップして装備/解除！"}[ProgresoJuego.idioma])
func _on_vestidor_papper_mouse_entered():
	var equipada = ProgresoJuego.get("skin_papper_equipada") == true
	mostrar_texto_progresivo({"en": "PapperBatz — tap to " + ("remove!" if equipada else "equip Batz!"), "es": "PapperBatz — ¡toca para " + ("quitar!" if equipada else "equipar a Batz!"), "ja": "ペーパーバッツ — タップして" + ("解除！" if equipada else "装備！")}[ProgresoJuego.idioma])
func _on_vestidor_default_mouse_entered():
	mostrar_texto_progresivo({"en": "Original Batz — classic look!", "es": "Batz Original — ¡el look clásico!", "ja": "オリジナルバッツ — クラシックな見た目！"}[ProgresoJuego.idioma])
func _on_boton_regalo_monedas_mouse_entered():
	var r = _ya_reclamo_hoy("ultimo_dia_regalo_monedas")
	mostrar_texto_progresivo({"en": "Daily: 5 free Retrorbs!" if not r else "Claimed! Come back tomorrow.", "es": "¡Diario: 5 Retrorbes gratis!" if not r else "Reclamado. ¡Vuelve mañana!", "ja": "毎日5R.O無料！" if not r else "受け取り済。明日また来てね！"}[ProgresoJuego.idioma])
func _on_boton_regalo_item_mouse_entered():
	var r = _ya_reclamo_hoy("ultimo_dia_regalo_item")
	mostrar_texto_progresivo({"en": "Mystery gift! Smoothie, Shield or Hourglass!" if not r else "Already claimed today!", "es": "¡Regalo misterioso! ¡Batido, Escudo o Reloj!" if not r else "¡Ya reclamado hoy!", "ja": "ミステリープレゼント！" if not r else "今日はもう受け取ったよ！"}[ProgresoJuego.idioma])


# ===========================================================
# PANZA DE BATZ
# ===========================================================

func _on_boton_panza_pressed():
	molestar_a_batz()

func molestar_a_batz():
	ProgresoJuego.enojo_batz += 1
	timer_texto.stop()
	label_dialogo.text = ""
	sprite_batz.play(skin_prefix + "touch")
	var t = create_tween()
	t.tween_property(sprite_batz, "scale", escala_original_batz * Vector2(1.1, 0.9), 0.1)
	t.tween_property(sprite_batz, "scale", escala_original_batz, 0.1)
	await sprite_batz.animation_finished
	if ProgresoJuego.enojo_batz > 4:
		vibrar_batz()
	var lang = ProgresoJuego.idioma
	if ProgresoJuego.enojo_batz <= 4:
		mostrar_texto_progresivo(frases_enojada[lang].pick_random())
	elif ProgresoJuego.enojo_batz <= 8:
		mostrar_texto_progresivo(frases_muy_enojada[lang].pick_random())
	elif ProgresoJuego.enojo_batz == 9:
		ProgresoJuego.otorgar_logro("logro_batz_enojado")
		ProgresoJuego.expulsado_una_vez = true
		ProgresoJuego.guardar_partida()
		mostrar_texto_progresivo({"en": "I'M TIRED OF YOU! GET OUT!", "es": "¡YA ME CANSASTE! ¡FUERA!", "ja": "もう我慢できない！出てけ！"}[lang])
		await get_tree().create_timer(1.5).timeout
		get_tree().change_scene_to_file("res://menu_inicio.tscn")
	else:
		cerrar_juego_con_nota()

func vibrar_batz():
	var pos_original = sprite_batz.position
	var t_shake = create_tween()
	for i in range(5):
		t_shake.tween_property(sprite_batz, "position", pos_original + Vector2(randf_range(-5,5), randf_range(-5,5)), 0.02)
	t_shake.tween_property(sprite_batz, "position", pos_original, 0.02)


# ===========================================================
# COMPRAS PÁGINA 1
# ===========================================================

func intentar_comprar_item(costo: int, tipo: String):
	var ya_tiene = false
	match tipo:
		"soda":        ya_tiene = ProgresoJuego.tiene_mejora_parry
		"ecto":        ya_tiene = ProgresoJuego.tiene_batido_ectoplasma
		"reloj":       ya_tiene = ProgresoJuego.tiene_reloj_arena
		"vida":        ya_tiene = ProgresoJuego.tiene_mejora_vida
		"fuerza":      ya_tiene = ProgresoJuego.tiene_mejora_fuerza
		"vel":         ya_tiene = ProgresoJuego.tiene_mejora_vel
		"dios":        ya_tiene = ProgresoJuego.tiene_despertar_dios
		"extra_money": ya_tiene = ProgresoJuego.get("tiene_extra_money")
		"shield":      ya_tiene = ProgresoJuego.get("tiene_shield")
		"poison":      ya_tiene = ProgresoJuego.get("tiene_poison")

	if ya_tiene:
		mostrar_texto_progresivo({"en": "You already have that!", "es": "¡Ya tienes eso!", "ja": "それはもう持ってるよ！"}[ProgresoJuego.idioma])
		return

	if ProgresoJuego.monedas >= costo:
		ProgresoJuego.monedas -= costo
		match tipo:
			"soda":        ProgresoJuego.tiene_mejora_parry       = true
			"ecto":        ProgresoJuego.tiene_batido_ectoplasma  = true
			"reloj":       ProgresoJuego.tiene_reloj_arena        = true
			"vida":        ProgresoJuego.tiene_mejora_vida        = true
			"fuerza":      ProgresoJuego.tiene_mejora_fuerza      = true
			"vel":         ProgresoJuego.tiene_mejora_vel         = true
			"dios":        ProgresoJuego.tiene_despertar_dios     = true
			"extra_money": ProgresoJuego.tiene_extra_money        = true
			"shield":      ProgresoJuego.tiene_shield             = true
			"poison":      ProgresoJuego.tiene_poison             = true
		ProgresoJuego.guardar_partida()
		actualizar_ui_monedas_con_efecto(ProgresoJuego.monedas)
		verificar_item_comprado()
		if sonido_compra: sonido_compra.play()
		mostrar_texto_progresivo(frases_gracias[ProgresoJuego.idioma].pick_random())
	else:
		mostrar_texto_progresivo(frases_pobre[ProgresoJuego.idioma].pick_random())
		vibrar_batz()

func _on_boton_soda_pressed():       intentar_comprar_item(10,   "soda")
func _on_boton_ecto_pressed():       intentar_comprar_item(25,   "ecto")
func _on_boton_reloj_pressed():      intentar_comprar_item(75,   "reloj")
func _on_boton_vida_pressed():       intentar_comprar_item(100,  "vida")
func _on_boton_fuerza_pressed():     intentar_comprar_item(100,  "fuerza")
func _on_boton_velocidad_pressed():  intentar_comprar_item(100,  "vel")
func _on_boton_extra_money_pressed():intentar_comprar_item(1000, "extra_money")
func _on_boton_shield_pressed():     intentar_comprar_item(1000, "shield")
func _on_boton_poison_pressed():     intentar_comprar_item(4550, "poison")
func _on_boton_dios_pressed():
	intentar_comprar_item(4000 if chicle_disponible == "dios" else 700, "dios")

func _on_boton_skin_max_pressed():    _comprar_skin("max",    250, "tiene_skin_max")
func _on_boton_skin_neko_pressed():   _comprar_skin("neko",   500, "tiene_skin_neko")
func _on_boton_skin_lionel_pressed(): _comprar_skin("lionel", 600, "tiene_skin_lionel")
func _on_boton_skin_papper_pressed(): _comprar_skin("papper", 400, "tiene_skin_papper")

func _comprar_skin(skin_id: String, costo: int, prop: String):
	if ProgresoJuego.get(prop):
		mostrar_texto_progresivo({"en": "You already own that! Check the fitting room →", "es": "¡Ya la tienes! Mira el vestidor →", "ja": "もう持ってるよ！試着室を見てみて →"}[ProgresoJuego.idioma])
		return
	if ProgresoJuego.monedas >= costo:
		ProgresoJuego.monedas -= costo
		ProgresoJuego.set(prop, true)
		ProgresoJuego.guardar_partida()
		actualizar_ui_monedas_con_efecto(ProgresoJuego.monedas)
		actualizar_stock_especial()
		if sonido_compra: sonido_compra.play()
		var nombre = nombres_skin[skin_id][ProgresoJuego.idioma]
		mostrar_texto_progresivo({"en": nombre + " unlocked! Equip it in the fitting room!", "es": "¡" + nombre + " desbloqueada! ¡Equípala en el vestidor!", "ja": nombre + "解放！試着室で装備してね！"}[ProgresoJuego.idioma])
	else:
		mostrar_texto_progresivo(frases_pobre[ProgresoJuego.idioma].pick_random())
		vibrar_batz()


# ===========================================================
# VOLVER / CERRAR
# ===========================================================

func _on_boton_volver_pressed():
	ProgresoJuego.guardar_partida()
	Cargador.ir_a_escena("res://menu_inicio.tscn")

func cerrar_juego_con_nota():
	ProgresoJuego.otorgar_logro("logro_batz_enojado")
	var desktop = OS.get_system_dir(OS.SYSTEM_DIR_DESKTOP)
	var file = FileAccess.open(desktop + "/BatzsNote.txt", FileAccess.WRITE)
	if file:
		file.store_string({"en": "I kicked you out for being annoying...", "es": "Te expulsé por molestar... Pelotudo", "ja": "うざいから追い出したよ…バーカ"}[ProgresoJuego.idioma])
		file = null
	get_tree().quit()


# ===========================================================
# DEBUG — Ajuste visual de slots + dinero de test
# M        → +1000 monedas de test
# Shift+M  → toggle modo ajuste de slots
# Tab      → alterna slot izquierdo/derecho
# Flechas  → mueve slot (Shift = 1px, normal = 5px)
# ===========================================================

func dar_dinero_test():
	ProgresoJuego.monedas += 1000
	ProgresoJuego.guardar_partida()
	actualizar_ui_monedas_con_efecto(ProgresoJuego.monedas)

func _input(event):
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_M:
				if not event.shift_pressed:
					dar_dinero_test()
				else:
					_debug_slots = not _debug_slots
					var estado = "ON — Tab=cambiar slot  Flechas=mover  Shift+M=salir" if _debug_slots else "OFF"
					print("🎯 Modo ajuste slots: ", estado)
					if _debug_slots and pagina_actual != 2:
						pagina_actual = 2
						actualizar_paginas()

			KEY_TAB:
				if _debug_slots:
					_debug_slot_activo = 1 - _debug_slot_activo
					print("Slot activo: ", "IZQUIERDO" if _debug_slot_activo == 0 else "DERECHO")

			KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT:
				if not _debug_slots: return
				var paso = 1 if event.shift_pressed else 5
				var delta_mov = Vector2.ZERO
				match event.keycode:
					KEY_UP:    delta_mov = Vector2(0, -paso)
					KEY_DOWN:  delta_mov = Vector2(0,  paso)
					KEY_LEFT:  delta_mov = Vector2(-paso, 0)
					KEY_RIGHT: delta_mov = Vector2( paso, 0)

				if _debug_slot_activo == 0:
					SLOT_IZQ += delta_mov
					print("SLOT_IZQ = Vector2(", SLOT_IZQ.x, ", ", SLOT_IZQ.y, ")")
				else:
					SLOT_DER += delta_mov
					print("SLOT_DER = Vector2(", SLOT_DER.x, ", ", SLOT_DER.y, ")")

				actualizar_stock_especial()
