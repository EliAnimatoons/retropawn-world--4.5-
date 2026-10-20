# NPCInteractuable.gd
extends Area3D

enum TipoNPC { MAX, CHOSMIX, BATZ, MICHAEL, JANE, NUBBE, BREAD }

@export var tipo_npc: TipoNPC = TipoNPC.MAX
@export var ui_dialogo: Control

@onready var sprite = $AnimatedSprite3D

var jugador_cerca: Node = null
var ya_interactuo: bool = false
var ya_hablo_una_vez: bool = false

var dialogos = {
	TipoNPC.MAX: {
		"es": ["¡Mmm! ¡Qué delicia de pastel!", "¡Gracias por la torta, bro!"],
		"en": ["Mmm! What a delicious cake!", "Thanks for the cake, bro!"],
		"ja": ["うわぁ！すごく美味しいケーキ！", "ケーキをありがとう、相棒！"]
	},
	TipoNPC.CHOSMIX: {
		"es": ["¡Uff, un pastel! Me lo como entero.", "¡Estaba increíble!"],
		"en": ["Phew, a cake! I'll eat it whole.", "It was amazing!"],
		"ja": ["うわ、ケーキだ！丸ごと食べるよ。", "最高だった！"]
	},
	TipoNPC.BATZ: {
		"es": ["¿Pastel para mí? ¡Ñam ñam!", "¡Qué gran detalle!"],
		"en": ["Cake for me? Yum yum!", "What a nice touch!"],
		"ja": ["僕にケーキ？モグモグ！", "なんて素敵な気配りだ！"]
	},
	TipoNPC.MICHAEL: {
		"es": ["¿Tienes fuego?", "*Enciende el cigarrillo*", "...Gracias, brochacho."],
		"en": ["Got a light?", "*Lights cigarette*", "...Thanks, son."],
		"ja": ["火はあるか？", "＊タバコに火をつける＊", "…ありがとよ、坊主。"]
	},
	TipoNPC.JANE: {
		"es": ["Hola, ¿qué tal tu día?", "Es un gusto verte por aquí."],
		"en": ["Hello, how is ur day?", "It's nice to see u here."],
		"ja": ["こんにちは、調子はどう？", "ここで会えて嬉しいわ。"]
	},
	TipoNPC.NUBBE: {
		"es": ["No gracias, no tengo hambre de pastel hoy."],
		"en": ["No thanks, I'm not hungry for cake today."],
		"ja": ["結構です、今日はケーキの気分じゃないんだ。"]
	},
	TipoNPC.BREAD: {
		"es": ["Se ve bien, pero lo guardaré para comerlo luego."],
		"en": ["Looks good, but I'll save it for later."],
		"ja": ["美味しそうだけど、後で食べることにするよ。"]
	}
}

func _ready():
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not body_exited.is_connected(_on_body_exited):
		body_exited.connect(_on_body_exited)
	
	if not ui_dialogo:
		ui_dialogo = get_tree().root.find_child("Dialogos", true, false)
		if not ui_dialogo:
			ui_dialogo = get_tree().root.find_child("Dialogo", true, false)

	reproducir_animacion_segura("idle")

func _on_body_entered(body):
	if body.is_in_group("player"):
		jugador_cerca = body

func _on_body_exited(body):
	if body == jugador_cerca:
		jugador_cerca = null

func _input(event):
	if jugador_cerca and not ya_interactuo:
		if event.is_action_pressed("salto") or event.is_action_pressed("ui_accept"):
			get_viewport().set_input_as_handled()
			ejecutar_interaccion()

