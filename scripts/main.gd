extends Node

const STAT_LABELS: Dictionary = {"damage":"dégâts","max_mana":"mana max.","max_hp":"vie max.","mana_regen":"mana/s","cast_speed":"cadence","cost_reduction":"économie de mana","hp_regen":"vie/s","speed":"vitesse","resistance":"résistance"}
const WORLD_SCENE: PackedScene = preload("res://scenes/world.tscn")
var world: GameWorld
var hud: GameHUD
var ui: Control
var modal: Control
var menu_background: TextureRect
var content: VBoxContainer
var modal_kind: String = ""
var pending_binding: String = ""
var options_return: String = "menu"
var grade: ColorRect
var qa_driver: Node

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Input.joy_connection_changed.connect(Controls.disconnected)
	var layer: CanvasLayer = CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	ui = Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.theme = GameTheme.create()
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(ui)
	menu_background = TextureRect.new()
	menu_background.texture = Catalog.texture("menu")
	menu_background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	menu_background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	menu_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.add_child(menu_background)
	menu_background.add_child(MenuAtmosphere.new())
	State.level_pending.connect(on_level_pending)
	get_tree().auto_accept_quit = false
	show_menu()
	if OS.has_feature("editor") and State.qa and "--qa-playthrough" in OS.get_cmdline_user_args():
		qa_driver = load("res://tests/playthrough.gd").new()
		add_child(qa_driver)
		qa_driver.call_deferred("start",self)
	elif OS.has_feature("editor") and State.qa and "--qa-visual" in OS.get_cmdline_user_args():
		qa_driver = load("res://tests/visual_qa.gd").new()
		add_child(qa_driver)
		qa_driver.call_deferred("start",self)
	elif OS.has_feature("editor") and State.qa and "--qa-floor" in OS.get_cmdline_user_args():
		var args: PackedStringArray = OS.get_cmdline_user_args()
		var index: int = args.find("--qa-floor")
		State.fresh(77331)
		State.learn("fire")
		State.learn("explode")
		State.learn("regen")
		State.learn("shield")
		State.run.floor = clampi(int(args[index+1]),1,13)
		State.run.return_floor = State.run.floor
		State.run.position = Dungeon.generate(State.run.seed,State.run.floor).entry
		start_game()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if is_instance_valid(world) and not State.run.dead:
			world.snapshot()
			State.save_game()
		quit_game()

func _process(_delta: float) -> void:
	if grade: grade.material.set_shader_parameter("brightness",State.options.brightness)

func _input(event: InputEvent) -> void:
	Controls.observe(event)
	if pending_binding.begins_with("pad:") and event is InputEventJoypadButton and event.pressed:
		State.options.pad_bindings[pending_binding.trim_prefix("pad:")] = event.button_index
		pending_binding = ""
		Controls.setup(State.options.bindings,State.options.pad_bindings)
		State.save_options()
		show_options()
		get_viewport().set_input_as_handled()
		return
	if not pending_binding.is_empty() and not pending_binding.begins_with("pad:") and event is InputEventKey and event.pressed and not event.echo:
		State.options.bindings[pending_binding] = event.physical_keycode
		pending_binding = ""
		Controls.setup(State.options.bindings,State.options.pad_bindings)
		State.save_options()
		show_options()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("pause") or (event.is_action_pressed("ui_cancel") and not modal_kind.is_empty()):
		if modal_kind in ["level","death","victory","initial"]: return
		if not modal_kind.is_empty():
			if is_instance_valid(world): close_modal()
			else: show_menu()
		elif is_instance_valid(world): show_pause()
		get_viewport().set_input_as_handled()
	if not is_instance_valid(world) or not modal_kind.is_empty(): return
	if event.is_action_pressed("inventory"): show_inventory(false)
	if event.is_action_pressed("skills"): show_skills()
	if event.is_action_pressed("map"): show_map()

func destroy_modal() -> void:
	if is_instance_valid(modal):
		ui.remove_child(modal)
		modal.queue_free()
	modal = null

func close_modal() -> void:
	destroy_modal()
	modal_kind = ""
	get_tree().paused = false
	if is_instance_valid(world) and not State.run.pending.is_empty(): show_level()

