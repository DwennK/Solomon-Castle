extends Node

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
	modal = Control.new()
	modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.add_child(modal)
	var dark: ColorRect = ColorRect.new()
	dark.color = Color(0.015,0.025,0.04,0.84)
	dark.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal.add_child(dark)
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal.add_child(center)
	var box: PanelContainer = PanelContainer.new()
	box.custom_minimum_size = Vector2(minf(width,get_viewport().get_visible_rect().size.x-60),0)
	center.add_child(box)
	var outer: VBoxContainer = VBoxContainer.new()
	box.add_child(outer)
	label(outer,title,32,Color("dbc38e"))
	if not subtitle.is_empty(): label(outer,subtitle,17,Color("a9b7bd"))
	var separator: HSeparator = HSeparator.new()
	outer.add_child(separator)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0,minf(515,get_viewport().get_visible_rect().size.y-220))
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(scroll)
	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)
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

func focus_first(parent: Node) -> void:
	for child: Node in parent.get_children():
		if child is Button and not child.disabled:
			call_deferred("safe_focus",weakref(child))
			return
		focus_first(child)

func show_menu() -> void:
	get_tree().paused = false
	if is_instance_valid(world):
		world.queue_free()
		world = null
	if is_instance_valid(hud): hud.queue_free()
	if is_instance_valid(grade): grade.get_parent().queue_free();grade = null
	destroy_modal()
	modal_kind = "menu"
	menu_background.show()
	modal = MarginContainer.new()
	modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal.add_theme_constant_override("margin_left",85)
	modal.add_theme_constant_override("margin_top",95)
	modal.add_theme_constant_override("margin_bottom",60)
	ui.add_child(modal)
	var column: VBoxContainer = VBoxContainer.new()
	column.custom_minimum_size.x = 430
	column.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	modal.add_child(column)
	label(column,"UN EXAMEN. TREIZE ÉTAGES. AUCUNE EXCUSE.",13,Color("b2b5ae"))
	var title: Label = label(column,"LA TOUR\nDES CENDRES",58,Color("eee2c2"))
	title.add_theme_constant_override("outline_size",3)
	title.add_theme_color_override("font_outline_color",Color("101b25"))
	label(column,"Le dernier cours de magie commence ici.",18,Color("bac4c5"))
	var space: Control = Control.new();space.custom_minimum_size.y = 42;column.add_child(space)
	var saved: Dictionary = SaveStore.read_save(State.save_path)
	var valid: bool = State.valid_payload(saved) and not saved.run.dead
	button(column,"Continuer l’ascension",continue_game,not valid)
	if FileAccess.file_exists(State.save_path) and not valid:
		label(column,"Sauvegarde indisponible ou partie hardcore terminée. Une nouvelle partie reste possible.",14,Color("c9a88b"))
	button(column,"Nouvelle partie",show_new)
	button(column,"Options et commandes",func()->void: options_return="menu";show_options())
	button(column,"Crédits",show_credits)
	button(column,"Quitter",quit_game)
	var stretch: Control = Control.new();stretch.size_flags_vertical=Control.SIZE_EXPAND_FILL;column.add_child(stretch)
	label(column,"VERSION 0.1  ·  GODOT 4.7.2  ·  JEU LOCAL",12,Color("8c9ba2"))
	focus_first(column)

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
	make_grade()
	if not State.run.pending.is_empty(): show_level()

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

func show_initial() -> void:
	var v: VBoxContainer = panel("Votre première étincelle","Orme : Choisissez bien. Vous pourrez apprendre d’autres éléments pendant l’ascension.","initial")
	for id: String in Catalog.ids("primary"):
		var d: ContentDefinition = Catalog.definition(id)
		button(v,d.title+" — "+d.description,func()->void:State.learn(id);world.snapshot();State.mark_checkpoint();State.save_game();close_modal(),false,id)
	focus_first(v)

func on_level_pending() -> void:
	if modal_kind.is_empty(): call_deferred("show_level")

