extends Node
# =====================================================================
# TUTORIAL MANAGER (v2)
# Etapas: movimiento -> combo -> parry (con minion) -> glory kill ->
#         agarre (real) -> camino al final.
#
# - El COLAPSO lo dispara el TriggerColapso (llama a avisar_colapso()).
# - Muros invisibles: bloquean el camino hasta terminar el tutorial.
# - Jugador inmortal en este nivel (necesita el parche en Player.gd).
# - Spawns de minion en Marker3D (nunca detrás de paredes).
# =====================================================================

signal dialogo_cerrado

enum EtapaTutorial {
	MOVIMIENTO_BASICO,
	GOLPES_Y_COMBOS,
	PARRY,
	CURACION_Y_GLORY_KILL,
	AGARRE_Y_ESCAPE,
	CAMINO_AL_FINAL,
	COLAPSO_FINAL,
	COMPLETADO
}

const MINION_SCENE := preload("res://scenes/minion.tscn")

const GRACIA_DESBLOQUEO := 0.25
const TIEMPO_MOVIMIENTO_REQUERIDO := 0.8
const GOLPES_PARA_COMBO := 3
const PARRY_WINDOW_TUTORIAL := 0.45
const ATAQUES_ANTES_DE_PISTA := 3
const TIEMPO_RESPAWN_MINION := 1.0
const DISTANCIA_MINIMA_AGARRE := 1.4

# Ajustes para que el minion sea "de práctica" (sin sorpresas)
const AJUSTES_MINION := {
	"probabilidad_imparable": 0.0,
	"probabilidad_amague": 0.0,
	"probabilidad_burla": 0.0,
	"probabilidad_bloqueo": 0.0,
	"probabilidad_slide": 0.0,
	"probabilidad_llamada_refuerzos": 0.0,
	"probabilidad_canto": 0.0,
	"probabilidad_agarre": 0.0,
	"dano_normal": 3,
	"dano_berserker": 3,
	"detection_range": 12.0,
}

@export_group("Muros invisibles")
## Tamaño de los muros generados desde Marker3D del grupo "muro_tutorial_marker".
## (Se puede cambiar por marker con un Metadata llamado "tamano" de tipo Vector3.)
@export var tamano_muro_por_defecto: Vector3 = Vector3(1.0, 12.0, 24.0)
## Capa de colisión de los muros generados (tiene que coincidir con lo que el jugador "ve" como suelo/pared)
@export_flags_3d_physics var capa_muros: int = 1

var etapa_actual: EtapaTutorial = EtapaTutorial.MOVIMIENTO_BASICO

var player: Node = null
var nodo_dialogo: Node = null
var minion_tutorial: Node3D = null

var _intro_lista: bool = false
var _dialogando: bool = false
var _practica_activa: bool = false
var _al_cerrar: Callable = Callable()

var _acumulado_movimiento: float = 0.0
var _ataques_sin_parry: int = 0
var _pista_mostrada: bool = false
var _parry_window_original: float = 0.25
var _gk_visto: bool = false
var _agarre_visto: bool = false
var _respawn_pendiente: bool = false

var _muros_generados: Array[Node] = []
var _muros_existentes: Array[Node] = []
var _timer_inmortal: float = 0.0


func _ready() -> void:
	add_to_group("tutorial_manager")

	# Esperar a que termine la intro del nivel
	var mundo := get_tree().current_scene
	if mundo and mundo.has_signal("intro_terminada"):
		mundo.intro_terminada.connect(func(): _intro_lista = true)
	else:
		_intro_lista = true

	await get_tree().process_frame
	player = get_tree().get_first_node_in_group("player")
	nodo_dialogo = get_tree().current_scene.find_child("Dialogos", true, false)

	if nodo_dialogo and nodo_dialogo.has_signal("terminado"):
		if not nodo_dialogo.terminado.is_connected(_on_dialogo_terminado):
			nodo_dialogo.terminado.connect(_on_dialogo_terminado)
	else:
		push_warning("TutorialManager: no encontré el nodo 'Dialogos' o no tiene la señal 'terminado'.")

	_aplicar_inmortalidad()
	_crear_muros_invisibles()

	while not _intro_lista:
		await get_tree().process_frame

	iniciar_etapa(EtapaTutorial.MOVIMIENTO_BASICO)


# =====================================================================
# INMORTALIDAD (el jugador no puede perder vida en el tutorial)
# =====================================================================
func _aplicar_inmortalidad() -> void:
	for p in get_tree().get_nodes_in_group("player"):
		if is_instance_valid(p) and "inmortal" in p:
			p.inmortal = true


