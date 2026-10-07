class_name GameTheme
extends RefCounted

static func panel(color: Color = Color("101b25"),border: Color = Color("665c49"),padding: int = 22) -> StyleBoxFlat:
	var s: StyleBoxFlat = StyleBoxFlat.new()
	s.bg_color = color
	s.border_color = border
	s.set_border_width_all(1)
	s.set_corner_radius_all(5)
	s.content_margin_left = padding
	s.content_margin_right = padding
	s.content_margin_top = padding
	s.content_margin_bottom = padding
	return s

static func create() -> Theme:
	var t: Theme = Theme.new()
	t.default_font_size = 19
	t.set_color("font_color","Label",Color("e5dcc8"))
	t.set_color("font_color","Button",Color("eadfc4"))
	t.set_color("font_hover_color","Button",Color("fff0ce"))
	t.set_stylebox("normal","Button",panel(Color("1a2932"),Color("655a45"),14))
	t.set_stylebox("hover","Button",panel(Color("293b43"),Color("b89d64"),14))
	t.set_stylebox("pressed","Button",panel(Color("34434a"),Color("d9bb7d"),14))
	t.set_stylebox("focus","Button",panel(Color(0,0,0,0),Color("f0ce89"),14))
	t.set_stylebox("disabled","Button",panel(Color("141d23"),Color("363a36"),14))
	t.set_color("font_disabled_color","Button",Color("797d78"))
	t.set_stylebox("panel","PanelContainer",panel())
	t.set_constant("separation","VBoxContainer",12)
	t.set_constant("separation","HBoxContainer",12)
	return t
