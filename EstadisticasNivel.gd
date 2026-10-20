extends Node

# ⚠️ CAMBIÁ ESTA RUTA por la de tu escena Score (click derecho en Score.tscn -> Copiar ruta)
const RUTA_SCORE := "res://Scores/Score.tscn"

var corriendo: bool = false
var tiempo: float = 0.0
var kills: int = 0
var parrys: int = 0
var indice_nivel: int = -1      # 0 = tutorial, 1 = mundo1, 2 = mundo2, 3 = mundo3
var datos_listos: bool = false  # true cuando hay una partida terminada para mostrar en el score
var _minions_al_inicio: int = 0

func iniciar_nivel() -> void:
	tiempo = 0.0
	kills = 0
	parrys = 0
	datos_listos = false
	_minions_al_inicio = int(ProgresoJuego.total_minions_muertos)
	corriendo = true

func _process(delta: float) -> void:
	if corriendo:
		tiempo += delta

# Llamala en el momento exacto en que el jugador hace un parry exitoso
func registrar_parry() -> void:
	if corriendo:
		parrys += 1
		print("[Estadisticas] Parry registrado. Total: ", parrys)
	else:
		print("[Estadisticas] Parry ignorado: el cronómetro no está corriendo.")

# Se llama desde el trigger final de cada mundo, con el índice del nivel
func finalizar_nivel(indice: int) -> void:
	if corriendo:
		corriendo = false
		kills = int(ProgresoJuego.total_minions_muertos) - _minions_al_inicio
	# Aunque no se haya llamado a iniciar_nivel(), igual se marca el nivel como
	# terminado para que el score pueda desbloquear el siguiente.
	indice_nivel = indice
	datos_listos = true

func ir_al_score() -> void:
	Cargador.ir_a_escena(RUTA_SCORE)

# Lo llama el score al salir
func limpiar() -> void:
	datos_listos = false
	indice_nivel = -1
