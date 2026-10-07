class_name DungeonLighting
extends Node2D
## Low-cost additive light painted below characters, projectiles and attack warnings.
var dungeon: Dungeon
var clock: float = 0.0
var light_sources: Array[Dictionary] = []

func _ready() -> void:
	var blend: CanvasItemMaterial = CanvasItemMaterial.new()
	blend.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = blend
	light_sources = dungeon.interior.lights.duplicate(true)

func _process(delta: float) -> void:
	clock += delta
	queue_redraw()

func _draw() -> void:
	var viewport: Rect2 = get_viewport_rect().grow(360)
	var transform: Transform2D = get_global_transform_with_canvas()
	for source: Dictionary in light_sources:
		var p: Vector2 = source.pos
		if not viewport.has_point(transform*p): continue
		var color: Color = source.color
		var flicker: float = 1.0 if State.options.reduced_effects else 0.96+sin(clock*2.7+p.x)*0.03+sin(clock*4.1+p.y)*0.01
		if source.window:
			# Directional, tapered light from each recessed stained-glass opening.
			var start: Vector2 = source.get("beam_origin",p-Vector2(0,61))
			for band: int in range(5):
				var spread: float = band*6.0
				var points: PackedVector2Array = PackedVector2Array([start+Vector2(-16,0),start+Vector2(16,0),start+Vector2(100+spread,214),start+Vector2(-30-spread,214)])
				draw_polygon(points,PackedColorArray([Color(color,0.038),Color(color,0.038),Color(color,0),Color(color,0)]))
			ArcaneArt.glow(self,p+Vector2(20,40),source.get("radius",220.0),Color(color,0.29))
			ArcaneArt.glow(self,start-Vector2(0,45),85,Color(color,0.29))
		else:
			var torch: bool = source.get("torch",false)
			ArcaneArt.glow(self,p,source.get("radius",265.0 if torch else 135.0),Color(color,(0.48 if torch else 0.34)*flicker))
			ArcaneArt.glow(self,p-Vector2(0,40 if torch else 8),70 if torch else 36,Color(color,0.19*flicker))
