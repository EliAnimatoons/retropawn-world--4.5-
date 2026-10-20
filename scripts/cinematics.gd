extends Control

@onready var video_player = $VideoStreamPlayer

func _ready():
	# Leemos los datos desde el GameManager
	var stream = GameManager.video_pendiente
	var destino = GameManager.nivel_tras_video
	
	# Limpiamos el singleton para no reutilizar datos viejos
	GameManager.video_pendiente = null
	GameManager.nivel_tras_video = ""
	
	if stream == null or destino == "":
		get_tree().change_scene_to_file("res://scenes/MenuPrincipal.tscn")
		return
	
	video_player.stream = stream
	video_player.play()
	video_player.finished.connect(func(): get_tree().change_scene_to_file(destino))
	
	# Guardamos destino localmente para el skip
	set_meta("destino", destino)

func _input(event):
	# Verificamos que sea un evento de teclado/botón antes de checar la acción
	if not (event is InputEventKey or event is InputEventJoypadButton):
		return
	if event.is_action_pressed("ui_accept"):
		video_player.stop()
		Cargador.ir_a_escena(get_meta("destino", "res://scenes/MenuPrincipal.tscn"))
