class_name SpellEffects
extends Node2D

var world: Node2D
var effects: Array[Dictionary] = []

func add_burst(p: Vector2,color: Color,radius: float) -> void:
	if effects.size()>160: return
	effects.append({"type":"burst","p":p,"color":color,"radius":radius,"life":0.45,"max":0.45})

func add_beam(a: Vector2,b: Vector2,color: Color,width: float,life: float,cone: bool) -> void:
	if effects.size()>160: return
	effects.append({"type":"beam","a":a,"b":b,"color":color,"width":width,"life":life,"max":life,"cone":cone})

func _process(delta: float) -> void:
	for i: int in range(effects.size()-1,-1,-1):
		effects[i].life -= delta
		if effects[i].life<=0: effects.remove_at(i)
	queue_redraw()

func _draw() -> void:
	if is_instance_valid(world) and not world.village:

		for drop: Dictionary in world.loot:
			var pos: Vector2 = Dungeon.vec(drop.pos)
			var texture: Texture2D = Catalog.texture("staff" if drop.kind=="item" and drop.item.slot=="staff" else ("ring" if drop.kind=="item" else drop.kind))
			draw_circle(pos,24,Color(0.8,0.67,0.35,0.13))
			if texture: draw_texture_rect(texture,Rect2(pos-Vector2(20,35),Vector2(40,40)),false)
		for zone: Dictionary in world.zones:
			var color: Color = zone.color
			draw_circle(zone.pos,zone.radius,Color(color,0.06 if zone.delay>0 else 0.15))
			draw_arc(zone.pos,zone.radius,0,TAU,48,Color(color,0.6),2,true)
			if zone.delay>0: draw_arc(zone.pos,zone.radius*(1-zone.delay/1.3),0,TAU,48,Color(color,0.4),2,true)

	for e: Dictionary in effects:
		var color: Color = e.color
		color.a = e.life/e.max*0.65
		if e.type == "burst":
			var radius: float = e.radius*(1.0-e.life/e.max)+5
			draw_arc(e.p,radius,0,TAU,40,color,2,true)
			for i: int in range(8):
				var d: Vector2 = Vector2.RIGHT.rotated(i*TAU/8.0)
				draw_line(e.p+d*radius*0.7,e.p+d*radius,color,2,true)
		else:
			if e.cone:
				var orthogonal: Vector2 = (e.b-e.a).normalized().orthogonal()*60
				draw_colored_polygon(PackedVector2Array([e.a,e.b+orthogonal,e.b-orthogonal]),Color(color,0.05))
				for i: int in range(5):
					var offset: Vector2 = orthogonal*(i-2)*0.3
					draw_line(e.a,e.b+offset,Color(color,0.12),3,true)
			else:
				var mid: Vector2 = (e.a+e.b)/2+(e.b-e.a).normalized().orthogonal()*sin(Time.get_ticks_msec()*0.027)*11
				draw_polyline(PackedVector2Array([e.a,mid,e.b]),Color(color,0.18),e.width*4,true)
				draw_polyline(PackedVector2Array([e.a,mid,e.b]),color,e.width,true)
