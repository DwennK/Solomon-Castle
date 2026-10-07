class_name GameHUD
extends Control

var world: GameWorld
var hp: ProgressBar
var mp: ProgressBar
var xp: ProgressBar
var values: Label
var location_label: Label
var hint_label: Label
var spell_label: Label
var ritual_label: Label
var toast_label: Label
var map: TowerMap
var help: Label
var toast_timer: float = 0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var top: HBoxContainer = HBoxContainer.new()
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 26
	top.offset_top = 22
	top.offset_right = -26
	add_child(top)
	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = Vector2(330,0)
	panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	top.add_child(panel)
	var v: VBoxContainer = VBoxContainer.new()
	panel.add_child(v)
	values = Label.new()
	v.add_child(values)
	hp = make_bar(Color("b06c66"));v.add_child(hp)
	mp = make_bar(Color("589cae"));v.add_child(mp)
	xp = make_bar(Color("c2a56a"),6);v.add_child(xp)
	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spacer)
	var right: VBoxContainer = VBoxContainer.new()
	top.add_child(right)
	location_label = Label.new()
	location_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.add_child(location_label)
	map = TowerMap.new()
	map.world = world
	map.custom_minimum_size = Vector2(250,194)
	right.add_child(map)
	var bottom: PanelContainer = PanelContainer.new()
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_left = 26
	bottom.offset_right = -26
	bottom.offset_top = -135
	bottom.offset_bottom = -20
	add_child(bottom)
	var row: HBoxContainer = HBoxContainer.new()
	bottom.add_child(row)
	var magic: VBoxContainer = VBoxContainer.new()
	magic.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(magic)
	spell_label = Label.new();magic.add_child(spell_label)
	ritual_label = Label.new();ritual_label.add_theme_font_size_override("font_size",15);magic.add_child(ritual_label)
	help = Label.new()
	help.text = "I  Inventaire     K  Grimoire     T  Village\nR  Vie     F  Mana     Échap  Pause"
	help.add_theme_font_size_override("font_size",16)
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(help)
	hint_label = Label.new()
	hint_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	hint_label.offset_left = -550
	hint_label.offset_right = 550
	hint_label.offset_top = -177
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.add_theme_color_override("font_shadow_color",Color.BLACK)
	hint_label.add_theme_constant_override("shadow_offset_x",2)
	hint_label.add_theme_constant_override("shadow_offset_y",2)
	add_child(hint_label)
	toast_label = Label.new()
	toast_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	toast_label.offset_left = -420
	toast_label.offset_right = 420
	toast_label.offset_top = 170
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(toast_label)
	State.message.connect(toast)

func make_bar(color: Color,height: int = 12) -> ProgressBar:
	var b: ProgressBar = ProgressBar.new()
	b.custom_minimum_size = Vector2(285,height)
	b.show_percentage = false
	b.add_theme_stylebox_override("background",GameTheme.panel(Color("080f15"),Color("26333a"),0))
	b.add_theme_stylebox_override("fill",GameTheme.panel(color,color,0))
	return b

func toast(text: String) -> void:
	toast_label.text = text
	toast_timer = 4

func _process(delta: float) -> void:
	if State.run.is_empty() or not is_instance_valid(world.player): return
	var s: Dictionary = world.player.cached_stats
	hp.max_value = s.max_hp;hp.value = State.run.hp
	mp.max_value = s.max_mana;mp.value = State.run.mp
	xp.max_value = State.xp_threshold(State.run.level);xp.value = State.run.xp
	values.text = "NIV. %02d    %d / %d ♥    %d / %d ◇"%[State.run.level,State.run.hp,s.max_hp,State.run.mp,s.max_mana]
	location_label.text = ("LE HAMEAU DES BRAISES" if world.village else "LA TOUR  ·  ÉTAGE %02d / 13"%State.run.floor)+"\n%d or  ·  %s"%[State.run.gold,Catalog.definition("campaign").values.difficulties[int(State.run.difficulty)]]
	map.visible = not world.village
	hint_label.text = world.hint
	help.text = "%s Inventaire   %s Grimoire   %s Village\n%s Vie   %s Mana   %s Pause"%[Controls.caption("inventory"),Controls.caption("skills"),Controls.caption("portal"),Controls.caption("hp_potion"),Controls.caption("mp_potion"),Controls.caption("pause")]
	spell_label.text = (Catalog.title(State.run.active) if not State.run.active.is_empty() else "Choisissez votre première magie auprès d’Orme")+"   [%s]      Vie ×%d   Mana ×%d"%[Controls.caption("cycle_spell"),State.run.hp_potions,State.run.mp_potions]
	var rituals: Array[String] = []
	for i: int in range(State.run.secondary.size()):
		var id: String = State.run.secondary[i]
		var cd: float = world.player.cooldowns.get(id,0)
		rituals.append("[%s] %s  %s"%[Controls.caption("secondary_%d"%i),Catalog.title(id),"%.0fs"%ceilf(cd) if cd>0 else "prêt"])
	ritual_label.text = "   ·   ".join(rituals) if not rituals.is_empty() else "Les rituels secondaires se débloquent à partir du niveau 3."
	toast_timer -= delta
	toast_label.visible = toast_timer>0
