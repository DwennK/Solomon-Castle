class_name GameHUD
extends Control

signal menu_requested(kind: String)
var world: GameWorld
var hp: VitalOrb
var mp: VitalOrb
var xp: ProgressBar
var values: Label
var location_label: Label
var hint_label: Label
var spell_label: Label
var toast_label: Label
var map: TowerMap
var primary: SpellSlot
var rituals: Array[SpellSlot] = []
var hp_potion: HUDPotion
var mp_potion: HUDPotion
var navigation: Dictionary = {}
var toast_timer: float = 0
var details_key: String = ""
var dock: Control
var xp_label: Label
var spell_hint: Label
var ritual_status: Label
var hint_panel: PanelContainer
var navigation_panel: GridContainer
const DOCK_SIZE: Vector2 = Vector2(1040,216)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var top: HBoxContainer = HBoxContainer.new()
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 28; top.offset_top = 24; top.offset_right = -28
	add_child(top)
	var identity: VBoxContainer = VBoxContainer.new()
	identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(identity)
	var chapter: Label = text_label("T H E  T O W E R  O F  A S H",12,GameTheme.GOLD)
	identity.add_child(chapter)
	values = text_label("",20); GameTheme.heading(values); identity.add_child(values)
	var right: VBoxContainer = VBoxContainer.new(); top.add_child(right)
	location_label = text_label("",16)
	location_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.add_child(location_label)
	map = TowerMap.new(); map.world = world
	map.custom_minimum_size = Vector2(230,175); right.add_child(map)

	# HUD dimensions are logical canvas units; let Godot scale them with the window.
	dock = preload("res://scripts/hud_dock.gd").new()
	dock.name = "CombatDock"
	add_child(dock)
	hp = VitalOrb.new(); hp.position = Vector2.ZERO; dock.add_child(hp)
	mp = VitalOrb.new(); mp.resource_kind = "mp"; mp.position = Vector2(824,0); dock.add_child(mp)
	hp_potion = potion_button("hp",Vector2(218,134))
	mp_potion = potion_button("mp",Vector2(748,134))

	primary = SpellSlot.new(); primary.primary_slot = true
	primary.position = Vector2(298,112); primary.size = Vector2(100,100)
	dock.add_child(primary)
	primary.pressed.connect(func()->void: world.cycle_spell())
	var active_title: Label = text_label("PRIMARY",11,GameTheme.GOLD)
	place(active_title,Vector2(298,44),Vector2(150,18))
	spell_label = text_label("",18,GameTheme.IVORY)
	GameTheme.heading(spell_label)
	spell_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	spell_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	spell_label.max_lines_visible = 1
	place(spell_label,Vector2(298,62),Vector2(170,25))
	spell_hint = text_label("Switch magic",12,GameTheme.MUTED)
	place(spell_hint,Vector2(298,85),Vector2(110,18))
	var ritual_title: Label = text_label("RITUALS",11,GameTheme.GOLD)
	place(ritual_title,Vector2(422,105),Vector2(100,18))
	ritual_status = text_label("",11,GameTheme.MUTED)
	ritual_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	place(ritual_status,Vector2(538,105),Vector2(154,18))
	for i: int in range(3):
		var slot: SpellSlot = SpellSlot.new()
		slot.position = Vector2(422+i*94,128); slot.size = Vector2(84,84)
		dock.add_child(slot); rituals.append(slot)
		slot.pressed.connect(func()->void:
			if not world.village: world.combat.secondary(world.player,i))
	xp = ProgressBar.new(); xp.show_percentage = false
	place(xp,Vector2(478,91),Vector2(268,7))
	xp.add_theme_stylebox_override("background",GameTheme.panel(Color("080b0f"),Color("39352e"),0))
	xp.add_theme_stylebox_override("fill",GameTheme.panel(Color("5c4b30"),Color("9a7e4f"),0))
	xp_label = text_label("",12,GameTheme.IVORY)
	xp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	place(xp_label,Vector2(478,70),Vector2(268,18))
	# Exploration menus live beneath the minimap, outside the combat dock.
	navigation_panel = GridContainer.new()
	navigation_panel.columns = 2
	navigation_panel.add_theme_constant_override("h_separation",4)
	navigation_panel.add_theme_constant_override("v_separation",4)
	right.add_child(navigation_panel)
	for entry: Array in [["inventory","Inventory"],["skills","Grimoire"],["portal","Village"],["map","Map"],["pause","Pause"]]:
		var b: Button = Button.new(); b.focus_mode = Control.FOCUS_NONE
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		b.add_theme_font_size_override("font_size",13)
		b.custom_minimum_size = Vector2(118,32)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		for state: String in ["normal","hover","pressed","disabled"]:
			var style: StyleBoxFlat = GameTheme.panel(Color("282b2d") if state in ["hover","pressed"] else Color(0.035,0.045,0.05,0.88),Color("3b4144"),6)
			style.content_margin_top = 5; style.content_margin_bottom = 5
			b.add_theme_stylebox_override(state,style)
		b.pressed.connect(func()->void:
			if entry[0]=="portal": world.use_portal()
			else: menu_requested.emit(entry[0]))
		navigation_panel.add_child(b); navigation[entry[0]] = [b,entry[1]]
	# Context is visually separate from the controls, with a backdrop on bright floors.
	hint_panel = PanelContainer.new()
	hint_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	hint_panel.add_theme_stylebox_override("panel",GameTheme.panel(Color(0.035,0.045,0.06,0.94),Color("514632"),10))
	add_child(hint_panel)
	hint_label = text_label("",16)
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint_panel.add_child(hint_label)
	resized.connect(layout_dock)
	get_viewport().size_changed.connect(layout_dock)
	layout_dock()
	GameTheme.enter(dock)
	toast_label = text_label("",20,GameTheme.IVORY)
	toast_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	toast_label.offset_left = -420; toast_label.offset_right = 420; toast_label.offset_top = 135
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(toast_label)
	ignore_decoration(self)
	State.message.connect(toast)

