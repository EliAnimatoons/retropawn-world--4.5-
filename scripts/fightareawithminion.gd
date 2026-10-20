extends Area3D

# --- CONFIGURACIÓN DE LA PUERTA DE SECTOR ---
@export var pared_bloqueo: Node3D 
@export var bajas_necesarias: int = 5
@export var spawner_sector: Node3D 

var bajas_actuales: int = 0
var sector_completado: bool = false
var escena_destruyendose: bool = false
var conteo_activo: bool = false # Escudo para no contar bajas al cargar el mapa

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	tree_exiting.connect(func(): escena_destruyendose = true)
	
	get_tree().node_added.connect(_on_nodo_agregado)
	
	# ESPERA DE SEGURIDAD: Dar 1.0 segundo para que el juego instancie a Sketch y limpie dummies
	await get_tree().create_timer(1.0).timeout
	if is_inside_tree() and not escena_destruyendose:
		conteo_activo = true
		bajas_actuales = 0 # Reseteamos cualquier baja fantasma que haya saltado en el arranque
		print("--- SISTEMA DE CUOTA ACTIVO Y LISTO ---")
		
		# Vinculamos a los enemigos legítimos ya presentes
		for enemigo in get_tree().get_nodes_in_group("enemies"):
			_vincular_enemigo(enemigo)

func _on_nodo_agregado(nodo: Node) -> void:
	if escena_destruyendose or not is_inside_tree(): return
	if nodo.is_in_group("enemies"):
		_vincular_enemigo(nodo)

func _vincular_enemigo(enemigo: Node) -> void:
	# IGNORAR DUMMIES O NODOS TEMPORALES DE SISTEMA
	var nombre_lowercase = enemigo.name.to_lower()
	if "dummy" in nombre_lowercase or "placeholder" in nombre_lowercase:
		return
		
	if enemigo.has_meta("vinculado_a_cuota"): return
	enemigo.set_meta("vinculado_a_cuota", true)
	
	if enemigo.has_signal("muerto"):
		enemigo.connect("muerto", _on_enemigo_muerto.bind(enemigo))
	
	if not enemigo.tree_exiting.is_connected(_on_enemigo_salio_de_arbol):
		enemigo.tree_exiting.connect(_on_enemigo_salio_de_arbol.bind(enemigo))

func _on_enemigo_muerto(_enemigo: Node) -> void:
	_procesar_baja()

func _on_enemigo_salio_de_arbol(enemigo: Node) -> void:
	if escena_destruyendose or not is_inside_tree() or not conteo_activo: return
	if enemigo.has_meta("borrado_por_sistema"): return
	_procesar_baja()

func _procesar_baja() -> void:
	if sector_completado or escena_destruyendose or not is_inside_tree() or not conteo_activo: 
		return
	
	bajas_actuales += 1
	print("--> [BAJA VÁLIDA] Progreso: ", bajas_actuales, "/", bajas_necesarias)
	
	# --- CONEXIÓN CON EL HUD Y EL TACHITO ---
	_notificar_hud_baja()
	
	call_deferred("_comprobar_condicion_victoria")

func _comprobar_condicion_victoria() -> void:
	if escena_destruyendose or not is_inside_tree() or is_queued_for_deletion() or sector_completado: 
		return
	
	var arbol = get_tree()
	if not arbol: return
	
	# Filtramos la lista de vivos para no tomar en cuenta a los dummies
	var enemigos_reales_vivos = 0
	for e in arbol.get_nodes_in_group("enemies"):
		if is_instance_valid(e) and not "dummy" in e.name.to_lower():
			enemigos_reales_vivos += 1
	
	if bajas_actuales >= bajas_necesarias or (conteo_activo and enemigos_reales_vivos == 0 and bajas_actuales > 0):
		abrir_paso()

func _on_body_entered(body: Node3D) -> void:
	if sector_completado or escena_destruyendose or not is_inside_tree(): return
	
	if body.is_in_group("player"):
		# Mostrar en HUD la cuota del sector al entrar el jugador
		_notificar_hud_baja()
		
		var arbol = get_tree()
		if not arbol: return
		
		var enemigos_reales_vivos = 0
		for e in arbol.get_nodes_in_group("enemies"):
			if is_instance_valid(e) and not "dummy" in e.name.to_lower():
				enemigos_reales_vivos += 1
		
		if bajas_actuales >= bajas_necesarias or (enemigos_reales_vivos == 0 and bajas_actuales > 0):
			abrir_paso()
		else:
			un_bloqueo_forzado()

func un_bloqueo_forzado() -> void:
	if not is_inside_tree(): return
	var faltantes = bajas_necesarias - bajas_actuales
	print("¡ACCESO DENEGADO! Faltan ", faltantes, " bajas de minions.")
	
	if has_node("/root/EfectosManager"):
		EfectosManager.play_sound("error_door", global_position)
	
	if is_instance_valid(spawner_sector) and spawner_sector.has_method("invocar_oleada_total"):
		spawner_sector.invocar_oleada_total()

func abrir_paso() -> void:
	if sector_completado or not is_inside_tree(): return
	sector_completado = true
	
	print("¡CUOTA CUMPLIDA! Sector desbloqueado.")
	
	# Ocultar o avisar al HUD que el sector se completó
	var hud_nodes = get_tree().get_nodes_in_group("hud")
	if hud_nodes.size() > 0 and hud_nodes[0].has_method("completar_sector"):
		hud_nodes[0].completar_sector()
	
	if is_instance_valid(pared_bloqueo):
		pared_bloqueo.visible = false
		for c in pared_bloqueo.get_children(true):
			if c is CollisionShape3D or c is CollisionPolygon3D:
				c.set_deferred("disabled", true)

# --- FUNCIÓN AUXILIAR PARA HABLAR CON EL HUD ---
func _notificar_hud_baja() -> void:
	var hud_nodes = get_tree().get_nodes_in_group("hud")
	if hud_nodes.size() > 0:
		var hud = hud_nodes[0]
		if hud.has_method("actualizar_contador_tachito"):
			hud.actualizar_contador_tachito(bajas_actuales, bajas_necesarias)
