extends CharacterBody2D
class_name NullStyleBoss

enum Estado { INTRO, IDLE, ATAQUE_DISPARO, ATAQUE_SUCCION, ATAQUE_EMBESTIDA, ATAQUE_PINCHOS, HERIDO, TRANSICION_FASE2, MUERTO }
var estado_actual = Estado.INTRO

@export_category("Texturas de Pinchos Personales")
@export var textura_pincho_suelo: Texture2D
@export var textura_pincho_caida: Texture2D
@export var textura_pincho_radial: Texture2D
@export var textura_bala: Texture2D

@export_category("Configuración y Debug")
@export var max_health: float = 500.0
var health: float = 500.0
@export var probar_fase_2_al_inicio: bool = false

@export_category("Daño y Combate")
@export var velocidad_embestida: float = 550.0
@export var velocidad_succion: float = 140.0
@export var dano_embestida: float = 25.0
@export var dano_contacto_succion: float = 35.0
@export var dano_contacto_cuerpo: float = 15.0
@export var rango_contacto_cuerpo: float = 75.0
@export var cooldown_dano_contacto: float = 0.5

@export var accion_parry: StringName = &"parry"

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var timer_cooldown: Timer = $TimerCooldown

@export var skill_check: SkillCheckCircular

var jugador: Node2D = null
var posicion_inicial: Vector2 = Vector2.ZERO
var skill_check_activo: bool = false
var tiempo_ultimo_contacto: float = 0.0
var en_fase_2: bool = false

signal vida_cambiada(nueva_vida: float, vida_maxima: float)
signal transicion_fase2_iniciada

func _ready():
	add_to_group("boss")
	health = max_health
	posicion_inicial = global_position
	emit_signal("vida_cambiada", health, max_health)
	
	if not is_instance_valid(skill_check):
		skill_check = get_node_or_null("../SkillCheckContainer") as SkillCheckCircular
		if not is_instance_valid(skill_check):
			skill_check = get_node_or_null("CanvasLayer/SkillCheckContainer") as SkillCheckCircular
	
	if is_instance_valid(skill_check):
		if not skill_check.skill_check_completado.is_connected(_on_skill_check_terminado):
			skill_check.skill_check_completado.connect(_on_skill_check_terminado)
		skill_check.visible = false
		
	call_deferred("_iniciar_combate_con_intro")

func _unhandled_input(event: InputEvent):
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F2:
			print("DEBUG: Forzando Fase 2...")
			if not en_fase_2:
				en_fase_2 = true
				estado_actual = Estado.TRANSICION_FASE2
				call_deferred("_ejecutar_transicion_fase_2")

func _iniciar_combate_con_intro():
	jugador = get_tree().get_first_node_in_group("player2d")
	var camara = get_tree().get_first_node_in_group("camera") as CamaraBatalla
	
	if probar_fase_2_al_inicio:
		en_fase_2 = true
		health = max_health * 0.5
		emit_signal("vida_cambiada", health, max_health)
		_volver_a_idle(true)
		return

	if is_instance_valid(camara) and is_instance_valid(jugador):
		_reproducir_animacion_boss(["intro", "succion_inicio", "idle"])
		if "puede_moverse" in jugador:
			jugador.puede_moverse = false
			
		camara.reproducir_cinematica_intro(global_position, jugador.global_position, func():
			if "puede_moverse" in jugador:
				jugador.puede_moverse = true
			_volver_a_idle(true)
		)
	else:
		_volver_a_idle(true)

func _physics_process(delta):
	if estado_actual == Estado.INTRO or estado_actual == Estado.TRANSICION_FASE2 or estado_actual == Estado.MUERTO:
		return
		
	if not is_instance_valid(jugador):
		jugador = get_tree().get_first_node_in_group("player")
		return

	tiempo_ultimo_contacto += delta
	_verificar_dano_contacto_cuerpo()

	match estado_actual:
		Estado.IDLE:
			_orientar_hacia(jugador.global_position)
			
		Estado.ATAQUE_SUCCION:
			if skill_check_activo and is_instance_valid(jugador):
				jugador.global_position = jugador.global_position.move_toward(global_position, velocidad_succion * delta)
				_forzar_animacion_jugador("grabbed_struggle")
				
				if global_position.distance_to(jugador.global_position) < 50.0:
					skill_check_fallo()