func ignore_decoration(node: Node) -> void:
	for child: Node in node.get_children():
		if child is Control and not child is BaseButton: child.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ignore_decoration(child)

func text_label(text: String, font_size: int, color: Color = GameTheme.IVORY) -> Label:
	var l: Label = Label.new(); l.text = text
	l.add_theme_font_size_override("font_size",font_size)
	l.add_theme_color_override("font_color",color)
	l.add_theme_color_override("font_shadow_color",Color.BLACK)
	l.add_theme_constant_override("shadow_offset_x",1)
	l.add_theme_constant_override("shadow_offset_y",2)
	return l

func place(control: Control, pos: Vector2, dimensions: Vector2) -> void:
	control.position = pos; control.size = dimensions
	dock.add_child(control)

func layout_dock() -> void:
	if not is_instance_valid(dock): return
	var factor: float = minf(maxf(minf(size.x/1440.0,size.y/900.0),0.85),(size.x-24.0)/DOCK_SIZE.x)
	dock.scale = Vector2.ONE*factor
	dock.size = DOCK_SIZE
	dock.position = Vector2((size.x-DOCK_SIZE.x*factor)/2.0,size.y-DOCK_SIZE.y*factor)
	if is_instance_valid(hint_panel):
		hint_panel.offset_top = -DOCK_SIZE.y*factor-60
		hint_panel.offset_bottom = -DOCK_SIZE.y*factor-16
		var hint_font_size: int = 16
		hint_label.add_theme_font_size_override("font_size",hint_font_size)
		var line_width: float = hint_label.get_theme_font("font").get_string_size(hint_label.text,HORIZONTAL_ALIGNMENT_LEFT,-1,hint_font_size).x+44
		var half_width: float = clampf(line_width*0.5,140,minf(380,size.x*0.44))
		hint_panel.offset_left = -half_width
		hint_panel.offset_right = half_width

func potion_button(kind: String, pos: Vector2) -> HUDPotion:
	var b: HUDPotion = HUDPotion.new()
	b.resource_kind = kind
	b.position = pos; b.size = Vector2(64,78)
	dock.add_child(b)
	b.pressed.connect(func()->void: use_potion(kind))
	return b

