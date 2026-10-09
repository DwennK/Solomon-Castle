class_name LevelUpView
extends Control

signal choice_requested(id: String)
signal reroll_requested
signal continue_requested

const INK: Color = Color("281b16")
const MUTED_INK: Color = Color("62462e")
const PAPER: Texture2D = preload("res://assets/ui/level-up/card-frame.png")
var offered: Array = []
var selected_id: String = ""
var cards: Dictionary = {}
var papers: Dictionary = {}
var detail_scrolls: Dictionary = {}
var detail_labels: Dictionary = {}
var rank_labels: Dictionary = {}
var artworks: Array[Control] = []
var confirm: Button
var reroll: Button
var card_row: HBoxContainer
var content: VBoxContainer
var footer: VBoxContainer
var committed: bool = false

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade: ColorRect = ColorRect.new()
	shade.color = Color(0.008,0.009,0.015,0.9)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left","right"]: margin.add_theme_constant_override("margin_"+side,48)
	for side: String in ["top","bottom"]: margin.add_theme_constant_override("margin_"+side,24)
	add_child(margin)
	content = VBoxContainer.new()
	content.add_theme_constant_override("separation",14)
	margin.add_child(content)
	var level: Label = text(content,"LEVEL %d" % int(State.run.pending[0]),18,GameTheme.GOLD)
	level.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var title: Label = text(content,"Choose your knowledge",32,GameTheme.IVORY)
	title.add_theme_font_override("font",GameTheme.TITLE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if State.run.pending.size()>1:
		var pending: Label = text(content,"%d choices remaining" % State.run.pending.size(),14,GameTheme.MUTED)
		pending.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card_row = HBoxContainer.new()
	card_row.add_theme_constant_override("separation",20)
	card_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(card_row)
	for id: String in offered: make_card(id)
	footer = VBoxContainer.new()
	footer.add_theme_constant_override("separation",8)
	content.add_child(footer)
	confirm = Button.new()
	confirm.name = "ConfirmKnowledge"
	confirm.custom_minimum_size = Vector2(480,52)
	confirm.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	confirm.add_theme_font_override("font",GameTheme.TITLE)
	confirm.add_theme_font_size_override("font_size",20)
	confirm.add_theme_stylebox_override("normal",GameTheme.panel(Color("251e17"),GameTheme.GOLD,12))
	confirm.pressed.connect(commit_choice)
	footer.add_child(confirm)
	reroll = Button.new()
	reroll.name = "RerollKnowledge"
	reroll.text = "Reroll choices · 1 shard (%d available)" % State.run.get("insight",1)
	reroll.custom_minimum_size.y = 36
	reroll.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	reroll.add_theme_font_size_override("font_size",14)
	reroll.disabled = not State.can_reroll()
	reroll.tooltip_text = "Start with one shard and earn one per main guardian. Each reroll costs 1 shard. Previous choices are avoided; a unique fusion or a choice with no alternative may return."
	if reroll.disabled:
		reroll.tooltip_text += "\n"+("No shards remaining." if State.run.get("insight",1)<=0 else "No other eligible upgrades.")
	reroll.pressed.connect(func()->void: reroll_requested.emit())
	footer.add_child(reroll)
	if offered.is_empty():
		text(card_row,"All knowledge mastered.",26,GameTheme.IVORY)
		confirm.text = "Continue"
		confirm.grab_focus()
	else:
		select(offered[0])
		cards[offered[0]].grab_focus()
	resized.connect(fit_art)
	fit_art()
	GameTheme.enter(content)

func make_card(id: String) -> void:
	var d: ContentDefinition = Catalog.definition(id)
	var card: PanelContainer = PanelContainer.new()
	card.name = "Choice_"+id
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.focus_mode = Control.FOCUS_ALL
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	card.clip_contents = true
	card_row.add_child(card)
	cards[id] = card
	card.gui_input.connect(func(event: InputEvent)->void:
		if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed:
			card.grab_focus();select(id);card.accept_event()
		elif event.is_action_pressed("ui_accept"):
			select(id);confirm.grab_focus();card.accept_event())
	card.focus_entered.connect(func()->void: select(id))
	card.mouse_entered.connect(func()->void:
		if id!=selected_id: card.modulate=Color(1.04,1.04,1.04))
	card.mouse_exited.connect(func()->void: card.modulate=Color.WHITE)
	var paper: PanelContainer = PanelContainer.new()
	paper.mouse_filter = Control.MOUSE_FILTER_PASS
	card.add_child(paper)
	papers[id] = paper
	var body: VBoxContainer = VBoxContainer.new()
	body.add_theme_constant_override("separation",8)
	body.mouse_filter = Control.MOUSE_FILTER_PASS
	paper.add_child(body)
	var art: TextureRect = TextureRect.new()
	art.texture = load("res://assets/ui/level-up/"+art_family(id)+".png")
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(art)
	artworks.append(art)
	var category: Label = text(body,kind_caption(id),13,MUTED_INK)
	category.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var heading: HBoxContainer = HBoxContainer.new()
	heading.add_theme_constant_override("separation",8)
	body.add_child(heading)
	var icon: TextureRect = TextureRect.new()
	icon.texture = Catalog.skill_texture(id)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(38,38)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	heading.add_child(icon)
	var title: Label = text(heading,d.title,22,INK)
	title.add_theme_font_override("font",GameTheme.TITLE)
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var progression: Dictionary = advancement(id)
	var next_value: String = progression.next
	if progression.current.begins_with("Lv. "): next_value=next_value.trim_prefix("Lv. ")
	elif progression.current.begins_with("Snapshot Lv. "): next_value=next_value.trim_prefix("Snapshot Lv. ")
	rank_labels[id] = text(body,progression.current+" → "+next_value,15,MUTED_INK)
	if not progression.note.is_empty(): text(body,progression.note,13,MUTED_INK)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.name = "SkillDetails_"+id
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	scroll.focus_mode = Control.FOCUS_ALL
	scroll.focus_entered.connect(func()->void: select(id))
	body.add_child(scroll)
	detail_scrolls[id] = scroll
	var details: VBoxContainer = VBoxContainer.new()
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.add_theme_constant_override("separation",10)
	scroll.add_child(details)
	text(details,d.description,16,INK)
	var rule: HSeparator = HSeparator.new()
	details.add_child(rule)
	# Use the same combat calculations and complete text as the previous choice UI.
	var info: Label = text(details,SkillDetails.text(id,true),15,INK)
	detail_labels[id] = info

func select(id: String) -> void:
	if committed or id not in offered: return
	selected_id = id
	for key: String in cards:
		var card: PanelContainer = cards[key]
		var paper: StyleBoxTexture = StyleBoxTexture.new()
		paper.texture = PAPER
		paper.modulate_color = Color(0.91,0.85,0.76) if key==id else Color(0.80,0.77,0.70)
		for side: int in [SIDE_LEFT,SIDE_TOP,SIDE_RIGHT,SIDE_BOTTOM]:
			paper.set_texture_margin(side,48)
			paper.set_content_margin(side,24)
		papers[key].add_theme_stylebox_override("panel",paper)
		var edge: StyleBoxFlat=GameTheme.panel(Color("1c1712"),GameTheme.GOLD if key==id else Color("57432b"),2)
		edge.set_border_width_all(2)
		edge.set_corner_radius_all(4)
		if key==id:
			edge.shadow_color=Color(0.85,0.59,0.22,0.25)
			edge.shadow_size=12
		card.add_theme_stylebox_override("panel",edge)
		card.modulate = Color.WHITE
	var d: ContentDefinition = Catalog.definition(id)
	confirm.text = ("Forge " if d.kind=="fusion" else ("Upgrade " if State.learned_rank(id)>0 else "Learn "))+d.title
	confirm.disabled = false

func commit_choice() -> void:
	if committed: return
	committed = true
	confirm.disabled = true
	Sound.play("ui")
	if offered.is_empty(): continue_requested.emit()
	else: choice_requested.emit(selected_id)

func fit_art() -> void:
	# Keep every choice and the confirmation visible, including Creativity's fourth card.
	var height: float = clampf((size.y-180)*0.255,130,250)
	if offered.size()==4: height*=0.82
	for art: Control in artworks: art.custom_minimum_size.y=height

static func kind_caption(id: String) -> String:
	var d: ContentDefinition = Catalog.definition(id)
	match d.kind:
		"primary": return "SPELL · PRIMARY"
		"secondary": return "RITUAL · ACTIVE"
		"fusion": return "SPELL · FUSION"
		"passive":
			if d.values.get("major",false): return "PASSIVE · MAJOR"
			if not d.prerequisite.is_empty(): return "PASSIVE · "+Catalog.title(d.prerequisite).to_upper()
			return "PASSIVE · KNOWLEDGE"
	return d.kind.to_upper()

static func advancement(id: String) -> Dictionary:
	var d: ContentDefinition = Catalog.definition(id)
	if d.kind=="fusion":
		var current: String = "Not forged"
		if State.run.fusion.get("id","")==id: current = "Snapshot Lv. %d" % State.run.fusion.level
		var elements: Array = []
		for element: String in d.values.elements: elements.append("%s Lv. %d" % [Catalog.title(element),State.rank(element)])
		return {"current":current,"next":"Snapshot Lv. %d" % State.run.level,"note":" + ".join(elements)}
	var learned: int = State.learned_rank(id)
	var effective: int = State.rank(id)
	var after: int = State.effective_rank(id,learned+1,State.equipment_bonuses())
	var note: String = ""
	if effective!=learned or after!=learned+1:
		note = "With equipment: Lv. %d → %d" % [effective,after]
	return {"current":"Lv. %d" % learned,"next":"Lv. %d" % (learned+1),"note":note}

static func art_family(id: String) -> String:
	var d: ContentDefinition = Catalog.definition(id)
	if id in ["freeze","ice","cone","chill","harden","blizzard","frost_missile"]: return "ice"
	if id in ["ring_fire","fire","explode","embers","immolation","fire_missile","steam"]: return "fire"
	if id in ["lightning","chain","stun","hurricane","ball_lightning","flame_lash"]: return "lightning"
	if id in ["missile","multishot","potent","ether_charge"]: return "arcane"
	return "ritual" if d.kind=="secondary" else "knowledge"

static func text(parent: Node, value: String, font_size: int, color: Color) -> Label:
	var label: Label = Label.new()
	label.text = value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_color_override("font_color",color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label
