extends Node

const STAT_LABELS: Dictionary = {"damage":"damage","max_mana":"max. mana","max_hp":"max. health","mana_regen":"mana/s","cast_speed":"cast speed","cost_reduction":"mana efficiency","hp_regen":"health/s","speed":"speed","resistance":"resistance"}
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
	box.set_meta("parchment",true)
	box.add_theme_stylebox_override("panel",GameTheme.parchment())
	center.add_child(box)
	var outer: VBoxContainer = VBoxContainer.new()
	outer.add_theme_constant_override("separation",14)
	box.add_child(outer)
	var header: HBoxContainer = HBoxContainer.new(); outer.add_child(header)
	var titles: VBoxContainer = VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL; header.add_child(titles)
	var sections: Dictionary = {"inventory":"EQUIPMENT", "skills":"ARCANE ARTS", "merchant":"THE SHOP", "teacher":"THE MASTER", "level":"ASCENT", "pause":"SANCTUARY", "options":"PREFERENCES", "new":"A NEW DESTINY", "initial":"INITIATION", "map":"CARTOGRAPHY", "death":"THE ASCENT ENDS", "victory":"THE EXAM IS COMPLETE", "credits":"THE CREATORS"}
	label(titles,sections.get(kind,"THE TOWER OF ASH"),12,GameTheme.GOLD)
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
		close.tooltip_text = "Close"
	if not subtitle.is_empty(): label(outer,subtitle,16,GameTheme.MUTED)
	outer.add_child(UIOrnament.new())
	if kind in ["inventory","skills","map"]:
		var nav: HBoxContainer = HBoxContainer.new(); outer.add_child(nav)
		for tab: Array in [["inventory","Inventory",show_inventory],["skills","Grimoire",show_skills],["map","Map",show_map]]:
			var item: Button = button(nav,tab[1],tab[2])
			item.alignment = HORIZONTAL_ALIGNMENT_CENTER
			if kind==tab[0]: item.add_theme_stylebox_override("normal",GameTheme.panel(Color("34291a"),GameTheme.GOLD,14))
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.follow_focus = true
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
	l.add_theme_color_override("font_color",GameTheme.surface_text(parent,color))
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.set_meta("ink",GameTheme.is_parchment(parent))
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
	return b

func focus_first(parent: Node) -> bool:
	for child: Node in parent.get_children():
		if child is HSlider or (child is Button and not child.disabled):
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
	margin.add_theme_constant_override("margin_top",38)
	margin.add_theme_constant_override("margin_bottom",38)
	modal.add_child(margin)
	var column: VBoxContainer = VBoxContainer.new()
	column.custom_minimum_size.x = 440
	column.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	column.add_theme_constant_override("separation",8)
	var menu_page: PanelContainer=PanelContainer.new()
	menu_page.size_flags_horizontal=Control.SIZE_SHRINK_BEGIN
	menu_page.set_meta("parchment",true)
	menu_page.add_theme_stylebox_override("panel",GameTheme.parchment())
	margin.add_child(menu_page)
	menu_page.add_child(column)
	label(column,"O N E  E X A M .   T H I R T E E N  F L O O R S .",12,GameTheme.GOLD)
	var title: Label = label(column,"THE TOWER\nOF ASH",44)
	GameTheme.heading(title)
	title.add_theme_constant_override("outline_size",0)
	title.add_theme_color_override("font_outline_color",Color("0a0c0f"))
	column.add_child(UIOrnament.new())
	label(column,"Your final lesson in magic begins here.",18,Color("bab1a2"))
	var space: Control = Control.new();space.custom_minimum_size.y = 12;column.add_child(space)
	var saved: Dictionary = SaveStore.read_save(State.save_path)
	var valid: bool = State.valid_payload(saved) and not saved.run.dead
	var resume: Button = button(column,"Continue the ascent",continue_game,not valid)
	var fresh: Button = button(column,"New game",show_new)
	for b: Button in [resume,fresh]:
		b.custom_minimum_size.y = 58
		b.add_theme_font_override("font",GameTheme.TITLE)
		b.alignment = HORIZONTAL_ALIGNMENT_CENTER
	var primary: Button = resume if valid else fresh
	primary.add_theme_stylebox_override("normal",GameTheme.panel(Color("372a1b"),GameTheme.GOLD,16))
	if FileAccess.file_exists(State.save_path) and not valid:
		label(column,"This ascent has ended or its save is unavailable.",14,GameTheme.MUTED)
	var ornament: UIOrnament = UIOrnament.new();column.add_child(ornament)
	for entry: Array in [["Options & controls",func()->void:options_return="menu";show_options()],["Credits",show_credits],["Quit",quit_game]]:
		var b: Button = button(column,entry[0],entry[1])
		b.custom_minimum_size.y = 42
		b.alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.add_theme_stylebox_override("normal",GameTheme.panel(Color("29231f"),Color("68523d"),9))
	var stretch: Control = Control.new();stretch.size_flags_vertical=Control.SIZE_EXPAND_FILL;column.add_child(stretch)
	label(column,"THE TOWER OF ASH    /    CHAPTER I",12,GameTheme.GOLD)
	label(column,"VERSION 0.2  ·  A SOLO ASCENT",11,Color("8e887d"))
	focus_first(column)
	GameTheme.enter(column)

