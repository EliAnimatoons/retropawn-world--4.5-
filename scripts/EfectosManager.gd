extends Node

var sonidos = {
	"hurt": preload("res://sonidos/hurt.mp3"),
	"curacion_coop": preload("res://sonidos/healthplayer.mp3"),
	"pasos": preload("res://sonidos/pasos.mp3"),
	"power": preload("res://sonidos/power.mp3"),
	"punch1": preload("res://sonidos/punch1.mp3"),
	"punch2": preload("res://sonidos/punch2.mp3"),
	"punch3": preload("res://sonidos/punch3.mp3"),
	"viento": preload("res://sonidos/viento.mp3"),
	"parry": preload("res://sonidos/parry.mp3"),
	"punch0": preload("res://sonidos/punch0.mp3"),
	"spawn_enemy": preload("res://sonidos/start.mp3"),
	"Brokenshield": preload("res://sonidos/Brokenshield.mp3"),
	"prepucin super": preload("res://sonidos/prepucin super.mp3"),
	"Shoot sound": preload("res://sonidos/Shoot sound.mp3"),
	"reload": preload("res://sonidos/reload.mp3"),
	"hurt_voice1": preload("res://AudioLines/hurtaudiominion1.mp3"),
	"hurt_voice2": preload("res://AudioLines/hurtaudiominion2.mp3"),
	"hurt_voice3": preload("res://AudioLines/hurtaudiominion3.mp3"),
	"attack_voice1": preload("res://AudioLines/attackaudiominion1.mp3"),
	"attack_voice2": preload("res://AudioLines/attackaudiominion2.mp3"),
	"attack_voice3": preload("res://AudioLines/attackaudiominion3.mp3"),
	"idle_voice1": preload("res://AudioLines/idleaudiominion1.mp3"),
	"idle_voice2": preload("res://AudioLines/idleaudiominion2.mp3"),
	"Glory kill 1 Sketch audio": preload("res://AudioLines/Glory kill 1 Sketch audio.mp3"),
	"Glory kill 2 Sketch audio": preload("res://AudioLines/Glory kill 2 Sketch audio.mp3"),
	"Glory kill 1 Jane audio": preload("res://AudioLines/Glory kill 1 Jane audio.mp3"),
	"Glory kill 2 Jane audio": preload("res://AudioLines/Glory kill 2 Jane audio.mp3"),
	"Glory kill 1 Maid Sketch audio": preload("res://AudioLines/Glory kill 1 Neko Sketch audio.mp3"),
	"Glory kill 2 Maid Sketch audio": preload("res://AudioLines/Glory kill 2 Neko Sketch audio.mp3"),
	"Glory kill 1 Neko Sketch audio": preload("res://AudioLines/Glory kill 1 Neko Sketch audio.mp3"),
	"Glory kill 2 Neko Sketch audio": preload("res://AudioLines/Glory kill 2 Neko Sketch audio.mp3"),
	"Glory kill 1 Lionel audio": preload("res://AudioLines/Glory kill 1 Lionel audio.mp3"),
	"Glory kill 1 Tankman audio": preload("res://AudioLines/Glory kill 1 Tankman audio.mp3"),
	"Glory kill 2 Lionel audio": preload("res://AudioLines/Glory kill 2 Lionel audio.mp3"),
	"Glory kill 3 Sketch audio": preload("res://AudioLines/Glory kill 3 Sketch audio.mp3"), 
	"Glory kill 3 Neko Sketch audio": preload("res://AudioLines/Glory Kill 3 Neko Sketch audio.mp3"),
	"Glory kill 1 Nubbe audio": preload("res://AudioLines/Glory kill 1 Nubbe audio.mp3"),
	"Glory kill 2 Nubbe audio": preload("res://AudioLines/Glory kill 2 Nubbe audio.mp3"),
	"Glory kill 1 Chosmix audio": preload("res://AudioLines/Glory kill 1 Chosmix audio.mp3"),
	"Glory kill 2 Tankman audio": preload("res://AudioLines/Glory kill 2 Tankman audio.mp3"),
	"Glory kill 2 Chosmix audio": preload("res://AudioLines/Glory kill 2 Chosmix audio.mp3")
}

func play_sound(nombre: String, posicion: Vector3 = Vector3.ZERO, variar_tono: bool = false, volumen_db: float = 0.0):
	if sonidos.has(nombre):
		var p = AudioStreamPlayer3D.new()
		p.stream = sonidos[nombre]
		p.volume_db = volumen_db
		
		# CRÍTICO: asignar al bus "Efectos" para que el slider lo controle
		p.bus = "Efectos"
		
		if variar_tono or nombre == "spawn_enemy" or nombre == "Brokenshield":
			p.pitch_scale = randf_range(0.9, 1.1)
			
		get_tree().root.add_child(p)
		
		if posicion != Vector3.ZERO:
			p.global_position = posicion
			
		p.play()
		p.finished.connect(func(): p.queue_free())
	else:
		print("--- ERROR: No se encontró el sonido: ", nombre)

func play_minion_voice(tipo: String, posicion: Vector3):
	var max_random = 1
	match tipo:
		"hurt": max_random = 3
		"attack": max_random = 3
		"idle": max_random = 2
	var num = randi_range(1, max_random)
	var nombre_final = tipo + "_voice" + str(num)
	play_sound(nombre_final, posicion, true, -2.0)

func parry_success_effect(posicion: Vector3):
	play_sound("parry", posicion, false, 6.0) 
	Engine.time_scale = 0.05
	await get_tree().create_timer(0.15, true, false, true).timeout
	Engine.time_scale = 1.0

func impact_effect(shake_power = 0.2, stop_time = 0.05, posicion_impacto = Vector3.ZERO, combo_step = 1):
	var cam = get_viewport().get_camera_3d()
	if cam and cam.has_method("apply_shake"):
		cam.apply_shake(shake_power)
	var num = combo_step
	if num > 3: num = 1
	var nombre_golpe = "punch" + str(num)
	play_sound(nombre_golpe, posicion_impacto, true)
	if stop_time > 0:
		Engine.time_scale = 0.0
		await get_tree().create_timer(stop_time, true, false, true).timeout
		Engine.time_scale = 1.0

# --- CONTROL DE MÚSICA POR BUS DE AUDIO ---
var _tween_bus_musica: Tween

# Opción suave (Fade In / Fade Out del Bus)
func atenuar_musica_nivel(atenuar: bool, tiempo: float = 0.4):
	var bus_idx = AudioServer.get_bus_index("Musica")
	if bus_idx == -1:
		print("--- ERROR: No existe el Bus 'Musica' en AudioServer ---")
		return
		
	if _tween_bus_musica and _tween_bus_musica.is_running():
		_tween_bus_musica.kill()
		
	_tween_bus_musica = create_tween()
	var db_objetivo = -80.0 if atenuar else 0.0
	var db_actual = AudioServer.get_bus_volume_db(bus_idx)
	
	_tween_bus_musica.tween_method(
		func(val): AudioServer.set_bus_volume_db(bus_idx, val),
		db_actual,
		db_objetivo,
		tiempo
	)

# Opción instantánea (Mute del Bus)
func pausar_musica_nivel():
	var bus_idx = AudioServer.get_bus_index("Musica")
	if bus_idx != -1:
		AudioServer.set_bus_mute(bus_idx, true)

func reanudar_musica_nivel():
	var bus_idx = AudioServer.get_bus_index("Musica")
	if bus_idx != -1:
		AudioServer.set_bus_mute(bus_idx, false)
