extends Control

@export var imagenes_fondo : Array[Texture2D]
@export var tiempo_minimo_espera : float = 4.0 

@onready var fondo = $TextureRect
@onready var barra_progreso = $ProgressBar
@onready var label_info = $Label
# Asegúrate de que el ColorRect se llame exactamente así en el árbol de nodos
@onready var color_rect_negro = $ColorRect 

var ruta_a_cargar : String
var progreso = []
var tiempo_transcurrido : float = 0.0
var timer_rotacion : float = 0.0 
var cargando_finalizado : bool = false

var frases = {
	"es": [
		"Recuerda hacer parry antes de que el enemigo golpee",
		"Haz combos presionando rápidamente el ataque",
		"El programador del juego es un desastre",
		"¿Sabías que vives en tu casa? :0"
	],
	"en": [
		"Remember to parry before the enemy strikes",
		"Perform combos by tapping attack rapidly",
		"The game programmer is a disaster",
		"Did you know you live in your house? :0"
	],
	"ja": [
		"敵が攻撃する前にパリィを忘れずに",
		"攻撃ボタンを連打してコンボを決めろ",
		"プログラマーは壊滅的だ",
		"自分の家に住んでるって知ってた？ :0"
	]
}

func _ready():
	# Forzamos filtrado para evitar que el zoom "vibre" o tiemble
	fondo.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	
	fondo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fondo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	# Centramos el pivote para que el zoom sea desde el medio de la pantalla
	fondo.pivot_offset = size / 2 
	fondo.modulate.a = 0 
	
	ruta_a_cargar = Cargador.escena_destino
	if ruta_a_cargar == "":
		get_tree().change_scene_to_file("res://menu_inicio.tscn")
		return

	rotar_contenido()
	ResourceLoader.load_threaded_request(ruta_a_cargar)

func _process(delta):
	if cargando_finalizado: return 
	
	tiempo_transcurrido += delta
	timer_rotacion += delta
	
	# Cambiamos imagen y frase cada 7 segundos
	if timer_rotacion >= 7.0:
		rotar_contenido()
		timer_rotacion = 0.0

	var estado = ResourceLoader.load_threaded_get_status(ruta_a_cargar, progreso)
	if progreso.size() > 0:
		var target_val = progreso[0] * 100
		barra_progreso.value = lerp(barra_progreso.value, target_val, 0.1)
	
	# Si terminó de cargar y pasó el tiempo mínimo, iniciamos el fadeout
	if estado == ResourceLoader.THREAD_LOAD_LOADED and tiempo_transcurrido >= tiempo_minimo_espera:
		iniciar_fade_out_final()

func rotar_contenido():
	# Lógica de idioma corregida (acceso directo al Autoload)
	var lang = "en"
	if is_instance_valid(ProgresoJuego):
		lang = ProgresoJuego.idioma
	
	# Si el idioma no está en la lista, usamos inglés por seguridad
	if not frases.has(lang): lang = "en"
	
	var nueva_frase = frases[lang].pick_random()
	
	if imagenes_fondo.size() > 0:
		var nueva_tex = imagenes_fondo.pick_random()
		
		var tw = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		
		# Desvanecemos lo actual
		tw.tween_property(fondo, "modulate:a", 0.0, 0.6)
		tw.parallel().tween_property(label_info, "modulate:a", 0.0, 0.6)
		
		# Cambiamos texturas y reseteamos escalas para la nueva animación
		tw.tween_callback(func(): 
			fondo.texture = nueva_tex
			label_info.text = nueva_frase
			fondo.scale = Vector2(1.0, 1.0)
			fondo.rotation_degrees = 0
		)
		
		# Aparecemos con el efecto de zoom y rotación lento ("Ken Burns")
		tw.tween_property(fondo, "modulate:a", 1.0, 0.6)
		tw.parallel().tween_property(label_info, "modulate:a", 1.0, 0.6)
		
		# El zoom y la rotación usan TRANS_LINEAR para que el movimiento no tenga saltos
		tw.parallel().tween_property(fondo, "scale", Vector2(1.1, 1.1), 7.2).set_trans(Tween.TRANS_LINEAR)
		tw.parallel().tween_property(fondo, "rotation_degrees", 1.5, 7.2).set_trans(Tween.TRANS_LINEAR)

func iniciar_fade_out_final():
	if cargando_finalizado: return
	cargando_finalizado = true
	
	var tw_final = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	
	# Desvanecemos elementos de UI e imagen, pero NO el ColorRect negro de fondo
	tw_final.tween_property(fondo, "modulate:a", 0.0, 0.8)
	tw_final.parallel().tween_property(barra_progreso, "modulate:a", 0.0, 0.8)
	tw_final.parallel().tween_property(label_info, "modulate:a", 0.0, 0.8)
	
	# Al terminar, cambiamos a la escena cargada
	tw_final.tween_callback(func():
		var nueva_escena = ResourceLoader.load_threaded_get(ruta_a_cargar)
		get_tree().change_scene_to_packed(nueva_escena)
)