func show_new() -> void:
	var v: VBoxContainer = panel("A new ascent","One mage, four elements, and a tower that never saw you coming.","new",770)
	label(v,"Difficulty")
	var choice: OptionButton = OptionButton.new()
	for i: int in range(5):
		choice.add_item(Catalog.definition("campaign").values.difficulties[i])
		choice.set_item_disabled(i,i>State.unlocked)
	v.add_child(choice)
	var hardcore: CheckBox = CheckBox.new()
	GameTheme.paper_checkbox(hardcore)
	hardcore.text = "Hardcore — one life, permanent death"
	v.add_child(hardcore)
	label(v,"Normal mode: resume from the last floor or portal checkpoint. Later actions are undone. Hardcore mode prevents continuing after death.",17)
	label(v,"A new game replaces the current ascent. Unlocked difficulties and settings are kept.",16,Color("bda98a"))
	button(v,"Begin",func()->void:State.fresh(0,choice.selected,hardcore.button_pressed or choice.selected==4);State.mark_checkpoint();State.save_game();start_game())
	button(v,"Back",show_menu)
	focus_first(v)

func continue_game() -> void:
	if State.load_game():
		start_game()
		if State.run.victory: show_victory()
	else:
		var v: VBoxContainer = panel("Save unavailable",SaveStore.last_error)
		button(v,"Back",show_menu)

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
		"archive", "oath_altar": show_discovery()
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
	var select: Button = button(body,"Choose",action,disabled)
	select.alignment = HORIZONTAL_ALIGNMENT_CENTER
	return body

func add_skill_details(body: VBoxContainer, id: String, compare: bool = true, acquiring: bool = false) -> void:
	var details: Label = label(body,SkillDetails.text(id,compare,acquiring),14,GameTheme.IVORY)
	details.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# Keep the action after its consequences, inside the scrollable card.
	for child: Node in body.get_children():
		if child is Button and child.text=="Choose":
			body.move_child(details,child.get_index())
			break

func section(parent: Node, title: String) -> void:
	var heading: Label = label(parent,title,16,GameTheme.GOLD)
	GameTheme.heading(heading)

func show_initial() -> void:
	var v: VBoxContainer = panel("Your first spark","Orme: Choose wisely. You can learn other elements during the ascent.","initial",1180)
	var grid: GridContainer = GridContainer.new();grid.columns = 4;v.add_child(grid)
	for id: String in Catalog.ids("primary"):
		var d: ContentDefinition = Catalog.definition(id)
		var body: VBoxContainer = choice_card(grid,d.title,d.description,id,func()->void:State.learn(id);world.snapshot();State.mark_checkpoint("First spell learned");State.save_game();close_modal())
		add_skill_details(body,id,false,true)
	focus_first(v)

