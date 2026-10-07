class_name UIOrnament
extends Control

func _init() -> void:
	custom_minimum_size.y = 18
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	var c: Vector2 = size * 0.5
	draw_line(Vector2(0,c.y), Vector2(c.x-18,c.y), Color("5f4b30"), 1)
	draw_line(Vector2(c.x+18,c.y), Vector2(size.x,c.y), Color("5f4b30"), 1)
	draw_colored_polygon(PackedVector2Array([c+Vector2(0,-5),c+Vector2(5,0),c+Vector2(0,5),c+Vector2(-5,0)]), GameTheme.GOLD)
	for x: float in [c.x-11, c.x+11]: draw_circle(Vector2(x,c.y), 1.5, GameTheme.GOLD)
