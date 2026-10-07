extends Control
## Low stone rail joins the orb pedestals and meets the bottom of the viewport.
const RAIL: Texture2D = preload("res://assets/ui/gothic-hud/ability-rail.png")

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	draw_texture_rect_region(RAIL,Rect2(176,76,688,140),Rect2(0,20,2172,655),Color(0.72,0.76,0.79))
	# Metal seams and a warm accent distinguish the larger primary spell socket.
	draw_line(Vector2(408,124),Vector2(408,211),Color("414447"),1.0,true)
	draw_line(Vector2(734,130),Vector2(734,211),Color("414447"),1.0,true)
