class_name HUDPotion
extends Button

var resource_kind: String = "hp"
var key_label: Label
var count_label: Label
var icon_view: TextureRect

func _init() -> void:
	custom_minimum_size = Vector2(64,78)
	focus_mode = Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for state: String in ["normal","hover","pressed","disabled","focus"]:
		var border: Color = Color("97805a") if state in ["hover","pressed"] else Color("423d36")
		add_theme_stylebox_override(state,GameTheme.panel(Color("14181e"),border,0))
	for state: String in ["font_color","font_hover_color","font_pressed_color","font_disabled_color","font_focus_color"]:
		add_theme_color_override(state,Color.TRANSPARENT)
	add_theme_font_size_override("font_size",12)
	clip_text = true

func _ready() -> void:
	icon_view = TextureRect.new()
	icon_view.texture = Catalog.texture("health" if resource_kind == "hp" else "mana")
	icon_view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_view.position = Vector2(6,2); icon_view.size = Vector2(44,53)
	icon_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(icon_view)
	count_label = Label.new()
	count_label.position = Vector2(34,33); count_label.size = Vector2(28,23)
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count_label.add_theme_font_size_override("font_size",15)
	count_label.add_theme_color_override("font_shadow_color",Color.BLACK)
	count_label.add_theme_constant_override("shadow_offset_y",2)
	count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(count_label)
	key_label = Label.new()
	key_label.position = Vector2(2,56); key_label.size = Vector2(60,20)
	key_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	key_label.add_theme_font_size_override("font_size",12)
	key_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	key_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(key_label)

func update_potion(key: String, count: int) -> void:
	text = "%s\n×%d" % [key,count]
	key_label.text = key
	count_label.text = "×%d" % count
	disabled = count<=0
	icon_view.modulate = Color("565963") if disabled else Color.WHITE
	count_label.add_theme_color_override("font_color",GameTheme.MUTED if disabled else GameTheme.IVORY)
	tooltip_text = "Potion de %s · %s\n%s" % ["vie" if resource_kind=="hp" else "mana",key,"Aucune potion" if disabled else "%d en réserve" % count]
