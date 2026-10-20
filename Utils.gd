extends Node
# =========================================================
# AUTOLOAD: Utils
# Agregalo en Project Settings > Autoload con el nombre "Utils"
# Así podés llamar Utils.direccion_segura(...) desde CUALQUIER script
# (minion.gd, minion_bomba.gd, aqua_glitcher.gd, sketch.gd, style.gd,
# minion_alacran.gd, tacho.gd, etc.) sin repetir la función en cada uno.
# =========================================================

func vector_valido(v: Vector3) -> bool:
	return is_finite(v.x) and is_finite(v.y) and is_finite(v.z)

# Devuelve la dirección normalizada de "desde" hacia "hacia".
# Si alguna de las dos posiciones es NaN/inf, o si están prácticamente
# en el mismo punto (distancia ~0), devuelve un fallback en vez de
# romper con "Vector3 cannot be normalized".
func direccion_segura(desde: Vector3, hacia: Vector3, fallback := Vector3.FORWARD) -> Vector3:
	if not vector_valido(desde) or not vector_valido(hacia):
		return fallback
	var diff = hacia - desde
	if diff.length_squared() < 0.0001:
		return fallback
	return diff.normalized()

# Igual que arriba pero para cuando ya tenés el vector diferencia calculado
# (por ejemplo antes de rotarlo o escalarlo).
func normalizar_seguro(v: Vector3, fallback := Vector3.FORWARD) -> Vector3:
	if not vector_valido(v) or v.length_squared() < 0.0001:
		return fallback
	return v.normalized()

# Watchdog: si un CharacterBody3D quedó con posición o velocidad NaN/inf,
# lo "resetea" a una posición de emergencia para cortar la cadena de contagio
# antes de que otros enemigos calculen distancias contra él.
# Llamalo al principio de _physics_process de cada enemigo:
#   if Utils.sanear_cuerpo(self, posicion_spawn_guardada): return
func sanear_cuerpo(cuerpo: Node3D, pos_emergencia: Vector3 = Vector3.ZERO) -> bool:
	var pos_rota = not vector_valido(cuerpo.global_position)
	var vel_rota = "velocity" in cuerpo and not vector_valido(cuerpo.velocity)
	if pos_rota or vel_rota:
		push_warning("[Utils] %s tenía posición/velocidad inválida. Reseteando." % cuerpo.name)
		cuerpo.global_position = pos_emergencia
		if "velocity" in cuerpo:
			cuerpo.velocity = Vector3.ZERO
		if "knockback_velocity" in cuerpo:
			cuerpo.knockback_velocity = Vector3.ZERO
		return true
	return false
