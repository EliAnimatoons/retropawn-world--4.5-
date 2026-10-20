# cuadro_interactivo.gd
extends Sprite3D

@export_multiline var texto_es: String = ""
@export_multiline var texto_en: String = ""
@export_multiline var texto_jp: String = ""

@export var duracion_cartel: float = 4.0

var area_interaccion: Area3D
var jugador_cerca: bool = false
var cartel_actual: CanvasLayer = null

func _ready():
	area_interaccion = find_child("*Area3D*", true, false) as Area3D
	
	if area_interaccion:
		area_interaccion.body_entered.connect(_on_body_entered)
		area_interaccion.body_exited.connect(_on_body_exited)
	else:
		print("⚠️ [CUADRO] No se encontró un Area3D dentro de ", name)

func _unhandled_input(event):
	if jugador_cerca and event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		mostrar_dialogo()

func _on_body_entered(body):
	if body.is_in_group("player"):
		jugador_cerca = true

func _on_body_exited(body):
	if body.is_in_group("player"):
		jugador_cerca = false
		_cerrar_cartel()

func obtener_texto_segun_idioma() -> String:
	var idioma = ProgresoJuego.idioma if "idioma" in ProgresoJuego else "es"
	
	match idioma:
		"en":
			return texto_en if not texto_en.is_empty() else texto_es
		"jp":
			return texto_jp if not texto_jp.is_empty() else texto_es
		_:
			return texto_es

func mostrar_dialogo():
	var mensaje = obtener_texto_segun_idioma()
	if mensaje.is_empty():
		return
		
	_cerrar_cartel()
	
	print("--- [CUADRO] Leyendo en idioma (", ProgresoJuego.idioma if "idioma" in ProgresoJuego else "es", "): ", name, " ---")
	
	cartel_actual = CanvasLayer.new()
	cartel_actual.layer = 90
	get_tree().current_scene.add_child(cartel_actual)
	
	var panel = Panel.new()
	panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	panel.custom_minimum_size = Vector2(0, 120)
	panel.position.y -= 120
	cartel_actual.add_child(panel)
	
	var label = Label.new()
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	label.add_theme_font_size_override("font_size", 20)
	label.text = mensaje
	panel.add_child(label)
	
	var tw = create_tween()
	tw.tween_interval(duracion_cartel)
	tw.tween_callback(_cerrar_cartel)

func _cerrar_cartel():
	if is_instance_valid(cartel_actual):
		cartel_actual.queue_free()
		cartel_actual = null
