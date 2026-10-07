class_name SpellSlot
extends Button

var icon_view: TextureRect
var key_label: Label
var cooldown_label: Label
var shade: ColorRect
var caption_label: Label
var spell_id: String = "!"
var primary_slot: bool = false
var unavailable: bool = false
var hover_amount: float = 0.0
var ready_flash: float = 0.0
var previous_cooldown: float = 0.0
var cooldown_ratio: float = 0.0
var frame_style: StyleBoxFlat

func _init() -> void:
	custom_minimum_size = Vector2(76,78)
	frame_style = GameTheme.panel(Color("11151c"),Color("5d5140"),0)
	frame_style.set_corner_radius_all(0)
	focus_mode = Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for state: String in ["normal","hover","pressed","disabled","focus"]:
		add_theme_stylebox_override(state,StyleBoxEmpty.new())

func _ready() -> void:
	icon_view = TextureRect.new()
	icon_view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon_view.offset_left = 8; icon_view.offset_top = 4
	icon_view.offset_right = -8; icon_view.offset_bottom = -19
	icon_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(icon_view)
	shade = ColorRect.new()
	shade.color = Color(0.025,0.03,0.04,0.78)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	key_label = overlay_label(14)
	key_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	key_label.offset_top = -21; key_label.offset_bottom = -2
	key_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	cooldown_label = overlay_label(24)
	cooldown_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cooldown_label.offset_bottom = -16
	cooldown_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	caption_label = overlay_label(11)
	caption_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	caption_label.offset_top = 27; caption_label.offset_bottom = -18
	caption_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	caption_label.add_theme_color_override("font_color",GameTheme.MUTED)

func overlay_label(font_size: int) -> Label:
	var l: Label = Label.new()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size",font_size)
	l.add_theme_color_override("font_shadow_color",Color.BLACK)
	l.add_theme_constant_override("shadow_offset_y",2)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l

func update_slot(id: String, key: String, cooldown: float = 0, duration: float = 1, empty: String = "EMPTY", blocked: bool = false) -> void:
	if spell_id != id:
		spell_id = id
		var definition: ContentDefinition = Catalog.definition(id)
		icon_view.texture = Catalog.skill_texture(id) if not id.is_empty() else null
		tooltip_text = definition.title + "\n" + definition.description if definition else empty
		previous_cooldown = 0.0
	if previous_cooldown > 0 and cooldown <= 0: ready_flash = 1.0
	previous_cooldown = cooldown
	cooldown_ratio = clampf(cooldown/maxf(duration,0.001),0,1)
	unavailable = blocked
	key_label.text = key
	caption_label.text = empty if id.is_empty() else ("MANA" if blocked and cooldown<=0 else "")
	cooldown_label.text = "%ds" % ceili(cooldown) if cooldown > 0 else ""
	shade.visible = cooldown > 0 or blocked
	shade.position = Vector2(3,3)
	shade.size = Vector2(size.x-6,(size.y-25)*(cooldown_ratio if cooldown>0 else 1.0))
	icon_view.modulate = Color("686b78") if cooldown > 0 or blocked else (Color("94979e") if disabled else Color.WHITE)
	queue_redraw()

func _process(delta: float) -> void:
	var reduced: bool = State.options.get("reduced_effects",false)
	var hover_target: float = 1.0 if is_hovered() and not disabled else 0.0
	hover_amount = hover_target if reduced else move_toward(hover_amount,hover_target,delta*10)
	ready_flash = maxf(0.0,ready_flash-delta*2.5) if not reduced else 0.0
	queue_redraw()

func _draw() -> void:
	var border: Color = Color("c6a56a") if primary_slot else Color("69706d")
	if spell_id.is_empty(): border = Color("34383f")
	border = border.lerp(GameTheme.IVORY,hover_amount*0.6+ready_flash*0.4)
	frame_style.bg_color = Color("241e16") if primary_slot else Color("101719")
	frame_style.border_color = border
	draw_style_box(frame_style,Rect2(Vector2.ZERO,size))
	draw_rect(Rect2(3,3,size.x-6,size.y-6),border.darkened(0.45),false,1.0)
	draw_line(Vector2(2,2),Vector2(size.x-2,2),border.lightened(0.15),2.0)
	for corner: Vector2 in [Vector2(3,3),Vector2(size.x-4,3),Vector2(3,size.y-4),size-Vector2(4,4)]:
		draw_circle(corner,1.5,border,true,-1,true)
	if primary_slot:
		draw_rect(Rect2(-3,-3,size.x+6,size.y+6),Color("80643c"),false,2.0)
	if not spell_id.is_empty():
		ArcaneArt.glow(self,size*Vector2(0.5,0.4),size.x*0.55,Color("b4925e"),0.1+hover_amount*0.12)
	else:
		var c: Vector2 = Vector2(size.x/2,23)
		if caption_label and caption_label.text == "LV. 20":
			draw_arc(c+Vector2(0,-3),5,PI,TAU,12,Color("6b6a68"),1.5,true)
			draw_rect(Rect2(c+Vector2(-7,-3),Vector2(14,11)),Color("6b6a68"),false,1.0)
		else:
			draw_line(c-Vector2(6,0),c+Vector2(6,0),Color("595d63"),1.0)
			draw_line(c-Vector2(0,6),c+Vector2(0,6),Color("595d63"),1.0)
	draw_rect(Rect2(2,size.y-22,size.x-4,20),Color("0a0d12"))
	draw_line(Vector2(7,size.y-23),Vector2(size.x-7,size.y-23),Color("413b31"),1.0)
	if cooldown_ratio>0:
		draw_line(Vector2(3,size.y-1),Vector2(3+(size.x-6)*(1-cooldown_ratio),size.y-1),GameTheme.GOLD,2.0)
