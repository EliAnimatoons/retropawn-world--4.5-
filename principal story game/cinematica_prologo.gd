extends Node3D

# --- ARCHIVO DE DIÁLOGOS ---
var recurso_dialogo: DialogueResource = preload("res://addons/prologo.dialogue")

# --- CÁMARAS DEDICADAS ---
@onready var cam_mesa: Camera3D = get_node_or_null("Camaras/Camara_Mesa")
@onready var cam_plaza_general: Camera3D = get_node_or_null("Camaras/Camara_Plaza")
@onready var cam_jane: Camera3D = get_node_or_null("Camaras/Camara_Jane")
@onready var cam_batz: Camera3D = get_node_or_null("Camaras/Camara_Batz")
@onready var cam_michael: Camera3D = get_node_or_null("Camaras/Camara_Michael")
@onready var cam_nubbe_bread: Camera3D = get_node_or_null("Camaras/Camara_NubbeBread")
@onready var cam_chosmix: Camera3D = get_node_or_null("Camaras/Camara_Chosmix")
@onready var cam_sketch: Camera3D = get_node_or_null("Camaras/Camara_Sketch")
@onready var cam_max: Camera3D = get_node_or_null("Camaras/Camara_Max")
@onready var cam_tienda: Camera3D = get_node_or_null("Camaras/Camara_Tienda")

# --- UI, FADE Y BOOT ---
@onready var ui_win95: CanvasLayer = $UI_Win95
@onready var cursor_win95: Control = $UI_Win95/Cursor
@onready var texto_win95: Label = $UI_Win95/TextoEstado
@onready var fade_rect: ColorRect = get_node_or_null("UI_Win95/FadeRect")

# --- PERSONAJES MESA Y PLAZA ---
@onready var sketch_sprite: AnimatedSprite3D = get_node_or_null("Personajes/Sketch")
@onready var max_sprite: AnimatedSprite3D = get_node_or_null("Personajes/Max")
@onready var marker_max: Marker3D = get_node_or_null("MarkerMax")

@onready var jane_sprite: AnimatedSprite3D = get_node_or_null("Personajes/Jane")
@onready var batz_sprite: AnimatedSprite3D = get_node_or_null("Personajes/Batz")
@onready var michael_sprite: AnimatedSprite3D = get_node_or_null("Personajes/Michael")
@onready var nubbe_sprite: AnimatedSprite3D = get_node_or_null("Personajes/Nubbe")
@onready var bread_sprite: AnimatedSprite3D = get_node_or_null("Personajes/Bread")
@onready var chosmix_sprite: AnimatedSprite3D = get_node_or_null("Personajes/Chosmix")

# --- PERSONAJES TIENDA ---
@onready var batz_tienda_sprite: AnimatedSprite3D = get_node_or_null("Personajes/BatzTienda")
@onready var sketch_tienda_sprite: AnimatedSprite3D = get_node_or_null("Personajes/SketchTienda")

# --- MARKERS DE MOVIMIENTO ---
@onready var marker_jane_entrada: Marker3D = get_node_or_null("MarkerJane_Entrada")
@onready var marker_jane_salida: Marker3D = get_node_or_null("MarkerJane_Salida")
@onready var marker_nubbe_entrada: Marker3D = get_node_or_null("MarkerNubbe_Entrada")
@onready var marker_sketch_tienda: Marker3D = get_node_or_null("MarkerSketchTienda")

func _ready() -> void:
	if fade_rect:
		fade_rect.visible = true
		fade_rect.modulate.a = 0.0 # Transparente al inicio
	reproducir_cinematica()

