extends Area3D

@export var enemigo_pan: Area3D
@export var musica_persecucion: AudioStreamPlayer

func _ready():
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D):
	if not body.is_in_group("player"):
		return

	print("Jugador cruzó la pared 'run'.")

	if "puede_saltar_aqui" in body:
		body.puede_saltar_aqui = true
	elif "puede_saltar" in body:
		body.puede_saltar = true

	if is_instance_valid(enemigo_pan):
		enemigo_pan.empezar_persecucion(body)
	else:
		push_error("TriggerPared: enemigo_pan no está asignado en el Inspector.")

	if is_instance_valid(musica_persecucion) and not musica_persecucion.playing:
		musica_persecucion.play()

	queue_free() # Se destruye para que no se ejecute infinitamente
