extends Control

signal terminado

@onready var texto_label = $RichTextLabel
@onready var timer_letras = $Timer
@onready var cara = $Cara
@onready var voz = $VozSonido

var frases = []
var indice = 0
var en_modo_love = false # Nueva variable para controlar el estado visual

func _ready():
	self.hide()
	timer_letras.wait_time = 0.05
	timer_letras.timeout.connect(_on_timer_timeout)

func iniciar_charla(lista):
	# Guardamos la lista original que viene del tutorial
	frases = lista
	var idioma = "es"
	if "idioma" in ProgresoJuego:
		idioma = ProgresoJuego.idioma

	# --- TRADUCCIÓN DINÁMICA DEL TUTORIAL (SOLUCIÓN AL ERROR) ---
	# Si el idioma no es español, traducimos las frases que vienen en la 'lista'
	if idioma != "es":
		for i in range(frases.size()):
			var frase_orig = frases[i]
			# Aquí mapeamos las frases típicas del tutorial a sus versiones en inglés/japonés
			match frase_orig:
				"Bienvenido al tutorial.":
					if idioma == "en": frases[i] = "Welcome to the tutorial."
					elif idioma == "ja": frases[i] = "チュートリアルへようこそ。"
				"Usa las flechas para moverte.":
					if idioma == "en": frases[i] = "Use the arrows to move."
					elif idioma == "ja": frases[i] = "矢印キーで移動します。"
				"Presiona Espacio para saltar.":
					if idioma == "en": frases[i] = "Press Space to jump."
					elif idioma == "ja": frases[i] = "スペースキーでジャンプ。"
				# Añade aquí todas las frases exactas que uses en tu tutorial...

	# Lista donde guardaremos los saludos personalizados
	var saludo_especial = []
	var pj = GameManager.personaje_elegido
	
	# Por defecto empezamos en modo normal
	en_modo_love = false

	# --- LÓGICA DE SALUDOS POR SKINS Y PERSONAJES ---
	
	# 1. CASO PREPUCÍN (Rata pelada)
	if pj == "prepucin":
		if idioma == "es":
			saludo_especial = ["Ay... qué asco...", "Es una rata.", "amigo, pense que eras un p*ne...", "Mi huevo izquierdo es igual a ti."]
		elif idioma == "ja":
			saludo_especial = ["うわ…気持ち悪い…", "ネズミじゃないか。", "おい、てっきり〇んこだと思ったぞ…", "僕の左のタマキンそっくりだ。"]
		else:
			saludo_especial = ["Ugh... how gross...", "It's a rat.", "Mate, I thought you were a d*ck...", "My left nut looks just like you."]
	
	# 2. CASO SKETCH (Con revisión de Skin Maid)
	elif pj == "sketch":
		if ProgresoJuego.skin_neko_equipada:
			en_modo_love = true # ¡A Meow le gusta el traje de Maid!
			if idioma == "es":
				saludo_especial = ["¡¿Pero qué rayos te pusiste?! ¿Acaso intentas seducirme con ese traje?"]
			elif idioma == "ja":
				saludo_especial = ["一体何を着てるんだ？！その服で僕を誘惑しようとしてるのか？"]
			else:
				saludo_especial = ["What on earth are you wearing?! Are you trying to seduce me with that outfit?"]
		else:
			if idioma == "es":
				saludo_especial = ["Oh vaya! eres otro asqueroso jugador! Agradece que solo soy asesino de programadores y no de jugadores, blegh!"]
			elif idioma == "ja":
				saludo_especial = ["おいおい、また汚らわしいプレイヤーか！僕はプログラマー専門の殺し屋で、プレイヤーは殺さないことに感謝するんだな、べーっ！"]
			else:
				saludo_especial = ["Oh well! another disgusting player! Be grateful I only kill programmers and not players, blegh!"]

	# 3. CASO JANE (Con revisión de Skin Lionel)
	elif pj == "jane":
		en_modo_love = true # Meow siempre ama a Jane o Lionel
		if ProgresoJuego.skin_lionel_equipada:
			if idioma == "es":
				saludo_especial = ["¡Un oficial de policía! Espera... ¿Lionel? Por un momento pensé que venías a arrestarme por mis crímenes digitales. Casi me asustas, guapo."]
			elif idioma == "ja":
				saludo_especial = ["警察官！？…待て、ライオネル？デジタル犯罪で僕を逮捕しに来たのかと思ったよ。驚かせやがって、イケメンくん。"]
			else:
				saludo_especial = ["A police officer! Wait... Lionel? For a moment I thought you were here to arrest me for my digital crimes. You almost scared me, handsome."]
		else:
			if idioma == "es":
				saludo_especial = ["Respawnium2, no? Eres la joven mas hermosa que he visto! <3", "Mi amor por ti es como el caramelo que un niño anhela!"]
			elif idioma == "ja":
				saludo_especial = ["Respawnium2だろ？君は僕が見た中で一番美しいお嬢さんだ！ <3", "君への愛は、子供が欲しがるキャンディのようなものさ！"]
			else:
				saludo_especial = ["Respawnium2, right? You're the most beautiful girl I've ever seen! <3", "My love for you is like the candy a child craves!"]

	# 4. CASO MAX (Con revisión de Skin Clásica)
	elif pj == "max":
		if ProgresoJuego.skin_max_equipada:
			if idioma == "es":
				saludo_especial = ["Te veo... diferente. Más simple, más pixelado. ¿Acaso venimos de una versión donde yo aún no existía? Qué nostalgia... ¡mentira, te odio igual!"]
			elif idioma == "ja":
				saludo_especial = ["なんだか…違って見えるな。もっとシンプルで、カクカクしてる。僕が存在しなかった頃のバージョンから来たのか？懐かしいな…なんて嘘だ、相変わらず大嫌いだぞ！"]
			else:
				saludo_especial = ["You look... different. Simpler, more pixelated. Are we from a version where I didn't even exist? So nostalgic... just kidding, I still hate you!"]
		else:
			if idioma == "es":
				saludo_especial = ["Vaya cabezón! Tu ya no tienes experiencia luchando con entidades asi? bueno ya que!"]
			elif idioma == "ja":
				saludo_especial = ["なんてデカ頭だ！こういう存在との戦いには慣れてるんじゃないのか？まあ、いいけどさ！"]
			else:
				saludo_especial = ["Look at that big head! Don't you already have experience fighting entities like this? well, whatever!"]

	# Combinamos: El saludo especial (si existe) + Los diálogos del tutorial
	var nueva_lista = []
	nueva_lista.append_array(saludo_especial)
	nueva_lista.append_array(frases)
	frases = nueva_lista

	indice = 0
	self.show()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	escribir_frase()

