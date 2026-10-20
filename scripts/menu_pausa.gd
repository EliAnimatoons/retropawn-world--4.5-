extends CanvasLayer

@onready var label_frases = %LabelFrases
@onready var timer_frases = $TimerFrases
@onready var sonido_frase = %SonidoFrase 

@onready var slider_musica = %HSliderMusica
@onready var slider_efectos = %HSliderEfectos
@onready var label_music_title = %LabelMusic
@onready var label_effects_title = %LabelEffects

# Nodos de Thomas Antony para el Menú de Pausa
@onready var thomas_ui = %ThomasAntony
@onready var thomas_theme = %ThomasAntonyTheme

@onready var boton_reiniciar = %BotonReiniciar

var frases = {
	"es": [
		"Puedes hacer parry a enemigos cuando te esten por golpear.",
		"¿Sabias que Jane ama la BossaNova?",
		"¡Sketch eres tu! T/N, ¡asi que cuídalo mucho!",
		"Prepucin es el personaje mas fuerte, solo que esta super nerfeado por el bien.",
		"Max ama a Sketch en secreto.",
		"¡Tu medidor de la barra super se carga con cada parry o golpe! ¡LLENALO!",
		"¡El codigo del juego funciona gracias a Fé y un poco de ayuda!",
		"Nunca mueres realmente in RetroPawnWorld, Final.exe siempre te revive.",
		"Meow.exe es uno de los asesinos en serie digitales mas temidos.",
		"Los minions son concientes, como lo es Final y Meow.exe.",
		"Las animaciones de combos se realizan cuando presionas mucho el ataque.",
		"Si buscas resultados distintos, no hagas siempre lo mismo.",
		"¡En la vida hay algo peor que el fracaso, y es no haber intentado nada!",
		"Un Bug no es un error, es RetroPawnWorld dándote una sorpresa inesperada.",
		"¿Sabias que el programador de RetroPawnWorld es novio de Prepucin?",
		"RetroPawnWorld se forma por muchas personas, pero solo 3 de ellos trabajan.",
		"No molestes a Batz o Meow.exe, por favor...",
		"¡Investiga todo del juego! ¡Tiene muchísimos easter eggs!",
		"RetroPawnWorld es el juego que mas interactua con el jugador, como ahora.",
		"¡Este juego esta programado con el pie! No intentes romperlo... puede morir.",
		"Prepucin entro a un restaurante y lo echaron solo por ser feo.",
		"Prepucin es el personaje con mas amorios, es todo un papucho.",
		"La mejor lucha de todas es entre Prepucin y Meow.exe.",
		"Meow.exe le tiene miedo a Prepucin, y eso que el es la rata.",
		"Meow.exe odia a Prepucin, pero no puede matarlo.",
		"Meow.exe lleva 4 Kills canonicamente, es el ProgrammerKiller mas letal.",
		"Meow.exe caza humanos y Npc, ¡ten cuidado! ¡El lo disfruta!",
		"Sketch no tiene personalidad, ¡es la tuya!",
		"Max ya estuvo en un juego parecido...",
		"Michael ya sabe con que esta lidiando...",
		"Quisiéramos colaborar con SrPelo, pero probablemente no nos escuche.",
		"¡La vida es como RetroPawnWorld, un desastre! ¡Solo tu puedes manejarlo!",
		"¡Dos latas de ParryHeal, por favor!",
		"Batz es el único personaje que nos odia pero no puede decir nada.",
		"¡Final.exe hará de todo para que salvemos las series indies!",
		"¿Por que tienes miedo a morir? Solamente es un cambio de etapa.",
		"Si el sol exploded nadie se daría cuenta, ¡asi de rapido lograrás tu meta!",
		"Te amo <3",
		"¡Amate a ti mismo! ¡Nadie te amara tanto como tu!",
		"¡La vida esta llena de imperfecciones, eso la hace única!",
		"Ser raro no es malo, es lo mas preciado que alguien puede tener.",
		"¿Porque la gente odia su cuerpo? ¡Es el único que te acompañará siempre!",
		"Los elefantes no pueden saltar, como los personajes de RetroPawnWorld.",
		"Febrero de 1865 es el único mes registrado que no tuvo luna llena.",
		"En promedio, las personas temen más a las arañas que a la muerte.",
		"Meow.exe tiene 32 músculos en cada oreja.",
		"Prepucin come basura, por eso es tan poderoso.",
		"Michael tiene una casa bastante comoda.",
		"¿Sabias que casi todas las series indies de aqui si existen?",
		"RetroPawnWorld nacio de la idea de dos desempleados.",
		"Joa es el unico artista de RetroPawnWorld que realmente trabaja.",
		"San es como el vago que todos quieren <3",
		"¡El amor que tengo hacia el juego es muchisimo!",
		"¡RetroPawnWorld se hace con puro amor a lo indie!"
	],
	"en": [
		"You can parry enemies right before they hit you.",
		"Did you know Jane loves Bossa Nova?",
		"Sketch is you! Y/N, so take good care of him!",
		"Forerat is the strongest character, he's just nerfed for everyone's safety.",
		"Max secretly loves Sketch.",
		"Your super bar charges with every parry or hit! FILL IT UP!",
		"The game's code works thanks to Faith and a little bit of help!",
		"You never truly die in RetroPawnWorld, Final.exe always brings you back.",
		"Meow.exe is one of the most feared digital serial killers.",
		"Minions are sentient, just like Final and Meow.exe.",
		"Combo animations happen when you mash the attack button.",
		"If you seek different results, don't always do the same thing.",
		"In life there is something worse than failure: not having tried at all!",
		"Bugs aren't mistakes, they are RetroPawnWorld's way of surprising you.",
		"Did you know the programmer is Forerat's boyfriend?",
		"Many people make up RetroPawnWorld, but only 3 actually work.",
		"Don't annoy Batz or Meow.exe, please...",
		"Investigate everything! The game is full of easter eggs!",
		"RetroPawnWorld interacts with the player more than any other game.",
		"This game is coded with the feet! Don't try to break it... it might die.",
		"Forerat entered a restaurant and was kicked out just for being ugly.",
		"Forerat has the most romances, he's a total heartthrob.",
		"The greatest fight of all is Forerat vs Meow.exe.",
		"Meow.exe is afraid of Forerat, even though Forerat is the rat.",
		"Meow.exe hates Forerat, but he just can't kill him.",
		"Meow.exe has 4 canonical kills, the deadliest ProgrammerKiller.",
		"Meow.exe hunts humans and NPCs, watch out! He enjoys it!",
		"Sketch has no personality, he has yours!",
		"Max has been in a similar game before...",
		"Michael already knows what he's dealing with...",
		"We'd love to collab with SrPelo, but he probably won't listen.",
		"Life is like RetroPawnWorld, a mess! Only you can handle it!",
		"Two cans of ParryHeal, please!",
		"Batz is the only character who hates us but can't say a word.",
		"Final.exe will do anything to make us save indie series!",
		"Why fear death? It's just a change of stage, be eternal!",
		"If the sun exploded, no one would notice; that's how fast you'll win!",
		"I love you <3",
		"Love yourself! No one will love you as much as you do!",
		"Life is full of imperfections, that's what makes it unique!",
		"Being weird isn't bad, it's the most precious thing someone can have.",
		"Why hate your body? It's the only one that stays with you forever!",
		"Elephants can't jump, just like RetroPawnWorld characters.",
		"February 1865 is the only month in history without a full moon.",
		"On average, people fear spiders more than death.",
		"Meow.exe has 32 muscles in each ear.",
		"Forerat eats trash, that's why he's so powerful.",
		"Michael has a pretty cozy house.",
		"Did you know almost all indie series here actually exist?",
		"RetroPawnWorld was born from the idea of two unemployed guys.",
		"Joa is the only RetroPawnWorld artist who actually works.",
		"San is like the slacker everyone loves <3",
		"I have so much love for this game!",
		"RetroPawnWorld is made with pure love for the indie scene!"
	],
	"ja": [
		"敵が攻撃してくる直前にパリィができるぞ。",
		"ジェーンがボサノバ好きだって知ってた？",
		"スケッチは君自身だ！大切にしてあげてね！",
		"プレプシン（Forerat）は最強のキャラだが、平和のために超弱体化されている。",
		"マックスは密かにスケッチのことが好きらしい。",
		"スーパーゲージはパリィや攻撃で溜まるぞ。満タンにしろ！",
		"このゲームのコードは信仰心と少しの助けで動いているんだ！",
		"この世界で本当の死はない。Final.exeがいつも蘇らせてくれるからね。",
		"Meow.exeはデジタル界で最も恐れられているシリアルキラーの一人だ。",
		"ミニオンたちにも意識がある。FinalやMeow.exeと同じようにな。",
		"攻撃ボタンを連打するとコンボアニメーションが出るぞ。",
		"違う結果を求めるなら、いつも同じことばかり繰り返すな。",
		"人生で失敗より悪いことは、何も挑戦しないことだ！",
		"バグはミスじゃない。この世界が君に贈るサプライズんだ。",
		"開発者がプレプシンの彼氏だって知ってたか？",
		"多くの人が関わっているが、実際に働いているのは3人だけだ。",
		"バッツやMeow.exeを怒らせないでくれ、頼むから…",
		"隅々まで探索しろ！イースターエッグが山ほどあるぞ！",
		"RetroPawnWorldは、今この瞬間もプレイヤーに干渉してくるゲームだ。",
		"このゲームは足でプログラミングされたんだ！壊そうとするなよ…死んじゃうから。",
		"プレプシンはレストランに入っただけで、ブサイクすぎて追い出された。",
		"プレプシンは一番のモテ男だ。まさに究極のイケメン（？）だな。",
		"史上最高の戦いはプレプシン対Meow.exe dぁ。",
		"Meow.exeはプレプシンを恐れている。ネズミの分際でな。",
		"Meow.exeはプレプシンを憎んでいるが、殺すことはできない。",
		"Meow.exeの公式キル数は4。最凶のプログラマーキラーだ。",
		"Meow.exeは人間やNPCを狩る。気をつけろ！彼はそれを楽しんでいる！",
		"スケッチに個性はない。君の個性が彼の個性だ！",
		"マックスは以前、似たようなゲームにいたことがあるらしい…",
		"マイケルは何と戦っているのか、すでに理解している…",
		"バゾンビはフライドポテトが大好きだ。理由は聞くな。",
		"SrPeloとコラボしたいけど、たぶん見向きもされないだろうな。",
		"人生はRetroPawnWorldみたいにめちゃくちゃだ！君にしか操れないぞ！",
		"パリィヒールを2缶頼む！",
		"バッツは僕らを憎んでいる唯一のキャラだが、何も言えないんだ。",
		"Final.exeはインディーシリーズを救うために何でもするだろう！",
		"なぜ死を恐れる？ それはただの段階の変化に過ぎないんだ。",
		"太陽が爆発しても誰も気づかない。それくらい速く君は目標を達成するさ！",
		"愛してるよ <3",
		"自分を愛せ！自分以上に愛してくれる人なんていないんだから！",
		"人生は不完全なものばかりだ。だからこそ唯一無二んだよ。",
		"変人であることは悪くない。それは誰にとっても一番大切な宝物だ。",
		"なぜ自分の体を嫌うんだ？ 最後まで一緒にいてくれるのは shared-body だけだぞ！",
		"ゾウはジャンプできない。このゲームのキャラと同じだな。",
		"1865年2月は、満月がなかった唯一の記録された月だ。",
		"平均して、人は死よりもクモを恐れるらしいぞ。",
		"Meow.exeの耳にはそれぞれ32個の筋肉があるんだ。",
		"プレプシンはゴミを食べる。だからあんなに強いんだ。",
		"マイケルの家はかなり居心地がいいぞ。",
		"ここに登場するインディーシリーズのほとんどが実在するって知ってた？",
		"RetroPawnWorldは2人の失業者のアイデアから生まれたんだ。",
		"Joaは実際にちゃんと働いている唯一のアーティストだ。",
		"Sanはみんなに愛される怠け者みたいな存在さ <3",
		"このゲームへの愛は計り知れないよ！",
		"RetroPawnWorldは純粋なインディー愛で作られているんだ！"
	]
}

