extends Node

var personaje_elegido = "sketch" 
var max_desbloqueado = false 
var video_pendiente = null          # ← sin tipo explícito
var nivel_tras_video: String = ""
var posicion_mapa: Vector2 = Vector2.ZERO
var tiene_posicion_guardada: bool = false

var rutas = {
	"sketch": "res://scenes/sketch.tscn",
	"max": "res://scenes/Max.tscn",
	"jane": "res://scenes/Jane.tscn",
	"prepucin": "res://scenes/prepucin.tscn",
	"nubbe": "res://Nubbetodo/nubbe.tscn" ,
	"chosmix": "res://ChosmixCharacter/Chosmix.tscn",
	"plasticsketch": "res://videos/character_body_3d.tscn",
	"alloy":        "res://Alloy mindchamber/alloy.tscn",
	"tankman": "res://Tankman/tankmen.tscn"
}

# --- NUEVO: SISTEMA CENTRALIZADO DE GLORY KILL ---
func disparar_glory_kill(jugador: Node3D, duracion: float = 1.2):
	var camara = get_viewport().get_camera_3d()
	
	if camara and camara.has_method("procesar_glory_kill"):
		camara.procesar_glory_kill(jugador, duracion)
