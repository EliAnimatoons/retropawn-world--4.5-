extends CanvasLayer

@onready var control = $Control
@onready var disco = $Control/DiscoAnimado
@onready var label_nombre = $Control/LabelNombre
@onready var label_nombre2 = $Control/LabelNombre2
@onready var label_musica = $Control/LabelMusica

func _ready():
	# Empezamos invisible y disco pequeño
	control.modulate.a = 0
	disco.scale = Vector2(0.1, 0.1)
	
	# Si ya tiene texto (puesto desde el inspector), lanzamos la animación
	# Si lo vas a configurar por código, llama a aparecer_presentacion() después de configurar
	aparecer_presentacion()

# Función para cambiar los textos desde afuera antes de mostrarse
func configurar(nombre_nivel: String, autor_musica: String):
	label_nombre.text = nombre_nivel
	label_nombre2.text = nombre_nivel
	label_musica.text = "" + autor_musica

func aparecer_presentacion():
	var tween = create_tween().set_parallel(true)
	
	# 1. Aparece el cartel y el disco rebota (estilo Sonic)
	tween.tween_property(control, "modulate:a", 1.0, 0.8).set_trans(Tween.TRANS_SINE)
	tween.tween_property(disco, "scale", Vector2(1.0, 1.0), 1.0).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	
	# 2. Secuencia para esperar y luego irse
	var secuencia = create_tween()
	secuencia.tween_interval(3.5) # Tiempo que se queda en pantalla
	secuencia.tween_property(control, "modulate:a", 0.0, 1.0)
	secuencia.tween_callback(queue_free) # Se auto-elimina al terminar
