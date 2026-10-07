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
	custom_minimum_size = Vector2(216,216)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _ready() -> void:
	liquid = ColorRect.new()
	liquid.position = Vector2(36,33)
	liquid.size = Vector2(144,144)
	liquid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = preload("res://assets/ui/vital_orb.gdshader")
	mat.set_shader_parameter("liquid_color",Color("b41c29") if resource_kind == "hp" else Color("19498f"))
	mat.set_shader_parameter("liquid_atlas",preload("res://assets/ui/gothic-hud/liquid-atlas.png"))
	# Measured circular regions, not assumed equal atlas cells.
	mat.set_shader_parameter("liquid_region",Vector4(80.0/1774.0,66.0/887.0,746.0/1774.0,742.0/887.0) if resource_kind == "hp" else Vector4(948.0/1774.0,66.0/887.0,748.0/1774.0,742.0/887.0))
	liquid.material = mat
	add_child(liquid)
	var frame: TextureRect = TextureRect.new()
	frame.texture = preload("res://assets/ui/gothic-hud/orb-holder.png")
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame.position = Vector2.ZERO
	frame.size = Vector2(216,216)
	frame.modulate = Color(0.72,0.76,0.79)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(frame)
	# Values sit on a calm, opaque plate instead of crossing the liquid surface.
	var plate: Panel = Panel.new()
	plate.position = Vector2(45,175); plate.size = Vector2(126,25)
	plate.add_theme_stylebox_override("panel",GameTheme.panel(Color(0.025,0.03,0.04,0.92),Color("484b4c"),0))
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(plate)
	value_label = Label.new()
	value_label.position = Vector2(45,175); value_label.size = Vector2(126,25)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	value_label.add_theme_font_size_override("font_size",19)
	value_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(value_label)
	title_label = Label.new()
	title_label.position = Vector2(0,199); title_label.size = Vector2(216,17)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size",12)
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(title_label)

func update_value(value: float, maximum: float) -> void:
	target = clampf(value / maxf(1,maximum),0,1)
	critical = resource_kind == "hp" and target <= 0.25
	value_label.text = "%d / %d" % [ceili(value),ceili(maximum)]
	value_label.add_theme_color_override("font_color",Color("ffb0a6") if critical else GameTheme.IVORY)
	title_label.text = "LOW HEALTH" if critical else ("HEALTH" if resource_kind == "hp" else "MANA")
	title_label.add_theme_color_override("font_color",Color("ffb0a6") if critical else GameTheme.MUTED)
	tooltip_text = ("Health" if resource_kind == "hp" else "Mana") + " : " + value_label.text

func _process(delta: float) -> void:
	displayed = move_toward(displayed,target,delta*1.5)
	liquid.material.set_shader_parameter("fill_level",displayed)
	liquid.material.set_shader_parameter("motion",0.0 if State.options.get("reduced_effects",false) else 1.0)
