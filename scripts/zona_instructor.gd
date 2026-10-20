extends Area3D

@export var pared_a_destruir: StaticBody3D 
@export var pared_bomba: StaticBody3D # La pared que rompe el minion bomba
@export var dummy: Node3D 
@export var enemigo_prueba: CharacterBody3D 

@onready var ui = get_tree().current_scene.find_child("Dialogos", true, false)

var activado = false
var etapa = 0
var jugador = null
var idioma = "es"

func _ready():
	idioma = "es"
	if "idioma" in ProgresoJuego:
		idioma = ProgresoJuego.idioma
	
	body_entered.connect(_on_body_entered)
	
	if dummy and dummy.has_signal("recibio_golpe"):
		# Quitamos CONNECT_ONE_SHOT para manejar nosotros el flujo
		dummy.recibio_golpe.connect(_on_dummy_golpeado)

func _on_body_entered(body):
	# Solo se activa si no hemos golpeado al dummy antes (etapa sigue en 0)
	if body.is_in_group("player") and not activado:
		activado = true
		jugador = body
		etapa = 1
		
		var lista = []
		if idioma == "en":
			lista = ["Hello imbecile... Well, you already know what this is about.", "See that dummy? Good, hit it! So we can move to the next step!"]
		elif idioma == "ja":
			lista = ["やあ、バカ野郎… まあ、これが何のことかはもう分かってるよな。", "そのマヌケな人形が見えるか？よし、叩け！そうすれば次に進めるからな！"]
		else:
			lista = ["Hola imbecil... Bueno ya sabes de que va esto.", "¿Ves ese maniquí? bueno, ¡golpéalo! ¡así pasamos al siguiente paso!"]
		
		iniciar_secuencia(lista)

func iniciar_secuencia(lista):
	# Buscamos al jugador si aún no lo tenemos (por si golpeó al dummy primero)
	if jugador == null:
		jugador = get_tree().get_first_node_in_group("player")
		
	if jugador:
		jugador.set_physics_process(false)
		if etapa > 1:
			ui.iniciar_charla_directa(lista) 
		else:
			ui.iniciar_charla(lista)
		await ui.terminado
		jugador.set_physics_process(true)

func _on_dummy_golpeado():
	# CASO ESPECIAL: Si golpea al dummy ANTES de hablar con Meow
	if etapa == 0:
		activado = true # Marcamos como activado para que no se dispare la charla inicial luego
		etapa = 2
		if pared_a_destruir:
			pared_a_destruir.queue_free()
		
		var lista = []
		if idioma == "es":
			lista = ["Bueno... Se ve que ya sabes como golpear. Pasemos a lo siguiente."]
		elif idioma == "en":
			lista = ["Well... It seems you already know how to hit. Let's move on."]
		else:
			lista = ["ふん… 叩き方はもう知っているようだな。次に行くぞ。"]
		
		iniciar_secuencia(lista)
		return # Salimos para no ejecutar el código de abajo

	# CASO NORMAL: Si ya estaba en la etapa 1 (esperando el golpe)
	if etapa == 1:
		etapa = 2
		if pared_a_destruir:
			pared_a_destruir.queue_free()
		
		var lista = []
		if idioma == "es":
			lista = ["¡Bien! Ya sabes golpear, algo básico."]
		elif idioma == "en":
			lista = ["Good! You already know how to hit, something basic."]
		else:
			lista = ["よし！叩き方は分かったようだな、基本中の基本だ。"]
		
		iniciar_secuencia(lista)

# --- PASO DEL PARRY Y SUPER BARRA ---
func trigger_congelar_parry():
	if etapa == 2:
		etapa = 3
		Engine.time_scale = 0 
		
		var lista = []
		if idioma == "es":
			lista = [
				"¡Bien! Justo te están por golpear. Hazle PARRY para bloquear el ataque.",
				"Al golpear o hacer parry, subirá tu barra de SUPER.",
				"Cada personaje tiene una habilidad única al usar el super. ¡No la desperdicies!"
			]
		elif idioma == "en":
			lista = [
				"Wait! They're about to hit you. Perform a PARRY to block.",
				"By hitting or parrying, your SUPER bar will increase.",
				"Each character has a unique mechanic when using their super. Don't waste it!"
			]
		else:
			lista = [
				"待て！攻撃が来るぞ。パリィで防ぐんだ。",
				"攻撃やパリィをすると、スーパーゲージが溜まっていくぞ。",
				"各キャラクターはスーパーを使うと独自の能力を発揮する。無駄にするなよ！"
			]
		
		ui.iniciar_charla_directa(lista)
		await ui.terminado
		Engine.time_scale = 1

# --- PASO DEL MINION BOMBA ---
func activar_paso_bomba():
	if etapa == 3:
		etapa = 4
		var lista = []
		if idioma == "es":
			lista = ["Bien... Para romper esa pared, golpea al minion bomba contra ella.", "Si fallas... bueno, mejor no falles."]
		elif idioma == "en":
			lista = ["Fine... To break that wall, hit the bomb minion against it.", "If you fail... well, you better not fail."]
		else:
			lista = ["よし… あの壁を壊すには、爆弾ミニオンを壁に叩きつけるんだ。", "もし失敗したら… まあ、失敗しないことだな。"]
		
		iniciar_secuencia(lista)

# --- RESULTADO BOMBA ---
func _on_bomba_exito():
	if etapa == 4:
		etapa = 5
		if pared_bomba: pared_bomba.queue_free()
		
		var lista = ["Bueno eso es todo! Espero que mueras >:D"]
		if idioma == "en": lista = ["Well, that's all! I hope you die! >:D"]
		elif idioma == "ja": lista = ["まあ、こんなもんだろ！さっさとくたばれ！ >:D"]
		
		iniciar_secuencia(lista)

func _on_bomba_fallida():
	if etapa == 4:
		var lista = []
		if idioma == "es":
			lista = ["Dios... Hasta para esto eres un fracaso... Reinicia el tutorial por favor..."]
		elif idioma == "en":
			lista = ["God... You're a failure even at this... Restart the tutorial, please..."]
		else:
			lista = ["やれやれ… こんなことすら出来ないなんて。チュートリアルをやり直せ。"]
			
		jugador.set_physics_process(false)
		ui.iniciar_charla_directa(lista)
		await ui.terminado
		get_tree().reload_current_scene() 

func _on_zona_bomba_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		if etapa == 3:
			activar_paso_bomba()
