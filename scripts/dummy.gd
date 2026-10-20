extends CharacterBody3D

# --- NUEVA SEÑAL PARA EL TUTORIAL ---
signal recibio_golpe

var prefix = ""
@onready var sprite = $AnimatedSprite3D

func _ready():
	add_to_group("enemies")
	intentar_identificar_jugador()

func intentar_identificar_jugador():
	var jugador = get_tree().get_first_node_in_group("player")
	
	# Si no hay jugador, esperamos un poco más
	if jugador == null:
		await get_tree().create_timer(0.5).timeout
		intentar_identificar_jugador()
		return

	# Sacamos el nombre del personaje (priorizando la variable character_name)
	var c_name = ""
	if "character_name" in jugador:
		c_name = jugador.character_name.to_lower()
	else:
		c_name = jugador.name.to_lower()

	# --- LÓGICA DE SELECCIÓN DE PREFIJO ---
	if "max" in c_name:
		prefix = "dummy2_"
	elif "sketch" in c_name:
		prefix = "dummy1_"
	elif "nubbe" in c_name:
		prefix = "luci_"  # Nubbe usa el dummy de Luci/Nubbe
	else:
		# ESTE ES EL DEFAULT (JANE)
		prefix = "dummy1_" # O el que sea el dummy por defecto de Jane
	
	print("Dummy identificado para: ", c_name, " usando prefijo: ", prefix)
	
	if sprite.sprite_frames.has_animation(prefix + "idle"):
		sprite.play(prefix + "idle")
	else:
		# Si falla el prefijo, intentamos el idle básico por si acaso
		sprite.play("idle") 

func take_damage(_amount, _source_pos = Vector3.ZERO):
	# Si por algún motivo el prefix falló, le damos uno por defecto para que no ignore el golpe
	if prefix == "": prefix = "dummy1_"
	
	# --- EMITIR SEÑAL PARA EL INSTRUCTOR ---
	emit_signal("recibio_golpe")
	
	var anim_hurt = prefix + "hurt1" 
	
	# Variaciones de daño para Sketch
	if prefix == "dummy1_":
		var random_hurt = randi_range(1, 3)
		anim_hurt = prefix + "hurt" + str(random_hurt)
	
	# Ejecutar animación de daño
	if sprite.sprite_frames.has_animation(anim_hurt):
		sprite.play(anim_hurt)
	else:
		# Fallback por si no existe la anim con prefijo
		if sprite.sprite_frames.has_animation("hurt"):
			sprite.play("hurt")

	# Efecto visual de brillo (Flash blanco)
	var tween = create_tween()
	sprite.modulate = Color(8, 8, 8)
	tween.tween_property(sprite, "modulate", Color(1, 1, 1), 0.1)

	# Conectar señal para volver al idle
	if not sprite.animation_finished.is_connected(_on_animation_finished):
		sprite.animation_finished.connect(_on_animation_finished)

func _on_animation_finished():
	# Siempre intentamos volver al idle del prefijo actual
	var anim_idle = prefix + "idle"
	if sprite.sprite_frames.has_animation(anim_idle):
		sprite.play(anim_idle)
	else:
		sprite.play("idle")

func _physics_process(_delta):
	pass
