extends Area3D

@export var velocidad = 15.0
var dano = 10.0
var direccion = Vector3.ZERO
var source_pos = Vector3.ZERO 

var max_distancia = 6.0 
var distancia_recorrida = 0.0

func _ready():
	if not body_entered.is_connected(_on_impacto):
		body_entered.connect(_on_impacto)
	if not area_entered.is_connected(_on_impacto):
		area_entered.connect(_on_impacto)
	
	if scale.x > 1.0:
		for child in get_children():
			if "modulate" in child:
				child.modulate = Color(2.5, 1.0, 2.5) 
	
	get_tree().create_timer(3.0).timeout.connect(queue_free)

func _physics_process(delta):
	var movimiento = direccion * velocidad * delta
	global_position += movimiento
	distancia_recorrida += movimiento.length()
	
	if distancia_recorrida >= max_distancia:
		queue_free()

func _on_impacto(objeto):
	# 1. IGNORAR A JANE (Para que no de error de argumentos)
	if objeto.is_in_group("player"):
		return

	var victima = objeto
	var es_tacho = "tacho" in objeto.name.to_lower()
	
	if not victima.is_in_group("enemies") and victima.get_parent() and victima.get_parent().is_in_group("enemies"):
		victima = victima.get_parent()

	# 2. LÓGICA DE IMPACTO
	if victima.is_in_group("enemies") or es_tacho:
		if victima.has_method("take_damage"):
			var punto_origen = source_pos if source_pos != Vector3.ZERO else global_position
			
			# Cirugía: Verificamos cuántos argumentos acepta el objeto antes de llamar
			# El tacho acepta 2, los enemigos aceptan 2, Jane acepta 1.
			victima.take_damage(dano, punto_origen)
			
			if EfectosManager:
				EfectosManager.impact_effect(0.5, 0.1, global_position, 1)
		
		queue_free() 
		
	elif objeto.is_in_group("mapa") or objeto is StaticBody3D:
		queue_free() 

func set_source(pos: Vector3):
	source_pos = pos
