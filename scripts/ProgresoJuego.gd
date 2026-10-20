extends Node

# --- SEÑALES GLOBALES ---
signal logro_desbloqueado(id_logro: String)

# --- VARIABLES DE JUGADORES (DESBLOQUEOS Y RESCATES) ---
var max_desbloqueado = false 
var jane_desbloqueada = false
var rata_pelada_desbloqueada = false 
var nubbe_desbloqueado = false
var plasticsketch_desbloqueado = true # <--- TESTING: cambiar a false cuando termine de testear
var chosmix_desbloqueado = false
var alloy_desbloqueado = true
var tankman_desbloqueado = true
var vol_musica: float = 1.0
var vol_efectos: float = 1.0
var escala_3d: float = 1.0 # <--- RESOLUCIÓN 3D (1.0 = 100%, 0.5 = 50%)

var max_rescatado_temporal = false
var jane_rescatada_temporal = false
var prepucin_rescatado_temporal = false
var nubbe_rescatado_temporal = false
var plasticsketch_rescatado_temporal = true
var chosmix_rescatado_temporal = false
var alloy_rescatado_temporal = true
var tankman_rescatado_temporal = false

var thomas_antony_activado: bool = false

# --- LOGROS ---
var logro_fisica_inestable = false
var lider_derrotado = false      
var logro_batz_enojado = false 
var logro_meow_exe = false   
var juego_terminado = false 
var total_minions_muertos = 0 
var recompensa_insignias_obtenida = false 
var logro_glitch_vacio = false
var logro_parry_master = false
var logro_mejor_cliente: bool = false
var logro_tacho_final: bool = false
var logro_bienvenida: bool = false
var logro_sketch_desbloqueado: bool = false
var logro_max_rescatado: bool = false
var logro_jane_rescatada: bool = false
var logro_nubbe_rescatado: bool = false
var logro_forerat_rescatado: bool = false

# --- MAPA DE LOGROS ---
const LOGROS_MAPA = {
	"logro_fisica_inestable":    {"sensor": "Sensor7",  "titulo": {"es": "¡Física Inestable!",    "en": "Unstable Physics!",  "ja": "不安定な物理！"}},
	"lider_derrotado":           {"sensor": "Sensor2",  "titulo": {"es": "¡Líder Derrotado!",     "en": "Leader Defeated!",   "ja": "リーダー撃破！"}},
	"logro_batz_enojado":        {"sensor": "Sensor4",  "titulo": {"es": "¡Batz Enojado!",        "en": "Angry Batz!",        "ja": "怒りのバッツ！"}},
	"logro_meow_exe":            {"sensor": "Sensor4",  "titulo": {"es": "¡Meow.exe!",             "en": "Meow.exe!",          "ja": "Meow.exe!"}},
	"juego_terminado":           {"sensor": "Sensor3",  "titulo": {"es": "¡Juego Terminado!",      "en": "Game Over!",         "ja": "ゲームクリア！"}},
	"logro_glitch_vacio":        {"sensor": "Sensor10", "titulo": {"es": "¡Caída al Vacío!",        "en": "Falling Void!",      "ja": "虚無への落下！"}},
	"logro_parry_master":        {"sensor": "Sensor9",  "titulo": {"es": "¡Parry Master!",          "en": "Parry Master!",      "ja": "パリィマスター！"}},
	"logro_mejor_cliente":       {"sensor": "Sensor11", "titulo": {"es": "¡Mejor Cliente!",        "en": "Best Customer!",     "ja": "上客！"}},
	"logro_tacho_final":         {"sensor": "Sensor12", "titulo": {"es": "¡U are the trash!",      "en": "U are the trash!",   "ja": "君がゴミだ！"}},
	"logro_bienvenida":          {"sensor": "Sensor5",  "titulo": {"es": "¡Bienvenido!",            "en": "Welcome!",           "ja": "ようこそ！"}},
	"logro_sketch_desbloqueado": {"sensor": "Sensor8",  "titulo": {"es": "¡Sketch Desbloqueado!",  "en": "Sketch Unlocked!",   "ja": "スケッチ解放！"}},
	"logro_nubbe_rescatado":     {"sensor": "Sensor1",  "titulo": {"es": "¡Nubbe Rescatado!",       "en": "Nubbe Rescued!",     "ja": "ヌッベ救出！"}},
	"logro_max_rescatado":       {"sensor": "Sensor1",  "titulo": {"es": "¡Max Rescatado!",         "en": "Max Rescued!",       "ja": "マックス救出！"}},
	"logro_jane_rescatada":      {"sensor": "Sensor1",  "titulo": {"es": "¡Jane Rescatada!",        "en": "Jane Rescued!",      "ja": "ジェーン救出！"}},
	"logro_forerat_rescatado":   {"sensor": "Sensor13", "titulo": {"es": "¡Forerat Rescatado!",    "en": "Forerat Rescued!",   "ja": "フォレネズミ救出！"}}
}