func on_level_pending() -> void:
	if modal_kind.is_empty(): call_deferred("show_level")

func show_level() -> void:
	if State.run.pending.is_empty(): return
	Sound.play("level_up")
	var offered: Array = State.offers()
	var v: VBoxContainer = panel("Level %d — choose your knowledge"%int(State.run.pending[0]),"Time is paused · %d choices pending. Theoretical DPS per enemy, before resistance, with mana available. Range in units (u)."%State.run.pending.size(),"level",1140)
	var reroll_button: Button = button(v,"Reroll choices · 1 shard (%d available)" % State.run.get("insight",1),func()->void:
		world.snapshot()
		if State.reroll(): show_level(),not State.can_reroll())
	reroll_button.tooltip_text = "Start with one shard and earn one per main guardian. Previous choices are avoided; a unique fusion or a choice with no alternative may return."
	label(v,"Knowledge shards: 1 at the start, then 1 per main guardian. Each reroll costs 1 shard.",14,GameTheme.MUTED)
	if not State.can_reroll(): label(v,"No shards remaining." if State.run.get("insight",1)<=0 else "No other eligible upgrades.",14,GameTheme.MUTED)
	var grid: GridContainer = GridContainer.new();grid.columns = 2 if offered.size()==4 else 3;v.add_child(grid)
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
		button(v,"All knowledge mastered — continue",func()->void:State.run.pending.pop_front();State.run.offers=[];close_modal())
		focus_first(v)
	else: focus_first(grid)

func show_pause() -> void:
	var v: VBoxContainer = panel("A moment of respite","The game is paused.","pause",620)
	button(v,"Resume",close_modal)
	button(v,"Save",func()->void:world.snapshot();var ok:bool=State.save_game();label(v,"Game saved." if ok else SaveStore.last_error))
	button(v,"Options & controls",func()->void:options_return="pause";show_options())
	button(v,"Save and return to menu",func()->void:world.snapshot();State.save_game();close_modal();show_menu())
	focus_first(v)

func show_discovery() -> void:
	var prop: WorldProp = world.pending_discovery
	if not is_instance_valid(prop): return
	var v: VBoxContainer = panel(DiscoveryRules.caption(prop.record),DiscoveryRules.hint(prop.record),"discovery",680)
	if prop.record.kind=="archive":
		var choices: Array[String] = State.signature_choices()
		var title: String = "No eligible spell lesson" if choices.is_empty() else "Learn %s"%Catalog.title(choices[0])
		button(v,title,func()->void:
			if world.resolve_discovery("lesson"): close_modal(),choices.is_empty())
		if not choices.is_empty(): label(v,Catalog.definition(choices[0]).description,17)
		button(v,"Take two Knowledge Shards · reroll future upgrades",func()->void:
			if world.resolve_discovery("insight"): close_modal())
	else:
		label(v,"The damage bonus applies only on this floor. Returning here preserves it. Health is paid immediately; the offer cannot kill you.",18)
		button(v,"Offer %d health · gain 20%% damage"%ceili(State.stats().max_hp*0.25),func()->void:
			if world.resolve_discovery("accept"): close_modal(),State.run.hp<=State.stats().max_hp*0.25)
	button(v,"Leave it untouched",close_modal)
	focus_first(v)

func show_teacher() -> void:
	if State.run.active.is_empty(): show_initial();return
	var v: VBoxContainer = panel("Orme’s wisdom","“Books are expensive. Ignorance costs more.”","teacher")
	var price: int = 80+int(State.run.wisdom)*65
	label(v,"Buying wisdom offers three upgrades eligible at your level. Cost: %d gold."%price)
	button(v,"Buy a lesson · %d gold"%price,func()->void:
		if State.run.gold>=price:
			State.run.gold-=price;State.run.wisdom+=1;State.run.pending.append(State.run.level);close_modal(),State.run.gold<price)
	button(v,"Open the grimoire",show_skills)
	label(v,"Fusions: learn two elements. Every five levels, a fusion may be offered. It captures your current ranks and subskills; learning it again updates that snapshot.",18)
	button(v,"Back to the village",close_modal)
	focus_first(v)