# =====================================================================
# MUROS INVISIBLES
# =====================================================================
# Dos formas de hacerlos:
#  A) Poné un Marker3D en el grupo "muro_tutorial_marker": se genera un muro ahí
#     (con la rotación del marker).
#  B) Poné tus propios StaticBody3D en el grupo "muro_tutorial": se desactivan solos.
func _crear_muros_invisibles() -> void:
	for m in get_tree().get_nodes_in_group("muro_tutorial"):
		_muros_existentes.append(m)

	for mk in get_tree().get_nodes_in_group("muro_tutorial_marker"):
		if not (mk is Node3D):
			continue
		var tam: Vector3 = mk.get_meta("tamano", tamano_muro_por_defecto)
		var cuerpo := StaticBody3D.new()
		cuerpo.name = "MuroInvisibleTutorial"
		cuerpo.collision_layer = capa_muros
		cuerpo.collision_mask = 0
		var forma := CollisionShape3D.new()
		var caja := BoxShape3D.new()
		caja.size = tam
		forma.shape = caja
		cuerpo.add_child(forma)
		get_tree().current_scene.add_child(cuerpo)
		cuerpo.global_position = mk.global_position
		cuerpo.global_rotation = mk.global_rotation
		_muros_generados.append(cuerpo)


func _abrir_muros() -> void:
	for m in _muros_generados:
		if is_instance_valid(m):
			m.queue_free()
	_muros_generados.clear()
	for m in _muros_existentes:
		if is_instance_valid(m) and m is CollisionObject3D:
			m.set_deferred("collision_layer", 0)
			m.set_deferred("collision_mask", 0)
	_muros_existentes.clear()


# =====================================================================
# DIÁLOGOS
# =====================================================================
func disparar_dialogo(claves: Array, al_cerrar: Callable = Callable()) -> void:
	_dialogando = true
	_al_cerrar = al_cerrar
	_bloquear_jugador(true)

	if nodo_dialogo and nodo_dialogo.has_method("iniciar_charla"):
		nodo_dialogo.iniciar_charla(claves)
	else:
		_on_dialogo_terminado.call_deferred()


func _on_dialogo_terminado() -> void:
	var callback := _al_cerrar
	_al_cerrar = Callable()
	await get_tree().create_timer(GRACIA_DESBLOQUEO).timeout
	_dialogando = false
	_bloquear_jugador(false)
	if callback.is_valid():
		callback.call()
	dialogo_cerrado.emit()


func _bloquear_jugador(bloquear: bool) -> void:
	if not is_instance_valid(player):
		return
	player.set("tutorial_bloqueo", bloquear)
	if bloquear:
		if player.has_method("reset_idle"):
			player.reset_idle()
		player.set("velocity", Vector3.ZERO)
		var ocupado: bool = player.get("attacking") == true or player.get("is_parrying") == true
		var spr = player.get("sprite")
		if not ocupado and spr and player.has_method("_obtener_animacion_valida"):
			var anim: String = player.skin_prefix + player.anim_prefix + "idle"
			if not spr.sprite_frames.has_animation(anim):
				anim = "idle"
			spr.play(anim)


# =====================================================================
# ETAPAS
# =====================================================================
func iniciar_etapa(nueva_etapa: EtapaTutorial) -> void:
	etapa_actual = nueva_etapa
	_practica_activa = false

	match etapa_actual:
		EtapaTutorial.MOVIMIENTO_BASICO:
			_acumulado_movimiento = 0.0
			disparar_dialogo(["tut_bienvenida", "tut_mover"], _activar_practica)

		EtapaTutorial.GOLPES_Y_COMBOS:
			disparar_dialogo(["tut_muybien", "tut_golpes"], _activar_practica)

		EtapaTutorial.PARRY:
			disparar_dialogo(["tut_parry1", "tut_parry2"], _iniciar_practica_parry)

		EtapaTutorial.CURACION_Y_GLORY_KILL:
			disparar_dialogo(["tut_gk1", "tut_gk2"], _iniciar_practica_gk)

		EtapaTutorial.AGARRE_Y_ESCAPE:
			disparar_dialogo(["tut_agarre1", "tut_agarre2"], _iniciar_practica_agarre)

		EtapaTutorial.CAMINO_AL_FINAL:
			# Los muros se abren recién cuando el jugador terminó de leer
			disparar_dialogo(["tut_final_libre"], _abrir_muros)

		_:
			pass


func _activar_practica() -> void:
	_practica_activa = true