func reproducir_cinematica() -> void:
	# ========================================================
	# PARTE 1: BOOT (WINDOWS 95)
	# ========================================================
	ui_win95.visible = true
	desactivar_todas_las_camaras()
	
	texto_win95.text = ""
	cursor_win95.visible = false
	await get_tree().create_timer(2.0).timeout
	
	if has_node("SFX_Boot"): $SFX_Boot.play()
	await get_tree().create_timer(1.5).timeout
	
	texto_win95.text = "RETROPAWNWORLD\nLoading..."
	await get_tree().create_timer(3.5).timeout 
	
	texto_win95.text = "Welcome."
	await get_tree().create_timer(2.5).timeout
	
	cursor_win95.visible = true
	var tween_cursor = create_tween()
	tween_cursor.tween_property(cursor_win95, "position", Vector2(400, 300), 2.5)
	await tween_cursor.finished
	
	if has_node("SFX_Click"): $SFX_Click.play()
	await get_tree().create_timer(1.0).timeout
	
	# ========================================================
	# PARTE 2: ESCENA MESA (SKETCH Y MAX EN MESA)
	# ========================================================
	ui_win95.visible = false
	activar_camara(cam_mesa)
	
	if has_node("MusicaPueblo"): $MusicaPueblo.play()
	
	if sketch_sprite: sketch_sprite.flip_h = false 
	if sketch_sprite: sketch_sprite.play("amasando")
	await get_tree().create_timer(4.5).timeout
	
	if sketch_sprite:
		sketch_sprite.play("masa_caida")
		await sketch_sprite.animation_finished 
	await get_tree().create_timer(1.5).timeout 
	
	if sketch_sprite: sketch_sprite.play("confundido")
	await get_tree().create_timer(3.5).timeout 
	
	if sketch_sprite: sketch_sprite.play("arreglando_masa")
	await get_tree().create_timer(3.5).timeout

	if max_sprite and marker_max:
		max_sprite.play("caminar")
		var tween_max = create_tween()
		tween_max.tween_property(max_sprite, "global_position", marker_max.global_position, 3.5)
		await tween_max.finished
		max_sprite.play("idle")

	await decir("max_grito")
	
	if sketch_sprite: sketch_sprite.flip_h = true 
	if max_sprite: max_sprite.play("brazos_arriba")
	await decir("max_que_haces")
	
	if sketch_sprite: sketch_sprite.play("senalar_torta")
	await get_tree().create_timer(0.5).timeout
	
	if max_sprite: max_sprite.play("idle")
	await decir("max_pregunta_torta")
	
	if sketch_sprite: sketch_sprite.play("asentir")
	await get_tree().create_timer(0.5).timeout
	
	if max_sprite: max_sprite.play("sonreir")
	await decir("max_sabia")
	
	if sketch_sprite:
		sketch_sprite.play("pegar_recipiente")
		await sketch_sprite.animation_finished 
		sketch_sprite.play("idle")
	
	await get_tree().create_timer(0.5).timeout
	if max_sprite: max_sprite.play("reir")
	await decir("max_jaja")

	# ========================================================
	# PARTE 3: CORTE A LA PLAZA CON PANORÁMICA DESDE EL CIELO
	# ========================================================
	activar_camara(cam_plaza_general)
	
	if has_node("MusicaPueblo"): $MusicaPueblo.stop()
	if has_node("MusicaPlaza") and not $MusicaPlaza.playing: $MusicaPlaza.play()
	
	if cam_plaza_general:
		var pos_final_cam = cam_plaza_general.global_position
		var rot_final_cam = cam_plaza_general.global_rotation
		
		cam_plaza_general.global_rotation.x += deg_to_rad(25.0)
		cam_plaza_general.global_position.y += 2.0
		
		var tween_cam_baja = create_tween().set_parallel(true)
		tween_cam_baja.tween_property(cam_plaza_general, "global_position", pos_final_cam, 2.5).set_trans(Tween.TRANS_SINE)
		tween_cam_baja.tween_property(cam_plaza_general, "global_rotation", rot_final_cam, 2.5).set_trans(Tween.TRANS_SINE)
		await tween_cam_baja.finished

	await get_tree().create_timer(0.5).timeout
	
	if jane_sprite and marker_jane_entrada:
		jane_sprite.play("correr")
		var tween_jane = create_tween()
		tween_jane.tween_property(jane_sprite, "global_position", marker_jane_entrada.global_position, 2.0)
		await tween_jane.finished
		jane_sprite.play("idle")
	
	await decir("jane_gente")
	
	if jane_sprite: jane_sprite.play("hablar")
	await decir("jane_noticia")
	
	if jane_sprite: jane_sprite.play("idle")
	await get_tree().create_timer(1.0).timeout
	await decir("jane_olvide")
	
	if jane_sprite and marker_jane_salida:
		jane_sprite.play("caminar")
		var tween_jane_sal = create_tween()
		tween_jane_sal.tween_property(jane_sprite, "global_position", marker_jane_salida.global_position, 2.0)
	
	activar_camara(cam_batz)
	if batz_sprite: batz_sprite.play("observar")
	await decir("batz_brillante")
	
	# ========================================================
	# PARTE 4: ENFOQUES EN LA PLAZA
	# ========================================================
	if jane_sprite and marker_jane_entrada:
		jane_sprite.global_position = marker_jane_entrada.global_position
		jane_sprite.play("idle")
	
	activar_camara(cam_jane)
	if jane_sprite: jane_sprite.play("hablar")
	await decir("jane_acorde")
	
	activar_camara(cam_michael)
	if michael_sprite: michael_sprite.play("fumar")
	await decir("michael_no")
	
	activar_camara(cam_jane)
	if jane_sprite: jane_sprite.play("confundido")
	await decir("jane_que_era")
	
	activar_camara(cam_michael)
	if michael_sprite: michael_sprite.play("fumar")
	await decir("michael_no")
		
	# --- NUBBE Y BREAD ---
	activar_camara(cam_nubbe_bread)
	
	if nubbe_sprite and marker_nubbe_entrada:
		nubbe_sprite.play("correr")
		var tween_nubbe = create_tween()
		tween_nubbe.tween_property(nubbe_sprite, "global_position", marker_nubbe_entrada.global_position, 1.5)
		await tween_nubbe.finished
		nubbe_sprite.play("idle")
	
	await decir("nubbe_bread")
	
	if bread_sprite: bread_sprite.play("timido")
	await decir("bread_si")
	
	if nubbe_sprite: nubbe_sprite.play("mostrar_objeto")
	await decir("nubbe_encontre")
	
	if bread_sprite: bread_sprite.play("idle")
	await decir("bread_ah")
	
	if nubbe_sprite: nubbe_sprite.play("orgulloso")
	await decir("nubbe_patata")
	
	if bread_sprite: bread_sprite.play("sonreir")
	await decir("bread_linda")
	
	# --- INTERACCIÓN CON MICHAEL ---
	activar_camara(cam_michael)
	if michael_sprite: michael_sprite.play("fumar")
	await get_tree().create_timer(0.5).timeout
	
	activar_camara(cam_nubbe_bread)
	if nubbe_sprite: nubbe_sprite.play("enojado")
	sacudir_camara(cam_nubbe_bread)
	await decir("nubbe_miras")
	
	activar_camara(cam_michael)
	if michael_sprite: michael_sprite.play("fumar")
	await decir("michael_nada")
	
	activar_camara(cam_nubbe_bread)
	if nubbe_sprite: nubbe_sprite.play("idle")
	await decir("nubbe_deja")
	
	activar_camara(cam_michael)
	if michael_sprite: michael_sprite.play("girar_cabeza")
	await get_tree().create_timer(0.5).timeout

	# --- CHOSMIX Y EL JUEGO ---
	activar_camara(cam_chosmix)
	if chosmix_sprite: chosmix_sprite.play("hablar")
	await decir("chosmix_jugar")
	
	activar_camara(cam_max)
	await decir("max_despues")
	
	activar_camara(cam_jane)
	await decir("jane_yo")
	
	activar_camara(cam_batz)
	await decir("batz_paso")
	
	activar_camara(cam_nubbe_bread)
	await decir("nubbe_yo")
	
	activar_camara(cam_michael)
	if michael_sprite: michael_sprite.play("negar_cabeza")
	
	activar_camara(cam_chosmix)
	await decir("chosmix_vos")
	
	activar_camara(cam_michael)
	if michael_sprite: michael_sprite.play("suspirar")
	await decir("michael_bueno")
	
	activar_camara(cam_chosmix)
	if chosmix_sprite: chosmix_sprite.play("sonreir")

	# ========================================================
	# PARTE 5: FADE OUT A NEGRO ➔ TRANSICIÓN A LA TIENDA
	# ========================================================
	ui_win95.visible = true
	var tween_fade_out = create_tween().set_parallel(true)
	
	if fade_rect:
		tween_fade_out.tween_property(fade_rect, "modulate:a", 1.0, 1.8)
	if has_node("MusicaPlaza"):
		tween_fade_out.tween_property($MusicaPlaza, "volume_db", -80.0, 1.8)
		
	await tween_fade_out.finished
	if has_node("MusicaPlaza"): $MusicaPlaza.stop()

	# ========================================================
	# PARTE 6: ESCENA DE LA TIENDA DE BATZ
	# ========================================================
	activar_camara(cam_tienda)
	
	if has_node("MusicaTienda"): $MusicaTienda.play()
	
	# Fade In (Pantalla vuelve a aclararse)
	if fade_rect:
		var tween_fade_in = create_tween()
		tween_fade_in.tween_property(fade_rect, "modulate:a", 0.0, 1.5)
		await tween_fade_in.finished
	
	# Batz limpia el mostrador
	if batz_tienda_sprite: batz_tienda_sprite.play("limpiar_mostrador")
	await get_tree().create_timer(1.5).timeout
	
	# Sketch entra caminando hasta la barra
	if sketch_tienda_sprite:
		sketch_tienda_sprite.play("caminar")
		if marker_sketch_tienda:
			var tween_sk_tienda = create_tween()
			tween_sk_tienda.tween_property(sketch_tienda_sprite, "global_position", marker_sketch_tienda.global_position, 2.0)
			await tween_sk_tienda.finished
		sketch_tienda_sprite.play("idle")
	
	# Batz lo mira
	if batz_tienda_sprite: batz_tienda_sprite.play("mirar")
	await decir("batz_otra_vez")
	
	# Sketch señala el objeto
	if sketch_tienda_sprite: sketch_tienda_sprite.play("senalar_objeto")
	await get_tree().create_timer(0.5).timeout
	
	await decir("batz_eso")
	
	# Sketch asiente
	if sketch_tienda_sprite: sketch_tienda_sprite.play("asentir")
	await get_tree().create_timer(0.5).timeout
	
	# Batz le entrega el objeto
	if batz_tienda_sprite: batz_tienda_sprite.play("entregar_objeto")
	await get_tree().create_timer(1.0).timeout
	
	# Sketch deja monedas
	if sketch_tienda_sprite: sketch_tienda_sprite.play("dejar_monedas")
	await get_tree().create_timer(0.8).timeout
	
	await decir("batz_faltan_dos")
	
	# Sketch revisa sus bolsillos
	if sketch_tienda_sprite: sketch_tienda_sprite.play("revisar_bolsillos")
	await get_tree().create_timer(1.5).timeout
	
	# Batz suspira y se lo regala
	if batz_tienda_sprite: batz_tienda_sprite.play("suspirar")
	await decir("batz_llevatelo")
	
	if batz_tienda_sprite: batz_tienda_sprite.play("sonreir")
	await decir("batz_despues_pagas")
	
	# Sketch agradece
	if sketch_tienda_sprite: sketch_tienda_sprite.play("agradecer")
	await get_tree().create_timer(1.0).timeout
	
	# Batz vuelve a limpiar
	if batz_tienda_sprite: batz_tienda_sprite.play("limpiar_mostrador")
	await get_tree().create_timer(2.0).timeout
	
	# --- FADE OUT FINAL DEL PRÓLOGO ---
	var tween_final = create_tween().set_parallel(true)
	if fade_rect:
		tween_final.tween_property(fade_rect, "modulate:a", 1.0, 2.0)
	if has_node("MusicaTienda"):
		tween_final.tween_property($MusicaTienda, "volume_db", -80.0, 2.0)
	await tween_final.finished
	
	# ¡AQUÍ PUEDES CAMBIAR DE ESCENA AL JUEGO PRINCIPAL!
	# get_tree().change_scene_to_file("res://escenas/nivel_1.tscn")