# --- VARIABLES DE SEGURIDAD ---
var bugs_detectados = 0

# --- VARIABLES DE NIVEL Y FLUJO ---
var nivel_actual = 1
var nivel_desbloqueado = 0 
var tutorial_completado = false 
var ultima_ruta_nivel = ""
var posicion_checkpoint_guardada: Vector3 = Vector3.ZERO
var usar_checkpoint_al_cargar: bool = false
var idioma = "en"
var entradas_a_config = 0 
var shaders_activos = true 

# --- VARIABLES DE ECONOMÍA ---
var monedas = 0 
var monedas_nivel = 0

# --- VARIABLES DE LA TIENDA E ITEMS ---
var enojo_batz = 0 
var expulsado_una_vez = false 
var tiene_mejora_parry = false 
var tiene_batido_ectoplasma = false
var tiene_reloj_arena = false 
var ectoplasma_usado_en_nivel = false
var tiene_mejora_vida = false             
var tiene_mejora_fuerza = false 
var tiene_mejora_vel = false                
var tiene_despertar_dios = false 
var ultimo_dia_regalo_monedas: String = ""
var ultimo_dia_regalo_item: String = ""

# --- NUEVOS ARTÍCULOS ---
var tiene_extra_money: bool = false
var tiene_shield: bool = false
var tiene_poison: bool = false

var tiene_skin_max = false
var skin_max_equipada = false
var tiene_skin_neko = false 
var skin_neko_equipada = false 
var tiene_skin_papper = false
var skin_papper_equipada = false
var tiene_skin_lionel = false
var skin_lionel_equipada = false

# --- VARIABLES DE MINIJUEGOS (COMPRAS TIENDA) ---
var mini1 = false
var mini2 = false
var mini3 = false
var mini4 = false

# --- VARIABLES DE MINIJUEGOS (CLICKER) ---
var clicker_total_clicks = 0
var clicker_mult_cost = 100
var clicker_feto_cost = 250
var clicker_click_multiplier = 1
var clicker_auto_power = 0
var clicker_stage = 0

# --- VARIABLES DE MINIJUEGOS (PATINETA) ---
var best_score_patineta = 0

const SAVE_PATH = "user://progreso.save"

func _ready():
	cargar_partida()
	aplicar_idioma()
	call_deferred("aplicar_volumenes")
	call_deferred("aplicar_resolucion_3d")

# --- AJUSTES GRÁFICOS Y DE AUDIO ---

func aplicar_resolucion_3d():
	get_viewport().scaling_3d_scale = escala_3d

func aplicar_volumenes():
	var bus_musica = AudioServer.get_bus_index("Musica")
	if bus_musica != -1:
		AudioServer.set_bus_volume_db(bus_musica, linear_to_db(vol_musica))
		AudioServer.set_bus_mute(bus_musica, vol_musica < 0.01)
	var bus_efectos = AudioServer.get_bus_index("Efectos")
	if bus_efectos != -1:
		AudioServer.set_bus_volume_db(bus_efectos, linear_to_db(vol_efectos))
		AudioServer.set_bus_mute(bus_efectos, vol_efectos < 0.01)

# --- LÓGICA DE TRADUCCIÓN ---

func cambiar_idioma(nuevo_idioma: String):
	idioma = nuevo_idioma
	aplicar_idioma()
	guardar_partida()

func aplicar_idioma():
	if typeof(idioma) != TYPE_STRING:
		idioma = "en"
	TranslationServer.set_locale(idioma)

func get_nombre_prepucin() -> String:
	match idioma:
		"es": return "Prepucín"
		"ja": return "Forenezumi (フォレネズミ)"
		_: return "Forerat"

# --- FUNCIONES DE FLUJO ---

func reset_progreso():
	tutorial_completado = false
	monedas_nivel = 0

