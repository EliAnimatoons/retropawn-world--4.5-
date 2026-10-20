# InteriorAutoUI.gd
extends CanvasLayer

signal viaje_terminado

@export_group("Configuración del Viaje")
@export var tiempo_viaje: float = 20.0
@export var ruta_escena_playa: String = "res://Beachday.tscn" # Ajusta la ruta exacta

@export_group("Referencias Internas")
@onready var contenedor_viaje: Control = $ContenedorViaje
# Aquí podrías referenciar sprites específicos si quieres animarlos por código
# @onready var sprite_max = $ContenedorViaje/CapaPersonajes/SpriteMax

var viaje_activo: bool = false

func _ready():
	# Nos aseguramos de empezar ocultos
	hide()
	contenedor_viaje.modulate.a = 0 # Empezamos transparentes para el Fade In

# Esta función será llamada por el script del auto (car.gd)
func iniciar_secuencia_viaje():
	if viaje_activo: return
	viaje_activo = true
	
	show() # Hacemos visible el CanvasLayer
	
	# --- SECUENCIA CINEMÁTICA CON TWEEN ---
	var tw = create_tween().set_parallel(false)
	
	# 1. Fade In (Aparecer suavemente en 1.5 segundos)
	tw.tween_property(contenedor_viaje, "modulate:a", 1.0, 1.5)
	
	# 2. Reproducir animaciones suaves de rebotar en los asientos (Opcional)
	tw.tween_callback(_animar_rebote_personajes)
	
	# 3. Pausa dramática inicial (2 segundos)
	tw.tween_interval(2.0)
	
	# 4. Diálogos automáticos durante el viaje
	tw.tween_callback(_mostrar_dialogos_viaje)
	
	# 5. Esperar el resto del tiempo de viaje (Total 20s - lo ya pasado)
	tw.tween_interval(tiempo_viaje - 3.5) # Ajustamos el tiempo restante
	
	# 6. Fade Out a Negro (1.5 segundos)
	tw.tween_property(contenedor_viaje, "modulate:a", 0.0, 1.5)
	
	# 7. Cambiar de escena
	tw.tween_callback(_cambiar_a_playa)

func _mostrar_dialogos_viaje():
	# Si tienes un sistema de diálogos, úsalo aquí. 
	# Si no, podemos usar el letrero automático dinámico que hicimos para la bocina.
	var frases = []
	var idioma = ProgresoJuego.idioma if "idioma" in ProgresoJuego else "es"
	
	if idioma == "es":
		frases = ["¡Ya casi llegamos!", "¡Miren, ya se ve el mar!", "¡Qué buenas vacaciones nos esperan!"]
	elif idioma == "en":
		frases = ["We're almost there!", "Look, I can see the sea!", "Amazing vacation awaits us!"]
	else:
		frases = ["もうすぐ着くよ！", "見て、海が見える！", "最高の休暇が待ってるぞ！"]
		
	# Instanciamos el letrero automático (el mismo código que en car.gd)
	_crear_letrero_viaje(frases)

func _crear_letrero_viaje(frases_array):
	# Letrero simple automático para el viaje (dura 6s)
	var panel = Panel.new()
	panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	panel.custom_minimum_size = Vector2(0, 120)
	panel.position.y -= 120
	contenedor_viaje.add_child(panel) # Lo añadimos dentro del contenedor 2D
	
	var label = Label.new()
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	label.add_theme_font_size_override("font_size", 22)
	
	# Unimos las frases con saltos de línea
	var texto_completo = ""
	for f in frases_array:
		texto_completo += f + "\n"
	label.text = texto_completo.strip_edges()
	
	panel.add_child(label)
	
	# Tween para que el panel aparezca y desaparezca solo
	var tw_panel = create_tween()
	tw_panel.tween_property(panel, "modulate:a", 1.0, 0.5).from(0.0)
	tw_panel.tween_interval(5.5)
	tw_panel.tween_property(panel, "modulate:a", 0.0, 0.5)
	tw_panel.tween_callback(panel.queue_free)

func _animar_rebote_personajes():
	# Ejemplo de cómo hacer que la capa de personajes rebote suavemente (simulando baches)
	var tw_rebote = create_tween().set_loops() # En bucle
	var capa = $ContenedorViaje/CapaPersonajes
	tw_rebote.tween_property(capa, "position:y", capa.position.y + 2, 0.2).set_trans(Tween.TRANS_SINE)
	tw_rebote.tween_property(capa, "position:y", capa.position.y, 0.2).set_trans(Tween.TRANS_SINE)

func _cambiar_a_playa():
	viaje_activo = false
	get_tree().change_scene_to_file(ruta_escena_playa)