func panel(title: String, subtitle: String = "", kind: String = "general", width: float = 940) -> VBoxContainer:
	destroy_modal()
	modal_kind = kind
	get_tree().paused = is_instance_valid(world)
	if get_tree().paused: Sound.stop_world()
	modal = Control.new()
	modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.add_child(modal)
	var dark: ColorRect = ColorRect.new()
	dark.color = Color(0.015,0.018,0.024,0.88)
	dark.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal.add_child(dark)
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal.add_child(center)
	var box: PanelContainer = PanelContainer.new()
	box.custom_minimum_size = Vector2(minf(width,get_viewport().get_visible_rect().size.x-80),0)
	var frame: StyleBoxFlat = GameTheme.panel(Color("101113"),Color("897048"),28)
	frame.border_width_top = 3
	frame.shadow_color = Color(0,0,0,0.65)
	frame.shadow_size = 24
	box.add_theme_stylebox_override("panel",frame)
	center.add_child(box)
	var outer: VBoxContainer = VBoxContainer.new()
	outer.add_theme_constant_override("separation",14)
	box.add_child(outer)
	var header: HBoxContainer = HBoxContainer.new(); outer.add_child(header)
	var titles: VBoxContainer = VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL; header.add_child(titles)
	var sections: Dictionary = {"inventory":"ÉQUIPEMENT", "skills":"ARTS ARCANES", "merchant":"LE COMPTOIR", "teacher":"LE MAÎTRE", "level":"ASCENSION", "pause":"SANCTUAIRE", "options":"PRÉFÉRENCES", "new":"UN NOUVEAU DESTIN", "initial":"L’INITIATION", "map":"CARTOGRAPHIE", "death":"FIN DE L’ASCENSION", "victory":"L’EXAMEN EST ACHEVÉ", "credits":"LES ARTISANS"}
	label(titles,sections.get(kind,"LA TOUR DES CENDRES"),12,GameTheme.GOLD)
	var heading: Label = label(titles,title,30,GameTheme.IVORY)
	GameTheme.heading(heading)
	if not kind in ["level","death","victory","initial"]:
		var close: Button = button(header,"×",func()->void:
			if kind=="options" and options_return=="pause" and is_instance_valid(world): show_pause()
			elif is_instance_valid(world): close_modal()
			else: show_menu())
		close.custom_minimum_size = Vector2(44,44)
		close.size_flags_horizontal = Control.SIZE_SHRINK_END
		close.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		close.alignment = HORIZONTAL_ALIGNMENT_CENTER
		close.tooltip_text = "Fermer"
	if not subtitle.is_empty(): label(outer,subtitle,16,GameTheme.MUTED)
	outer.add_child(UIOrnament.new())
	if kind in ["inventory","skills","map"]:
		var nav: HBoxContainer = HBoxContainer.new(); outer.add_child(nav)
		for tab: Array in [["inventory","Inventaire",show_inventory],["skills","Grimoire",show_skills],["map","Carte",show_map]]:
			var item: Button = button(nav,tab[1],tab[2])
			item.alignment = HORIZONTAL_ALIGNMENT_CENTER
			if kind==tab[0]: item.add_theme_stylebox_override("normal",GameTheme.panel(Color("34291a"),GameTheme.GOLD,14))
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0,minf(285 if kind in ["pause","death","teacher"] else (590 if kind in ["level","initial","skills"] else 470),get_viewport().get_visible_rect().size.y-310))
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(scroll)
	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation",14)
	scroll.add_child(content)
	GameTheme.enter(box)
	return content

