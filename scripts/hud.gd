extends CanvasLayer

@onready var retrato = %RetratoAnimado
@onready var nombre_label = %Label
@onready var barra_vida = %Vida
@onready var barra_poder = %Poder_MAX

@onready var blood_screen = $BloodScreen
@onready var super_screen = $SuperScreen
@onready var super_effect_sound = $SuperEffect

@onready var fuego_animado = $SuperScreen/super

@onready var icono_parry = $ModuloJugador/IconoParry
@onready var sonido_parry_hud = $SonidoParryHUD

@onready var super_time_audio = $SuperTime
@onready var super_time_sprite = $SuperTime2

@onready var modulo_jugador = $ModuloJugador 

@onready var tarrito_basura = %TarritoBasura if has_node("%TarritoBasura") else find_child("TarritoBasura", true, false)
@onready var label_cuota = %LabelCuota if has_node("%LabelCuota") else find_child("LabelCuota", true, false)

@onready var vidrio_roto = %VidrioRoto if has_node("%VidrioRoto") else find_child("VidrioRoto", true, false)
@onready var calavera_jumpscare = %CalaveraJumpscare if has_node("%CalaveraJumpscare") else find_child("CalaveraJumpscare", true, false)
@onready var fondo_negro = %BlackScreenEscape if has_node("%BlackScreenEscape") else find_child("BlackScreenEscape", true, false)

@onready var tinte_colapso = %TinteColapso if has_node("%TinteColapso") else find_child("TinteColapso", true, false)

@onready var label_timer_colapso = %TimerColapso if has_node("%TimerColapso") else find_child("TimerColapso", true, false)
@onready var impact_frame_rect = %ImpactFrame if has_node("%ImpactFrame") else find_child("ImpactFrame", true, false)

# Risa de enemigo (AnimatedSprite2D)
@onready var risa_enemigo_sprite: AnimatedSprite2D = %RisaEnemigo if has_node("%RisaEnemigo") else find_child("RisaEnemigo", true, false)
@export_group("Risa de Enemigo (Colapso)")
@export var intervalo_min_risa: float = 8.0
@export var intervalo_max_risa: float = 16.0
@export_range(0.0, 1.0) var probabilidad_aparicion_risa: float = 0.45 # NUEVO: baja las chances de que aparezca en cada intervalo

var _risas_activas: bool = false
var _timer_risa: float = 0.0
var _proxima_risa: float = 0.0

# NUEVO: manos al costado, aparecen al pasar 1 minuto de colapso y se quedan para siempre
# Busca el nodo por varios nombres posibles (incluido "minions hands")
@onready var manos_sprite: AnimatedSprite2D = _buscar_nodo_manos()
@export_group("Manos de Minions (Colapso)")
@export var duracion_fade_manos: float = 2.5 # NUEVO: segundos que tarda el fade in (lento)
var _manos_mostradas: bool = false

var es_meta_cumplida: bool = false

@onready var contenedor_skill_check = $ModuloJugador/SkillCheckContainer
@onready var visual_zona = $ModuloJugador/SkillCheckContainer/ZonaExito
@onready var visual_aguja = $ModuloJugador/SkillCheckContainer/Aguja
@onready var barra_progreso_liberacion = $ModuloJugador/SkillCheckContainer/BarraProgreso

var player_ref: Node = null 

var skill_check_activa: bool = false
var angulo_aguja: float = 0.0
var velocidad_aguja: float = 300.0

var zona_inicio: float = 0.0
var zona_fin: float = 0.0
var tamano_zona: float = 50.0

var progreso_liberacion: float = 0.0
var progreso_requerido: float = 100.0
var progreso_por_acierto: float = 25.0

var ultima_animacion = "" 
var super_activo = false

var _vida_delay_expiration: int = 0
var _vida_last_was_heal: bool = false

var posicion_centro_super: Vector2 = Vector2.ZERO
var posicion_original_modulo: Vector2 = Vector2.ZERO
var modulo_caido: bool = false 

var parry_ejecutandose: bool = false

var super_music_player: AudioStreamPlayer = null