func _ready():
	visible = false 
	process_mode = Node.PROCESS_MODE_ALWAYS 
	if timer_frases:
		timer_frases.timeout.connect(_on_timer_frases_timeout)
	actualizar_idioma_ui()
	
	# --- OCULTAR EL BOTÓN DE REINICIAR SOLO EN LA FASE DEL JEFE ---
	var escena_actual = get_tree().current_scene.name
	if escena_actual == "Batalla2D" or "Boss" in escena_actual or "batalla" in escena_actual.to_lower():
		if boton_reiniciar:
			boton_reiniciar.visible = false
			print("Botón de reiniciar ocultado específicamente para la fase de jefe.")
	else:
		if boton_reiniciar:
			boton_reiniciar.visible = true

func _input(event):
	if event.is_action_pressed("ui_cancel"):
		alternar_pausa()

func alternar_pausa():
	if get_tree() == null: return
	var nuevo_estado = !get_tree().paused
	get_tree().paused = nuevo_estado
	visible = nuevo_estado 
	
	if visible:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		
		# --- VERIFICACIÓN EASTER EGG THOMAS ANTONY ---
		if ProgresoJuego.thomas_antony_activado:
			activar_modo_thomas_antony()
		else:
			if thomas_ui: thomas_ui.visible = false
			if slider_musica: slider_musica.value = ProgresoJuego.vol_musica
			if slider_efectos: slider_efectos.value = ProgresoJuego.vol_efectos
			mostrar_frase_aleatoria()
			actualizar_idioma_ui()
			if timer_frases: timer_frases.start()
	else:
		if timer_frases: timer_frases.stop()
		ProgresoJuego.guardar_partida()
		var escena_actual = get_tree().current_scene.name
		if escena_actual == "mundo" or escena_actual == "mundo1":
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func activar_modo_thomas_antony():
	if thomas_ui:
		thomas_ui.visible = true
	
	if thomas_theme and not thomas_theme.playing:
		thomas_theme.play()
		
	if timer_frases: 
		timer_frases.stop()
		
	if label_frases:
		label_frases.text = "T H O M A S   A N T O N Y"

	# Corrompemos todos los botones y labels del menú de pausa
	corromper_textos(self)