func _verificar_dano_contacto_cuerpo():
	if estado_actual == Estado.ATAQUE_SUCCION: return
	if tiempo_ultimo_contacto < cooldown_dano_contacto: return
	
	if is_instance_valid(jugador):
		var distancia = global_position.distance_to(jugador.global_position)
		if distancia <= rango_contacto_cuerpo:
			tiempo_ultimo_contacto = 0.0
			if jugador.has_method("recibir_dano"):
				jugador.recibir_dano(dano_contacto_cuerpo)
				
			EfectosManager.impact_effect(0.25, 0.04, Vector3(global_position.x, global_position.y, 0), 1)
			
			var camara = get_tree().get_first_node_in_group("camera") as CamaraBatalla
			if is_instance_valid(camara):
				camara.aplicar_golpe_shake(10.0)

# --- ATAQUE DISPARO ---
func ejec_ataque_disparo():
	estado_actual = Estado.ATAQUE_DISPARO
	_reproducir_animacion_boss(["disparo", "idle"])
	
	var cantidad_balas = 3 if en_fase_2 else 1
	var permitir_camara = not en_fase_2
	
	for i in range(cantidad_balas):
		if not is_instance_valid(jugador) or estado_actual == Estado.MUERTO: break
		
		EfectosManager.play_sound("Shoot sound", Vector3(global_position.x, global_position.y, 0), true)
		
		var bala = BalaTeledirigida.new()
		bala.textura_custom = textura_bala
		bala.global_position = global_position
		bala.objetivo = jugador
		bala.jefe_dueno = self
		bala.permitir_camara = permitir_camara
		if en_fase_2:
			bala.velocidad *= 1.2
		get_parent().add_child(bala)
		
		if en_fase_2:
			await get_tree().create_timer(0.25).timeout
	
	await get_tree().create_timer(0.6 if en_fase_2 else 0.8).timeout
	_volver_a_idle()

# --- ATAQUE DE PINCHOS ---
func ejec_ataque_pinchos():
	estado_actual = Estado.ATAQUE_PINCHOS
	_reproducir_animacion_boss(["pinchos", "golpe", "intro_fase_2", "idle"])
	
	EfectosManager.play_sound("power", Vector3(global_position.x, global_position.y, 0), true, 1.2)
	
	await lanzar_pinchos_suelo_en_ola()
	
	if en_fase_2:
		await get_tree().create_timer(0.2).timeout
		lanzar_lluvia_pinchos_techo()
		
	await get_tree().create_timer(0.8).timeout
	_volver_a_idle()

func lanzar_pinchos_suelo_en_ola():
	if not is_instance_valid(jugador): return
	
	var pos_y_suelo = jugador.global_position.y
	
	var limite_izq: float = -400.0
	var limite_der: float = 800.0
	var ancho_pincho: float = 64.0
	
	var columnas_totales = int((limite_der - limite_izq) / ancho_pincho)
	var columna_segura = randi() % (columnas_totales - 1)
	
	for i in range(columnas_totales):
		if estado_actual == Estado.MUERTO: break
		
		if i == columna_segura or i == columna_segura + 1:
			continue
			
		var spawn_x = limite_izq + (i * ancho_pincho)
		
		var trampa = PinchoSuelo.new()
		trampa.textura_custom = textura_pincho_suelo
		trampa.global_position = Vector2(spawn_x, pos_y_suelo)
		get_parent().add_child(trampa)

func lanzar_lluvia_pinchos_techo():
	if not is_instance_valid(jugador): return
	
	var cantidad = 5
	var centro_x = jugador.global_position.x
	var altura_techo = jugador.global_position.y - 380.0
	
	for i in range(cantidad):
		if estado_actual == Estado.MUERTO: break
		
		var offset_x = (i - (cantidad / 2)) * 75.0
		var pos_spawn = Vector2(centro_x + offset_x, altura_techo)
		
		var pincho = PinchoCaida.new()
		pincho.textura_custom = textura_pincho_caida
		pincho.global_position = pos_spawn
		pincho.dano = 18.0
		get_parent().add_child(pincho)
		
		await get_tree().create_timer(0.1).timeout

