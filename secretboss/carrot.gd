extends CharacterBody2D
class_name BossZanahoria

enum Estado { INTRO, IDLE, DISPARO_1, DISPARO_2, REBOTE_DVD, CURACION, HERIDO, MUERTO }
var estado_actual = Estado.INTRO

@export_category("Configuración y Vida")
@export var max_health: float = 500.0
var health: float = 500.0
@export var cantidad_curacion: float = 35.0

@export_category("Proyectiles (Disparo 1 - Extremo)")
@export var sprite_frames_bala: SpriteFrames
@export var velocidad_bala_inicial: float = 480.0 # Más rápido
@export var velocidad_bala_acelerada: float = 850.0 # Velocidad tras redirección
@export var dano_bala: float = 15.0
@export var probabilidad_bala_dorada: float = 0.40 # 40% de que salgan amarillas
@export var cantidad_balas_punta: int = 7 # 7 balas para una Punta en V
@export var tiempo_reorientacion: float = 0.25 # Reacción en el aire
@export var escala_bala: Vector2 = Vector2(0.6, 0.6)
@export var offset_rotacion_bala_grados: float = 180.0

@export_category("Ataque Cielo (Disparo 2)")
@export var altura_cielo: float = 320.0
@export var ancho_patrulla_cielo: float = 350.0
@export var dano_rayo_cielo: float = 20.0

@export_category("Ataque Rebote DVD")
@export var velocidad_dvd: float = 650.0
@export var duracion_rebote_dvd: float = 5.0
@export var dano_contacto_dvd: float = 25.0
@export var cooldown_dano_contacto: float = 0.4

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var timer_cooldown: Timer = $TimerCooldown

var jugador: Node2D = null
var posicion_inicial: Vector2 = Vector2.ZERO

var vector_movimiento_dvd: Vector2 = Vector2.ZERO
var tiempo_ultimo_contacto: float = 0.0

signal vida_cambiada(nueva_vida: float, vida_maxima: float)

func _ready():
	add_to_group("boss")
	health = max_health
	posicion_inicial = global_position
	emit_signal("vida_cambiada", health, max_health)
	
	if timer_cooldown:
		timer_cooldown.timeout.connect(_elegir_siguiente_accion)
		
	call_deferred("_iniciar_combate_con_intro")

func _physics_process(delta: float):
	if estado_actual == Estado.INTRO or estado_actual == Estado.MUERTO:
		return
		
	tiempo_ultimo_contacto += delta
	
	if is_instance_valid(jugador) and estado_actual == Estado.IDLE:
		_orientar_hacia(jugador.global_position)

	# FÍSICA REBOTE DVD
	if estado_actual == Estado.REBOTE_DVD:
		var colision = move_and_collide(vector_movimiento_dvd * delta)
		if colision:
			vector_movimiento_dvd = vector_movimiento_dvd.bounce(colision.get_normal())
			rotation = vector_movimiento_dvd.angle()
			
			EfectosManager.play_sound("impact", Vector3(global_position.x, global_position.y, 0), true, 1.1)
			
			var cam = get_tree().get_first_node_in_group("camera") as CamaraBatalla
			if is_instance_valid(cam):
				cam.aplicar_golpe_shake(8.0)
				
		_verificar_dano_contacto_dvd()

# =====================================================================
# --- INTRO CINEMÁTICA ---
# =====================================================================
func _iniciar_combate_con_intro():
	estado_actual = Estado.INTRO
	jugador = get_tree().get_first_node_in_group("player")
	var camara = get_tree().get_first_node_in_group("camera") as CamaraBatalla
	
	_reproducir_animacion(["intro", "idle"])
	
	if is_instance_valid(jugador) and "puede_moverse" in jugador:
		jugador.puede_moverse = false
		
	if is_instance_valid(camara) and is_instance_valid(jugador) and camara.has_method("reproducir_cinematica_intro"):
		camara.reproducir_cinematica_intro(global_position, jugador.global_position, func():
			if is_instance_valid(jugador) and "puede_moverse" in jugador:
				jugador.puede_moverse = true
			_volver_a_idle()
		)
	else:
		if sprite.sprite_frames and sprite.sprite_frames.has_animation("intro"):
			sprite.play("intro")
			await sprite.animation_finished
		else:
			await get_tree().create_timer(1.2).timeout
			
		if is_instance_valid(jugador) and "puede_moverse" in jugador:
			jugador.puede_moverse = true
		_volver_a_idle()