func otorgar_logro(id_logro: String):
	if id_logro in self and self[id_logro] == false:
		self[id_logro] = true
		guardar_partida()
		if LOGROS_MAPA.has(id_logro):
			logro_desbloqueado.emit(id_logro)

func desbloquear_logro_fisica():
	otorgar_logro("logro_fisica_inestable")

func finalizar_nivel_exitosamente():
	monedas += monedas_nivel
	monedas_nivel = 0

	if max_rescatado_temporal:
		max_desbloqueado = true
		max_rescatado_temporal = false
		otorgar_logro("logro_max_rescatado")

	if jane_rescatada_temporal:
		jane_desbloqueada = false
		jane_rescatada_temporal = false
		otorgar_logro("logro_jane_rescatada")

	if nubbe_rescatado_temporal:
		nubbe_desbloqueado = false
		nubbe_rescatado_temporal = false
		otorgar_logro("logro_nubbe_rescatado")

	if plasticsketch_rescatado_temporal:
		plasticsketch_desbloqueado = true
		plasticsketch_rescatado_temporal = false

	if chosmix_rescatado_temporal:
		chosmix_desbloqueado = true
		chosmix_rescatado_temporal = false

	if alloy_rescatado_temporal:
		alloy_desbloqueado = true
		alloy_rescatado_temporal = false

	if tankman_rescatado_temporal:
		tankman_desbloqueado = true
		tankman_rescatado_temporal = false

	var arbol = Engine.get_main_loop() as SceneTree
	if arbol:
		var escena_actual = arbol.current_scene
		if escena_actual:
			var tacho = escena_actual.find_child("*Tacho*", true, false)
			var jugador = arbol.get_first_node_in_group("player")
			if tacho and jugador:
				var distancia = tacho.global_position.distance_to(jugador.global_position)
				if distancia < 5.0 and not logro_tacho_final:
					otorgar_logro("logro_tacho_final")

	guardar_partida()

func guardar_partida():
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_var(max_desbloqueado)
		file.store_var(jane_desbloqueada)
		file.store_var(rata_pelada_desbloqueada)
		file.store_var(nubbe_desbloqueado)
		file.store_var(nivel_desbloqueado)
		file.store_var(entradas_a_config)
		file.store_var(monedas)
		file.store_var(enojo_batz)
		file.store_var(expulsado_una_vez)
		file.store_var(tiene_mejora_parry)
		file.store_var(tiene_batido_ectoplasma)
		file.store_var(tiene_reloj_arena)
		file.store_var(idioma)
		file.store_var(tutorial_completado)
		file.store_var(tiene_mejora_vida)
		file.store_var(tiene_mejora_fuerza)
		file.store_var(tiene_mejora_vel)
		file.store_var(tiene_despertar_dios)
		file.store_var(tiene_skin_max)
		file.store_var(skin_max_equipada)
		file.store_var(tiene_skin_neko)
		file.store_var(skin_neko_equipada)
		file.store_var(tiene_skin_lionel)
		file.store_var(skin_lionel_equipada)
		file.store_var(clicker_total_clicks)
		file.store_var(clicker_mult_cost)
		file.store_var(clicker_feto_cost)
		file.store_var(clicker_click_multiplier)
		file.store_var(clicker_auto_power)
		file.store_var(clicker_stage)
		file.store_var(best_score_patineta)
		file.store_var(logro_fisica_inestable)
		file.store_var(lider_derrotado)
		file.store_var(logro_batz_enojado)
		file.store_var(logro_meow_exe)
		file.store_var(juego_terminado)
		file.store_var(total_minions_muertos)
		file.store_var(recompensa_insignias_obtenida)
		file.store_var(bugs_detectados)
		file.store_var(shaders_activos)
		file.store_var(tiene_skin_papper)
		file.store_var(skin_papper_equipada)
		file.store_var(tiene_extra_money)
		file.store_var(tiene_shield)
		file.store_var(tiene_poison)
		file.store_var(vol_musica)
		file.store_var(vol_efectos)
		file.store_var(plasticsketch_desbloqueado)
		file.store_var(logro_glitch_vacio)
		file.store_var(logro_parry_master)
		file.store_var(logro_mejor_cliente)
		file.store_var(logro_tacho_final)
		file.store_var(chosmix_desbloqueado)
		file.store_var(logro_bienvenida)
		file.store_var(logro_sketch_desbloqueado)
		file.store_var(logro_max_rescatado)
		file.store_var(logro_jane_rescatada)
		file.store_var(logro_nubbe_rescatado)
		file.store_var(logro_forerat_rescatado)
		file.store_var(alloy_desbloqueado)
		file.store_var(tankman_desbloqueado)
		file.store_var(mini1)
		file.store_var(mini2)
		file.store_var(mini3)
		file.store_var(mini4)
		file.store_var(escala_3d) # <--- GUARDADO DE RESOLUCIÓN 3D
		file.close()

