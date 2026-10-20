extends Area3D

enum Tipo { MONEDA, VENDAJE }
@export var tipo_actual : Tipo = Tipo.MONEDA 
@export var tiempo_vida : float = 10.0 # Segundos antes de desaparecer

@onready var visual = $AnimatedSprite3D

var tiempo_restante : float

func _ready():
	tiempo_restante = tiempo_vida
	call_deferred("actualizar_item")
	body_entered.connect(_on_body_entered)

func actualizar_item():
	if tipo_actual == Tipo.MONEDA:
		visual.play("Sprite Moneda")
	else:
		visual.play("Sprite Vendaje")

func _process(delta):
	# Tu movimiento original
	visual.position.y = sin(Time.get_ticks_msec() * 0.004) * 0.1 + 0.5
	
	# --- LÓGICA DE DESAPARICIÓN ---
	tiempo_restante -= delta
	
	# Efecto de parpadeo cuando queda poco tiempo (menos de 3 segundos)
	if tiempo_restante < 3.0:
		# Hace que el sprite se vuelva invisible y visible rápido
		visual.visible = fmod(tiempo_restante * 10, 2.0) > 1.0
	
	if tiempo_restante <= 0:
		queue_free()

# Busca la función _on_body_entered en tu script de Drop y cámbiala por esta:

func _on_body_entered(body):
	if body.is_in_group("player"):
		if tipo_actual == Tipo.MONEDA:
			# USAMOS EL MULTIPLICADOR DEL MANAGER
			var cantidad = 1 * PocionManager.multiplicador_monedas
			ProgresoJuego.monedas_nivel += cantidad
			print("Dinero recogido: +", cantidad, " (Total: ", ProgresoJuego.monedas_nivel, ")")
		elif tipo_actual == Tipo.VENDAJE:
			if body.has_method("heal"):
				body.heal(30)
				print("Curado con vendaje")
		
		queue_free()
