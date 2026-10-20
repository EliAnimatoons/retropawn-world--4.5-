extends Control
class_name SkillCheckCircular

# Señal que avisa al Jefe o a la Batalla si el jugador lo logró o falló
signal skill_check_completado(exito: bool)

@export_category("Nodos Visuales")
@export var visual_zona: Control
@export var visual_aguja: Control
@export var barra_progreso: TextureProgressBar # O ProgressBar

@export_category("Parámetros de Juego")
@export var velocidad_aguja: float = 300.0 # Grados por segundo
@export var tamano_zona: float = 50.0 # Ancho de la zona en grados
@export var progreso_por_acierto: float = 25.0 # Con 4 aciertos llega a 100
@export var progreso_requerido: float = 100.0

@export_category("Geometría Circular (Diseño HUD)")
@export var centro_rueda: Vector2 = Vector2(87.5, 87.5) # Centro del contenedor
@export var radio_orbita: float = 62.0 # Distancia de la zona al centro

var activa: bool = false
var angulo_aguja: float = 0.0
var zona_inicio: float = 0.0
var zona_fin: float = 0.0
var progreso_actual: float = 0.0
var accion_input: String = "parry"

func _ready() -> void:
	visible = false

func iniciar_skill_check(input_accion: String = "parry") -> void:
	accion_input = input_accion
	activa = true
	progreso_actual = 0.0
	angulo_aguja = 0.0
	
	if barra_progreso:
		barra_progreso.value = 0.0
		
	visible = true
	modulate = Color.WHITE
	scale = Vector2.ONE
	
	# Ajuste del Pivot de la Aguja para que gire desde su base hacia afuera
	if visual_aguja:
		visual_aguja.pivot_offset = Vector2(visual_aguja.size.x / 2.0, visual_aguja.size.y)
		visual_aguja.position = Vector2(centro_rueda.x - (visual_aguja.size.x / 2.0), centro_rueda.y - visual_aguja.size.y)
		
	_generar_nueva_zona_exito()

func _process(delta: float) -> void:
	if not activa:
		return
		
	# 1. Giro continuo de 0 a 360 grados
	angulo_aguja += velocidad_aguja * delta
	if angulo_aguja >= 360.0:
		angulo_aguja -= 360.0
		
	if visual_aguja:
		visual_aguja.rotation_degrees = angulo_aguja
		
	# 2. Detección de Input
	if Input.is_action_just_pressed(accion_input):
		_evaluar_intento()

func _generar_nueva_zona_exito() -> void:
	zona_inicio = randf_range(0.0, 360.0)
	zona_fin = zona_inicio + tamano_zona
	if zona_fin >= 360.0:
		zona_fin -= 360.0
		
	if visual_zona:
		visual_zona.pivot_offset = visual_zona.size / 2.0
		
		# Cálculo de posición orbital exacta según grados
		var angulo_medio = zona_inicio + (tamano_zona / 2.0)
		var angulo_medio_rad = deg_to_rad(angulo_medio - 90.0)
		
		var pos_x = centro_rueda.x + cos(angulo_medio_rad) * radio_orbita - (visual_zona.size.x / 2.0)
		var pos_y = centro_rueda.y + sin(angulo_medio_rad) * radio_orbita - (visual_zona.size.y / 2.0)
		
		visual_zona.position = Vector2(pos_x, pos_y)
		visual_zona.rotation_degrees = angulo_medio

func _evaluar_intento() -> void:
	var acierto = false
	
	# Validación de colisión angular (soporta el cruce por los 0/360 grados)
	if zona_inicio <= zona_fin:
		if angulo_aguja >= zona_inicio and angulo_aguja <= zona_fin:
			acierto = true
	else:
		if angulo_aguja >= zona_inicio or angulo_aguja <= zona_fin:
			acierto = true

	if acierto:
		progreso_actual += progreso_por_acierto
		if barra_progreso:
			barra_progreso.value = progreso_actual
			
		# Feedback visual verde
		var tw = create_tween()
		tw.tween_property(visual_zona, "modulate", Color.GREEN, 0.05)
		tw.tween_property(visual_zona, "modulate", Color.WHITE, 0.05)
		
		if progreso_actual >= progreso_requerido:
			_finalizar(true)
		else:
			_generar_nueva_zona_exito()
	else:
		# Penalización por fallo
		progreso_actual = max(0.0, progreso_actual - (progreso_por_acierto * 0.5))
		if barra_progreso:
			barra_progreso.value = progreso_actual
			
		# Feedback visual rojo en todo el contenedor
		var tw = create_tween()
		tw.tween_property(self, "modulate", Color.RED, 0.05)
		tw.tween_property(self, "modulate", Color.WHITE, 0.05)

func _finalizar(exito: bool) -> void:
	activa = false
	var tw = create_tween()
	if exito:
		tw.tween_property(self, "scale", Vector2(1.2, 1.2), 0.1)
		tw.parallel().tween_property(self, "modulate:a", 0.0, 0.15)
	else:
		tw.tween_property(self, "modulate:a", 0.0, 0.15)
		
	await tw.finished
	visible = false
	scale = Vector2.ONE
	skill_check_completado.emit(exito)
