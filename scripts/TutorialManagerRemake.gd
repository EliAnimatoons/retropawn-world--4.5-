extends Control
# =====================================================================
# DIALOGOS (Nodo Control)
# - Recibe CLAVES de texto (ej: "tut_bienvenida") o texto suelto.
#   Si la clave existe en TEXTOS se traduce; si no, se muestra tal cual.
# - Idiomas: es, en, ja, id (indonesio).
# - El saludo especial por personaje se dice UNA sola vez por escena.
# =====================================================================

signal terminado

@onready var texto_label = $RichTextLabel
@onready var timer_letras = $Timer
@onready var cara = $Cara
@onready var voz = $VozSonido

const IDIOMA_POR_DEFECTO := "es"
const IDIOMAS_SOPORTADOS := ["es", "en", "ja", "id"]
# Por si tu selector de idioma guarda otro nombre/código para el indonesio
const ALIAS_IDIOMA := {
	"español": "es", "spanish": "es", "esp": "es",
	"english": "en", "inglés": "en", "ingles": "en",
	"japanese": "ja", "japonés": "ja", "japones": "ja", "jp": "ja",
	"indonesio": "id", "indonesian": "id", "indonesia": "id",
	"bahasa": "id", "bahasa indonesia": "id", "in": "id",
}

const VELOCIDAD_LETRA := 0.035
const PAUSA_PUNTUACION := {
	".": 0.25, "!": 0.25, "?": 0.25, ",": 0.12, "…": 0.2,
	"。": 0.25, "！": 0.25, "？": 0.25, "、": 0.12,
}
const CARACTERES_SIN_VOZ := [" ", ".", ",", "!", "?", "…", "。", "！", "？", "、"]
# Evita que el mismo botón que abrió el diálogo lo cierre/saltee al instante
const BLOQUEO_INPUT_INICIAL_MS := 250