func cargar_partida():
	if not FileAccess.file_exists(SAVE_PATH): return
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file:
		if file.get_position() < file.get_length(): max_desbloqueado = file.get_var()
		if file.get_position() < file.get_length(): jane_desbloqueada = file.get_var()
		if file.get_position() < file.get_length(): rata_pelada_desbloqueada = file.get_var()
		if file.get_position() < file.get_length(): nubbe_desbloqueado = file.get_var()
		if file.get_position() < file.get_length(): nivel_desbloqueado = file.get_var()
		if file.get_position() < file.get_length(): entradas_a_config = file.get_var()
		if file.get_position() < file.get_length(): monedas = file.get_var()
		if file.get_position() < file.get_length(): enojo_batz = file.get_var()
		if file.get_position() < file.get_length(): expulsado_una_vez = file.get_var()
		if file.get_position() < file.get_length(): tiene_mejora_parry = file.get_var()
		if file.get_position() < file.get_length(): tiene_batido_ectoplasma = file.get_var()
		if file.get_position() < file.get_length(): tiene_reloj_arena = file.get_var()
		if file.get_position() < file.get_length():
			var temp_idioma = file.get_var()
			if typeof(temp_idioma) == TYPE_STRING:
				idioma = temp_idioma
		if file.get_position() < file.get_length(): tutorial_completado = file.get_var()
		if file.get_position() < file.get_length(): tiene_mejora_vida = file.get_var()
		if file.get_position() < file.get_length(): tiene_mejora_fuerza = file.get_var()
		if file.get_position() < file.get_length(): tiene_mejora_vel = file.get_var()
		if file.get_position() < file.get_length(): tiene_despertar_dios = file.get_var()
		if file.get_position() < file.get_length(): tiene_skin_max = file.get_var()
		if file.get_position() < file.get_length(): skin_max_equipada = file.get_var()
		if file.get_position() < file.get_length(): tiene_skin_neko = file.get_var()
		if file.get_position() < file.get_length(): skin_neko_equipada = file.get_var()
		if file.get_position() < file.get_length(): tiene_skin_lionel = file.get_var()
		if file.get_position() < file.get_length(): skin_lionel_equipada = file.get_var()
		if file.get_position() < file.get_length(): clicker_total_clicks = file.get_var()
		if file.get_position() < file.get_length(): clicker_mult_cost = file.get_var()
		if file.get_position() < file.get_length(): clicker_feto_cost = file.get_var()
		if file.get_position() < file.get_length(): clicker_click_multiplier = file.get_var()
		if file.get_position() < file.get_length(): clicker_auto_power = file.get_var()
		if file.get_position() < file.get_length(): clicker_stage = file.get_var()
		if file.get_position() < file.get_length(): best_score_patineta = file.get_var()
		if file.get_position() < file.get_length(): logro_fisica_inestable = file.get_var()
		if file.get_position() < file.get_length(): lider_derrotado = file.get_var()
		if file.get_position() < file.get_length(): logro_batz_enojado = file.get_var()
		if file.get_position() < file.get_length(): logro_meow_exe = file.get_var()
		if file.get_position() < file.get_length(): juego_terminado = file.get_var()
		if file.get_position() < file.get_length(): total_minions_muertos = file.get_var()
		if file.get_position() < file.get_length(): recompensa_insignias_obtenida = file.get_var()
		if file.get_position() < file.get_length(): bugs_detectados = file.get_var()
		if file.get_position() < file.get_length(): shaders_activos = file.get_var()
		if file.get_position() < file.get_length(): tiene_skin_papper = file.get_var()
		if file.get_position() < file.get_length(): skin_papper_equipada = file.get_var()
		if file.get_position() < file.get_length(): tiene_extra_money = file.get_var()
		if file.get_position() < file.get_length(): tiene_shield = file.get_var()
		if file.get_position() < file.get_length(): tiene_poison = file.get_var()
		if file.get_position() < file.get_length(): vol_musica = file.get_var()
		if file.get_position() < file.get_length(): vol_efectos = file.get_var()
		if file.get_position() < file.get_length(): plasticsketch_desbloqueado = file.get_var()
		if file.get_position() < file.get_length(): logro_glitch_vacio = file.get_var()
		if file.get_position() < file.get_length(): logro_parry_master = file.get_var()
		if file.get_position() < file.get_length(): logro_mejor_cliente = file.get_var()
		if file.get_position() < file.get_length(): logro_tacho_final = file.get_var()
		if file.get_position() < file.get_length(): chosmix_desbloqueado = file.get_var()
		if file.get_position() < file.get_length(): logro_bienvenida = file.get_var()
		if file.get_position() < file.get_length(): logro_sketch_desbloqueado = file.get_var()
		if file.get_position() < file.get_length(): logro_max_rescatado = file.get_var()
		if file.get_position() < file.get_length(): logro_jane_rescatada = file.get_var()
		if file.get_position() < file.get_length(): logro_nubbe_rescatado = file.get_var()
		if file.get_position() < file.get_length(): logro_forerat_rescatado = file.get_var()
		if file.get_position() < file.get_length(): alloy_desbloqueado = file.get_var()
		if file.get_position() < file.get_length(): tankman_desbloqueado = file.get_var()
		if file.get_position() < file.get_length(): mini1 = file.get_var()
		if file.get_position() < file.get_length(): mini2 = file.get_var()
		if file.get_position() < file.get_length(): mini3 = file.get_var()
		if file.get_position() < file.get_length(): mini4 = file.get_var()
		if file.get_position() < file.get_length(): escala_3d = file.get_var() # <--- CARGA DE RESOLUCIÓN 3D
		file.close()