func _process(delta: float) -> void:
	# Re-aplicar inmortalidad cada tanto (por si entra el jugador 2)
	_timer_inmortal += delta
	if _timer_inmortal >= 1.0:
		_timer_inmortal = 0.0
		_aplicar_inmortalidad()

	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")
		if player == null:
			return
	if _dialogando or not _practica_activa:
		return

	match etapa_actual:
		EtapaTutorial.MOVIMIENTO_BASICO:
			var se_mueve := Input.is_action_pressed("izquierda") or Input.is_action_pressed("derecha") \
				or Input.is_action_pressed("arriba") or Input.is_action_pressed("abajo")
			if se_mueve:
				_acumulado_movimiento += delta
			if _acumulado_movimiento >= TIEMPO_MOVIMIENTO_REQUERIDO:
				iniciar_etapa(EtapaTutorial.GOLPES_Y_COMBOS)

		EtapaTutorial.GOLPES_Y_COMBOS:
			var paso = player.get("combo_step")
			if paso != null and int(paso) >= GOLPES_PARA_COMBO:
				iniciar_etapa(EtapaTutorial.PARRY)

		EtapaTutorial.PARRY:
			_actualizar_practica_parry()

		EtapaTutorial.CURACION_Y_GLORY_KILL:
			_actualizar_practica_gk()

		EtapaTutorial.AGARRE_Y_ESCAPE:
			_actualizar_practica_agarre()

		_:
			pass


# =====================================================================
# ETAPA 3: PARRY CON MINION REAL
# =====================================================================
func _iniciar_practica_parry() -> void:
	_ataques_sin_parry = 0
	_pista_mostrada = false
	var pw = player.get("parry_window")
	if pw != null:
		_parry_window_original = float(pw)
		player.set("parry_window", PARRY_WINDOW_TUTORIAL)
	_spawn_minion_parry()
	_practica_activa = true


func _spawn_minion_parry() -> void:
	var m := _crear_minion(25, "Parry", 2.5)
	minion_tutorial = m
	if m.has_signal("ataque_inminente"):
		m.ataque_inminente.connect(_on_minion_ataca)


func _actualizar_practica_parry() -> void:
	if not _minion_vivo():
		_programar_respawn(_spawn_minion_parry)
		return
	if minion_tutorial.get("en_stun_parry") == true:
		_practica_activa = false
		player.set("parry_window", _parry_window_original)
		disparar_dialogo(["tut_parry_ok"], _tras_parry)


func _tras_parry() -> void:
	_limpiar_minion()
	iniciar_etapa(EtapaTutorial.CURACION_Y_GLORY_KILL)


func _on_minion_ataca(_m) -> void:
	if etapa_actual != EtapaTutorial.PARRY or not _practica_activa:
		return
	_ataques_sin_parry += 1
	if _ataques_sin_parry >= ATAQUES_ANTES_DE_PISTA and not _pista_mostrada:
		_pista_mostrada = true
		await get_tree().create_timer(1.2).timeout
		if etapa_actual == EtapaTutorial.PARRY and _practica_activa and not _dialogando and _minion_vivo():
			disparar_dialogo(["tut_parry_pista"])


# =====================================================================
# ETAPA 4: GLORY KILL
# =====================================================================
func _iniciar_practica_gk() -> void:
	_gk_visto = false
	_spawn_minion_gk()
	_practica_activa = true


func _spawn_minion_gk() -> void:
	var m := _crear_minion(25, "GK", 2.2)
	m.set("tutorial_congelado", true)
	m.set("health", 6) # <= 25% de 25: queda listo para ejecutar
	if m.has_method("actualizar_barra_vida"):
		m.actualizar_barra_vida()
	if m.has_method("activar_estado_ejecutable"):
		m.activar_estado_ejecutable()
	minion_tutorial = m


func _actualizar_practica_gk() -> void:
	if is_instance_valid(minion_tutorial):
		if minion_tutorial.get("siendo_ejecutado") == true:
			_gk_visto = true
			return
		if minion_tutorial.get("esta_muerto") == true:
			_programar_respawn(_spawn_minion_gk)
		return

	if _gk_visto:
		_practica_activa = false
		disparar_dialogo(["tut_gk_ok"], _tras_gk)
	else:
		_programar_respawn(_spawn_minion_gk)


func _tras_gk() -> void:
	iniciar_etapa(EtapaTutorial.AGARRE_Y_ESCAPE)


# =====================================================================
# ETAPA 5: AGARRE REAL
# El minion camina hasta el jugador (no se teletransporta al jugador) y
# cuando está cerca y no está aturdido, lo agarra.
# =====================================================================
func _iniciar_practica_agarre() -> void:
	_agarre_visto = false
	_practica_activa = true
	_spawn_minion_agarre()


func _spawn_minion_agarre() -> void:
	var m := _crear_minion(25, "Agarre", 1.8)
	minion_tutorial = m
	_forzar_agarre(m)


func _agarre_sigue_vigente() -> bool:
	return is_instance_valid(player) and etapa_actual == EtapaTutorial.AGARRE_Y_ESCAPE and _practica_activa