# ---------------------------------------------------------------------
# TEXTOS DEL TUTORIAL
# ---------------------------------------------------------------------
const TEXTOS := {
	"tut_bienvenida": {
		"es": "Bienvenido al tutorial.",
		"en": "Welcome to the tutorial.",
		"ja": "チュートリアルへようこそ。",
		"id": "Selamat datang di tutorial.",
	},
	"tut_mover": {
		"es": "Usa las flechas o el joystick para moverte por la sala.",
		"en": "Use the arrow keys or the joystick to move around the room.",
		"ja": "矢印キーやジョイスティックで部屋を移動しよう。",
		"id": "Gunakan tombol panah atau joystick untuk bergerak di ruangan ini.",
	},
	"tut_muybien": {
		"es": "¡Muy bien!",
		"en": "Nice work!",
		"ja": "いいね！",
		"id": "Bagus sekali!",
	},
	"tut_golpes": {
		"es": "Ahora presiona el botón de ataque varias veces seguidas para ejecutar tu combo de golpes.",
		"en": "Now press the attack button several times in a row to unleash your punch combo.",
		"ja": "次は攻撃ボタンを連続で押して、コンボを出してみよう。",
		"id": "Sekarang tekan tombol serang beberapa kali berturut-turut untuk melakukan kombo pukulanmu.",
	},
	"tut_parry1": {
		"es": "Los enemigos atacan fuerte, pero si usas el Parry justo a tiempo, los aturdirás.",
		"en": "Enemies hit hard, but if you Parry at just the right moment, you'll stun them.",
		"ja": "敵の攻撃は強力だけど、ちょうどいいタイミングでパリィすれば気絶させられるよ。",
		"id": "Musuh menyerang dengan keras, tetapi jika kamu melakukan Parry tepat waktu, mereka akan pingsan.",
	},
	"tut_parry2": {
		"es": "Se acerca un minion. Presiona Parry justo cuando empiece su ataque. ¡Prepárate!",
		"en": "A minion is coming. Press Parry right as it starts its attack. Get ready!",
		"ja": "ミニオンが近づいてくる。攻撃を始めた瞬間にパリィを押そう。準備はいい？",
		"id": "Seorang minion mendekat. Tekan Parry tepat saat ia memulai serangannya. Bersiaplah!",
	},
	"tut_parry_pista": {
		"es": "¡Casi! No lo presiones antes de tiempo: espera a que el minion empiece a atacar y ahí sí, Parry.",
		"en": "Close! Don't press it too early: wait for the minion to start attacking, then Parry.",
		"ja": "惜しい！早く押しすぎないで。ミニオンが攻撃を始めるのを待ってからパリィだ。",
		"id": "Hampir! Jangan menekannya terlalu cepat: tunggu minion mulai menyerang, baru Parry.",
	},
	"tut_parry_ok": {
		"es": "¡Parry perfecto! El minion quedó aturdido.",
		"en": "Perfect Parry! The minion is stunned.",
		"ja": "完璧なパリィ！ミニオンが気絶した。",
		"id": "Parry sempurna! Minion itu pingsan.",
	},
	"tut_gk1": {
		"es": "Cuando un enemigo quede debilitado con poca vida, aparecerá una marca sobre él.",
		"en": "When an enemy is weakened with low health, a mark will appear above it.",
		"ja": "敵が弱って体力が少なくなると、頭上にマークが現れるよ。",
		"id": "Saat musuh melemah dan darahnya tinggal sedikit, sebuah tanda akan muncul di atasnya.",
	},
	"tut_gk2": {
		"es": "Acércate y presiona el botón de Glory Kill para ejecutarlo, curarte y ganar poder.",
		"en": "Get close and press the Glory Kill button to finish it, heal yourself and gain power.",
		"ja": "近づいてグローリーキルボタンを押すと、とどめを刺して回復し、パワーも手に入るよ。",
		"id": "Dekati musuh lalu tekan tombol Glory Kill untuk menghabisinya, memulihkan darah, dan mendapatkan tenaga.",
	},
	"tut_gk_ok": {
		"es": "¡Brutal! Cada Glory Kill te cura y llena tu barra de poder.",
		"en": "Brutal! Every Glory Kill heals you and fills your power bar.",
		"ja": "すごい！グローリーキルのたびに回復して、パワーゲージが溜まるよ。",
		"id": "Keren! Setiap Glory Kill memulihkan darahmu dan mengisi bar tenaga.",
	},
	"tut_agarre1": {
		"es": "Cuidado: si un enemigo te atrapa en un agarre, no podrás moverte y recibirás daño.",
		"en": "Careful: if an enemy catches you in a grab, you can't move and you take damage.",
		"ja": "気をつけて。敵につかまれると動けなくなって、ダメージを受け続けるよ。",
		"id": "Hati-hati: jika musuh menangkapmu, kamu tidak bisa bergerak dan terus menerima damage.",
	},
	"tut_agarre2": {
		"es": "Para zafarte, presiona Parry cuando la aguja del HUD pase por la zona de éxito. ¡Repítelo hasta llenar la barra!",
		"en": "To break free, press Parry when the HUD needle passes over the success zone. Repeat until the bar is full!",
		"ja": "振りほどくには、HUDの針が成功ゾーンを通るときにパリィを押そう。ゲージが満タンになるまで繰り返して！",
		"id": "Untuk melepaskan diri, tekan Parry saat jarum HUD melewati zona sukses. Ulangi sampai bar penuh!",
	},
	"tut_agarre_ok": {
		"es": "¡Te zafaste! Mientras te agarran el daño no para, así que no pierdas tiempo.",
		"en": "You broke free! Damage doesn't stop while you're grabbed, so don't waste time.",
		"ja": "振りほどいた！つかまれている間はダメージが続くから、急ごう。",
		"id": "Kamu berhasil lepas! Damage tidak berhenti selama kamu ditangkap, jadi jangan buang waktu.",
	},
	"tut_final_libre": {
		"es": "Eso es todo lo básico. Avanza por el nivel hasta el final... ¿Qué podría salir mal?",
		"en": "That's all the basics. Make your way to the end of the level... What could possibly go wrong?",
		"ja": "基本はこれで全部。ステージの最後まで進もう……何が起こるかな？",
		"id": "Itu semua dasarnya. Majulah sampai akhir level... Apa yang mungkin salah?",
	},
	"tut_colapso1": {
		"es": "¡ALERTA! El nivel está colapsando.",
		"en": "ALERT! The level is collapsing!",
		"ja": "警告！ステージが崩壊している！",
		"id": "PERINGATAN! Level ini sedang runtuh!",
	},
	"tut_colapso2": {
		"es": "¡Date la vuelta y corre hacia el inicio antes de que el tiempo se agote!",
		"en": "Turn around and run back to the start before time runs out!",
		"ja": "振り返って、時間切れになる前にスタート地点まで走れ！",
		"id": "Berbaliklah dan lari ke titik awal sebelum waktu habis!",
	},
	"tut_colapso3": {
		"es": "Mantén presionada una dirección para tomar impulso y correr a toda velocidad.",
		"en": "Hold a direction to build momentum and run at full speed.",
		"ja": "方向キーを押し続けて勢いをつけ、全速力で走ろう。",
		"id": "Tahan satu arah untuk mengumpulkan momentum dan berlari secepat mungkin.",
	},
}