# =====================================================================
# --- SELECTOR DE ATAQUES ---
# =====================================================================
func _elegir_siguiente_accion():
	if estado_actual != Estado.IDLE: return
	if not is_instance_valid(jugador):
		jugador = get_tree().get_first_node_in_group("player")
		return

	if health < (max_health * 0.75) and randf() < 0.20:
		ejec_curacion()
		return

	var eleccion = randi() % 3
	match eleccion:
		0: ejec_disparo_1()
		1: ejec_disparo_2_cielo()
		2: ejec_ataque_rebote_dvd()

func _volver_a_idle():
	if estado_actual == Estado.MUERTO: return
	estado_actual = Estado.IDLE
	rotation = 0.0
	
	if sprite.sprite_frames and sprite.sprite_frames.has_animation("idle"):
		sprite.play("idle")
		
	if timer_cooldown:
		timer_cooldown.start(randf_range(0.8, 1.5))

func _orientar_hacia(destino: Vector2):
	if sprite:
		sprite.flip_h = destino.x > global_position.x

# =====================================================================
# --- ATAQUE 1: PATRÓN DE DISPAROS EN PUNTA Y COBERTURA ---
# =====================================================================
func ejec_disparo_1():
	estado_actual = Estado.DISPARO_1
	_reproducir_animacion(["disparo_1", "disparo 1", "disparo", "idle"])
	
	if not is_instance_valid(jugador): return

	# 1. PUNTA DE FLECHA CENTRAL
	_orientar_hacia(jugador.global_position)
	EfectosManager.play_sound("Shoot sound", Vector3(global_position.x, global_position.y, 0), true)
	await _disparar_punta_de_flecha(jugador.global_position, cantidad_balas_punta, true)
	
	await get_tree().create_timer(0.45).timeout

	# 2. ABANICO CERRADOR A LAS BANDAS
	if estado_actual != Estado.MUERTO and is_instance_valid(jugador):
		_disparar_cobertura_lateral(jugador.global_position)
		EfectosManager.play_sound("Shoot sound", Vector3(global_position.x, global_position.y, 0), true, 1.2)

	await get_tree().create_timer(0.5).timeout

	# 3. ATAQUE EN PINZA
	if estado_actual != Estado.MUERTO and is_instance_valid(jugador):
		_orientar_hacia(jugador.global_position)
		var dir_jugador = (jugador.global_position - global_position).normalized()
		
		# Puntas simultáneas pero separadas
		_disparar_punta_de_flecha(global_position + dir_jugador.rotated(deg_to_rad(-25)) * 200, 5, true)
		_disparar_punta_de_flecha(global_position + dir_jugador.rotated(deg_to_rad(25)) * 200, 5, true)
		EfectosManager.play_sound("Shoot sound", Vector3(global_position.x, global_position.y, 0), true, 1.4)

	await get_tree().create_timer(0.6).timeout
	_volver_a_idle()

func _disparar_punta_de_flecha(destino: Vector2, cantidad: int, redireccionar: bool):
	var dir_principal = (destino - global_position).normalized()
	var centro_idx = cantidad / 2
	
	for i in range(cantidad):
		if estado_actual == Estado.MUERTO: break

		var offset_indice = abs(i - centro_idx)
		
		# AUMENTADO: Separación de posición adelantando la punta (110) y retrasando laterales (45)
		var offset_posicion = dir_principal * (110.0 - (offset_indice * 45.0))
		
		# AUMENTADO: Separación angular a 22 grados para que se abran en vez de amontonarse
		var angulo_offset = deg_to_rad((i - centro_idx) * 22.0)
		var dir_inicial = dir_principal.rotated(angulo_offset)
		
		var es_amarilla = (i == centro_idx) or (randf() < probabilidad_bala_dorada)
		
		var bala = BalaZanahoria.new()
		bala.global_position = global_position + offset_posicion
		bala.direccion = dir_inicial
		bala.velocidad = velocidad_bala_inicial
		bala.dano = dano_bala
		bala.es_amarilla_parry = es_amarilla
		bala.jefe_dueno = self
		bala.sprite_frames_custom = sprite_frames_bala
		bala.escala_custom = escala_bala
		bala.offset_rotacion_grados = offset_rotacion_bala_grados
		
		# Redirección
		bala.puede_redireccionar = redireccionar
		bala.tiempo_para_girar = tiempo_reorientacion + (offset_indice * 0.05)
		bala.velocidad_post_giro = velocidad_bala_acelerada
		
		get_parent().add_child(bala)
		
		# CLAVE: Pequeña espera de 0.04s entre bala y bala para evitar amontonamientos
		await get_tree().create_timer(0.04).timeout

