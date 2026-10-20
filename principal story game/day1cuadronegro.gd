extends Control

# Precargamos la escena de Sketch para clonarla cuando termine la pantalla negra
const SKETCH_SCENE = preload("res://scenes/sketch.tscn")

@onready var color_rect = $ColorRect
@onready var label_dia = $LabelDia
@onready var timer = $Timer

func _ready():
	# 1. Detectamos el idioma usando tu sistema global de ProgresoJuego
	var texto_dia = ""
	match ProgresoJuego.idioma:
		"es": texto_dia = "Día 1"
		"ja": texto_dia = "1日目"
		_: texto_dia = "Day 1" # Inglés por defecto
		
	label_dia.text = texto_dia
	
	# Aseguramos que empiece tapando todo en negro
	color_rect.modulate.a = 1.0
	label_dia.modulate.a = 1.0
	
	# 2. Conectamos el Timer y lo iniciamos por 2 segundos
	if not timer.timeout.is_connected(_on_timer_timeout):
		timer.timeout.connect(_on_timer_timeout)
	timer.start(2.0)

func _on_timer_timeout():
	# 1. Al terminarse el tiempo, hacemos el desvanecido visual suave
	var tween = create_tween().set_parallel(true)
	tween.tween_property(color_rect, "modulate:a", 0.0, 1.5)
	tween.tween_property(label_dia, "modulate:a", 0.0, 1.0)
	
	# Esperamos a que la pantalla termine de aclararse del todo
	await tween.finished
	
	# 2. Instanciamos a Sketch
	var sketch_instancia = SKETCH_SCENE.instantiate()
	
	# 3. SOLUCIÓN AL ERROR: Buscamos el SpawnPlayer de forma segura en la escena de forma relativa
	# Buscamos en el nodo de arriba (tu Mundo3D) un hijo llamado "SpawnPlayer" sin usar rutas absolutas
	var spawn_point = get_parent().find_child("SpawnPlayer", true, false)
	
	if spawn_point:
		sketch_instancia.global_position = spawn_point.global_position
	else:
		print("AVISO: No encontré el nodo 'SpawnPlayer', Sketch aparecerá en el centro (0,0,0)")
	
	# 4. Lo agregamos al mapa y al grupo
	get_parent().add_child(sketch_instancia)
	
	if not sketch_instancia.is_in_group("player"):
		sketch_instancia.add_to_group("player")
	
	# Eliminamos la pantalla de inicio para limpiar la memoria
	queue_free()
