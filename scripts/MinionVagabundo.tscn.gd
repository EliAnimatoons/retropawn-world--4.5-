extends CharacterBody3D

# --- ESTADOS DEL VAGABUNDO ---
var health = 50
var esta_muerto = false
var is_singing = false
var is_sitting = true
var esta_haciendo_intro = false

@onready var sprite = $AnimatedSprite3D
@onready var audio_canto = $AudioCanto

func _ready():
	add_to_group("enemies") 
	sentarse()

func _physics_process(delta):
	if esta_muerto:
		return
		
	if not is_on_floor():
		velocity.y -= 18.0 * delta
	else:
		velocity.y = -0.1
		
	velocity.x = 0
	velocity.z = 0
	
	move_and_slide()

# ==========================================
# LÓGICA DE ESTADOS
# ==========================================

func sentarse():
	if esta_muerto: return
	is_sitting = true
	is_singing = false
	esta_haciendo_intro = false
	
	sprite.play("idle")
	print("[VAGABUNDO] Quieto en idle.")

func empezar_a_cantar():
	if esta_muerto: return
	is_sitting = false
	esta_haciendo_intro = true
	
	# 1. Arranca el audio al instante
	audio_canto.play()
	print("[VAGABUNDO] ¡Primer golpe! Empieza la intro...")
	
	# 2. Reproduce la intro
	if sprite.sprite_frames.has_animation("intro"):
		sprite.play("intro")
		
		# Calculamos el tiempo exacto que dura la intro usando los frames y los FPS configurados
		var fps = sprite.sprite_frames.get_animation_speed("intro")
		var frames = sprite.sprite_frames.get_frame_count("intro")
		var duracion_intro = 0.5 # por defecto
		
		if fps > 0 and frames > 0:
			duracion_intro = float(frames) / float(fps)
			
		# Esperamos de forma segura el tiempo exacto que dura la intro
		await get_tree().create_timer(duracion_intro).timeout
	else:
		# Si no hay intro, pasa directo
		await get_tree().create_timer(0.3).timeout
	
	# Si lo mataron o interrumpieron durante la intro, cortamos acá
	if esta_muerto or not is_inside_tree() or is_sitting: return
	
	# 3. Pasa al bucle de singing
	pasar_a_singing_bucle()

func pasar_a_singing_bucle():
	if esta_muerto or not is_inside_tree(): return
	
	esta_haciendo_intro = false
	is_singing = true
	
	if sprite.sprite_frames.has_animation("minion singing"):
		sprite.play("minion singing")
		print("[VAGABUNDO] ¡Cambiado a minion singing en bucle!")
	else:
		print("[ADVERTENCIA] No se encontró la animación 'minion singing'.")
	
	# Calculamos cuánto le queda al audio para terminar
	var duracion_restante = 4.5
	if audio_canto.stream != null:
		var posicion_actual = audio_canto.get_playback_position()
		duracion_restante = audio_canto.stream.get_length() - posicion_actual
		if duracion_restante < 0.1: duracion_restante = 4.5
		
	await get_tree().create_timer(duracion_restante).timeout
	
	if not esta_muerto and is_singing:
		print("[VAGABUNDO] Terminó la canción completa, volviendo a idle.")
		audio_canto.stop()
		sentarse()

# ==========================================
# INTERACCIÓN CON EL JUGADOR
# ==========================================

func take_damage(amount, source_pos):
	if esta_muerto: return
	
	if is_sitting:
		empezar_a_cantar()
		
	elif is_singing or esta_haciendo_intro:
		print("[VAGABUNDO] ¡Interrumpido por un golpe! Corta audio y se sienta.")
		audio_canto.stop()
		is_singing = false
		esta_haciendo_intro = false
		
		health -= amount
		
		if health <= 0:
			morir()
		else:
			if sprite.sprite_frames.has_animation("hurt"):
				sprite.play("hurt")
				await get_tree().create_timer(0.4).timeout
			
			if not esta_muerto:
				sentarse()

func morir():
	if esta_muerto: return
	esta_muerto = true
	is_singing = false
	is_sitting = false
	esta_haciendo_intro = false
	audio_canto.stop()
	
	print("[VAGABUNDO] Abatido.")
	
	if sprite.sprite_frames.has_animation("die"):
		sprite.play("die")
	elif sprite.sprite_frames.has_animation("hurt"):
		sprite.play("hurt")
		
	await get_tree().create_timer(1.2).timeout
	queue_free()