func show_merchant() -> void:
	var v: VBoxContainer = panel("Basile’s shop","%d gold · Staves, rings, and supplies. Stock is tied to this ascent."%State.run.gold,"merchant",1080)
	var row: HBoxContainer = HBoxContainer.new();v.add_child(row)
	button(row,"Health potion · 18 gold",func()->void:buy_potion("hp"),State.run.gold<18,"health")
	button(row,"Mana potion · 18 gold",func()->void:buy_potion("mp"),State.run.gold<18,"mana")
	button(v,"Sell your items",func()->void:show_inventory(true))
	section(v,"Enchanted items")
	for item: Dictionary in State.run.shop:
		var item_box: PanelContainer = PanelContainer.new();v.add_child(item_box)
		item_box.add_theme_stylebox_override("panel",GameTheme.panel(Color("18181a"),rarity_color(item.rarity).darkened(0.6),12))
		var item_body: VBoxContainer = VBoxContainer.new();item_box.add_child(item_body)
		button(item_body,"%s · %d gold"%[item.name,item.price],func()->void:State.buy(item.uid);Sound.play("loot");show_merchant(),State.run.gold<item.price or State.run.inventory.size()>=48,"staff" if item.slot=="staff" else "ring")
		label(item_body,item_description(item),16,rarity_color(item.rarity))
	button(v,"Back to the village",close_modal)
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
	return ["Enchanted","Rare","Epic"][int(item.rarity)]+" · "+" / ".join(bits)

func show_inventory(selling: bool = false) -> void:
	destroy_modal()
	modal_kind = "inventory"
	get_tree().paused = is_instance_valid(world)
	if get_tree().paused: Sound.stop_world()
	var inventory: InventoryView = InventoryView.new()
	inventory.selling = selling
	inventory.close_requested.connect(close_modal)
	inventory.section_requested.connect(on_inventory_section)
	modal = inventory
	ui.add_child(inventory)

func on_inventory_section(section_name: String) -> void:
	match section_name:
		"inventory": show_inventory()
		"pause": show_pause()
		"skills": show_skills()
		"map": show_map()
		"merchant": show_merchant()

func show_skills() -> void:
	destroy_modal()
	modal_kind="skills"
	get_tree().paused=is_instance_valid(world)
	if get_tree().paused: Sound.stop_world()
	var grimoire: GrimoireView=GrimoireView.new()
	grimoire.close_requested.connect(close_modal)
	grimoire.section_requested.connect(on_inventory_section)
	modal=grimoire
	ui.add_child(grimoire)

func show_map() -> void:
	var v: VBoxContainer = panel("Explored rooms","Ivory: you · gold: stairs · turquoise: chest · violet diamond: trial · red: blood font.","map",870)
	var map: TowerMap = TowerMap.new()
	map.world = world
	map.custom_minimum_size = Vector2(650,400)
	v.add_child(map)
	button(v,"Close",close_modal)

func show_death() -> void:
	var v: VBoxContainer = panel("Your hat falls to the floor…","Death is permanent." if State.run.hardcore else "Your last checkpoint has been restored. Later actions were undone.","death",800)
	if not State.run.hardcore:
		label(v,State.checkpoint_description(),18,GameTheme.GOLD)
		button(v,"Resume from checkpoint",func()->void:close_modal();world.load_floor(int(State.run.floor),true))
	button(v,"Back to menu",func()->void:close_modal();show_menu())
	focus_first(v)