func borrar_progreso():
	max_desbloqueado = false
	jane_desbloqueada = false
	rata_pelada_desbloqueada = false
	nubbe_desbloqueado = false
	plasticsketch_desbloqueado = false
	chosmix_desbloqueado = false
	alloy_desbloqueado = true
	tankman_desbloqueado = false
	mini1 = false
	mini2 = false
	mini3 = false
	mini4 = false
	nivel_desbloqueado = 0
	entradas_a_config = 0
	monedas = 0
	monedas_nivel = 0
	tutorial_completado = false
	enojo_batz = 0
	expulsado_una_vez = false
	tiene_mejora_parry = false
	tiene_batido_ectoplasma = false
	tiene_reloj_arena = false
	tiene_mejora_vida = false
	tiene_mejora_fuerza = false
	tiene_mejora_vel = false
	tiene_despertar_dios = false
	tiene_skin_max = false
	skin_max_equipada = false
	tiene_skin_neko = false
	skin_neko_equipada = false
	tiene_skin_lionel = false
	skin_lionel_equipada = false
	tiene_skin_papper = false
	skin_papper_equipada = false
	tiene_extra_money = false
	tiene_shield = false
	tiene_poison = false
	logro_fisica_inestable = false
	lider_derrotado = false
	logro_batz_enojado = false
	logro_meow_exe = false
	juego_terminado = false
	total_minions_muertos = 0
	recompensa_insignias_obtenida = false
	logro_glitch_vacio = false
	logro_parry_master = false
	logro_mejor_cliente = false
	logro_tacho_final = false
	logro_bienvenida = false
	logro_sketch_desbloqueado = false
	logro_max_rescatado = false
	logro_jane_rescatada = false
	logro_nubbe_rescatado = false
	logro_forerat_rescatado = false
	bugs_detectados = 0
	shaders_activos = true
	idioma = "en"
	clicker_total_clicks = 0
	clicker_mult_cost = 100
	clicker_feto_cost = 250
	clicker_click_multiplier = 1
	clicker_auto_power = 0
	clicker_stage = 0
	best_score_patineta = 0
	ultima_ruta_nivel = ""
	posicion_checkpoint_guardada = Vector3.ZERO
	usar_checkpoint_al_cargar = false
	escala_3d = 1.0 # <--- RESET DE RESOLUCIÓN
	aplicar_volumenes()
	aplicar_resolucion_3d()
	if FileAccess.file_exists(SAVE_PATH):
		var ruta_real = ProjectSettings.globalize_path(SAVE_PATH)
		DirAccess.remove_absolute(ruta_real)

func limpiar_checkpoint_temporal():
	posicion_checkpoint_guardada = Vector3.ZERO
	usar_checkpoint_al_cargar = false
	print("🧹 [PROGRESO JUEGO]: Checkpoint temporal limpiado.")
