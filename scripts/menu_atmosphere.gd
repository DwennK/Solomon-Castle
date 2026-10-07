class_name MenuAtmosphere
extends Control

var clock: float = 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _process(delta: float) -> void:
	if not is_visible_in_tree(): return
	clock += delta
	queue_redraw()

func _draw() -> void:
	var amount: int = 8 if State.options.reduced_effects else 38
	for i: int in range(amount):
		var t: float = fposmod(clock*(0.035+i%4*0.006)+i*0.618,1)
		var p: Vector2 = Vector2(size.x*(0.45+fposmod(i*0.37,0.53))+sin(t*7+i)*22,size.y*(1.08-t*0.95))
		var opacity: float = sin(t*PI)*0.6
		ArcaneArt.glow(self,p,9,Color(1,0.52,0.18,opacity*0.5))
		draw_circle(p,1.0+i%2*0.5,Color(1,0.72,0.35,opacity))