func show_level() -> void:
	if State.run.pending.is_empty(): return
	var offered: Array = State.offers()
	var v: VBoxContainer = panel("Niveau %d — choisissez votre savoir"%int(State.run.pending[0]),"Le temps est suspendu. Une amélioration par niveau. %d choix en attente."%State.run.pending.size(),"level",1020)
	for id: String in offered:
		var d: ContentDefinition = Catalog.definition(id)
		var title: String = d.title+"  ·  "+("Fusion : capture des rangs actuels" if d.kind=="fusion" else "%d → %d"%[State.rank(id),State.rank(id)+1])
		button(v,title,func()->void:
			if State.choose(id):
				world.player.refresh_stats()
				world.snapshot()
				State.save_game()
				close_modal(),false,d.icon)
		label(v,d.description,18,Color("bdc9cd"))
		if d.kind=="primary":
			var p: Dictionary = world.combat.profile(id)
			var next: Dictionary = world.combat.profile(id,State.rank(id)+1)
			var unit: String = "/s" if p.channel else "/tir"
			label(v,"Dégâts : %.1f → %.1f%s · Mana : %.1f → %.1f%s"%[p.damage if State.rank(id)>0 else 0,next.damage,unit,p.mana*(1-State.stats().cost_reduction) if State.rank(id)>0 else 0,next.mana*(1-State.stats().cost_reduction),unit],15,Color("93afb5"))
	if offered.is_empty():
		button(v,"Savoirs maîtrisés — poursuivre",func()->void:State.run.pending.pop_front();State.run.offers=[];close_modal())
	focus_first(v)

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
	for item: Dictionary in State.run.shop:
		button(v,"%s · %d or"%[item.name,item.price],func()->void:State.buy(item.uid);Sound.play("loot");show_merchant(),State.run.gold<item.price or State.run.inventory.size()>=48,"staff" if item.slot=="staff" else "ring")
		label(v,item_description(item),16,rarity_color(item.rarity))
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
	var labels: Dictionary = {"damage":"dégâts","max_mana":"mana max.","max_hp":"vie max.","mana_regen":"mana/s","cast_speed":"cadence","cost_reduction":"économie de mana","hp_regen":"vie/s","speed":"vitesse","resistance":"résistance"}
	for key: String in item.get("bonuses",{}):
		var value: float = item.bonuses[key]
		bits.append(("+%.0f %%"%(value*100) if key in ["damage","cast_speed","cost_reduction","speed","resistance"] else "+%.1f"%value)+" "+labels.get(key,key))
	return ["Enchanté","Rare","Épique"][int(item.rarity)]+" · "+" / ".join(bits)

func compare_item(item: Dictionary) -> String:
	var slot: String = "staff" if item.slot=="staff" else ("ring1" if State.run.equipped.ring1.is_empty() else "ring2")
	var old: Dictionary = State.find_item(State.run.equipped[slot])
	var changes: Array[String] = []
	var keys: Array = item.bonuses.keys()
	for key: String in old.get("bonuses",{}):
		if not key in keys: keys.append(key)
	for key: String in keys:
		var diff: float = float(item.bonuses.get(key,0))-float(old.get("bonuses",{}).get(key,0))
		changes.append("%s %+.2f"%[key,diff])
	return "Comparaison "+slot+" : "+", ".join(changes)

func show_inventory(selling: bool = false) -> void:
	var v: VBoxContainer = panel("Votre sac" if not selling else "Vendre à Basile","%d / 48 objets · %d or · Un bâton et deux anneaux."%[State.run.inventory.size(),State.run.gold],"inventory",1120)
	var s: Dictionary = State.stats()
	label(v,"Vie %.0f · Mana %.0f · Régén. %.1f/s · Dégâts ×%.2f · Coût ×%.2f"%[s.max_hp,s.max_mana,s.mana_regen,s.damage,1-s.cost_reduction],18)
	for slot: String in ["staff","ring1","ring2"]:
		var equipped: Dictionary = State.find_item(State.run.equipped[slot])
		button(v,("Bâton" if slot=="staff" else "Anneau "+slot[-1])+" : "+equipped.get("name","vide")+ (" — retirer" if not equipped.is_empty() else ""),func()->void:State.unequip(slot);show_inventory(selling),equipped.is_empty())
	if State.run.inventory.is_empty(): label(v,"Votre sac est vide. Les coffres et les gardiens renferment des objets.")
	for item: Dictionary in State.run.inventory:
		var equipped: bool = item.uid in State.run.equipped.values()
		button(v,item.name+("  [équipé]" if equipped else ("  · vendre %d or"%maxi(1,int(item.price/3)) if selling else "  · équiper")),func()->void:
			if selling: State.sell(item.uid)
			else: State.equip(item.uid)
			show_inventory(selling),equipped,"staff" if item.slot=="staff" else "ring")
		label(v,item_description(item),16,rarity_color(item.rarity))
		if not equipped and not selling: label(v,compare_item(item),14,Color("93a7ae"))
	button(v,"Retour à l’échoppe" if selling else "Fermer",show_merchant if selling else close_modal)
	focus_first(v)

