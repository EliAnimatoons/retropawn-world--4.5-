extends Node

# Estados del Jugador
var invisible = false
var veneno_activo = false
var multiplicador_monedas = 1

# 1. REEMPLAZO DE INVISIBILIDAD (Sigilo)
func activar_invisibilidad(duracion: float):
	invisible = true
	print("ESTADO: El jugador es difícil de ver.")
	await get_tree().create_timer(duracion).timeout
	invisible = false
	print("ESTADO: Visible de nuevo.")

# 2. REEMPLAZO DE VENENO (Aura de Daño)
# En lugar de "envenenar" al minion, el JUGADOR emite veneno a lo que tiene cerca
func activar_aura_veneno(duracion: float):
	veneno_activo = true
	print("ESTADO: Aura de veneno activada.")
	await get_tree().create_timer(duracion).timeout
	veneno_activo = false
	print("ESTADO: Aura apagada.")

# 3. REEMPLAZO DE X2 (Multiplicador)
func activar_x2_monedas(duracion: float):
	multiplicador_monedas = 2
	print("ESTADO: Monedas x2 activadas.")
	await get_tree().create_timer(duracion).timeout
	multiplicador_monedas = 1