var musicas_super = {
	"sketch": "res://SUPER SONGS!/super_sketch.mp3", 
	"jane": "res://SUPER SONGS!/super_jane.mp3",
	"max": "res://SUPER SONGS!/super_max.mp3",
	"prepucin": "res://SUPER SONGS!/super_prepucin.mp3",
	"nubbe": "res://SUPER SONGS!/super_nubbe.mp3",
	"plasticsketch": "res://SUPER SONGS!/super_plasticsketch.mp3"
}

var secuencia_destruccion_hud: bool = false
var temblor_post_susto_hud: bool = false
var _tiempo_destruccion_hud: float = 0.0

# NUEVO: busca el AnimatedSprite2D de las manos probando varios nombres
func _buscar_nodo_manos() -> AnimatedSprite2D:
	if has_node("%ManosColapso"):
		return get_node("%ManosColapso") as AnimatedSprite2D
	var nombres_posibles = ["ManosColapso", "minions hands", "Minions Hands", "MinionsHands", "minions_hands"]
	for nombre in nombres_posibles:
		var nodo = find_child(nombre, true, false)
		if nodo and nodo is AnimatedSprite2D:
			return nodo as AnimatedSprite2D
	return null

func _ready():
	add_to_group("hud")

	if blood_screen:
		blood_screen.visible = true
		blood_screen.modulate.a = 0.0
	if super_screen:
		super_screen.visible = true
		super_screen.modulate.a = 0.0

	if fuego_animado:
		fuego_animado.modulate.a = 0.0
		fuego_animado.stop()

	if super_time_sprite:
		posicion_centro_super = super_time_sprite.position
		super_time_sprite.position.y += 300.0
		super_time_sprite.modulate.a = 0.0

	if modulo_jugador:
		posicion_original_modulo = modulo_jugador.position

	if contenedor_skill_check:
		contenedor_skill_check.visible = false

	if icono_parry:
		icono_parry.modulate.a = 1.0

	_reproducir_anim_reposo_tarrito()

	if vidrio_roto:
		vidrio_roto.visible = false

	if calavera_jumpscare:
		calavera_jumpscare.visible = false
		if calavera_jumpscare.has_method("stop"): 
			calavera_jumpscare.stop()

	if fondo_negro:
		fondo_negro.visible = true 
		fondo_negro.modulate.a = 0.0

	if tinte_colapso:
		tinte_colapso.visible = true
		tinte_colapso.modulate.a = 0.0

	if label_timer_colapso:
		label_timer_colapso.visible = false
	if impact_frame_rect:
		impact_frame_rect.visible = false

	if risa_enemigo_sprite:
		risa_enemigo_sprite.visible = false
		risa_enemigo_sprite.modulate.a = 0.0
		risa_enemigo_sprite.stop()

	# NUEVO: manos ocultas al arrancar
	if manos_sprite:
		manos_sprite.visible = false
		manos_sprite.modulate.a = 0.0
		manos_sprite.stop()
	else:
		push_warning("HUD: no encontré el AnimatedSprite2D de las manos ('minions hands' / 'ManosColapso').")

	super_music_player = AudioStreamPlayer.new()
	add_child(super_music_player)
	super_music_player.bus = "SuperSong"

