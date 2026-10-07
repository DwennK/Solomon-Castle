extends Control
## A single, cut-brass silhouette behind the combat controls.

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	var outline: PackedVector2Array = PackedVector2Array([
		Vector2(0,42),Vector2(24,18),Vector2(220,18),Vector2(240,8),
		Vector2(840,8),Vector2(860,18),Vector2(1056,18),Vector2(1080,42),
		Vector2(1080,142),Vector2(1056,166),Vector2(860,166),Vector2(840,184),
		Vector2(240,184),Vector2(220,166),Vector2(24,166),Vector2(0,142)])
	var shadow: PackedVector2Array = PackedVector2Array()
	for point: Vector2 in outline: shadow.append(point+Vector2(0,5))
	draw_colored_polygon(shadow,Color(0,0,0,0.45))
	draw_colored_polygon(outline,Color("101317"))
	outline.append(outline[0])
	draw_polyline(outline,Color("716044"),1.0,true)
	draw_line(Vector2(242,10),Vector2(838,10),Color("c4a573"),1.0,true)
	for x: float in [232.0,848.0]:
		draw_line(Vector2(x,38),Vector2(x,128),Color("39352e"),1.0)
	# Soft resource light stays beneath all text and controls.
	ArcaneArt.glow(self,Vector2(76,83),110,Color("a52f40"),0.12)
	ArcaneArt.glow(self,Vector2(1004,83),110,Color("367fc2"),0.14)
	for x: float in [18.0,1062.0]:
		for y: float in [48.0,136.0]:
			draw_circle(Vector2(x,y),2,Color("9a8158"),true,-1,true)
	draw_line(Vector2(250,147),Vector2(830,147),Color("34312b"),1.0)