func corromper_textos(nodo: Node):
	for hijo in nodo.get_children():
		# Ignoramos la UI del propio screamer de Thomas si existe dentro del CanvasLayer
		if thomas_ui and (hijo == thomas_ui or thomas_ui.is_ancestor_of(hijo)):
			continue
			
		if hijo is Button:
			hijo.text = "ThomasAntony"
		elif hijo is Label:
			hijo.text = "ThomasAntony"
			
		if hijo.get_child_count() > 0:
			corromper_textos(hijo)

func actualizar_idioma_ui():
	match ProgresoJuego.idioma:
		"es":
			label_music_title.text = "MÚSICA"
			label_effects_title.text = "EFECTOS"
		"ja":
			label_music_title.text = "音楽"
			label_effects_title.text = "効果音"
		_:
			label_music_title.text = "MUSIC"
			label_effects_title.text = "EFFECTS"

func mostrar_frase_aleatoria():
	var lang = ProgresoJuego.idioma
	if not frases.has(lang): lang = "en"
	var lista = frases[lang]
	var frase_elegida = lista[randi() % lista.size()]
	label_frases.text = frase_elegida
	if sonido_frase:
		sonido_frase.play()

func _on_timer_frases_timeout():
	if visible:
		mostrar_frase_aleatoria()