func ejecutar_interaccion():
	ya_interactuo = true
	var idioma = ProgresoJuego.idioma if "idioma" in ProgresoJuego else "es"
	
	var frases_npc = dialogos.get(tipo_npc, {})
	var arreglo_raw = frases_npc.get(idioma, frases_npc.get("es", ["..."]))
	
	if ya_hablo_una_vez and arreglo_raw.size() > 0:
		arreglo_raw = [arreglo_raw[arreglo_raw.size() - 1]]
	
	var lista_frases: Array[String] = []
	for frase in arreglo_raw:
		lista_frases.append(str(frase))
	
	# MANEJO DE ANIMACIONES
	match tipo_npc:
		TipoNPC.MAX, TipoNPC.CHOSMIX, TipoNPC.BATZ:
			reproducir_animacion_segura("eat")
				
		TipoNPC.MICHAEL:
			if not ya_hablo_una_vez and sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation("middle"):
				sprite.play("middle")
				if not sprite.animation_finished.is_connected(_on_michael_middle_finished):
					sprite.animation_finished.connect(_on_michael_middle_finished, CONNECT_ONE_SHOT)
			else:
				reproducir_animacion_segura("smoking")

		TipoNPC.JANE, TipoNPC.BREAD:
			reproducir_animacion_segura("idle")
				
		TipoNPC.NUBBE:
			if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation("no"):
				# Desconectamos si había alguna conexión previa para limpiar
				if sprite.animation_finished.is_connected(_on_nubbe_no_finished):
					sprite.animation_finished.disconnect(_on_nubbe_no_finished)
				
				# Conectamos para que detecte cuándo termina "no"
				sprite.animation_finished.connect(_on_nubbe_no_finished, CONNECT_ONE_SHOT)
				sprite.play("no")
			else:
				reproducir_animacion_segura("idle")

	# MOSTRAR EL DIÁLOGO
	if ui_dialogo:
		if ui_dialogo.has_method("mostrar_dialogo"):
			ui_dialogo.mostrar_dialogo(lista_frases)
		elif ui_dialogo.has_method("iniciar_charla_directa"):
			ui_dialogo.iniciar_charla_directa(lista_frases)
		elif ui_dialogo.has_method("iniciar_charla"):
			ui_dialogo.iniciar_charla(lista_frases)
		
		if ui_dialogo.has_signal("terminado"):
			if not ui_dialogo.terminado.is_connected(_on_dialogo_terminado):
				ui_dialogo.terminado.connect(_on_dialogo_terminado, CONNECT_ONE_SHOT)
	else:
		ya_interactuo = false

func _on_michael_middle_finished():
	reproducir_animacion_segura("smoking")

func _on_nubbe_no_finished():
	# APENAS TERMINA LA ANIMACIÓN "NO", VUELVE A IDLE
	reproducir_animacion_segura("idle")

func _on_dialogo_terminado():
	ya_interactuo = false
	ya_hablo_una_vez = true

func reproducir_animacion_segura(anim_nombre: String):
	if sprite and sprite.sprite_frames:
		if sprite.sprite_frames.has_animation(anim_nombre):
			sprite.play(anim_nombre)
			
			
# Agregar dentro de NPCInteractuable.gd

func caminar_hacia_destino(destino_final: Vector3, punto_puerta: Vector3, callback_al_llegar: Callable):
	reproducir_animacion_segura("walk")
	var tween = create_tween()
	
	var sprite_node = find_child("AnimatedSprite3D", true, false)
	if not sprite_node:
		sprite_node = find_child("Sprite3D", true, false)

	# Detectar si es Max o Batz por el nombre del nodo (en minúsculas)
	var nombre_lower = name.to_lower()
	var es_max = "max" in nombre_lower
	var es_batz = "batz" in nombre_lower

	# Tamaño para Max (Cámbialo a tu gusto: 0.6, 0.7, 0.8, etc.)
	if es_max:
		scale = Vector3(0.06, 0.06, 0.06)

	# Función para orientar la mirada sin hacer Moonwalk
	var orientar_npc = func(target: Vector3):
		if sprite_node and "flip_h" in sprite_node:
			var va_hacia_izquierda = (target.x < global_position.x)
			
			# Si es Max o Batz, invertimos la lógica para que caminen de frente
			if es_max or es_batz:
				sprite_node.flip_h = not va_hacia_izquierda
			else:
				sprite_node.flip_h = va_hacia_izquierda

	if punto_puerta != Vector3.ZERO:
		orientar_npc.call(punto_puerta)
		var tiempo1 = global_position.distance_to(punto_puerta) / 3.0
		tween.tween_property(self, "global_position", punto_puerta, tiempo1)
		
		tween.tween_callback(func(): orientar_npc.call(destino_final))
		
		var tiempo2 = punto_puerta.distance_to(destino_final) / 3.0
		tween.tween_property(self, "global_position", destino_final, tiempo2)
	else:
		orientar_npc.call(destino_final)
		var tiempo = global_position.distance_to(destino_final) / 3.0
		tween.tween_property(self, "global_position", destino_final, tiempo)
		
	tween.tween_callback(func(): callback_al_llegar.call(self))