func show_skills() -> void:
	var v: VBoxContainer = panel("Le grimoire","Magies actives, rituels et savoirs acquis. Les fusions se choisissent lors des niveaux multiples de cinq.","skills",1000)
	for kind: String in ["primary","secondary","passive"]:
		label(v,{"primary":"LES QUATRE ÉLÉMENTS","secondary":"RITUELS  ·  %d / %d emplacements"%[State.run.secondary.size(),3 if State.run.level>=20 else 2],"passive":"SAVOIRS ET SPÉCIALISATIONS"}[kind],20,Color("d1ba8c"))
		for id: String in Catalog.ids(kind):
			if State.rank(id)==0: continue
			var d: ContentDefinition = Catalog.definition(id)
			if kind=="primary":
				button(v,d.title+" · rang %d"%State.rank(id)+("  [actif]" if State.run.active==id else "  · activer"),func()->void:State.run.active=id;show_skills(),false,id)
			else: label(v,d.title+" · rang %d"%State.rank(id),18)
			label(v,d.description,16,Color("a9b8bd"))
	if not State.run.fusion.is_empty():
		var id: String = State.run.fusion.id
		button(v,Catalog.title(id)+" · activer la fusion",func()->void:State.run.active=id;show_skills(),false,Catalog.definition(id).icon)
		label(v,Catalog.definition(id).description+" Figée au niveau %d."%State.run.fusion.level,17)
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
		button(v,"Reprendre au point de sauvegarde",func()->void:close_modal();world.load_floor(int(State.run.floor),true))
	button(v,"Retour au menu",func()->void:close_modal();show_menu())
	focus_first(v)

func show_victory() -> void:
	Sound.play("victory")
	var v: VBoxContainer = panel("L’aube sur les cendres","Treize étages. Un examen réussi. Orme prétendra qu’il n’en a jamais douté.","victory",900)
	label(v,"Niveau %d · %d morts · %d or\nDifficulté achevée : %s"%[State.run.level,State.run.deaths,State.run.gold,Catalog.definition("campaign").values.difficulties[int(State.run.difficulty)]],23)
	label(v,"La prochaine ascension conserve vos compétences et votre équipement. La tour et ses récompenses sont renouvelées. L’Épreuve éternelle impose la mort définitive.",18)
	button(v,"Commencer la difficulté suivante",func()->void:State.next_difficulty();close_modal();world.load_floor(0))
	button(v,"Retour au menu",func()->void:close_modal();show_menu())
	focus_first(v)

func slider(parent: Node,title: String,key: String,min_value: float,max_value: float) -> void:
	label(parent,title,18)
	var control: HSlider = HSlider.new()
	control.min_value = min_value
	control.max_value = max_value
	control.step = 0.05
	control.value = State.options[key]
	control.value_changed.connect(func(value: float)->void:State.options[key]=value;State.save_options())
	parent.add_child(control)

func show_options() -> void:
	var v: VBoxContainer = panel("Options et commandes","Clavier WASD / ZQSD ou flèches. Souris : viser et maintenir le clic. Manette : les deux sticks.","options",1050)
	slider(v,"Volume général","volume",0,1)
	slider(v,"Ambiance musicale","music",0,1)
	slider(v,"Luminosité","brightness",0.7,1.5)
	for option: String in ["fullscreen","reduced_effects"]:
		var check: CheckBox = CheckBox.new()
		check.text = "Plein écran" if option=="fullscreen" else "Réduire les flashs et les effets brusques"
		check.button_pressed = State.options[option]
		check.toggled.connect(func(value:bool)->void:State.options[option]=value;State.save_options())
		v.add_child(check)
	label(v,"Manette : A interaction · Y inventaire · Retour grimoire · B changer de sort · LB/RB/X rituels · croix gauche/droite potions · bas portail · haut carte · Start pause. Menus : croix/stick et A/B.",16)
	label(v,"RECONFIGURER LE CLAVIER",20,Color("d4be91"))
	for action: String in Controls.KEYS:
		button(v,Controls.LABELS[action]+" : "+Controls.caption(action),func()->void:pending_binding=action;label(v,"Appuyez sur la nouvelle touche pour « "+Controls.LABELS[action]+" ».",20))
	label(v,"RECONFIGURER LES BOUTONS DE MANETTE",20,Color("d4be91"))
	for action: String in Controls.PADS:
		button(v,Controls.LABELS[action]+" : bouton %d"%int(State.options.pad_bindings.get(action,Controls.PADS[action])),func()->void:pending_binding="pad:"+action;label(v,"Appuyez sur un bouton de manette pour « "+Controls.LABELS[action]+" ».",20))
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