func lanzar_rafaga_pinchos(cantidad: int = 16):
	var paso_angulo = TAU / cantidad
	for i in range(cantidad):
		var angulo = i * paso_angulo
		var pincho = PinchoRadial.new()
		pincho.textura_custom = textura_pincho_radial
		pincho.global_position = global_position
		pincho.direccion = Vector2.RIGHT.rotated(angulo)
		get_parent().add_child(pincho)

# --- ATAQUE EMBESTIDA ---
func ejec_ataque_embestida():
	estado_actual = Estado.ATAQUE_EMBESTIDA
	var repeticiones = 2 if en_fase_2 else 1
	
	for i in range(repeticiones):
		if not is_instance_valid(jugador): break
		var pos_objetivo = jugador.global_position
		
		_reproducir_animacion_boss(["correr", "idle"])
		_orientar_hacia(pos_objetivo)
		
		var duracion = 0.35 if en_fase_2 else 0.45
		var tw_ida = create_tween()
		tw_ida.tween_property(self, "global_position", pos_objetivo, duracion).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		await tw_ida.finished
		
		_reproducir_animacion_boss(["golpe", "idle"])
		await get_tree().create_timer(0.12).timeout
		
		if is_instance_valid(jugador) and global_position.distance_to(jugador.global_position) < 110.0:
			if jugador.has_method("recibir_dano"):
				jugador.recibir_dano(dano_embestida)
			
			EfectosManager.impact_effect(0.4, 0.07, Vector3(global_position.x, global_position.y, 0), 2)
			
			var camara = get_tree().get_first_node_in_group("camera") as CamaraBatalla
			if is_instance_valid(camara):
				camara.aplicar_golpe_shake(18.0)
				camara.disparar_impact_frame(0.06)
				camara.aplicar_hitstop(0.07)

		await get_tree().create_timer(0.15).timeout

	_orientar_hacia(posicion_inicial)
	var tw_vuelta = create_tween()
	tw_vuelta.tween_property(self, "global_position", posicion_inicial, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tw_vuelta.finished
	
	_volver_a_idle()

# --- ATAQUE SUCCIÓN ---
func ejec_ataque_succion():
	estado_actual = Estado.ATAQUE_SUCCION
	_reproducir_animacion_boss(["succion_inicio", "idle"])
	EfectosManager.play_sound("power", Vector3(global_position.x, global_position.y, 0), true, 1.0)
		
	if is_instance_valid(jugador):
		if "siendo_agarrado" in jugador: jugador.siendo_agarrado = true
		if "puede_moverse" in jugador: jugador.puede_moverse = false
		_forzar_animacion_jugador("grabbed_struggle")

	var camara = get_tree().get_first_node_in_group("camera") as CamaraBatalla
	if is_instance_valid(camara):
		camara.iniciar_zoom_agarre()

	var accion = String(accion_parry)
	if is_instance_valid(jugador) and "sufijo_control" in jugador:
		accion += String(jugador.sufijo_control)

	if is_instance_valid(skill_check):
		skill_check_activo = true
		skill_check.iniciar_skill_check(accion)
	else:
		_volver_a_idle()

func _on_skill_check_terminado(exito: bool):
	if exito: skill_check_exito(false)
	else: skill_check_fallo()

func skill_check_exito(perfecto: bool = false):
	EfectosManager.play_sound("Brokenshield", Vector3(global_position.x, global_position.y, 0), true)
	var camara = get_tree().get_first_node_in_group("camera") as CamaraBatalla
	if is_instance_valid(camara):
		camara.aplicar_golpe_shake(20.0 if perfecto else 12.0)
		camara.disparar_impact_frame(0.08)
		camara.aplicar_hitstop(0.07)
	soltar_jugador()

func skill_check_fallo():
	if not skill_check_activo: return
	if is_instance_valid(jugador) and jugador.has_method("recibir_dano"):
		jugador.recibir_dano(dano_contacto_succion)
		
	EfectosManager.impact_effect(0.5, 0.08, Vector3(global_position.x, global_position.y, 0), 3)
	
	var camara = get_tree().get_first_node_in_group("camera") as CamaraBatalla
	if is_instance_valid(camara):
		camara.aplicar_golpe_shake(18.0)
		camara.disparar_impact_frame(0.1)
		camara.aplicar_hitstop(0.08)
		
	soltar_jugador()

func soltar_jugador():
	skill_check_activo = false
	if is_instance_valid(skill_check): skill_check.visible = false
	
	var camara = get_tree().get_first_node_in_group("camera") as CamaraBatalla
	if is_instance_valid(camara): camara.detener_zoom_agarre()
	
	if is_instance_valid(jugador):
		if "siendo_agarrado" in jugador: jugador.siendo_agarrado = false
		if "puede_moverse" in jugador: jugador.puede_moverse = true
		
	_reproducir_animacion_boss(["succion_fin", "idle"])
	await get_tree().create_timer(0.3).timeout
	_volver_a_idle()

func _forzar_animacion_jugador(nombre_anim: String):
	if not is_instance_valid(jugador): return
	if jugador.has_method("play_anim"): jugador.play_anim(nombre_anim)
	elif jugador.has_method("reproducir_animacion"): jugador.reproducir_animacion(nombre_anim)
	else:
		var sprite_jugador = jugador.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
		if is_instance_valid(sprite_jugador) and sprite_jugador.sprite_frames and sprite_jugador.sprite_frames.has_animation(nombre_anim):
			sprite_jugador.play(nombre_anim)

func _elegir_siguiente_ataque():
	if estado_actual != Estado.IDLE or not is_instance_valid(jugador): return
		
	var opc_max = 4 if en_fase_2 else 3
	var eleccion = randi() % opc_max
	
	match eleccion:
		0: ejec_ataque_disparo()
		1: ejec_ataque_succion()
		2: ejec_ataque_embestida()
		3: ejec_ataque_pinchos()

func _volver_a_idle(forzar: bool = false):
	if estado_actual == Estado.MUERTO: return
	
	if estado_actual == Estado.TRANSICION_FASE2 and not forzar: return
	
	estado_actual = Estado.IDLE
	
	var anim_idle = "idle_fase_2" if (en_fase_2 and sprite.sprite_frames.has_animation("idle_fase_2")) else "idle"
	if sprite.sprite_frames.has_animation(anim_idle):
		sprite.play(anim_idle)
		
	if timer_cooldown:
		if not timer_cooldown.timeout.is_connected(_elegir_siguiente_ataque):
			timer_cooldown.timeout.connect(_elegir_siguiente_ataque)
		timer_cooldown.start(randf_range(1.0, 1.8) if en_fase_2 else randf_range(2.0, 3.2))

func _orientar_hacia(destino: Vector2):
	sprite.flip_h = destino.x > global_position.x

func recibir_dano(cantidad: float):
	if estado_actual == Estado.MUERTO or estado_actual == Estado.TRANSICION_FASE2: return
	
	health = max(0.0, health - cantidad)
	emit_signal("vida_cambiada", health, max_health)
	
	EfectosManager.play_sound("hurt", Vector3(global_position.x, global_position.y, 0), true)
	
	var camara = get_tree().get_first_node_in_group("camera") as CamaraBatalla
	if is_instance_valid(camara):
		camara.aplicar_golpe_shake(12.0)
		camara.aplicar_hitstop(0.05)

	if not en_fase_2 and health <= (max_health * 0.5) and health > 0:
		en_fase_2 = true
		estado_actual = Estado.TRANSICION_FASE2
		call_deferred("_ejecutar_transicion_fase_2")
		return

	var anim_hurt = "hurt_fase_2" if (en_fase_2 and sprite.sprite_frames.has_animation("hurt_fase_2")) else "hurt"
	if estado_actual != Estado.ATAQUE_SUCCION and sprite.sprite_frames.has_animation(anim_hurt):
		estado_actual = Estado.HERIDO
		sprite.play(anim_hurt)
		
		var tw = create_tween()
		tw.tween_property(sprite, "modulate", Color.RED, 0.1)
		tw.tween_property(sprite, "modulate", Color.WHITE, 0.1)
		
		await sprite.animation_finished
		if health > 0 and estado_actual == Estado.HERIDO:
			_volver_a_idle()
	else:
		var tw = create_tween()
		tw.tween_property(sprite, "modulate", Color.RED, 0.1)
		tw.tween_property(sprite, "modulate", Color.WHITE, 0.1)

	if health <= 0:
		_morir()

func _ejecutar_transicion_fase_2():
	emit_signal("transicion_fase2_iniciada")
	
	if timer_cooldown: timer_cooldown.stop()
	
	EfectosManager.play_sound("prepucin super", Vector3(global_position.x, global_position.y, 0), false, 2.0)
	
	var camara = get_tree().get_first_node_in_group("camera") as CamaraBatalla
	if is_instance_valid(camara):
		camara.aplicar_golpe_shake(25.0)
		camara.disparar_impact_frame(0.1)
	
	lanzar_rafaga_pinchos(16)
	
	if sprite.sprite_frames.has_animation("intro_fase_2"):
		sprite.play("intro_fase_2")
		await sprite.animation_finished
	elif sprite.sprite_frames.has_animation("intro phase 2"):
		sprite.play("intro phase 2")
		await sprite.animation_finished
	else:
		await get_tree().create_timer(1.2).timeout
		
	velocidad_embestida *= 1.25
	velocidad_succion *= 1.2
	dano_embestida += 10.0
	
	_volver_a_idle(true)

# === NUEVA SECUENCIA DE MUERTE ===
func _morir():
	estado_actual = Estado.MUERTO
	
	if timer_cooldown:
		timer_cooldown.stop()
	
	# Reproducimos la animación "die" (o "muerte" como respaldo)
	if sprite.sprite_frames:
		if sprite.sprite_frames.has_animation("die"):
			sprite.play("die")
		elif sprite.sprite_frames.has_animation("muerte"):
			sprite.play("muerte")
	
	# Llamamos al nuevo método de la cámara para el zoom y fade a negro
	var camara = get_tree().get_first_node_in_group("camera") as CamaraBatalla
	if is_instance_valid(camara):
		camara.reproducir_animacion_muerte(global_position, Callable(self, "_on_fade_out_terminado"))
	else:
		# Fallback por si la cámara no está en la escena
		await get_tree().create_timer(2.0).timeout
		_on_fade_out_terminado()

func _on_fade_out_terminado():
	# Todo ya está oscuro. Ideal para disparar señales al GameManager, soltar loot o cambiar de escena.
	
	# MAGIA FINAL: Borramos toda la escena de Batalla2D (el padre de NullStyleBoss). 
	# Esto activa el "await" del nivel 3D y te devuelve a donde estabas parado.
	get_parent().queue_free()

func _reproducir_animacion_boss(nombres: Array):
	for nom in nombres:
		if sprite.sprite_frames and sprite.sprite_frames.has_animation(nom):
			sprite.play(nom)
			return

# =====================================================================
# --- CLASES Y PROYECTILES CON SOPORTE DE TEXTURAS ---
# =====================================================================
class PinchoSuelo extends Area2D:
	var dano: float = 20.0
	var activo: bool = false
	var sprite: Sprite2D
	var colision: CollisionShape2D
	var textura_custom: Texture2D = null

	func _ready():
		add_to_group("proyectil_enemigo")
		body_entered.connect(_on_body_entered)
		
		sprite = Sprite2D.new()
		if textura_custom:
			sprite.texture = textura_custom
		else:
			var img = Image.create(24, 65, false, Image.FORMAT_RGBA8)
			img.fill(Color.RED)
			sprite.texture = ImageTexture.create_from_image(img)
			
		sprite.offset = Vector2(0, -sprite.texture.get_height() / 2.0)
		sprite.scale = Vector2(1.0, 0.05)
		sprite.modulate = Color(1, 1, 1, 0.35)
		add_child(sprite)

		colision = CollisionShape2D.new()
		var shape = RectangleShape2D.new()
		shape.size = sprite.texture.get_size()
		colision.shape = shape
		colision.position = Vector2(0, -sprite.texture.get_height() / 2.0)
		
		colision.set_deferred("disabled", true)
		add_child(colision)
		
		_animar_brote()

	func _animar_brote():
		var tw_prep = create_tween()
		tw_prep.tween_property(sprite, "modulate:a", 0.8, 0.28)
		await tw_prep.finished
		
		EfectosManager.play_sound("impact", Vector3(global_position.x, global_position.y, 0), true, 1.2)
		
		colision.set_deferred("disabled", false)
		activo = true
		sprite.modulate = Color.WHITE
		
		var tw_brote = create_tween()
		tw_brote.tween_property(sprite, "scale:y", 1.0, 0.07).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		
		var cam = get_tree().get_first_node_in_group("camera") as CamaraBatalla
		if is_instance_valid(cam):
			cam.aplicar_golpe_shake(6.0)
			
		await tw_brote.finished
		
		await get_tree().create_timer(0.35).timeout
		
		colision.set_deferred("disabled", true)
		
		var tw_retract = create_tween()
		tw_retract.tween_property(sprite, "scale:y", 0.0, 0.12)
		await tw_retract.finished
		queue_free()

	func _on_body_entered(body: Node2D):
		if activo and body.is_in_group("player"):
			if body.has_method("recibir_dano"):
				body.recibir_dano(dano)

class PinchoCaida extends Area2D:
	var velocidad: float = 650.0
	var dano: float = 18.0
	var textura_custom: Texture2D = null

	func _ready():
		add_to_group("proyectil_enemigo")
		body_entered.connect(_on_body_entered)
		area_entered.connect(_on_area_entered)
		get_tree().create_timer(4.0).timeout.connect(queue_free)
		
		var sprite = Sprite2D.new()
		if textura_custom:
			sprite.texture = textura_custom
		else:
			var img = Image.create(16, 40, false, Image.FORMAT_RGBA8)
			img.fill(Color.DARK_RED)
			sprite.texture = ImageTexture.create_from_image(img)
		add_child(sprite)

		var colision = CollisionShape2D.new()
		var shape = RectangleShape2D.new()
		shape.size = sprite.texture.get_size()
		colision.shape = shape
		add_child(colision)

	func _process(delta: float):
		position.y += velocidad * delta

	func _on_body_entered(body: Node2D):
		if body.is_in_group("player2d"):
			if body.has_method("recibir_dano"):
				body.recibir_dano(dano)
			queue_free()
		elif not body.is_in_group("boss"):
			queue_free()

	func _on_area_entered(area: Area2D):
		if area.is_in_group("parry_shield"):
			queue_free()

class BalaTeledirigida extends Area2D:
	var objetivo: Node2D = null
	var jefe_dueno: Node2D = null
	var velocidad: float = 340.0
	var dano: float = 20.0
	var maniobrabilidad: float = 7.0
	var direccion: Vector2 = Vector2.RIGHT
	var parreada: bool = false
	var permitir_camara: bool = true
	var textura_custom: Texture2D = null

	func _ready():
		add_to_group("proyectil_enemigo")
		body_entered.connect(_on_body_entered)
		area_entered.connect(_on_area_entered)
		get_tree().create_timer(6.0).timeout.connect(queue_free)
		
		var sprite = Sprite2D.new()
		sprite.name = "SpriteBala"
		
		if textura_custom:
			sprite.texture = textura_custom
		else:
			var img = Image.create(12, 12, false, Image.FORMAT_RGBA8)
			img.fill(Color.PURPLE)
			sprite.texture = ImageTexture.create_from_image(img)
			
		add_child(sprite)

		var colision = CollisionShape2D.new()
		var shape = CircleShape2D.new()
		shape.radius = 8.0
		colision.shape = shape
		add_child(colision)

	func _process(delta: float):
		if is_instance_valid(objetivo):
			var dir_deseada = (objetivo.global_position - global_position).normalized()
			direccion = direccion.slerp(dir_deseada, maniobrabilidad * delta).normalized()
			
		position += direccion * velocidad * delta
		rotation = direccion.angle()

	func parrear():
		if parreada: return
		parreada = true
		objetivo = jefe_dueno
		velocidad *= 1.4
		dano *= 1.5
		
		EfectosManager.parry_success_effect(Vector3(global_position.x, global_position.y, 0))
		
		var jugador = get_tree().get_first_node_in_group("player")
		if is_instance_valid(jugador) and jugador.has_method("notificar_parry_exitoso"):
			jugador.notificar_parry_exitoso()

		var cam = get_tree().get_first_node_in_group("camera") as CamaraBatalla
		if is_instance_valid(cam):
			if permitir_camara:
				cam.iniciar_seguimiento_bala(self)
				
			cam.disparar_impact_frame(0.06)
			cam.aplicar_hitstop(0.05)
			cam.aplicar_golpe_shake(10.0)
		
		var sprite = get_node_or_null("SpriteBala") as Sprite2D
		if sprite:
			sprite.modulate = Color.YELLOW
			
		remove_from_group("proyectil_enemigo")
		add_to_group("proyectil_jugador")

	func _on_body_entered(body: Node2D):
		if not parreada:
			if body.is_in_group("player2d"):
				if body.has_method("esta_parreando") and body.esta_parreando():
					parrear()
					return
				if body.has_method("recibir_dano"):
					body.recibir_dano(dano)
				queue_free()
		else:
			if body.is_in_group("boss") or body == jefe_dueno:
				if body.has_method("recibir_dano"):
					body.recibir_dano(dano)
				
				var cam = get_tree().get_first_node_in_group("camera") as CamaraBatalla
				if is_instance_valid(cam):
					cam.aplicar_golpe_shake(22.0)
					cam.disparar_impact_frame(0.12)
					cam.aplicar_hitstop(0.08)
					if permitir_camara:
						cam.detener_seguimiento_bala()
				queue_free()

	func _on_area_entered(area: Area2D):
		if not parreada and area.is_in_group("parry_shield"):
			parrear()

class PinchoRadial extends Area2D:
	var velocidad: float = 420.0
	var dano: float = 15.0
	var direccion: Vector2 = Vector2.ZERO
	var textura_custom: Texture2D = null

	func _ready():
		add_to_group("proyectil_enemigo")
		body_entered.connect(_on_body_entered)
		area_entered.connect(_on_area_entered)
		get_tree().create_timer(4.0).timeout.connect(queue_free)
		
		var sprite = Sprite2D.new()
		if textura_custom:
			sprite.texture = textura_custom
		else:
			var img = Image.create(16, 8, false, Image.FORMAT_RGBA8)
			img.fill(Color.RED)
			sprite.texture = ImageTexture.create_from_image(img)
		add_child(sprite)

		var colision = CollisionShape2D.new()
		var shape = RectangleShape2D.new()
		shape.size = sprite.texture.get_size()
		colision.shape = shape
		add_child(colision)
		
		rotation = direccion.angle()

	func _process(delta: float):
		position += direccion * velocidad * delta

	func _on_body_entered(body: Node2D):
		if body.is_in_group("player2d"):
			if body.has_method("recibir_dano"):
				body.recibir_dano(dano)
			queue_free()

	func _on_area_entered(area: Area2D):
		if area.is_in_group("parry_shield"):
			queue_free()
			


func reiniciar_jefe():
	# 1. Restaurar vida y fases
	health = max_health
	en_fase_2 = probar_fase_2_al_inicio
	if en_fase_2:
		health = max_health * 0.5
		
	emit_signal("vida_cambiada", health, max_health)
	
	# 2. Reiniciar estados y habilidades
	estado_actual = Estado.IDLE
	skill_check_activo = false
	if is_instance_valid(skill_check):
		skill_check.visible = false
	
	# 3. Restaurar posición y color
	global_position = posicion_inicial
	sprite.modulate = Color.WHITE
	
	# 4. Destruir cualquier pincho o bala que haya quedado en pantalla
	var proyectiles = get_tree().get_nodes_in_group("proyectil_enemigo")
	for p in proyectiles:
		if is_instance_valid(p):
			p.queue_free()
			
	# 5. --- ¡NUEVO: SOLUCIÓN AL BUG DEL ZOOM! ---
	var camara = get_tree().get_first_node_in_group("camera")
	if is_instance_valid(camara):
		# Cancelamos cualquier zoom de agarre que haya quedado a medias
		if camara.has_method("detener_zoom_agarre"):
			camara.detener_zoom_agarre()
			
		# Por seguridad, forzamos el zoom a su valor por defecto (1, 1)
		if "zoom" in camara:
			camara.zoom = Vector2(1.0, 1.0)
			
	# 6. Volver al estado de espera
	_volver_a_idle(true)