func use_potion(kind: String) -> void:
	if State.potion(kind): Sound.play("mana" if kind=="mp" else "potion")

func toast(text: String) -> void:
	toast_label.text = text; toast_timer = 4
	GameTheme.enter(toast_label)

func _process(delta: float) -> void:
	if State.run.is_empty() or not is_instance_valid(world.player): return
	var s: Dictionary = world.player.cached_stats
	hp.update_value(State.run.hp,s.max_hp); mp.update_value(State.run.mp,s.max_mana)
	xp.max_value = State.xp_threshold(State.run.level); xp.value = State.run.xp
	xp.tooltip_text = "Experience: %d / %d" % [xp.value,xp.max_value]
	xp_label.text = "LV. %02d   ·   %d / %d XP" % [State.run.level,xp.value,xp.max_value]
	values.text = "Mage • Level %02d" % State.run.level
	location_label.text = ("EMBER HAMLET" if world.village else "THE TOWER  ·  FLOOR %02d / 13" % State.run.floor)+"\n%d gold  ·  %s" % [State.run.gold,Catalog.definition("campaign").values.difficulties[int(State.run.difficulty)]]
	if State.qa: location_label.text += "\nQA · test save"
	map.visible = not world.village
	if hint_label.text != world.hint:
		hint_label.text = world.hint
		layout_dock()
	hint_panel.visible = not world.hint.is_empty()
	spell_label.text = Catalog.title(State.run.active) if not State.run.active.is_empty() else "No magic"
	primary.update_slot(State.run.active,Controls.caption("cycle_spell"),0,1,"MAGIC")
	primary.disabled = State.run.active.is_empty()
	hp_potion.update_potion(Controls.caption("hp_potion"),State.run.hp_potions)
	mp_potion.update_potion(Controls.caption("mp_potion"),State.run.mp_potions)
	ritual_status.text = "In the village" if world.village else ""
	var available: Array = State.secondary_skills()
	for i: int in range(3):
		var id: String = available[i] if i < available.size() else ""
		var cd: float = world.player.cooldowns.get(id,0)
		var profile: Dictionary = world.combat.secondary_profile(id) if not id.is_empty() else {"cooldown":1.0,"mana":0.0}
		var empty: String = "LV. 20" if i==2 and State.run.level<20 else "EMPTY"
		var low_mana: bool = not id.is_empty() and State.run.mp + 0.00001 < State.mana_cost(profile.mana,profile.offensive)
		rituals[i].disabled = id.is_empty() or cd>0 or world.village or low_mana
		rituals[i].update_slot(id,Controls.caption("secondary_%d"%i),cd,profile.cooldown,empty,low_mana)
		if id.is_empty():
			rituals[i].tooltip_text = "Third ritual · unlocks at level 20" if empty=="LV. 20" else "Empty slot · learn a ritual when you level up"
	for action: String in navigation:
		navigation[action][0].text = "%s  %s" % [Controls.caption(action),navigation[action][1]]
	var new_key: String = str([State.run.skills,State.run.fusion,State.run.active,available,State.run.equipped,s,Controls.caption("cycle_spell")])
	if details_key!=new_key:
		details_key=new_key
		spell_hint.text = "Talk to Orme"
		if not State.run.active.is_empty():
			var attack: Dictionary = world.combat.profile(State.run.active)
			spell_hint.text = "%s mana %s" % [String.num(State.mana_cost(attack.mana),1).trim_suffix(".0").replace(".",","),"/ s" if attack.channel else "/ cast"]
		if not State.run.active.is_empty(): primary.tooltip_text=Catalog.title(State.run.active)+"\n"+SkillDetails.text(State.run.active,false)+"\nTheoretical DPS before resistance, with mana available. Range in units (u).\n"+Controls.caption("cycle_spell")+" · Switch magic (or click)."
		for i: int in range(available.size()):
			var id: String = available[i]
			rituals[i].tooltip_text=Catalog.title(id)+"\n"+SkillDetails.text(id,false)+"\nAverage DPS: damage ÷ cooldown. Before resistance."
	toast_timer -= delta; toast_label.visible = toast_timer>0
