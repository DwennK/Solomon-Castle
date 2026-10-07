class_name CodexShell
extends Control

signal close_requested
signal section_requested(section: String)

const INK: Color = Color("281b16")
const MUTED: Color = Color("594330")
const ACCENT: Color = Color("583254")
var section: String = "inventory"
var left: VBoxContainer
var right: VBoxContainer
var footer: HBoxContainer
var navigation: HBoxContainer

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade: ColorRect = ColorRect.new()
	shade.color = Color(0.015,0.012,0.018,0.86)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_"+side,24)
	add_child(margin)
	var root: VBoxContainer = VBoxContainer.new();margin.add_child(root)
	root.add_theme_constant_override("separation",8)
	navigation = HBoxContainer.new();root.add_child(navigation)
	var name_label: Label = Label.new()
	name_label.text = "THE MAGE’S CODEX"
	name_label.add_theme_font_override("font",GameTheme.TITLE)
	name_label.add_theme_font_size_override("font_size",18)
	name_label.add_theme_color_override("font_color",GameTheme.GOLD)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	navigation.add_child(name_label)
	for entry: Array in [["inventory","Inventory"],["skills","Grimoire"],["map","Map"],["pause","Pause"]]:
		var tab: Button = button(navigation,entry[1],func()->void:
			if section!=entry[0]: section_requested.emit(entry[0]))
		tab.custom_minimum_size.x = 120
		if section==entry[0]: tab.add_theme_stylebox_override("normal",selected_style())
	var close: Button = button(navigation,"Close",func()->void:close_requested.emit())
	close.custom_minimum_size.x=100
	close.tooltip_text = "Close codex · Esc / B"
	var book: Control = Control.new();root.add_child(book)
	book.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var texture: TextureRect = TextureRect.new()
	texture.texture = preload("res://assets/ui/codex-book.png")
	texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture.stretch_mode = TextureRect.STRETCH_SCALE
	texture.self_modulate = Color(0.78,0.75,0.72)
	texture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	book.add_child(texture)
	left = page(book,0.065,0.455)
	right = page(book,0.55,0.935)
	footer = HBoxContainer.new();root.add_child(footer)
	GameTheme.enter(book)

func page(parent: Control, start: float, end: float) -> VBoxContainer:
	var body: VBoxContainer = VBoxContainer.new()
	parent.add_child(body)
	body.anchor_left=start;body.anchor_right=end
	body.anchor_top=0.065;body.anchor_bottom=0.9
	body.add_theme_constant_override("separation",12)
	return body

static func selected_style() -> StyleBoxFlat:
	return GameTheme.panel(Color("443047"),Color("b698bd"),10)

static func heading(parent: Node, value: String, size: int = 30) -> Label:
	var label: Label = text(parent,value,size)
	label.add_theme_font_override("font",GameTheme.TITLE)
	return label

static func text(parent: Node, value: String, size: int = 16, color: Color = INK) -> Label:
	var label: Label = Label.new()
	label.text=value;label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size",size)
	label.add_theme_color_override("font_color",color)
	label.mouse_filter=Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

static func button(parent: Node, value: String, callback: Callable) -> Button:
	var result: Button = Button.new()
	result.text=value;result.custom_minimum_size.y=42
	result.add_theme_font_size_override("font_size",15)
	result.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	result.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
	result.pressed.connect(func()->void:Sound.play("ui");callback.call())
	parent.add_child(result)
	return result

static func search(parent: Node, placeholder: String) -> LineEdit:
	var edit: LineEdit = LineEdit.new()
	edit.placeholder_text=placeholder
	edit.clear_button_enabled=true
	edit.custom_minimum_size.y=42
	edit.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	edit.add_theme_font_size_override("font_size",16)
	edit.add_theme_color_override("font_color",GameTheme.IVORY)
	edit.add_theme_color_override("font_placeholder_color",Color("b9aa96"))
	edit.add_theme_stylebox_override("normal",GameTheme.panel(Color("29231f"),Color("66513d"),10))
	edit.add_theme_stylebox_override("focus",GameTheme.panel(Color("29231f"),GameTheme.GOLD,10))
	parent.add_child(edit)
	return edit

static func matches_query(value: String, query: String) -> bool:
	return query.strip_edges().is_empty() or value.to_lower().contains(query.strip_edges().to_lower())
