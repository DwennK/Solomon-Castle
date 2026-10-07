class_name ArcaneArt
extends RefCounted
## Shared, cached soft light and deterministic vector motifs. No per-frame textures.
static var halo: Texture2D

static func glow(canvas: CanvasItem, pos: Vector2, radius: float, color: Color, strength: float = 1.0) -> void:
	if halo == null:
		var gradient: Gradient = Gradient.new()
		gradient.offsets = PackedFloat32Array([0.0,0.18,0.48,1.0])
		gradient.colors = PackedColorArray([Color(1,1,1,0.8),Color(1,1,1,0.45),Color(1,1,1,0.12),Color(1,1,1,0)])
		var tex: GradientTexture2D = GradientTexture2D.new()
		tex.gradient = gradient
		tex.width = 128; tex.height = 128
		tex.fill = GradientTexture2D.FILL_RADIAL
		tex.fill_from = Vector2(0.5,0.5); tex.fill_to = Vector2(1.0,0.5)
		halo = tex
	canvas.draw_texture_rect(halo,Rect2(pos-Vector2.ONE*radius,Vector2.ONE*radius*2),false,Color(color,strength*color.a))

static func rune(canvas: CanvasItem, pos: Vector2, radius: float, color: Color, angle: float = 0.0, count: int = 12) -> void:
	canvas.draw_arc(pos,radius,0,TAU,64,Color(color,color.a*0.7),1.2,true)
	canvas.draw_arc(pos,radius*0.87,0,TAU,64,Color(color,color.a*0.35),1,true)
	for i: int in range(count):
		var a: float = angle + i*TAU/count
		var d: Vector2 = Vector2.from_angle(a)
		var p: Vector2 = pos + d*radius*0.94
		var t: Vector2 = d.orthogonal()
		canvas.draw_line(p-d*3,p+d*3,color,1.3,true)
		canvas.draw_line(p-d*2,p+t*3,color,1,true)
		if i%2==0: canvas.draw_line(p+t*3,p+d*2,color,1,true)

static func crystal(canvas: CanvasItem, pos: Vector2, direction: Vector2, size: float, color: Color) -> void:
	if size<0.5 or color.a<0.01: return
	var d: Vector2 = direction*size
	var side: Vector2 = direction.orthogonal()*size*0.28
	canvas.draw_primitive(PackedVector2Array([pos+d,pos+side,pos-d*0.6,pos-side]),PackedColorArray([color]),PackedVector2Array())
	canvas.draw_line(pos-d*0.4,pos+d,Color(1,1,1,color.a*0.8),1,true)
