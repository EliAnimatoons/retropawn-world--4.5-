extends AnimatedSprite3D

var listo_para_reclamo = false
@onready var label_mensaje = $Label3D 
@onready var colision_rescatar = get_node_or_null("CuerpoNubbe/CollisionShape3D")

func _ready():
	# --- LÓGICA DE AUTO-DESAPARICIÓN ---
	# Si ya está desbloqueada o rescatada temporalmente, se borra sola
	if ProgresoJuego.nubbe_desbloqueado or ProgresoJuego.nubbe_rescatado_temporal:
		print("Nubbe NPC: Ya rescatada, desapareciendo...")
		queue_free()
		return # Detenemos el resto del proceso

	remove_from_group("enemy")
	if colision_rescatar:
		colision_rescatar.disabled = true
	if sprite_frames.has_animation("idle"):
		play("idle")
	if label_mensaje:
		label_mensaje.visible = false

func _process(_delta):
	if listo_para_reclamo and label_mensaje and label_mensaje.visible:
		var tiempo = Time.get_ticks_msec() / 1000.0
		label_mensaje.modulate = Color.from_hsv(fmod(tiempo * 0.5, 1.0), 0.8, 1.0)
		label_mensaje.position.y = 1.2 + sin(tiempo * 3.0) * 0.1

func habilitar_reclamo():
	listo_para_reclamo = true
	add_to_group("enemy") 
	if has_node("CuerpoNubbe"):
		get_node("CuerpoNubbe").add_to_group("enemy")
	
	if colision_rescatar:
		colision_rescatar.disabled = false 
	if label_mensaje:
		label_mensaje.visible = true

func take_damage(_amount, _pos = Vector3.ZERO):
	if not listo_para_reclamo: return
	
	listo_para_reclamo = false
	if colision_rescatar:
		colision_rescatar.set_deferred("disabled", true) 
	
	if sprite_frames.has_animation("parry"):
		play("parry")
	
	# Usamos el singleton de efectos si existe
	if get_tree().root.has_node("EfectosManager"):
		get_tree().root.get_node("EfectosManager").parry_success_effect(global_position)
	
	ProgresoJuego.nubbe_rescatado_temporal = true
	
	var t = create_tween().set_parallel(true)
	t.tween_property(self, "modulate:a", 0.0, 1.5).set_delay(0.3)
	t.tween_property(self, "scale", Vector3(0.001, 0.001, 0.001), 1.5).set_delay(0.3)
	
	if label_mensaje:
		t.tween_property(label_mensaje, "modulate:a", 0.0, 0.5)
	
	t.chain().tween_callback(queue_free)