func _process(delta):
	_process_risa_enemigo(delta)

	if not is_instance_valid(player_ref):
		player_ref = get_tree().get_first_node_in_group("player")

	if not is_instance_valid(player_ref):
		return

	if secuencia_destruccion_hud:
		_tiempo_destruccion_hud += delta
		if modulo_jugador:
			var intensidad_temblor = clamp(_tiempo_destruccion_hud * 2.0, 0.3, 5.0)
			modulo_jugador.position = posicion_original_modulo + Vector2(randf_range(-intensidad_temblor, intensidad_temblor), randf_range(-intensidad_temblor, intensidad_temblor))
			modulo_jugador.rotation_degrees = randf_range(-intensidad_temblor * 0.12, intensidad_temblor * 0.12)
	elif temblor_post_susto_hud:
		if modulo_jugador:
			var t_susto = Time.get_ticks_msec() * 0.02
			modulo_jugador.position = posicion_original_modulo + Vector2(sin(t_susto) * 3.0, cos(t_susto * 1.4) * 3.0)
			modulo_jugador.rotation_degrees = 0.0

	var nombre_real = ""
	if "character_name" in player_ref:
		nombre_real = player_ref.character_name
	else:
		nombre_real = GameManager.personaje_elegido.capitalize()

	var nombre_bajo = nombre_real.to_lower()
	if nombre_bajo == "forerat":
		nombre_bajo = "prepucin"

	nombre_label.text = nombre_real

	if "health" in player_ref and "max_health" in player_ref:
		barra_vida.value = player_ref.health

		if barra_vida.material is ShaderMaterial:
			_actualizar_shader_vida(barra_vida.material, player_ref.health, player_ref.max_health, delta)

		if blood_screen and not secuencia_destruccion_hud:
			if player_ref.health <= 40:
				var factor_sangre = remap(player_ref.health, 0, 40, 1.0, 0.0)
				blood_screen.modulate.a = clamp(factor_sangre, 0.0, 1.0)
			else:
				blood_screen.modulate.a = move_toward(blood_screen.modulate.a, 0.0, delta * 2.0)

		if modulo_jugador and not secuencia_destruccion_hud and not temblor_post_susto_hud:
			if player_ref.health <= (player_ref.max_health * 0.35):
				if not modulo_caido:
					modulo_caido = true
					var tw_caida = create_tween()
					tw_caida.set_parallel(true)
					tw_caida.tween_property(modulo_jugador, "position:y", posicion_original_modulo.y + 25.0, 0.4).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
					tw_caida.tween_property(modulo_jugador, "rotation_degrees", -5.0, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			else:
				if modulo_caido:
					modulo_caido = false
					var tw_subida = create_tween()
					tw_subida.set_parallel(true)
					tw_subida.tween_property(modulo_jugador, "position:y", posicion_original_modulo.y, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
					tw_subida.tween_property(modulo_jugador, "rotation_degrees", 0.0, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	else:
		barra_vida.value = 100

	if "power" in player_ref and "max_power" in player_ref:
		if player_ref.is_max_mode and not super_activo:
			_activar_super_screen()

		if player_ref.is_max_mode:
			player_ref.power -= delta * 25.0 
			if player_ref.power <= 0:
				player_ref.power = 0

		if not player_ref.is_max_mode and super_activo:
			_desactivar_super_screen()

		barra_poder.value = player_ref.power
		var power_pct = clamp(player_ref.power / player_ref.max_power, 0.0, 1.0)

		if barra_poder.material is ShaderMaterial:
			barra_poder.material.set_shader_parameter("height", power_pct)
			barra_poder.material.set_shader_parameter("oheight", power_pct)
			barra_poder.material.set_shader_parameter("plane_inclined_effect", false)

			match nombre_bajo:
				"prepucin": barra_poder.material.set_shader_parameter("water_color", Color(0.2, 0.9, 0.2))
				"jane": barra_poder.material.set_shader_parameter("water_color", Color(1.0, 0.8, 0.1))
				"max": barra_poder.material.set_shader_parameter("water_color", Color(0.9, 0.1, 1.0))
				"sketch": barra_poder.material.set_shader_parameter("water_color", Color(0.1, 0.5, 1.0))
				"nubbe": barra_poder.material.set_shader_parameter("water_color", Color(0.8, 0.2, 1.0))

	var anim_objetivo = ""
	var esta_herido = false
	if "health" in player_ref and "max_health" in player_ref:
		if player_ref.health <= (player_ref.max_health * 0.5):
			esta_herido = true

	if esta_herido:
		anim_objetivo = nombre_bajo + "_hurt"
		if nombre_bajo == "prepucin":
			retrato.modulate = Color(0.2, 1.0, 0.2)
			retrato.offset = Vector2(randf_range(-2, 2), randf_range(-2, 2))
	else:
		anim_objetivo = nombre_bajo + "_normal"
		if nombre_bajo == "prepucin":
			retrato.modulate = Color(1, 1, 1)
			retrato.offset = Vector2(0, 0)

	if ultima_animacion != anim_objetivo:
		if retrato.sprite_frames.has_animation(anim_objetivo):
			retrato.play(anim_objetivo)
		else:
			var fallback = nombre_bajo + "_normal"
			if retrato.sprite_frames.has_animation(fallback):
				retrato.play(fallback)
		ultima_animacion = anim_objetivo

	if icono_parry and not parry_ejecutandose:
		var sufijo = player_ref.sufijo_control if "sufijo_control" in player_ref else ""
		var accion_parry = "parry" + sufijo

		if Input.is_action_just_pressed(accion_parry) and not skill_check_activa:
			_ejecutar_fade_parry()

	var icons_shop = $ModuloJugador/Interface/icons_shop if has_node("$ModuloJugador/Interface/icons_shop") else find_child("icons shop", true, false)
	if icons_shop:
		if icons_shop.has_node("Soda"): icons_shop.get_node("Soda").visible = ProgresoJuego.tiene_mejora_parry
		if icons_shop.has_node("Ecto"): icons_shop.get_node("Ecto").visible = ProgresoJuego.tiene_batido_ectoplasma
		if icons_shop.has_node("Vida"): icons_shop.get_node("Vida").visible = ProgresoJuego.tiene_mejora_vida
		if icons_shop.has_node("Fuerza"): icons_shop.get_node("Fuerza").visible = ProgresoJuego.tiene_mejora_fuerza
		if icons_shop.has_node("Velocidad"): icons_shop.get_node("Velocidad").visible = ProgresoJuego.tiene_mejora_vel
		if icons_shop.has_node("Shield"): icons_shop.get_node("Shield").visible = ProgresoJuego.get("tiene_shield") == true
		if icons_shop.has_node("Poison"): icons_shop.get_node("Poison").visible = ProgresoJuego.get("tiene_poison") == true

	if skill_check_activa:
		angulo_aguja += velocidad_aguja * delta
		if angulo_aguja >= 360.0:
			angulo_aguja -= 360.0

		if visual_aguja:
			visual_aguja.rotation_degrees = angulo_aguja

		var sufijo = player_ref.sufijo_control if "sufijo_control" in player_ref else ""
		var accion_parry = "parry" + sufijo

		if Input.is_action_just_pressed(accion_parry):
			_intentar_click_skill_check()


func actualizar_contador_tachito(actuales: int, requeridas: int) -> void:
	actualizar_bajas(actuales, requeridas)

func actualizar_bajas(actuales: int, requeridas: int) -> void:
	if label_cuota:
		label_cuota.text = str(actuales) + " / " + str(requeridas)

	if tarrito_basura:
		var escala_base = tarrito_basura.scale

		var tw = create_tween()
		tw.tween_property(tarrito_basura, "scale", escala_base * Vector2(1.2, 0.8), 0.05).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(tarrito_basura, "scale", escala_base, 0.15).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)

		if actuales >= requeridas:
			completar_sector()
		else:
			es_meta_cumplida = false
			_reproducir_anim_comer_tarrito()

func completar_sector() -> void:
	es_meta_cumplida = true
	if label_cuota:
		label_cuota.text = "¡OK!"

	if tarrito_basura and tarrito_basura.sprite_frames:
		if tarrito_basura.sprite_frames.has_animation("full"):
			tarrito_basura.play("full")

func _reproducir_anim_comer_tarrito() -> void:
	if not tarrito_basura or not tarrito_basura.sprite_frames: return

	var anim_comer = ""
	if tarrito_basura.sprite_frames.has_animation("comere"):
		anim_comer = "comere"
	elif tarrito_basura.sprite_frames.has_animation("kill"):
		anim_comer = "kill"

	if anim_comer != "":
		tarrito_basura.stop()
		tarrito_basura.play(anim_comer)
		if not tarrito_basura.animation_finished.is_connected(_on_tarrito_anim_finished):
			tarrito_basura.animation_finished.connect(_on_tarrito_anim_finished)
	else:
		print("⚠️ HUD: El tarrito no tiene animación 'comere' ni 'kill'.")

func _reproducir_anim_reposo_tarrito() -> void:
	if not tarrito_basura or not tarrito_basura.sprite_frames: return

	if tarrito_basura.sprite_frames.has_animation("default"):
		tarrito_basura.play("default")
	elif tarrito_basura.sprite_frames.has_animation("idle"):
		tarrito_basura.play("idle")

func _on_tarrito_anim_finished() -> void:
	if not tarrito_basura: return

	var anim_actual = tarrito_basura.animation
	if anim_actual == "comere" or anim_actual == "kill":
		if tarrito_basura.animation_finished.is_connected(_on_tarrito_anim_finished):
			tarrito_basura.animation_finished.disconnect(_on_tarrito_anim_finished)

		if es_meta_cumplida:
			if tarrito_basura.sprite_frames.has_animation("full"):
				tarrito_basura.play("full")
		else:
			_reproducir_anim_reposo_tarrito()


func iniciar_skill_check_liberacion():
	skill_check_activa = true
	progreso_liberacion = 0.0
	angulo_aguja = 0.0

	if barra_progreso_liberacion:
		barra_progreso_liberacion.value = 0.0

	if contenedor_skill_check:
		contenedor_skill_check.visible = true
		contenedor_skill_check.modulate = Color.WHITE

	if visual_aguja:
		visual_aguja.pivot_offset = Vector2(visual_aguja.size.x / 2.0, visual_aguja.size.y)
		visual_aguja.position = Vector2(87.5 - (visual_aguja.size.x / 2.0), 87.5 - visual_aguja.size.y)

	_generar_nueva_zona_exito()

func _generar_nueva_zona_exito():
	zona_inicio = randf_range(0.0, 360.0)
	zona_fin = zona_inicio + tamano_zona
	if zona_fin >= 360.0:
		zona_fin -= 360.0

	if visual_zona:
		visual_zona.pivot_offset = visual_zona.size / 2.0

		var angulo_medio = zona_inicio + (tamano_zona / 2.0)
		var angulo_medio_rad = deg_to_rad(angulo_medio - 90.0)

		var radio_orbita = 62.0 
		var centro_x = 87.5
		var centro_y = 87.5

		var posicion_orbita_x = centro_x + cos(angulo_medio_rad) * radio_orbita - (visual_zona.size.x / 2.0)
		var posicion_orbita_y = centro_y + sin(angulo_medio_rad) * radio_orbita - (visual_zona.size.y / 2.0)

		visual_zona.position = Vector2(posicion_orbita_x, posicion_orbita_y)
		visual_zona.rotation_degrees = angulo_medio

func _intentar_click_skill_check():
	var acierto = false

	if zona_inicio <= zona_fin:
		if angulo_aguja >= zona_inicio and angulo_aguja <= zona_fin:
			acierto = true
	else:
		if angulo_aguja >= zona_inicio or angulo_aguja <= zona_fin:
			acierto = true

	if acierto:
		progreso_liberacion += progreso_por_acierto
		if barra_progreso_liberacion:
			barra_progreso_liberacion.value = progreso_liberacion

		var tw = create_tween()
		tw.tween_property(visual_zona, "modulate", Color.GREEN, 0.05)
		tw.tween_property(visual_zona, "modulate", Color.WHITE, 0.05)

		if progreso_liberacion >= progreso_requerido:
			_finalizar_skill_check(true)
		else:
			_generar_nueva_zona_exito()
	else:
		progreso_liberacion = max(0.0, progreso_liberacion - (progreso_por_acierto * 0.5))
		if barra_progreso_liberacion:
			barra_progreso_liberacion.value = progreso_liberacion

		var tw = create_tween()
		tw.tween_property(contenedor_skill_check, "modulate", Color.RED, 0.05)
		tw.tween_property(contenedor_skill_check, "modulate", Color.WHITE, 0.05)

func _finalizar_skill_check(exito: bool):
	skill_check_activa = false
	var tw = create_tween()
	if exito:
		tw.tween_property(contenedor_skill_check, "scale", Vector2(1.2, 1.2), 0.1)
		tw.parallel().tween_property(contenedor_skill_check, "modulate:a", 0.0, 0.15)
	else:
		tw.tween_property(contenedor_skill_check, "modulate:a", 0.0, 0.15)

	await tw.finished
	if contenedor_skill_check:
		contenedor_skill_check.visible = false
		contenedor_skill_check.scale = Vector2.ONE

	if is_instance_valid(player_ref):
		if exito:
			var minion = player_ref.get("minion_que_agarra")
			if minion and is_instance_valid(minion) and minion.has_method("soltar_por_liberacion_jugador"):
				minion.soltar_por_liberacion_jugador()
			else:
				if player_ref.has_method("liberado_de_agarre"):
					player_ref.liberado_de_agarre()
		else:
			if player_ref.has_method("liberado_de_agarre"):
				player_ref.liberado_de_agarre()

func _ejecutar_fade_parry():
	parry_ejecutandose = true
	if sonido_parry_hud:
		sonido_parry_hud.play()

	var tw = create_tween()
	tw.tween_property(icono_parry, "modulate:a", 0.3, 0.05).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_interval(1.1)
	tw.tween_property(icono_parry, "modulate:a", 1.0, 0.25).set_trans(Tween.TRANS_LINEAR)

	await tw.finished
	parry_ejecutandose = false

func _actualizar_shader_vida(mat: ShaderMaterial, actual_hp: float, max_hp: float, delta: float):
	var fract = actual_hp / max_hp
	var current_shader_health = mat.get_shader_parameter("health")

	if current_shader_health != null:
		var vacio_previo_sanando = _vida_last_was_heal
		_vida_last_was_heal = fract > current_shader_health
		if vacio_previo_sanando != _vida_last_was_heal:
			mat.set_shader_parameter("trail", current_shader_health)

	mat.set_shader_parameter("health", fract)
	mat.set_shader_parameter("width", barra_vida.size.x)
	mat.set_shader_parameter("height", barra_vida.size.y)

	var trail = mat.get_shader_parameter("trail")
	if trail != null:
		var trail_speed = 50.0
		var dhealth = fract - trail
		if abs(dhealth) * max_hp > 0.0001:
			if dhealth >= 0.0:
				trail += delta * trail_speed / max_hp
				if trail >= fract: trail = fract
			else:
				trail -= delta * trail_speed / max_hp
				if trail <= fract: trail = fract
			mat.set_shader_parameter("trail", trail)

func _activar_super_screen():
	super_activo = true
	if super_effect_sound:
		super_effect_sound.play()

	var tween = create_tween().set_parallel(true)
	if super_screen:
		tween.tween_property(super_screen, "modulate:a", 1.0, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if fuego_animado:
		tween.tween_property(fuego_animado, "modulate:a", 1.0, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		fuego_animado.play()

	var bus_musica_index = AudioServer.get_bus_index("Musica")
	if bus_musica_index != -1:
		AudioServer.set_bus_mute(bus_musica_index, true)

	var personaje_actual = ""
	if "character_name" in player_ref:
		personaje_actual = player_ref.character_name.to_lower()
	else:
		personaje_actual = GameManager.personaje_elegido.to_lower()

	if personaje_actual == "forerat":
		personaje_actual = "prepucin"

	if musicas_super.has(personaje_actual):
		var ruta_cancion = musicas_super[personaje_actual]
		if ResourceLoader.exists(ruta_cancion):
			var cancion_recurso = load(ruta_cancion)
			if cancion_recurso:
				super_music_player.stream = cancion_recurso
				super_music_player.stream_paused = false
				super_music_player.play()

	if super_time_sprite:
		super_time_sprite.position = posicion_centro_super + Vector2(0, 400)
		super_time_sprite.modulate.a = 0.0
		super_time_sprite.play()

		if super_time_audio:
			super_time_audio.play()

		var tween_pop = create_tween().set_parallel(true)
		tween_pop.tween_property(super_time_sprite, "position:y", posicion_centro_super.y, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween_pop.tween_property(super_time_sprite, "modulate:a", 1.0, 0.2)

		var tween_fade = create_tween()
		tween_fade.tween_interval(1.1)
		tween_fade.tween_property(super_time_sprite, "position:y", posicion_centro_super.y - 350.0, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

		var tween_alpha = create_tween()
		tween_alpha.tween_interval(1.1)
		tween_alpha.tween_property(super_time_sprite, "modulate:a", 0.0, 0.2)

func _desactivar_super_screen():
	super_activo = false

	if super_music_player and super_music_player.playing:
		super_music_player.stop()

	var bus_musica_index = AudioServer.get_bus_index("Musica")
	if bus_musica_index != -1:
		AudioServer.set_bus_mute(bus_musica_index, false)

	var tween = create_tween().set_parallel(true)
	if super_screen:
		tween.tween_property(super_screen, "modulate:a", 0.0, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	if fuego_animado:
		tween.tween_property(fuego_animado, "modulate:a", 0.0, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	if fuego_animado:
		await tween.finished
		fuego_animado.stop()

func _animar_vidrio_roto():
	if not vidrio_roto or not vidrio_roto.material:
		return

	vidrio_roto.visible = true
	vidrio_roto.modulate.a = 1.0
	vidrio_roto.material.set_shader_parameter("fall_progress", 0.0)

	var tw_vidrio = create_tween()
	tw_vidrio.tween_property(vidrio_roto.material, "shader_parameter/fall_progress", 1.0, 1.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw_vidrio.tween_interval(2.0)
	tw_vidrio.tween_property(vidrio_roto.material, "shader_parameter/fall_progress", 0.15, 1.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw_vidrio.parallel().tween_property(vidrio_roto, "modulate:a", 0.5, 1.0)

func detonar_hud_final():
	ejecutar_impact_frame()
	iniciar_secuencia_risas()
	secuencia_destruccion_hud = true
	temblor_post_susto_hud = false
	_tiempo_destruccion_hud = 0.0

	if fondo_negro:
		fondo_negro.modulate.a = 1.0 
		var tw_fondo = create_tween()
		tw_fondo.tween_interval(0.1) 
		tw_fondo.tween_property(fondo_negro, "modulate:a", 0.0, 1.5).set_trans(Tween.TRANS_SINE)

	_animar_vidrio_roto()

	if calavera_jumpscare:
		calavera_jumpscare.visible = true
		calavera_jumpscare.scale = Vector2(0.8, 0.8) 

		if calavera_jumpscare.has_method("play"):
			calavera_jumpscare.play("default")

		var tw_skull = create_tween()
		tw_skull.tween_property(calavera_jumpscare, "scale", Vector2(1.2, 1.2), 0.3).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)

	var camara_3d = get_viewport().get_camera_3d()
	if camara_3d and camara_3d.has_method("iniciar_apocalipsis"):
		camara_3d.iniciar_apocalipsis()

func calmar_hud_post_susto():
	secuencia_destruccion_hud = false
	temblor_post_susto_hud = true

	if calavera_jumpscare:
		var tw_skull = create_tween()
		tw_skull.tween_property(calavera_jumpscare, "modulate:a", 0.0, 1.0)
		await tw_skull.finished
		calavera_jumpscare.visible = false
		calavera_jumpscare.modulate.a = 1.0

	var camara_3d = get_viewport().get_camera_3d()
	if camara_3d and camara_3d.has_method("detener_apocalipsis"):
		camara_3d.detener_apocalipsis()

func mostrar_temporizador_colapso(tiempo_total: float) -> void:
	if label_timer_colapso:
		label_timer_colapso.visible = true
	actualizar_timer_colapso(tiempo_total)

func actualizar_timer_colapso(tiempo_restante: float) -> void:
	if not label_timer_colapso:
		return
	var tiempo_clamp = max(0.0, tiempo_restante)
	var minutos = int(tiempo_clamp) / 60
	var segundos = int(tiempo_clamp) % 60
	var centesimas = int((tiempo_clamp - int(tiempo_clamp)) * 100)
	label_timer_colapso.text = "%01d:%02d.%02d" % [minutos, segundos, centesimas]

func ejecutar_impact_frame() -> void:
	if impact_frame_rect and impact_frame_rect.material is ShaderMaterial:
		var mat := impact_frame_rect.material as ShaderMaterial
		impact_frame_rect.visible = true
		mat.set_shader_parameter("intensity", 1.0)
		var tw = create_tween()
		tw.tween_property(mat, "shader_parameter/intensity", 0.0, 0.25)
		await tw.finished
		impact_frame_rect.visible = false

	Engine.time_scale = 0.05
	await get_tree().create_timer(0.08, true, false, true).timeout
	Engine.time_scale = 1.0

func actualizar_intensidad_colapso(intensidad: float) -> void:
	if tinte_colapso:
		tinte_colapso.modulate.a = clamp(intensidad, 0.0, 0.55)

func actualizar_tiempo_colapso(tiempo: float):
	pass

# ====================================================================
# --- RISA DE ENEMIGO (AnimatedSprite2D) DURANTE EL COLAPSO ---
# ====================================================================
func iniciar_secuencia_risas() -> void:
	if not risa_enemigo_sprite:
		push_warning("No encontré el nodo AnimatedSprite2D '%RisaEnemigo' en el HUD.")
		return
	_risas_activas = true
	_timer_risa = 0.0
	_proxima_risa = randf_range(intervalo_min_risa, intervalo_max_risa)

func _process_risa_enemigo(delta: float) -> void:
	if not _risas_activas or not risa_enemigo_sprite:
		return
	_timer_risa += delta
	if _timer_risa >= _proxima_risa:
		_timer_risa = 0.0
		_proxima_risa = randf_range(intervalo_min_risa, intervalo_max_risa)
		# NUEVO: además del intervalo random, hay un chance de que directamente no aparezca esta vez
		if randf() <= probabilidad_aparicion_risa:
			_mostrar_risa_enemigo()

func _mostrar_risa_enemigo() -> void:
	if not risa_enemigo_sprite:
		return

	risa_enemigo_sprite.visible = true
	risa_enemigo_sprite.modulate.a = 0.0

	if risa_enemigo_sprite.sprite_frames:
		var animaciones = risa_enemigo_sprite.sprite_frames.get_animation_names()
		if animaciones.size() > 0:
			var anim_a_usar = "default" if risa_enemigo_sprite.sprite_frames.has_animation("default") else animaciones[0]
			risa_enemigo_sprite.play(anim_a_usar)
		else:
			push_warning("El AnimatedSprite2D 'RisaEnemigo' no tiene animaciones en su SpriteFrames.")
	else:
		push_warning("El AnimatedSprite2D 'RisaEnemigo' no tiene un SpriteFrames asignado.")

	var tw = create_tween()
	tw.tween_property(risa_enemigo_sprite, "modulate:a", 1.0, 0.15)
	tw.tween_interval(1.0)
	tw.tween_property(risa_enemigo_sprite, "modulate:a", 0.0, 0.3)
	await tw.finished
	if is_instance_valid(risa_enemigo_sprite):
		risa_enemigo_sprite.visible = false

# ====================================================================
# --- NUEVO: MANOS DE MINIONS AL COSTADO (1 MINUTO DESPUÉS DE QUE ARRANCA EL COLAPSO) ---
# ====================================================================
func mostrar_manos_costado() -> void:
	if _manos_mostradas or not manos_sprite:
		return
	_manos_mostradas = true

	manos_sprite.visible = true
	manos_sprite.modulate.a = 0.0

	if manos_sprite.sprite_frames:
		var animaciones = manos_sprite.sprite_frames.get_animation_names()
		if animaciones.size() > 0:
			var anim_a_usar = "default" if manos_sprite.sprite_frames.has_animation("default") else animaciones[0]
			manos_sprite.play(anim_a_usar)
		else:
			push_warning("El AnimatedSprite2D de las manos no tiene animaciones en su SpriteFrames.")
	else:
		push_warning("El AnimatedSprite2D de las manos no tiene un SpriteFrames asignado.")

	# Fade in lento y se queda ahí para siempre (no hay fade out ni queue_free)
	var tw = create_tween()
	tw.tween_property(manos_sprite, "modulate:a", 1.0, duracion_fade_manos).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