func _disparar_cobertura_lateral(destino: Vector2):
	var dir_base = (destino - global_position).normalized()
	
	# Ángulos de cobertura más abiertos para no encimarse
	for angulo in [-55.0, -38.0, 38.0, 55.0]:
		var dir_curva = dir_base.rotated(deg_to_rad(angulo))
		
		var bala = BalaZanahoria.new()
		bala.global_position = global_position
		bala.direccion = dir_curva
		bala.velocidad = velocidad_bala_inicial * 1.15
		bala.dano = dano_bala
		bala.es_amarilla_parry = randf() < 0.3
		bala.jefe_dueno = self
		bala.sprite_frames_custom = sprite_frames_bala
		bala.escala_custom = escala_bala
		bala.offset_rotacion_grados = offset_rotacion_bala_grados
		bala.velocidad_curva = -angulo * 1.8
		
		get_parent().add_child(bala)

# =====================================================================
# --- ATAQUE 2: PATRULLA AÉREA CON RAYOS ---
# =====================================================================
func ejec_disparo_2_cielo():
	estado_actual = Estado.DISPARO_2
	
	var pos_techo = Vector2(global_position.x, posicion_inicial.y - altura_cielo)
	var tw_subida = create_tween()
	tw_subida.tween_property(self, "global_position", pos_techo, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tw_subida.finished
	
	_reproducir_animacion(["disparo_2", "disparo 2", "volar", "idle"])
	
	var pos_izq = Vector2(posicion_inicial.x - ancho_patrulla_cielo, pos_techo.y)
	var pos_der = Vector2(posicion_inicial.x + ancho_patrulla_cielo, pos_techo.y)
	
	var tw_patrulla1 = create_tween()
	tw_patrulla1.tween_property(self, "global_position", pos_izq, 0.7)
	
	for i in range(4):
		if estado_actual == Estado.MUERTO: break
		_disparar_rayo_caida()
		await get_tree().create_timer(0.18).timeout
		
	await tw_patrulla1.finished
	
	var tw_patrulla2 = create_tween()
	tw_patrulla2.tween_property(self, "global_position", pos_der, 1.2)
	
	for i in range(6):
		if estado_actual == Estado.MUERTO: break
		_disparar_rayo_caida()
		await get_tree().create_timer(0.18).timeout
		
	await tw_patrulla2.finished

	var tw_regreso = create_tween()
	tw_regreso.tween_property(self, "global_position", posicion_inicial, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tw_regreso.finished
	
	_volver_a_idle()

func _disparar_rayo_caida():
	EfectosManager.play_sound("power", Vector3(global_position.x, global_position.y, 0), true, 1.3)
	
	var rayo = RayoCielo.new()
	rayo.global_position = global_position
	rayo.dano = dano_rayo_cielo
	get_parent().add_child(rayo)

# =====================================================================
# --- ATAQUE 3: REBOTE DVD ---
# =====================================================================
func ejec_ataque_rebote_dvd():
	estado_actual = Estado.REBOTE_DVD
	_reproducir_animacion(["rebote", "dvd", "disparo_1", "idle"])
	
	var angulo_inicial = [PI/4, 3*PI/4, -PI/4, -3*PI/4].pick_random()
	vector_movimiento_dvd = Vector2.RIGHT.rotated(angulo_inicial) * velocidad_dvd
	
	EfectosManager.play_sound("power", Vector3(global_position.x, global_position.y, 0), true, 1.5)
	
	await get_tree().create_timer(duracion_rebote_dvd).timeout
	
	if estado_actual == Estado.MUERTO: return
	
	estado_actual = Estado.IDLE
	rotation = 0.0
	
	var tw_retorno = create_tween()
	tw_retorno.tween_property(self, "global_position", posicion_inicial, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tw_retorno.finished
	
	_volver_a_idle()

func _verificar_dano_contacto_dvd():
	if tiempo_ultimo_contacto < cooldown_dano_contacto: return
	if is_instance_valid(jugador):
		var dist = global_position.distance_to(jugador.global_position)
		if dist <= 60.0:
			tiempo_ultimo_contacto = 0.0
			if jugador.has_method("recibir_dano"):
				jugador.recibir_dano(dano_contacto_dvd)
				
			EfectosManager.impact_effect(0.4, 0.06, Vector3(global_position.x, global_position.y, 0), 2)
			
			var cam = get_tree().get_first_node_in_group("camera") as CamaraBatalla
			if is_instance_valid(cam):
				cam.aplicar_golpe_shake(15.0)

# =====================================================================
# --- HABILIDAD: AUTOCURACIÓN ---
# =====================================================================
func ejec_curacion():
	estado_actual = Estado.CURACION
	_reproducir_animacion(["curacion", "idle"])
	
	EfectosManager.play_sound("power", Vector3(global_position.x, global_position.y, 0), true, 1.2)
	
	var tw_green = create_tween()
	tw_green.tween_property(sprite, "modulate", Color.GREEN, 0.3)
	tw_green.tween_property(sprite, "modulate", Color.WHITE, 0.3)
	
	health = min(max_health, health + cantidad_curacion)
	emit_signal("vida_cambiada", health, max_health)
	
	await get_tree().create_timer(1.0).timeout
	_volver_a_idle()

# =====================================================================
# --- COMBATE Y DAÑO RECIBIDO ---
# =====================================================================
func recibir_dano(cantidad: float):
	if estado_actual == Estado.MUERTO: return
	
	health = max(0.0, health - cantidad)
	emit_signal("vida_cambiada", health, max_health)
	
	EfectosManager.play_sound("hurt", Vector3(global_position.x, global_position.y, 0), true)
	
	var tw = create_tween()
	tw.tween_property(sprite, "modulate", Color.RED, 0.08)
	tw.tween_property(sprite, "modulate", Color.WHITE, 0.08)
	
	var camara = get_tree().get_first_node_in_group("camera") as CamaraBatalla
	if is_instance_valid(camara):
		camara.aplicar_golpe_shake(12.0)

	if health <= 0:
		_morir()

func _morir():
	estado_actual = Estado.MUERTO
	if timer_cooldown: timer_cooldown.stop()
	
	if sprite.sprite_frames and sprite.sprite_frames.has_animation("muerte"):
		sprite.play("muerte")
		await sprite.animation_finished
	queue_free()

func _reproducir_animacion(nombres: Array):
	for nom in nombres:
		if sprite.sprite_frames and sprite.sprite_frames.has_animation(nom):
			sprite.play(nom)
			return

# =====================================================================
# --- CLASE PROYECTIL BALA ZANAHORIA CON PARRY Y SPRITE AMARILLO ---
# =====================================================================
class BalaZanahoria extends Area2D:
	var direccion: Vector2 = Vector2.RIGHT
	var velocidad: float = 400.0
	var dano: float = 15.0
	var es_amarilla_parry: bool = false
	var parreada: bool = false
	var jefe_dueno: Node2D = null
	var sprite_frames_custom: SpriteFrames = null
	var escala_custom: Vector2 = Vector2(0.6, 0.6)
	var offset_rotacion_grados: float = 180.0

	var puede_redireccionar: bool = false
	var ya_redirecciono: bool = false
	var tiempo_para_girar: float = 0.25
	var velocidad_post_giro: float = 850.0
	var velocidad_curva: float = 0.0
	var tiempo_acumulado: float = 0.0

	func _ready():
		add_to_group("proyectil_enemigo")
		body_entered.connect(_on_body_entered)
		area_entered.connect(_on_area_entered)
		get_tree().create_timer(5.0).timeout.connect(queue_free)
		
		var anim_sprite = AnimatedSprite2D.new()
		anim_sprite.name = "SpriteBala"
		anim_sprite.scale = escala_custom
		
		if sprite_frames_custom:
			anim_sprite.sprite_frames = sprite_frames_custom
			var anim_nombre = "normal"
			
			if es_amarilla_parry:
				if sprite_frames_custom.has_animation("default 2"):
					anim_nombre = "default 2"
				elif sprite_frames_custom.has_animation("amarilla"):
					anim_nombre = "amarilla"
				elif sprite_frames_custom.has_animation("dorada"):
					anim_nombre = "dorada"
				else:
					anim_nombre = "default"
			else:
				if sprite_frames_custom.has_animation("normal"):
					anim_nombre = "normal"
				else:
					anim_nombre = "default"
					
			anim_sprite.play(anim_nombre)
		else:
			var img = Image.create(14, 14, false, Image.FORMAT_RGBA8)
			img.fill(Color.YELLOW if es_amarilla_parry else Color.ORANGE)
			var sp = Sprite2D.new()
			sp.texture = ImageTexture.create_from_image(img)
			sp.scale = escala_custom
			add_child(sp)
			
		if anim_sprite.sprite_frames:
			add_child(anim_sprite)

		var colision = CollisionShape2D.new()
		var shape = CircleShape2D.new()
		shape.radius = 7.0 * escala_custom.x
		colision.shape = shape
		add_child(colision)
		
		_actualizar_orientacion()

	func _process(delta: float):
		tiempo_acumulado += delta

		# Redirección agresiva en el aire
		if puede_redireccionar and not ya_redirecciono and not parreada:
			if tiempo_acumulado >= tiempo_para_girar:
				ya_redirecciono = true
				var jugador = get_tree().get_first_node_in_group("player")
				if is_instance_valid(jugador):
					direccion = (jugador.global_position - global_position).normalized()
					velocidad = velocidad_post_giro
					_actualizar_orientacion()

		# Trayectoria curva
		if velocidad_curva != 0.0 and not parreada:
			direccion = direccion.rotated(deg_to_rad(velocidad_curva) * delta)
			_actualizar_orientacion()

		position += direccion * velocidad * delta

	func _actualizar_orientacion():
		rotation = direccion.angle() + deg_to_rad(offset_rotacion_grados)

	func parrear():
		if not es_amarilla_parry or parreada: return
		
		parreada = true
		
		var jefe = get_tree().get_first_node_in_group("boss")
		if is_instance_valid(jefe):
			direccion = (jefe.global_position - global_position).normalized()
		else:
			direccion = -direccion
			
		velocidad *= 1.8
		dano *= 2.0
		_actualizar_orientacion()
		
		EfectosManager.play_sound("Brokenshield", Vector3(global_position.x, global_position.y, 0), true)
		
		remove_from_group("proyectil_enemigo")
		add_to_group("proyectil_jugador")
		
		var jugador = get_tree().get_first_node_in_group("player")
		if is_instance_valid(jugador) and jugador.has_method("notificar_parry_exitoso"):
			jugador.notificar_parry_exitoso()

		var cam = get_tree().get_first_node_in_group("camera") as CamaraBatalla
		if is_instance_valid(cam):
			cam.aplicar_golpe_shake(14.0)
			cam.disparar_impact_frame(0.07)

	func _on_body_entered(body: Node2D):
		if not parreada:
			if body.is_in_group("player"):
				if es_amarilla_parry and body.has_method("esta_parreando") and body.esta_parreando():
					parrear()
					return
				
				if body.has_method("recibir_dano"):
					body.recibir_dano(dano)
				queue_free()
			elif not body.is_in_group("boss"):
				queue_free()
		else:
			if body.is_in_group("boss") or body == jefe_dueno:
				if body.has_method("recibir_dano"):
					body.recibir_dano(dano)
				
				var cam = get_tree().get_first_node_in_group("camera") as CamaraBatalla
				if is_instance_valid(cam):
					cam.aplicar_golpe_shake(18.0)
					cam.disparar_impact_frame(0.08)
				queue_free()

	func _on_area_entered(area: Area2D):
		if es_amarilla_parry and not parreada and area.is_in_group("parry_shield"):
			parrear()

# =====================================================================
# --- CLASE RAYO CAÍDA ---
# =====================================================================
class RayoCielo extends Area2D:
	var velocidad: float = 750.0
	var dano: float = 20.0

	func _ready():
		add_to_group("proyectil_enemigo")
		body_entered.connect(_on_body_entered)
		get_tree().create_timer(3.0).timeout.connect(queue_free)
		
		var sprite = Sprite2D.new()
		var img = Image.create(8, 32, false, Image.FORMAT_RGBA8)
		img.fill(Color.YELLOW)
		sprite.texture = ImageTexture.create_from_image(img)
		add_child(sprite)

		var colision = CollisionShape2D.new()
		var shape = RectangleShape2D.new()
		shape.size = Vector2(8, 32)
		colision.shape = shape
		add_child(colision)

	func _process(delta: float):
		position.y += velocidad * delta

	func _on_body_entered(body: Node2D):
		if body.is_in_group("player"):
			if body.has_method("recibir_dano"):
				body.recibir_dano(dano)
			queue_free()
		elif not body.is_in_group("boss"):
			queue_free()
