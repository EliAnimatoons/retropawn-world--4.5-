extends Area3D

var speed: float = 20.0
var direction: Vector3 = Vector3.ZERO
var player = null
var es_parreado: bool = false
var ya_golpeo: bool = false

# Antes el bloque de seguimiento/movimiento estaba pegado dos veces, así que el proyectil
# se movía y giraba al doble. Ahora hay un solo bloque, con estos multiplicadores para que
# se sienta EXACTAMENTE igual que antes. Si lo querés más lento, bajá MULT_VELOCIDAD a 1.0.
const MULT_VELOCIDAD: float = 2.0
const MULT_GIRO: float = 2.0

func _ready():
	player = get_tree().get_first_node_in_group("player")
	if has_node("WarningSound"):
		$WarningSound.play()

	get_tree().create_timer(6.0).timeout.connect(func(): if is_instance_valid(self): queue_free())

func _physics_process(delta):
	if es_parreado or ya_golpeo:
		if es_parreado:
			global_position += Vector3.UP * speed * delta
		return

	if is_instance_valid(player):
		# Apuntamos al centro del pecho
		var target_pos: Vector3 = player.global_position + Vector3(0, 0.6, 0)
		var hacia: Vector3 = target_pos - global_position
		var dir_al_jugador: Vector3 = direction
		if hacia.length_squared() > 0.0001:
			dir_al_jugador = hacia.normalized()

		# Seguimiento agresivo: gira más rápido cuando está cerca
		var distancia: float = global_position.distance_to(target_pos)
		var fuerza_giro: float = (4.0 if distancia > 3.0 else 10.0) * MULT_GIRO

		var nueva_dir: Vector3 = direction.lerp(dir_al_jugador, delta * fuerza_giro)
		if nueva_dir.length_squared() > 0.0001:
			direction = nueva_dir.normalized()

	# Movimiento constante
	global_position += direction * (speed * MULT_VELOCIDAD * delta)

	# PARRY JUSTO
	if is_instance_valid(player) and player.get("is_parrying"):
		if global_position.distance_to(player.global_position) < 1.2:
			hacer_parry_proyectil()

func hacer_parry_proyectil():
	if es_parreado:
		return   # evita contar el mismo parry dos veces
	es_parreado = true
	ya_golpeo = true
	EstadisticasNivel.registrar_parry()   # cuenta el parry para el score

	if has_node("/root/EfectosManager"):
		get_node("/root/EfectosManager").parry_success_effect(global_position)

	if has_node("MeshInstance3D"):
		$MeshInstance3D.transparency = 0.5

	await get_tree().create_timer(0.5).timeout
	queue_free()

func _on_body_entered(body):
	if es_parreado or ya_golpeo: return

	if body.is_in_group("player") or body == player:
		ya_golpeo = true

		if body.has_method("aplicar_glitch"):
			body.aplicar_glitch(global_position)

		set_deferred("monitoring", false)
		set_deferred("monitorable", false)

		if has_node("WarningSound"):
			$WarningSound.stop()

		if has_node("ImpactSound"):
			$ImpactSound.play()
			hide()
			await $ImpactSound.finished

		queue_free()
