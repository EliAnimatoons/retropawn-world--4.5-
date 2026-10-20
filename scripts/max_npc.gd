extends AnimatedSprite3D

var listo_para_reclamo = false
@onready var label_mensaje = $Label3D 
@onready var colision_rescatar = $CuerpoMax/CollisionShape3D

func _ready():
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
	if colision_rescatar:
		colision_rescatar.disabled = false 
	if label_mensaje:
		label_mensaje.visible = true

func take_damage(_amount, _pos):
	if not listo_para_reclamo: return
	
	listo_para_reclamo = false
	if colision_rescatar:
		colision_rescatar.set_deferred("disabled", true) 
	
	if sprite_frames.has_animation("parry"):
		play("parry")
	
	if Engine.has_singleton("EfectosManager") or get_tree().root.has_node("EfectosManager"):
		EfectosManager.parry_success_effect(global_position)
	
	# --- RESCATE TEMPORAL ---
	# No se guarda en el archivo todavía. Solo se marca como "en espera".
	ProgresoJuego.max_rescatado_temporal = true 
	print("Max rescatado temporalmente. ¡Llega al final para salvarlo!")
	
	var t = create_tween().set_parallel(true)
	t.tween_property(self, "modulate:a", 0.0, 1.5).set_delay(0.3)
	t.tween_property(self, "scale", Vector3(0.001, 0.001, 0.001), 1.5).set_delay(0.3)
	
	if label_mensaje:
		t.tween_property(label_mensaje, "modulate:a", 0.0, 0.5)
	
	t.chain().tween_callback(iniciar_final_oscuro)

func iniciar_final_oscuro():
	if get_tree().current_scene.has_method("iniciar_degradacion"):
		get_tree().current_scene.iniciar_degradacion()
	queue_free()
