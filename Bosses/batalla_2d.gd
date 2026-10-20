extends Control

@onready var jefe = $NullStyleBoss
@onready var jugador = $JugadorFolder2D

# NODOS DESDE EL ÁRBOL
@onready var audio_rewind: AudioStreamPlayer = $rewind_sound 
@onready var audio_theme: AudioStreamPlayer = $theme 
@onready var sprite_rewind: AnimatedSprite2D = $HUD/watch 
@onready var pantalla_negra: ColorRect = $HUD/ControlRewind 

var muriendo: bool = false

func _ready() -> void:
	_resetear_estado_visual()

func _resetear_estado_visual() -> void:
	muriendo = false
	
	if is_instance_valid(sprite_rewind):
		sprite_rewind.visible = false
		sprite_rewind.scale = Vector2.ONE
		sprite_rewind.stop()
		
	if is_instance_valid(pantalla_negra):
		pantalla_negra.visible = false
		pantalla_negra.modulate.a = 0.0
		
	if is_instance_valid(audio_theme) and not audio_theme.playing:
		audio_theme.play()

func _process(_delta: float) -> void:
	if muriendo: 
		return
	
	if is_instance_valid(jugador):
		var hp_jugador: float = 100.0
		if "health" in jugador:
			hp_jugador = jugador.health
		elif "vida" in jugador:
			hp_jugador = jugador.vida
			
		if hp_jugador <= 0:
			muriendo = true
			_disparar_secuencia_rebobinar()

func _disparar_secuencia_rebobinar() -> void:
	if is_instance_valid(audio_theme):
		audio_theme.stop()

	if is_instance_valid(pantalla_negra):
		pantalla_negra.visible = true
		
	if is_instance_valid(sprite_rewind):
		sprite_rewind.visible = true
		sprite_rewind.play("rewind") 

	if is_instance_valid(audio_rewind):
		audio_rewind.play()

	var tw = create_tween().set_parallel(true)
	if is_instance_valid(pantalla_negra):
		tw.tween_property(pantalla_negra, "modulate:a", 1.0, 0.8)
	
	if is_instance_valid(sprite_rewind):
		tw.tween_property(sprite_rewind, "scale", Vector2(1.5, 1.5), 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	await tw.finished
	
	# FIX: Si el audio de rewind tiene Loop, "finished" nunca ocurre y traba el juego.
	# Usamos un temporizador de seguridad en su lugar para garantizar que reinicie.
	if is_instance_valid(audio_rewind) and audio_rewind.playing:
		await get_tree().create_timer(1.0).timeout 
		audio_rewind.stop()

	# 5. ¡REINICIAMOS SOLO LAS VARIABLES Y EL HUD!
	_reiniciar_batalla()

func _reiniciar_batalla() -> void:
	# 1. Restaurar al Jugador
	if is_instance_valid(jugador):
		if jugador.has_method("revivir"):
			jugador.revivir()
		else:
			# Reseteo manual por defecto:
			if "health" in jugador: jugador.health = 100
			elif "vida" in jugador: jugador.vida = 100
			
			# Opcional: Si el jugador se queda en animación de muerte, forzamos idle
			if jugador.has_method("play"):
				jugador.play("idle")

	# 2. Restaurar al Jefe
	if is_instance_valid(jefe):
		if jefe.has_method("reiniciar_jefe"):
			jefe.reiniciar_jefe()
		else:
			# Reseteo manual por defecto:
			if "health" in jefe: jefe.health = 100
			elif "vida" in jefe: jefe.vida = 100

	# 3. Ocultar la pantalla de muerte, el reloj y volver a poner la música
	_resetear_estado_visual()
