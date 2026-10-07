class_name WorldProp
extends Node2D

var record: Dictionary
var texture: Texture2D
var time: float = 0.0
var label: String = ""
var font: Font = ThemeDB.fallback_font

func _ready() -> void:
	texture = Catalog.texture("chest_open" if record.get("opened",false) and record.kind=="chest" else record.kind)
	position = Dungeon.vec(record.pos)

func _process(delta: float) -> void:
	time += delta
	if record.kind in ["torch","portal"]: queue_redraw()

func _draw() -> void:
	var kind: String = record.kind
	if kind=="urn" and record.get("opened",false): return
	var height: float = {"torch":100,"chest":65,"chest_open":65,"portal":125,"stairs":150,"merchant":115,"teacher":120,"healer":112,"urn":58}.get(kind,65)
	if kind in ["torch","portal"]:
		var color: Color = Color("e3a051") if kind=="torch" else Color("69ccd9")
		for i: int in range(10,0,-1):
			draw_circle(Vector2(0,-35),i*14.0,Color(color,0.010+sin(time*4)*0.002))
	if texture:
		var size: Vector2 = texture.get_size()*height/texture.get_height()
		draw_texture_rect(texture,Rect2(Vector2(-size.x/2,-size.y+12),size),false)
	if not label.is_empty():
		draw_string(font,Vector2(-font.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,18).x/2,36),label,HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color("e4d3ac"))