# ---------------------------------------------------------------------
# SALUDOS ESPECIALES POR PERSONAJE / SKIN
# ---------------------------------------------------------------------
const SALUDOS := {
	"prepucin": {
		"es": ["Ay... qué bonito...", "Es una rata."],
		"en": ["Aww... how cute...", "It's a rat."],
		"ja": ["あぁ…かわいい…", "ネズミだ。"],
		"id": ["Aww... lucu sekali...", "Itu tikus."],
	},
	"sketch": {
		"es": ["..."], "en": ["..."], "ja": ["..."], "id": ["..."],
	},
	"sketch_neko": {
		"es": ["¡¿Pero qué rayos te pusiste?! ¡¿Intentas seducirme?!"],
		"en": ["What on earth are you wearing?! Are you trying to seduce me?!"],
		"ja": ["一体なんて格好してるの！？誘惑しようとしてるの！？"],
		"id": ["Apa-apaan yang kamu pakai?! Kamu mencoba menggodaku?!"],
	},
	"jane": {
		"es": ["¡Eres la persona más hermosa que he visto! <3"],
		"en": ["You're the most beautiful person I've ever seen! <3"],
		"ja": ["あなたは今まで見た中で一番素敵な人！<3"],
		"id": ["Kamu orang paling cantik yang pernah kulihat! <3"],
	},
	"max": {
		"es": ["Vaya cabezón, ¿otra vez tú por aquí?"],
		"en": ["Well, if it isn't the big-head. You again?"],
		"ja": ["おや、大頭くんじゃないか。またお前か？"],
		"id": ["Wah, si kepala besar. Kamu lagi?"],
	},
}

var _lineas: Array = []          # [{ "texto": String, "love": bool }]
var _indice: int = 0
var _escribiendo: bool = false
var _activo: bool = false
var _love_actual: bool = false
var _tiempo_apertura_ms: int = 0
var _saludo_dado: bool = false

func _ready() -> void:
	hide()
	timer_letras.one_shot = true
	if not timer_letras.timeout.is_connected(_on_timer_timeout):
		timer_letras.timeout.connect(_on_timer_timeout)
	if texto_label:
		texto_label.bbcode_enabled = true

# ---------------------------------------------------------------------
# API PÚBLICA
# ---------------------------------------------------------------------
func iniciar_charla(lista: Array) -> void:
	var idioma := _idioma_actual()
	var pj := _personaje_actual()
	_lineas.clear()

	# Saludo especial: solo la primera vez que se abre el diálogo en la escena
	if not _saludo_dado:
		_saludo_dado = true
		var saludo := _saludo_para(pj, idioma)
		for t in saludo["lineas"]:
			_lineas.append({"texto": str(t), "love": saludo["love"]})

	# Jane está enamorada durante todo el tutorial
	var love_general := (pj == "jane")
	for item in lista:
		_lineas.append({"texto": _traducir(str(item), idioma), "love": love_general})

	_indice = 0
	_activo = true
	_tiempo_apertura_ms = Time.get_ticks_msec()
	show()
	_mostrar_linea()