func label(parent: Node, text: String, size: int = 19, color: Color = Color("e5dcc8")) -> Label:
	var l: Label = Label.new()
	l.text = tr(text)
	l.add_theme_font_size_override("font_size",size)
	l.add_theme_color_override("font_color",color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(l)
	return l

func button(parent: Node, text: String, action: Callable, disabled: bool = false, icon_id: String = "") -> Button:
	var b: Button = Button.new()
	b.text = tr(text)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size.y = 48
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.disabled = disabled
	if not icon_id.is_empty():
		b.icon = Catalog.texture(icon_id)
		b.expand_icon = true
		b.add_theme_constant_override("icon_max_width",38)
	b.pressed.connect(func()->void: Sound.play("ui");action.call())
	parent.add_child(b)
	if parent.get_child_count()==1: call_deferred("safe_focus",weakref(b))
	return b

func focus_first(parent: Node) -> bool:
	for child: Node in parent.get_children():
		if child is Button and not child.disabled:
			call_deferred("safe_focus",weakref(child))
			return true
		if focus_first(child): return true
	return false

func show_menu() -> void:
	Sound.stop_world()
	Sound.set_music("menu")
	get_tree().paused = false
	if is_instance_valid(world):
		world.queue_free()
		world = null
	if is_instance_valid(hud): hud.queue_free()
	if is_instance_valid(grade): grade.get_parent().queue_free();grade = null
	destroy_modal()
	modal_kind = "menu"
	menu_background.show()
	modal = Control.new()
	modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.add_child(modal)
	var shade: ColorRect = ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material: ShaderMaterial = ShaderMaterial.new()
	var shader: Shader = Shader.new()
	shader.code = "shader_type canvas_item; void fragment(){COLOR=vec4(0.015,0.018,0.023,(1.0-smoothstep(0.0,0.65,UV.x))*0.65);}"
	material.shader = shader; shade.material = material; modal.add_child(shade)
	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left",90)
	margin.add_theme_constant_override("margin_top",78)
	margin.add_theme_constant_override("margin_bottom",38)
	modal.add_child(margin)
	var column: VBoxContainer = VBoxContainer.new()
	column.custom_minimum_size.x = 480
	column.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	column.add_theme_constant_override("separation",14)
	margin.add_child(column)
	label(column,"U N  E X A M E N .   T R E I Z E  É T A G E S .",12,GameTheme.GOLD)
	var title: Label = label(column,"LA TOUR\nDES CENDRES",57)
	GameTheme.heading(title)
	title.add_theme_constant_override("outline_size",2)
	title.add_theme_color_override("font_outline_color",Color("0a0c0f"))
	column.add_child(UIOrnament.new())
	label(column,"Le dernier cours de magie commence ici.",18,Color("bab1a2"))
	var space: Control = Control.new();space.custom_minimum_size.y = 27;column.add_child(space)
	var saved: Dictionary = SaveStore.read_save(State.save_path)
	var valid: bool = State.valid_payload(saved) and not saved.run.dead
	var resume: Button = button(column,"Continuer l’ascension",continue_game,not valid)
	var fresh: Button = button(column,"Nouvelle partie",show_new)
	for b: Button in [resume,fresh]:
		b.custom_minimum_size.y = 58
		b.add_theme_font_override("font",GameTheme.TITLE)
		b.alignment = HORIZONTAL_ALIGNMENT_CENTER
	var primary: Button = resume if valid else fresh
	primary.add_theme_stylebox_override("normal",GameTheme.panel(Color("372a1b"),GameTheme.GOLD,16))
	if FileAccess.file_exists(State.save_path) and not valid:
		label(column,"Cette ascension est terminée ou sa sauvegarde indisponible.",14,GameTheme.MUTED)
	var ornament: UIOrnament = UIOrnament.new();column.add_child(ornament)
	for entry: Array in [["Options et commandes",func()->void:options_return="menu";show_options()],["Crédits",show_credits],["Quitter",quit_game]]:
		var b: Button = button(column,entry[0],entry[1])
		b.custom_minimum_size.y = 42
		b.alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.add_theme_stylebox_override("normal",GameTheme.panel(Color(0,0,0,0),Color(0,0,0,0),9))
	var stretch: Control = Control.new();stretch.size_flags_vertical=Control.SIZE_EXPAND_FILL;column.add_child(stretch)
	label(column,"LA TOUR DES CENDRES    /    CHAPITRE I",12,GameTheme.GOLD)
	label(column,"VERSION 0.2  ·  UNE ASCENSION EN SOLITAIRE",11,Color("8e887d"))
	focus_first(column)
	GameTheme.enter(column)

func show_new() -> void:
	var v: VBoxContainer = panel("Une nouvelle ascension","Un mage, quatre éléments et une tour qui ne vous attendait pas.","new",770)
	label(v,"Difficulté")
	var choice: OptionButton = OptionButton.new()
	for i: int in range(5):
		choice.add_item(Catalog.definition("campaign").values.difficulties[i])
		choice.set_item_disabled(i,i>State.unlocked)
	v.add_child(choice)
	var hardcore: CheckBox = CheckBox.new()
	hardcore.text = "Hardcore — une seule vie, mort définitive"
	v.add_child(hardcore)
	label(v,"Mode normal : reprise au dernier point de sauvegarde d’étage ou de portail. Les actions depuis ce point sont annulées. Le mode hardcore interdit toute reprise après la mort.",17)
	label(v,"Une nouvelle partie remplace l’ascension actuelle. Les difficultés débloquées et les options sont conservées.",16,Color("bda98a"))
	button(v,"Commencer",func()->void:State.fresh(0,choice.selected,hardcore.button_pressed or choice.selected==4);State.mark_checkpoint();State.save_game();start_game())
	button(v,"Retour",show_menu)
	focus_first(v)

func continue_game() -> void:
	if State.load_game():
		start_game()
		if State.run.victory: show_victory()
	else:
		var v: VBoxContainer = panel("Sauvegarde indisponible",SaveStore.last_error)
		button(v,"Retour",show_menu)

func start_game() -> void:
	close_modal()
	menu_background.hide()
	world = WORLD_SCENE.instantiate() as GameWorld
	world.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(world)
	world.interaction.connect(on_interaction)
	world.died.connect(show_death)
	world.victory.connect(show_victory)
	hud = GameHUD.new()
	hud.world = world
	ui.add_child(hud)
	hud.menu_requested.connect(on_hud_menu)
	make_grade()
	if not State.run.pending.is_empty(): show_level()

func on_hud_menu(kind: String) -> void:
	match kind:
		"inventory": show_inventory()
		"skills": show_skills()
		"map": show_map()
		"pause": show_pause()

func make_grade() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	layer.layer = 3
	add_child(layer)
	grade = ColorRect.new()
	grade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	grade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader: Shader = Shader.new()
	shader.code = "shader_type canvas_item; uniform sampler2D screen_texture : hint_screen_texture, filter_linear; uniform float brightness = 1.0; void fragment(){vec3 c=texture(screen_texture,SCREEN_UV).rgb; float v=smoothstep(0.2,0.79,length((SCREEN_UV-0.5)*vec2(1.0,0.9)));COLOR=vec4(c*(1.0-v*0.52)*brightness,1.0);}"
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = shader
	grade.material = material
	layer.add_child(grade)

func on_interaction(kind: String) -> void:
	match kind:
		"initial": show_initial()
		"merchant": show_merchant()
		"teacher": show_teacher()

# Illustrated choices share the same material and typography across every menu.
func choice_card(parent: Node, title: String, description: String, icon_id: String, action: Callable, note: String = "", disabled: bool = false) -> VBoxContainer:
	var box: PanelContainer = PanelContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_stylebox_override("panel",GameTheme.panel(Color("19191a"),Color("443b2f"),18))
	parent.add_child(box)
	var body: VBoxContainer = VBoxContainer.new();box.add_child(body)
	var icon: TextureRect = TextureRect.new()
	icon.texture = Catalog.skill_texture(icon_id)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(0,54)
	body.add_child(icon)
	var heading: Label = label(body,title,19,GameTheme.IVORY)
	GameTheme.heading(heading)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(UIOrnament.new())
	var text: Label = label(body,description,16,GameTheme.MUTED)
	text.custom_minimum_size.y = 40
	text.size_flags_vertical = Control.SIZE_FILL
	if not note.is_empty(): label(body,note,14,GameTheme.GOLD)
	var select: Button = button(body,"Choisir",action,disabled)
	select.alignment = HORIZONTAL_ALIGNMENT_CENTER
	return body

func add_skill_details(body: VBoxContainer, id: String, compare: bool = true, acquiring: bool = false) -> void:
	var details: Label = label(body,SkillDetails.text(id,compare,acquiring),14,GameTheme.IVORY)
	details.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# Keep the action after its consequences, inside the scrollable card.
	for child: Node in body.get_children():
		if child is Button and child.text=="Choisir":
			body.move_child(details,child.get_index())
			break

func section(parent: Node, title: String) -> void:
	var heading: Label = label(parent,title,16,GameTheme.GOLD)
	GameTheme.heading(heading)

func show_initial() -> void:
	var v: VBoxContainer = panel("Votre première étincelle","Orme : Choisissez bien. Vous pourrez apprendre d’autres éléments pendant l’ascension.","initial",1180)
	var grid: GridContainer = GridContainer.new();grid.columns = 4;v.add_child(grid)
	for id: String in Catalog.ids("primary"):
		var d: ContentDefinition = Catalog.definition(id)
		var body: VBoxContainer = choice_card(grid,d.title,d.description,id,func()->void:State.learn(id);world.snapshot();State.mark_checkpoint("Première magie apprise");State.save_game();close_modal())
		add_skill_details(body,id,false,true)
	focus_first(v)

func on_level_pending() -> void:
	if modal_kind.is_empty(): call_deferred("show_level")

func show_level() -> void:
	if State.run.pending.is_empty(): return
	Sound.play("level_up")
	var offered: Array = State.offers()
	var v: VBoxContainer = panel("Niveau %d — choisissez votre savoir"%int(State.run.pending[0]),"Temps suspendu · %d choix en attente. DPS théorique par ennemi, avant résistance, à mana disponible. Portée en unités (u)."%State.run.pending.size(),"level",1140)
	var reroll_button: Button = button(v,"Relancer les choix · 1 éclat (%d disponibles)" % State.run.get("insight",1),func()->void:
		world.snapshot()
		if State.reroll(): show_level(),not State.can_reroll())
	reroll_button.tooltip_text = "Un éclat offert au départ, puis un par gardien principal. Les choix précédents sont évités ; une fusion unique ou un choix sans alternative peut revenir."
	label(v,"Éclats de savoir : 1 au départ, puis 1 par gardien principal. Une relance coûte 1 éclat.",14,GameTheme.MUTED)
	if not State.can_reroll(): label(v,"Plus d’éclats disponibles." if State.run.get("insight",1)<=0 else "Aucune autre amélioration éligible.",14,GameTheme.MUTED)
	var grid: GridContainer = GridContainer.new();grid.columns = 3;v.add_child(grid)
	for id: String in offered:
		var d: ContentDefinition = Catalog.definition(id)
		var note: String = ""
		var body: VBoxContainer = choice_card(grid,d.title,d.description,d.id,func()->void:
			if State.choose(id):
				world.player.refresh_stats()
				world.snapshot()
				State.save_game()
				close_modal(),note)
		add_skill_details(body,id,true)
	if offered.is_empty():
		button(v,"Savoirs maîtrisés — poursuivre",func()->void:State.run.pending.pop_front();State.run.offers=[];close_modal())
		focus_first(v)
	else: focus_first(grid)

func show_pause() -> void:
	var v: VBoxContainer = panel("Un instant de répit","La partie est en pause.","pause",620)
	button(v,"Reprendre",close_modal)
	button(v,"Sauvegarder",func()->void:world.snapshot();var ok:bool=State.save_game();label(v,"Partie sauvegardée." if ok else SaveStore.last_error))
	button(v,"Options et commandes",func()->void:options_return="pause";show_options())
	button(v,"Sauvegarder et quitter au menu",func()->void:world.snapshot();State.save_game();close_modal();show_menu())
	focus_first(v)

func show_teacher() -> void:
	if State.run.active.is_empty(): show_initial();return
	var v: VBoxContainer = panel("Le savoir d’Orme","« Les livres coûtent cher. L’ignorance, davantage. »","teacher")
	var price: int = 80+int(State.run.wisdom)*65
	label(v,"Acheter de la sagesse propose trois améliorations éligibles à votre niveau. Coût : %d or."%price)
	button(v,"Acheter une leçon · %d or"%price,func()->void:
		if State.run.gold>=price:
			State.run.gold-=price;State.run.wisdom+=1;State.run.pending.append(State.run.level);close_modal(),State.run.gold<price)
	button(v,"Consulter le grimoire",show_skills)
	label(v,"Fusions : apprenez deux éléments. Aux niveaux multiples de cinq, un assemblage peut être proposé. Il conserve les rangs et sous-compétences du moment ; une nouvelle fusion actualise ce savoir.",18)
	button(v,"Retour au village",close_modal)
	focus_first(v)

func show_merchant() -> void:
	var v: VBoxContainer = panel("L’échoppe de Basile","%d or · Bâtons, anneaux et provisions. Le stock appartient à cette ascension."%State.run.gold,"merchant",1080)
	var row: HBoxContainer = HBoxContainer.new();v.add_child(row)
	button(row,"Potion de vie · 18 or",func()->void:buy_potion("hp"),State.run.gold<18,"health")
	button(row,"Potion de mana · 18 or",func()->void:buy_potion("mp"),State.run.gold<18,"mana")
	button(v,"Vendre vos objets",func()->void:show_inventory(true))
	section(v,"Objets enchantés")
	for item: Dictionary in State.run.shop:
		var item_box: PanelContainer = PanelContainer.new();v.add_child(item_box)
		item_box.add_theme_stylebox_override("panel",GameTheme.panel(Color("18181a"),rarity_color(item.rarity).darkened(0.6),12))
		var item_body: VBoxContainer = VBoxContainer.new();item_box.add_child(item_body)
		button(item_body,"%s · %d or"%[item.name,item.price],func()->void:State.buy(item.uid);Sound.play("loot");show_merchant(),State.run.gold<item.price or State.run.inventory.size()>=48,"staff" if item.slot=="staff" else "ring")
		label(item_body,item_description(item),16,rarity_color(item.rarity))
	button(v,"Retour au village",close_modal)
	focus_first(v)

func buy_potion(kind: String) -> void:
	if State.run.gold<18: return
	State.run.gold-=18
	State.run[kind+"_potions"]+=1
	Sound.play("loot")
	show_merchant()

func rarity_color(rarity: int) -> Color:
	return [Color("bdc9c9"),Color("78bcd8"),Color("c7a1e5")][clampi(rarity,0,2)]

func item_description(item: Dictionary) -> String:
	var bits: Array[String] = []
	for key: String in item.get("bonuses",{}):
		bits.append(Equipment.bonus_text(key,float(item.bonuses[key])))
	return ["Enchanté","Rare","Épique"][int(item.rarity)]+" · "+" / ".join(bits)

func compare_item(item: Dictionary, slot: String = "") -> String:
	if slot.is_empty(): slot = "staff" if item.slot=="staff" else "ring1"
	var old: Dictionary = State.find_item(State.run.equipped[slot])
	var changes: Array[String] = []
	var keys: Array = item.bonuses.keys()
	for key: String in old.get("bonuses",{}):
		if not key in keys: keys.append(key)
	for key: String in keys:
		var diff: float = float(item.bonuses.get(key,0))-float(old.get("bonuses",{}).get(key,0))
		if not is_zero_approx(diff): changes.append(Equipment.bonus_text(key,diff))
	return "Remplace "+("le bâton" if slot=="staff" else "l’anneau "+slot[-1])+" : "+(", ".join(changes) if not changes.is_empty() else "bonus identiques")

func show_inventory(selling: bool = false) -> void:
	var v: VBoxContainer = panel("Votre sac" if not selling else "Vendre à Basile","%d / 48 objets · %d or · Un bâton et deux anneaux."%[State.run.inventory.size(),State.run.gold],"inventory",1120)
	var s: Dictionary = State.stats()
	label(v,"Éclats de savoir : %d" % State.run.get("insight",1),16,GameTheme.GOLD)
	label(v,"Vie %.0f · Mana %.0f · Régén. %.1f/s · Dégâts +%.0f puis ×%.2f · Coût ×%.2f"%[s.max_hp,s.max_mana,s.mana_regen,s.flat_damage,s.damage,1-s.cost_reduction],18)
	label(v,"Or +%.0f %% · XP +%.0f %% · Poison −%.0f %% · Cadence ×%.2f"%[s.gold_bonus*100,s.xp_bonus*100,s.poison_resistance*100,s.cast_speed],16,GameTheme.MUTED)
	var powers: Array[String] = []
	if s.telekinesis: powers.append("Télékinésie : ramassage étendu")
	if s.meditation: powers.append("Méditation : mana ×4 au repos")
	if s.mental_focus: powers.append("Concentration mentale : recharge des rituels ÷2")
	if not powers.is_empty(): label(v," · ".join(powers),16,GameTheme.GOLD)
	section(v,"Équipement porté")
	var equipment: HBoxContainer = HBoxContainer.new();v.add_child(equipment)
	for slot: String in ["staff","ring1","ring2"]:
		var equipped: Dictionary = State.find_item(State.run.equipped[slot])
		button(equipment,("Bâton" if slot=="staff" else "Anneau "+slot[-1])+" : "+equipped.get("name","vide")+ (" — retirer" if not equipped.is_empty() else ""),func()->void:State.unequip(slot);show_inventory(selling),equipped.is_empty(),"staff" if slot=="staff" else "ring")
	section(v,"Dans votre sac")
	if State.run.inventory.is_empty(): label(v,"Votre sac est vide. Les coffres et les gardiens renferment des objets.")
	for item: Dictionary in State.run.inventory:
		var item_box: PanelContainer = PanelContainer.new();v.add_child(item_box)
		item_box.add_theme_stylebox_override("panel",GameTheme.panel(Color("18181a"),rarity_color(item.rarity).darkened(0.6),12))
		var item_body: VBoxContainer = VBoxContainer.new();item_box.add_child(item_body)
		var equipped: bool = item.uid in State.run.equipped.values()
		label(item_body,item.name+("  [équipé]" if equipped else ""),18,GameTheme.IVORY)
		label(item_body,item_description(item),16,rarity_color(item.rarity))
		if selling:
			button(item_body,"Vendre · %d or"%maxi(1,int(item.price/3)),func()->void:State.sell(item.uid);show_inventory(true),equipped)
		elif not equipped:
			for slot: String in (["staff"] if item.slot=="staff" else ["ring1","ring2"]):
				label(item_body,compare_item(item,slot),14,GameTheme.MUTED)
				button(item_body,"Équiper le bâton" if slot=="staff" else "Équiper — anneau "+slot[-1],func()->void:State.equip(item.uid,slot);show_inventory(),false,"staff" if slot=="staff" else "ring")

	button(v,"Retour à l’échoppe" if selling else "Fermer",show_merchant if selling else close_modal)
	focus_first(v)

func show_skills() -> void:
	var v: VBoxContainer = panel("Le grimoire","Magies actives, rituels et savoirs acquis. Les fusions se choisissent lors des niveaux multiples de cinq.","skills",1000)
	label(v,"DPS théorique par ennemi, avant résistance, à mana disponible. Moyenne des rituels : dégâts ÷ recharge. Portées en unités du monde (u), limitées par les murs.",14,GameTheme.MUTED)
	for kind: String in ["primary","secondary","passive"]:
		label(v,{"primary":"LES QUATRE ÉLÉMENTS","secondary":"RITUELS  ·  %d / %d emplacements"%[State.secondary_skills().size(),3 if State.run.level>=20 else 2],"passive":"SAVOIRS ET SPÉCIALISATIONS"}[kind],20,Color("d1ba8c"))
		var grid: GridContainer = GridContainer.new();grid.columns = 2;v.add_child(grid)
		var known: int = 0
		for id: String in Catalog.ids(kind):
			if State.rank(id)==0: continue
			known += 1
			var d: ContentDefinition = Catalog.definition(id)
			var box: PanelContainer = PanelContainer.new();grid.add_child(box)
			box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			box.add_theme_stylebox_override("panel",GameTheme.panel(Color("19191a"),Color("443b2f"),14))
			var body: VBoxContainer = VBoxContainer.new();box.add_child(body)
			if kind=="primary":
				button(body,d.title+" · rang %d"%State.rank(id)+("  [actif]" if State.run.active==id else "  · activer"),func()->void:State.run.active=id;show_skills(),false,id)
			else: label(body,d.title+" · rang %d"%State.rank(id),18,GameTheme.GOLD)
			if State.rank(id)!=State.learned_rank(id): label(body,"Appris : %d · Équipement : +%d"%[State.learned_rank(id),State.rank(id)-State.learned_rank(id)],14,GameTheme.GOLD)
			if kind=="secondary" and id not in State.secondary_skills(): label(body,"Rituel fourni par l’équipement : emplacements occupés.",14,GameTheme.MUTED)
			label(body,d.description,16,GameTheme.MUTED)
			add_skill_details(body,id)
		if known==0: label(v,"Aucun savoir acquis dans cette discipline.",16,GameTheme.MUTED)
	if not State.run.fusion.is_empty():
		var id: String = State.run.fusion.id
		button(v,Catalog.title(id)+" · activer la fusion",func()->void:State.run.active=id;show_skills(),false,Catalog.definition(id).icon)
		label(v,SkillDetails.text(id)+"\nFigée au niveau %d."%State.run.fusion.level,16)
	button(v,"Fermer",close_modal)
	focus_first(v)

func show_map() -> void:
	var v: VBoxContainer = panel("Les salles explorées","Ivoire : vous · or : escalier · turquoise : coffre non ouvert.","map",870)
	var map: TowerMap = TowerMap.new()
	map.world = world
	map.custom_minimum_size = Vector2(650,400)
	v.add_child(map)
	button(v,"Fermer",close_modal)

func show_death() -> void:
	var v: VBoxContainer = panel("Votre chapeau retombe…","La mort est définitive." if State.run.hardcore else "Votre dernier point de reprise a été restauré. Les actions plus récentes ont été annulées.","death",800)
	if not State.run.hardcore:
		label(v,State.checkpoint_description(),18,GameTheme.GOLD)
		button(v,"Reprendre au point de sauvegarde",func()->void:close_modal();world.load_floor(int(State.run.floor),true))
	button(v,"Retour au menu",func()->void:close_modal();show_menu())
	focus_first(v)

func show_victory() -> void:
	Sound.stop_world()
	Sound.set_music("")
	Sound.play("victory")
	var v: VBoxContainer = panel("L’aube sur les cendres","Treize étages. Un examen réussi. Orme prétendra qu’il n’en a jamais douté.","victory",900)
	label(v,"Niveau %d · %d morts · %d or\nDifficulté achevée : %s"%[State.run.level,State.run.deaths,State.run.gold,Catalog.definition("campaign").values.difficulties[int(State.run.difficulty)]],23)
	label(v,"La prochaine ascension conserve vos compétences et votre équipement. La tour et ses récompenses sont renouvelées. L’Épreuve éternelle impose la mort définitive.",18)
	button(v,"Commencer la difficulté suivante",func()->void:State.next_difficulty();close_modal();world.load_floor(0))
	button(v,"Retour au menu",func()->void:close_modal();show_menu())
	focus_first(v)

func slider(parent: Node,title: String,key: String,min_value: float,max_value: float) -> void:
	var caption: Label = label(parent,title + "  ·  %d %%" % roundi(State.options[key]*100),18)
	var control: HSlider = HSlider.new()
	control.min_value = min_value
	control.max_value = max_value
	control.step = 0.05
	control.value = State.options[key]
	control.value_changed.connect(func(value: float)->void:State.options[key]=value;caption.text=title+"  ·  %d %%"%roundi(value*100);State.save_options())
	parent.add_child(control)

func show_options() -> void:
	var v: VBoxContainer = panel("Options et commandes","Clavier WASD / ZQSD ou flèches. Souris : viser et maintenir le clic. Manette : les deux sticks.","options",1050)
	section(v,"Son & image")
	slider(v,"Volume général","volume",0,1)
	slider(v,"Ambiance musicale","music",0,1)
	slider(v,"Effets sonores","effects",0,1)
	slider(v,"Luminosité","brightness",0.7,1.5)
	for option: String in ["fullscreen","reduced_effects"]:
		var check: CheckBox = CheckBox.new()
		check.text = "Plein écran" if option=="fullscreen" else "Réduire les flashs et les effets brusques"
		check.button_pressed = State.options[option]
		check.toggled.connect(func(value:bool)->void:State.options[option]=value;State.save_options())
		v.add_child(check)
	label(v,"Manette : A interaction · Y inventaire · Retour grimoire · B changer de sort · LB/RB/X rituels · croix gauche/droite potions · bas portail · haut carte · Start pause. Menus : croix/stick et A/B.",16)
	section(v,"Commandes clavier")
	for action: String in Controls.KEYS:
		button(v,Controls.LABELS[action]+" : "+Controls.caption(action,true),begin_rebind.bind(action))
	section(v,"Commandes manette")
	for action: String in Controls.PADS:
		button(v,Controls.LABELS[action]+" : "+Controls.pad_caption(int(State.options.pad_bindings.get(action,Controls.PADS[action]))),begin_rebind.bind("pad:"+action))
	button(v,"Rétablir les commandes",func()->void:State.options.bindings={};State.options.pad_bindings={};Controls.setup();State.save_options();show_options())
	button(v,"Retour",show_pause if options_return=="pause" and is_instance_valid(world) else show_menu)
	focus_first(v)

func show_credits() -> void:
	var v: VBoxContainer = panel("Crédits","La Tour des Cendres · version 0.1","credits",880)
	label(v,"Un jeu indépendant réalisé dans Godot 4.7.2.\n\nCode original en GDScript. Illustrations originales générées avec ImageGen, puis découpées et intégrées. Ambiance musicale et effets de synthèse originaux.\n\nInspiré des mécaniques de Solomon’s Keep, créé par Raptisoft. Aucun code, personnage, son ou graphisme de ce jeu n’est réutilisé. Ce projet n’est pas affilié à Raptisoft.\n\nGodot Engine : licence MIT. La notice complète et la provenance des ressources figurent dans docs/asset_manifest.md.",19)
	button(v,"Retour",show_menu)
	focus_first(v)

func safe_focus(reference: WeakRef) -> void:
	var control: Control = reference.get_ref() as Control
	if is_instance_valid(control) and control.is_inside_tree(): control.grab_focus()

func quit_game() -> void:
	Sound.stop_all()
	await get_tree().create_timer(0.2,true).timeout
	get_tree().quit()

func begin_rebind(action: String) -> void:
	pending_binding = action
	var focused: Control = get_viewport().gui_get_focus_owner()
	if focused is Button: focused.text = "Appuyez sur le nouveau bouton…" if action.begins_with("pad:") else "Appuyez sur la nouvelle touche…"