# ========================================================
# FUNCIONES AUXILIARES DE CÁMARAS Y EFECTOS
# ========================================================

func activar_camara(camara_objetivo: Camera3D) -> void:
	desactivar_todas_las_camaras()
	if camara_objetivo:
		camara_objetivo.current = true

func desactivar_todas_las_camaras() -> void:
	if cam_mesa: cam_mesa.current = false
	if cam_plaza_general: cam_plaza_general.current = false
	if cam_jane: cam_jane.current = false
	if cam_batz: cam_batz.current = false
	if cam_michael: cam_michael.current = false
	if cam_nubbe_bread: cam_nubbe_bread.current = false
	if cam_chosmix: cam_chosmix.current = false
	if cam_sketch: cam_sketch.current = false
	if cam_max: cam_max.current = false
	if cam_tienda: cam_tienda.current = false

func sacudir_camara(camara: Camera3D) -> void:
	if not camara: return
	var pos_orig = camara.h_offset
	var tween = create_tween()
	for i in range(4):
		tween.tween_property(camara, "h_offset", pos_orig + randf_range(-0.15, 0.15), 0.05)
	tween.tween_property(camara, "h_offset", pos_orig, 0.05)

# ========================================================
# FUNCIÓN DE DIÁLOGOS
# ========================================================
func decir(clave: String) -> void:
	var idioma_actual = "es"
	if ProgresoJuego and "idioma" in ProgresoJuego and ProgresoJuego.idioma:
		idioma_actual = ProgresoJuego.idioma
	
	var titulo = clave + "_" + idioma_actual
	DialogueManager.show_dialogue_balloon(recurso_dialogo, titulo)
	await DialogueManager.dialogue_ended