# ---------------------------------------------------------------------
# TRADUCCIÓN / PERSONAJE
# ---------------------------------------------------------------------
func _idioma_actual() -> String:
	var crudo = ProgresoJuego.get("idioma")
	if crudo == null:
		return IDIOMA_POR_DEFECTO
	var codigo := str(crudo).to_lower().strip_edges()
	if ALIAS_IDIOMA.has(codigo):
		codigo = ALIAS_IDIOMA[codigo]
	return codigo if codigo in IDIOMAS_SOPORTADOS else IDIOMA_POR_DEFECTO

func _personaje_actual() -> String:
	var pj := str(GameManager.personaje_elegido).to_lower()
	if pj == "forerat":
		pj = "prepucin"
	return pj

func _traducir(clave: String, idioma: String) -> String:
	if TEXTOS.has(clave):
		var d: Dictionary = TEXTOS[clave]
		return d.get(idioma, d["es"])
	return clave # texto suelto: se muestra tal cual

func _saludo_para(pj: String, idioma: String) -> Dictionary:
	var clave := pj
	var love := false
	if pj == "sketch" and ProgresoJuego.get("skin_neko_equipada") == true:
		clave = "sketch_neko"
		love = true
	elif pj == "jane":
		love = true
	if not SALUDOS.has(clave):
		return {"lineas": [], "love": false}
	var por_idioma: Dictionary = SALUDOS[clave]
	return {"lineas": por_idioma.get(idioma, por_idioma["es"]), "love": love}

# ---------------------------------------------------------------------
# ESCRITURA
# ---------------------------------------------------------------------
func _mostrar_linea() -> void:
	if _indice >= _lineas.size():
		_finalizar()
		return
	var linea: Dictionary = _lineas[_indice]
	_love_actual = linea["love"]
	texto_label.text = linea["texto"]
	texto_label.visible_characters = 0
	_escribiendo = true
	_poner_cara(true)
	timer_letras.start(VELOCIDAD_LETRA)

func _on_timer_timeout() -> void:
	if not _escribiendo:
		return
	var total: int = texto_label.get_total_character_count()
	if texto_label.visible_characters >= total:
		_terminar_escritura()
		return

	texto_label.visible_characters += 1
	var visibles: String = texto_label.get_parsed_text()
	var pos: int = texto_label.visible_characters - 1
	var car := visibles[pos] if pos < visibles.length() else " "

	if voz and not (car in CARACTERES_SIN_VOZ):
		voz.pitch_scale = randf_range(1.1, 1.4)
		voz.play()

	if texto_label.visible_characters >= total:
		_terminar_escritura()
	else:
		timer_letras.start(VELOCIDAD_LETRA + float(PAUSA_PUNTUACION.get(car, 0.0)))

func _terminar_escritura() -> void:
	_escribiendo = false
	timer_letras.stop()
	texto_label.visible_characters = -1
	_poner_cara(false)

func _completar_linea() -> void:
	_terminar_escritura()

func _poner_cara(hablando: bool) -> void:
	if not cara:
		return
	var anim := "talk" if hablando else "idle"
	if _love_actual:
		anim += "love" # talklove / idlelove
	cara.play(anim)

# ---------------------------------------------------------------------
# INPUT
# ---------------------------------------------------------------------
func _es_confirmar(event: InputEvent) -> bool:
	for a in ["ui_accept", "ataque", "ataque_p2"]:
		if InputMap.has_action(a) and event.is_action_pressed(a):
			return true
	return false

func _input(event: InputEvent) -> void:
	if not _activo or event.is_echo():
		return
	if not _es_confirmar(event):
		return
	get_viewport().set_input_as_handled()
	if Time.get_ticks_msec() - _tiempo_apertura_ms < BLOQUEO_INPUT_INICIAL_MS:
		return
	if _escribiendo:
		_completar_linea()
	else:
		_indice += 1
		_mostrar_linea()

func _finalizar() -> void:
	_activo = false
	_escribiendo = false
	timer_letras.stop()
	hide()
	if cara:
		cara.stop()
	terminado.emit()
