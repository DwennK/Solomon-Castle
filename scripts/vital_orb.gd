class_name VitalOrb
extends Control

var liquid: ColorRect
var value_label: Label
var title_label: Label
var displayed: float = 1.0
var target: float = 1.0
var resource_kind: String = "hp"
var critical: bool = false

func _init() -> void:
	custom_minimum_size = Vector2(136,158)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _ready() -> void:
	liquid = ColorRect.new()
	liquid.position = Vector2(29,23)
	liquid.size = Vector2(78,78)
	liquid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = preload("res://assets/ui/vital_orb.gdshader")
	mat.set_shader_parameter("liquid_color",Color("d52240") if resource_kind == "hp" else Color("348cec"))
	liquid.material = mat
	add_child(liquid)
	var frame: TextureRect = TextureRect.new()
	frame.texture = preload("res://assets/ui/orb-frame.png")
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame.position = Vector2(6,0)
	frame.size = Vector2(124,124)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(frame)
	# Values sit on a calm, opaque plate instead of crossing the liquid surface.
	var plate: Panel = Panel.new()
	plate.position = Vector2(6,107); plate.size = Vector2(124,28)
	plate.add_theme_stylebox_override("panel",GameTheme.panel(Color("0e1115"),Color("4e4537"),0))
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(plate)
	value_label = Label.new()
	value_label.position = Vector2(6,107); value_label.size = Vector2(124,28)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	value_label.add_theme_font_size_override("font_size",19)
	value_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(value_label)
	title_label = Label.new()
	title_label.position = Vector2(0,136); title_label.size = Vector2(136,20)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size",12)
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(title_label)

func update_value(value: float, maximum: float) -> void:
	target = clampf(value / maxf(1,maximum),0,1)
	critical = resource_kind == "hp" and target <= 0.25
	value_label.text = "%d / %d" % [ceili(value),ceili(maximum)]
	value_label.add_theme_color_override("font_color",Color("ffb0a6") if critical else GameTheme.IVORY)
	title_label.text = "VIE FAIBLE" if critical else ("VIE" if resource_kind == "hp" else "MANA")
	title_label.add_theme_color_override("font_color",Color("ffb0a6") if critical else GameTheme.MUTED)
	tooltip_text = ("Vie" if resource_kind == "hp" else "Mana") + " : " + value_label.text

func _process(delta: float) -> void:
	displayed = move_toward(displayed,target,delta*1.5)
	liquid.material.set_shader_parameter("fill_level",displayed)
	liquid.material.set_shader_parameter("motion",0.0 if State.options.get("reduced_effects",false) else 1.0)