func show_victory() -> void:
	Sound.stop_world()
	Sound.set_music("")
	Sound.play("victory")
	var v: VBoxContainer = panel("Dawn over the ashes","Thirteen floors. One exam passed. Orme will claim he never doubted you.","victory",900)
	label(v,"Level %d · %d deaths · %d gold\nDifficulty completed: %s"%[State.run.level,State.run.deaths,State.run.gold,Catalog.definition("campaign").values.difficulties[int(State.run.difficulty)]],23)
	label(v,"The next ascent keeps your skills and equipment. The tower and its rewards are renewed. The Eternal Trial enforces permanent death.",18)
	button(v,"Start the next difficulty",func()->void:State.next_difficulty();close_modal();world.load_floor(0))
	button(v,"Back to menu",func()->void:close_modal();show_menu())
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
	var v: VBoxContainer = panel("Options & controls","Keyboard: WASD / ZQSD or arrows. Mouse: aim and hold fire. Controller: twin sticks.","options",1050)
	section(v,"Sound & display")
	slider(v,"Master volume","volume",0,1)
	slider(v,"Music volume","music",0,1)
	slider(v,"Sound effects","effects",0,1)
	slider(v,"Brightness","brightness",0.7,1.5)
	for option: String in ["fullscreen","reduced_effects"]:
		var check: CheckBox = CheckBox.new()
		GameTheme.paper_checkbox(check)
		check.text = "Fullscreen" if option=="fullscreen" else "Reduce flashes and sudden effects"
		check.button_pressed = State.options[option]
		check.toggled.connect(func(value:bool)->void:State.options[option]=value;State.save_options())
		v.add_child(check)
	label(v,"Controller: A interact · Y inventory · Back grimoire · B switch spell · LB/RB/X rituals · D-pad left/right potions · down portal · up map · Start pause. Menus: D-pad/stick and A/B.",16)
	section(v,"Keyboard controls")
	for action: String in Controls.KEYS:
		button(v,Controls.LABELS[action]+" : "+Controls.caption(action,true),begin_rebind.bind(action))
	section(v,"Controller controls")
	for action: String in Controls.PADS:
		button(v,Controls.LABELS[action]+" : "+Controls.pad_caption(int(State.options.pad_bindings.get(action,Controls.PADS[action]))),begin_rebind.bind("pad:"+action))
	button(v,"Reset controls",func()->void:State.options.bindings={};State.options.pad_bindings={};Controls.setup();State.save_options();show_options())
	button(v,"Back",show_pause if options_return=="pause" and is_instance_valid(world) else show_menu)
	focus_first(v)

func show_credits() -> void:
	var v: VBoxContainer = panel("Credits","The Tower of Ash · version 0.2","credits",880)
	label(v,"An independent game made with Godot 4.7.2.\n\nOriginal GDScript code. Original illustrations generated with ImageGen, then cut out and integrated. Original synthesized music and sound effects.\n\nInspired by the mechanics of Solomon’s Keep, created by Raptisoft. No code, characters, sounds, or artwork from that game are reused. This project is not affiliated with Raptisoft.\n\nGodot Engine: MIT license. Full notices and asset provenance are in docs/asset_manifest.md.",19)
	button(v,"Back",show_menu)
	focus_first(v)

func safe_focus(reference: WeakRef) -> void:
	# Wait for container layout before ScrollContainer follows keyboard focus.
	await get_tree().process_frame
	await get_tree().process_frame
	var control: Control = reference.get_ref() as Control
	if not is_instance_valid(control) or not control.is_inside_tree(): return
	control.grab_focus()
	var parent: Node=control.get_parent()
	while parent:
		if parent is ScrollContainer:
			parent.ensure_control_visible(control)
			break
		parent=parent.get_parent()

func quit_game() -> void:
	Sound.stop_all()
	await get_tree().create_timer(0.2,true).timeout
	get_tree().quit()

func begin_rebind(action: String) -> void:
	pending_binding = action
	var focused: Control = get_viewport().gui_get_focus_owner()
	if focused is Button: focused.text = "Press the new button…" if action.begins_with("pad:") else "Press the new key…"
