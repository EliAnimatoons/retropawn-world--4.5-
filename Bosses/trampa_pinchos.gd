extends Area2D

@export var danio: float = 15.0
@export var tiempo_aviso: float = 1.2
@export var tiempo_duracion: float = 0.6

@onready var area_aviso: ColorRect = $AreaAviso
@onready var sprite_pinchos: Sprite2D = $SpritePinchos
@onready var colision: CollisionShape2D = $CollisionShape2D

var direccion_disparo: Vector2 = Vector2.UP

func _ready():
	# CORREGIDO: Uso de set_deferred para evitar error en el servidor de físicas
	colision.set_deferred("disabled", true)
	sprite_pinchos.visible = false
	body_entered.connect(_on_body_entered)
	iniciar_trampa()

func iniciar_trampa():
	if direccion_disparo == Vector2.DOWN:
		rotation_degrees = 180
	
	# FASE 1: AVISO ROJO (Parpadeo donde va a salir el pincho)
	area_aviso.visible = true
	var tween_aviso = create_tween().set_loops(3)
	tween_aviso.tween_property(area_aviso, "modulate:a", 0.1, tiempo_aviso / 6.0)
	tween_aviso.tween_property(area_aviso, "modulate:a", 0.8, tiempo_aviso / 6.0)
	
	await get_tree().create_timer(tiempo_aviso).timeout
	
	# FASE 2: SALIDA DE PINCHOS
	area_aviso.visible = false
	sprite_pinchos.visible = true
	# CORREGIDO: Activación diferida de la colisión
	colision.set_deferred("disabled", false)
	
	var pos_inicial = Vector2(0, 32)
	var pos_final = Vector2.ZERO
	sprite_pinchos.position = pos_inicial
	
	var tween_disparo = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween_disparo.tween_property(sprite_pinchos, "position", pos_final, 0.1)
	
	# FASE 3: RETRACCIÓN Y LIMPIEZA
	await get_tree().create_timer(tiempo_duracion).timeout
	
	# CORREGIDO: Desactivación diferida de la colisión
	colision.set_deferred("disabled", true)
	var tween_retraer = create_tween()
	tween_retraer.tween_property(sprite_pinchos, "position", pos_inicial, 0.15)
	await tween_retraer.finished
	
	queue_free()

func _on_body_entered(body: Node2D):
	if body.is_in_group("player"):
		if body.has_method("recibir_dano"):
			body.recibir_dano(danio)
		elif body.has_method("recibir_danio"):
			body.recibir_danio(danio)
		elif "health" in body:
			body.health -= danio