func _on_boton_continuar_pressed():
	alternar_pausa()

func _on_boton_reiniciar_pressed() -> void:
	limpiar_progreso_temporal()
	get_tree().paused = false 
	get_tree().reload_current_scene()

func _on_boton_menu_pressed():
	limpiar_progreso_temporal()
	get_tree().paused = false 
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	Cargador.ir_a_escena("res://menu_inicio.tscn")

func limpiar_progreso_temporal():
	ProgresoJuego.monedas_nivel = 0
	ProgresoJuego.max_rescatado_temporal = false
	ProgresoJuego.jane_rescatada_temporal = false
	ProgresoJuego.prepucin_rescatado_temporal = false
	
	ProgresoJuego.posicion_checkpoint_guardada = Vector3.ZERO
	ProgresoJuego.usar_checkpoint_al_cargar = false
	
	print("Progreso del nivel y checkpoint temporal descartados de la memoria.")

func _on_h_slider_musica_value_changed(value: float) -> void:
	var bus_index = AudioServer.get_bus_index("Musica")
	if bus_index != -1:
		AudioServer.set_bus_volume_db(bus_index, linear_to_db(value))
		AudioServer.set_bus_mute(bus_index, value < 0.01)
	ProgresoJuego.vol_musica = value

func _on_h_slider_efectos_value_changed(value: float) -> void:
	var bus_index = AudioServer.get_bus_index("Efectos")
	if bus_index != -1:
		AudioServer.set_bus_volume_db(bus_index, linear_to_db(value))
		AudioServer.set_bus_mute(bus_index, value < 0.01)
	ProgresoJuego.vol_efectos = value

func _on_h_slider_drag_ended(_value_changed: bool) -> void:
	ProgresoJuego.guardar_partida()