func _forzar_agarre(m: Node) -> void:
	await get_tree().create_timer(0.9).timeout # espera a que termine el "grow"
	for i in 60: # ~15 s de intentos
		if not is_instance_valid(m) or not _agarre_sigue_vigente():
			return
		if m.get("esta_muerto") == true:
			_programar_respawn(_spawn_minion_agarre)
			return
		if m.get("agarrando_a_sketch") == true or player.get("siendo_agarrado") == true:
			return
		var cerca: bool = m.global_position.distance_to(player.global_position) < DISTANCIA_MINIMA_AGARRE
		if cerca and m.get("is_stunned") != true and m.has_method("intentar_agarrar_a_sketch"):
			m.intentar_agarrar_a_sketch()
			if m.get("agarrando_a_sketch") == true:
				return
		await get_tree().create_timer(0.25).timeout

	# No se logró agarrar: minion nuevo
	if is_instance_valid(m):
		m.queue_free()
	if _agarre_sigue_vigente():
		_spawn_minion_agarre()


func _actualizar_practica_agarre() -> void:
	if player.get("siendo_agarrado") == true:
		_agarre_visto = true
	elif _agarre_visto:
		_practica_activa = false
		disparar_dialogo(["tut_agarre_ok"], _tras_agarre)


func _tras_agarre() -> void:
	_limpiar_minion()
	iniciar_etapa(EtapaTutorial.CAMINO_AL_FINAL)


# =====================================================================
# COLAPSO: lo llama el TriggerColapso al tocarlo (y solo ahí)
# =====================================================================
func avisar_colapso() -> void:
	if _dialogando:
		await dialogo_cerrado
	_practica_activa = false
	_limpiar_minion()
	_abrir_muros()
	etapa_actual = EtapaTutorial.COLAPSO_FINAL
	disparar_dialogo(["tut_colapso1", "tut_colapso2", "tut_colapso3"])
	await dialogo_cerrado
	etapa_actual = EtapaTutorial.COMPLETADO


# =====================================================================
# UTILIDADES DE MINION Y SPAWN
# =====================================================================
func _lado() -> float:
	var d = player.get("direccion_mirando_x")
	if d == null or float(d) == 0.0:
		return 1.0
	return float(d)


# Orden de búsqueda del punto de aparición:
#  1) Marker3D específico: "SpawnMinionParry", "SpawnMinionGK", "SpawnMinionAgarre"
#  2) Marker3D genérico: "SpawnMinionTutorial"
#  3) Junto al jugador, con raycast para no atravesar paredes
func _pos_spawn(clave: String, distancia: float) -> Vector3:
	var escena := get_tree().current_scene
	for nombre in ["SpawnMinion" + clave, "SpawnMinionTutorial"]:
		var marcador = escena.find_child(nombre, true, false)
		if marcador is Node3D:
			return marcador.global_position
	return _pos_segura_junto_al_jugador(distancia)


func _distancia_libre(lado: float, distancia: float) -> float:
	var origen: Vector3 = player.global_position + Vector3(0, 0.6, 0)
	var destino: Vector3 = origen + Vector3(lado * distancia, 0, 0)
	var q := PhysicsRayQueryParameters3D.create(origen, destino)
	if player is CollisionObject3D:
		q.exclude = [player.get_rid()]
	var hit: Dictionary = player.get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return distancia
	var d: float = origen.distance_to(hit["position"]) - 0.5
	return maxf(d, 0.0)


func _pos_segura_junto_al_jugador(distancia: float) -> Vector3:
	var lado := _lado()
	var d_pref := _distancia_libre(lado, distancia)
	var d_otro := _distancia_libre(-lado, distancia)
	if d_pref < 1.2 and d_otro > d_pref:
		lado = -lado
		d_pref = d_otro
	return player.global_position + Vector3(lado * d_pref, 0.1, 0)


func _crear_minion(vida: int, clave: String, distancia: float) -> Node3D:
	var m: Node3D = MINION_SCENE.instantiate()
	# Se configura ANTES de add_child para que max_health_ref tome esta vida
	m.set("health", vida)
	for k in AJUSTES_MINION:
		m.set(k, AJUSTES_MINION[k])
	get_tree().current_scene.add_child(m)
	m.global_position = _pos_spawn(clave, distancia)
	return m


func _minion_vivo() -> bool:
	return is_instance_valid(minion_tutorial) and minion_tutorial.get("esta_muerto") != true


func _limpiar_minion() -> void:
	if is_instance_valid(minion_tutorial):
		minion_tutorial.queue_free()
	minion_tutorial = null


func _programar_respawn(que: Callable) -> void:
	if _respawn_pendiente:
		return
	_respawn_pendiente = true
	await get_tree().create_timer(TIEMPO_RESPAWN_MINION).timeout
	_respawn_pendiente = false
	if _practica_activa and is_instance_valid(player):
		que.call()
