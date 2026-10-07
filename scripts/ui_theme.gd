class_name GameTheme
extends RefCounted

const GOLD: Color = Color("bea06a")
const IVORY: Color = Color("eee4d1")
const MUTED: Color = Color("a69d8e")
const TITLE: Font = preload("res://assets/fonts/Cinzel.ttf")
const BODY: Font = preload("res://assets/fonts/Lato-Regular.ttf")

static func panel(color: Color = Color("121315"), border: Color = Color("65533a"), padding: int = 22) -> StyleBoxFlat:
	var s: StyleBoxFlat = StyleBoxFlat.new()
	s.bg_color = color
	s.border_color = border
	s.set_border_width_all(1)
	s.set_corner_radius_all(2)
	s.content_margin_left = padding
	s.content_margin_right = padding
	s.content_margin_top = padding
	s.content_margin_bottom = padding
	return s

static func create() -> Theme:
	var t: Theme = Theme.new()
	t.default_font = BODY
	t.default_font_size = 18
	t.set_color("font_color", "Label", IVORY)
	for type: String in ["Button", "OptionButton"]:
		t.set_color("font_color", type, IVORY)
		t.set_color("font_hover_color", type, Color("fff0cf"))
		t.set_color("font_focus_color", type, Color("fff0cf"))
		t.set_color("font_disabled_color", type, Color("746f65"))
		t.set_stylebox("normal", type, panel(Color("1d1c1a"), Color("514633"), 14))
		t.set_stylebox("hover", type, panel(Color("30291e"), GOLD, 14))
		t.set_stylebox("pressed", type, panel(Color("443421"), Color("e1bd7c"), 14))
		t.set_stylebox("focus", type, panel(Color(0,0,0,0), Color("d1b77e"), 14))
		t.set_stylebox("disabled", type, panel(Color("141414"), Color("34312b"), 14))
		t.set_constant("h_separation", type, 16)
	t.set_icon("checked","CheckBox",preload("res://assets/ui/check-on.svg"))
	t.set_icon("unchecked","CheckBox",preload("res://assets/ui/check-off.svg"))
	t.set_constant("h_separation","CheckBox",12)
	for state: String in ["grabber","grabber_highlight","grabber_disabled"]:
		t.set_icon(state,"HSlider",preload("res://assets/ui/slider-knob.svg"))
	t.set_stylebox("panel", "PanelContainer", panel())
	t.set_stylebox("panel", "PopupMenu", panel())
	t.set_stylebox("hover", "PopupMenu", panel(Color("30291e"), GOLD, 8))
	t.set_color("font_color", "PopupMenu", IVORY)
	t.set_constant("v_separation", "PopupMenu", 16)
	t.set_stylebox("normal", "TooltipPanel", panel(Color("151515"), GOLD, 14))
	t.set_color("font_color", "TooltipLabel", IVORY)
	var line: StyleBoxLine = StyleBoxLine.new()
	line.color = Color("514633")
	line.thickness = 1
	t.set_stylebox("separator", "HSeparator", line)
	for type: String in ["HSlider", "HScrollBar", "VScrollBar"]:
		t.set_stylebox("slider" if type == "HSlider" else "scroll", type, panel(Color("090a0b"), Color("353027"), 4))
		t.set_stylebox("grabber_area" if type == "HSlider" else "grabber", type, panel(Color("87704b"), GOLD, 4))
		t.set_stylebox("grabber_area_highlight" if type == "HSlider" else "grabber_highlight", type, panel(GOLD, IVORY, 4))
	t.set_constant("separation", "VBoxContainer", 12)
	t.set_constant("separation", "HBoxContainer", 12)
	t.set_constant("h_separation", "GridContainer", 16)
	t.set_constant("v_separation", "GridContainer", 16)
	return t

static func heading(label: Label) -> void:
	label.add_theme_font_override("font", TITLE)
	label.add_theme_color_override("font_color", CodexShell.INK if label.get_meta("ink",false) else IVORY)

static func parchment() -> StyleBoxTexture:
	var style: StyleBoxTexture=StyleBoxTexture.new()
	style.texture=preload("res://assets/ui/codex-parchment.png")
	style.modulate_color=Color(0.78,0.75,0.72)
	for side: int in [SIDE_LEFT,SIDE_TOP,SIDE_RIGHT,SIDE_BOTTOM]:
		style.set_texture_margin(side,70)
		style.set_content_margin(side,60)
	return style

static func is_parchment(node: Node) -> bool:
	var current: Node=node
	while current:
		if current.has_meta("parchment"): return current.get_meta("parchment")
		if current is PanelContainer and current.has_theme_stylebox_override("panel"): return false
		current=current.get_parent()
	return false

static func surface_text(parent: Node, color: Color) -> Color:
	if not is_parchment(parent): return color
	return CodexShell.MUTED if color==MUTED or color==GOLD else CodexShell.INK

static func paper_checkbox(check: CheckBox) -> void:
	for state: String in ["font_color","font_hover_color","font_pressed_color","font_hover_pressed_color","font_focus_color"]:
		check.add_theme_color_override(state,CodexShell.INK)
	for state: String in ["normal","pressed","hover","hover_pressed"]:
		check.add_theme_stylebox_override(state,panel(Color(0,0,0,0),Color(0,0,0,0),10))
	check.add_theme_stylebox_override("focus",panel(Color(0,0,0,0),CodexShell.ACCENT,10))

static func enter(control: Control) -> void:
	if State.options.get("reduced_effects", false): return
	control.modulate.a = 0
	control.create_tween().tween_property(control, "modulate:a", 1.0, 0.2)
