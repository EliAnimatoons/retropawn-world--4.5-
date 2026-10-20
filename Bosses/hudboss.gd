extends CanvasLayer

@onready var barra_jugador: Range = %ProgressBarJugador
@onready var retrato_jugador: AnimatedSprite2D = %SpriteJugador

@onready var barra_jefe: Range = %BarraVidaBoss
@onready var retrato_jefe: AnimatedSprite2D = %SpriteJefe

var jefe_en_fase_2: bool = false

func _ready():
	call_deferred("_conectar_entidades")

func _conectar_entidades():
	# CORRECCIÓN 1: Buscar "player2d" primero (combate 2D), si no existe cae a "player" (3D)
	var jugador = get_tree().get_first_node_in_group("player2d")
	if not is_instance_valid(jugador):
		jugador = get_tree().get_first_node_in_group("player")
		
	var jefe = get_tree().get_first_node_in_group("boss")
	
	if is_instance_valid(jugador):
		if jugador.has_signal("vida_cambiada"):
			# Asegurar que no esté conectada previamente para evitar duplicados
			if not jugador.vida_cambiada.is_connected(_on_jugador_vida_cambiada):
				jugador.vida_cambiada.connect(_on_jugador_vida_cambiada)
		
		# Forzamos actualización inicial leyendo health/max_health o sus equivalentes
		var hp_actual = jugador.get("health") if "health" in jugador else 100.0
		var hp_max = jugador.get("max_health") if "max_health" in jugador else 100.0
		_on_jugador_vida_cambiada(hp_actual, hp_max)
		
	if is_instance_valid(jefe):
		if jefe.has_signal("vida_cambiada"):
			if not jefe.vida_cambiada.is_connected(_on_jefe_vida_cambiada):
				jefe.vida_cambiada.connect(_on_jefe_vida_cambiada)
		if jefe.has_signal("transicion_fase2_iniciada"):
			if not jefe.transicion_fase2_iniciada.is_connected(_on_jefe_transicion_fase2):
				jefe.transicion_fase2_iniciada.connect(_on_jefe_transicion_fase2)
				
		var hp_jefe_actual = jefe.get("health") if "health" in jefe else 100.0
		var hp_jefe_max = jefe.get("max_health") if "max_health" in jefe else 100.0
		_on_jefe_vida_cambiada(hp_jefe_actual, hp_jefe_max)

# --- JUGADOR HUD ---
func _on_jugador_vida_cambiada(nueva_vida: float, vida_maxima: float):
	if is_instance_valid(barra_jugador):
		barra_jugador.max_value = vida_maxima
		barra_jugador.value = nueva_vida
		
	if is_instance_valid(retrato_jugador) and retrato_jugador.sprite_frames:
		if vida_maxima > 0:
			var porcentaje = nueva_vida / vida_maxima
			if porcentaje <= 0.35:
				_play_anim_si_existe(retrato_jugador, "hurt")
			else:
				_play_anim_si_existe(retrato_jugador, "idle")

# --- JEFE HUD ---
func _on_jefe_vida_cambiada(nueva_vida: float, vida_maxima: float):
	if is_instance_valid(barra_jefe):
		barra_jefe.max_value = vida_maxima
		barra_jefe.value = nueva_vida

	if is_instance_valid(retrato_jefe) and retrato_jefe.sprite_frames:
		if jefe_en_fase_2:
			_reproducir_hurt_jefe("hurt phase 2", "idle phase 2")
		else:
			_reproducir_hurt_jefe("hurt", "idle")

func _reproducir_hurt_jefe(anim_hurt: String, anim_idle: String):
	if retrato_jefe.sprite_frames.has_animation(anim_hurt):
		retrato_jefe.play(anim_hurt)
		if not retrato_jefe.animation_finished.is_connected(_volver_a_idle_jefe):
			retrato_jefe.animation_finished.connect(_volver_a_idle_jefe, CONNECT_ONE_SHOT)
	else:
		_play_anim_si_existe(retrato_jefe, anim_idle)

func _volver_a_idle_jefe():
	var anim_idle = "idle phase 2" if jefe_en_fase_2 else "idle"
	_play_anim_si_existe(retrato_jefe, anim_idle)

func _on_jefe_transicion_fase2():
	jefe_en_fase_2 = true
	if is_instance_valid(retrato_jefe) and retrato_jefe.sprite_frames:
		if retrato_jefe.sprite_frames.has_animation("intro phase 2"):
			retrato_jefe.play("intro phase 2")
			await retrato_jefe.animation_finished
		_play_anim_si_existe(retrato_jefe, "idle phase 2")

func _play_anim_si_existe(sprite: AnimatedSprite2D, anim_name: String):
	if is_instance_valid(sprite) and sprite.sprite_frames and sprite.sprite_frames.has_animation(anim_name):
		sprite.play(anim_name)