func escribir_frase():
	if indice < frases.size():
		texto_label.text = frases[indice]
		texto_label.visible_characters = 0
		
		# Decidimos qué animación usar
		if cara:
			if en_modo_love and indice < (frases.size() - (frases.size() - 2 if frases.size() > 2 else 1)):
				cara.play("talklove")
			else:
				cara.play("talk")
				
		timer_letras.start()
	else:
		finalizar()

func _on_timer_timeout():
	if texto_label.visible_characters < texto_label.text.length():
		texto_label.visible_characters += 1
		
		if voz:
			var car = texto_label.text[texto_label.visible_characters - 1]
			if car != " " and car != "." and car != ",":
				voz.pitch_scale = randf_range(1.1, 1.4) 
				voz.play()
	else:
		timer_letras.stop()
		if cara:
			if en_modo_love and cara.animation == "talklove":
				cara.play("idlelove")
			else:
				cara.play("idle")

func _input(event):
	if event.is_action_pressed("ui_accept"):
		if self.visible:
			if texto_label.visible_characters < texto_label.text.length():
				texto_label.visible_characters = texto_label.text.length()
				timer_letras.stop()
				if cara:
					if en_modo_love and cara.animation == "talklove":
						cara.play("idlelove")
					else:
						cara.play("idle")
			else:
				indice += 1
				escribir_frase()

func finalizar():
	self.hide()
	if cara: cara.stop()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	emit_signal("terminado")
	
# Añade esto al final del script de Meow (el de Control/RichTextLabel)
func iniciar_charla_directa(lista):
	frases = lista
	indice = 0
	en_modo_love = false # O la lógica que prefieras
	self.show()
	escribir_frase()
