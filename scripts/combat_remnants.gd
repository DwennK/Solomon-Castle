class_name CombatRemnants
extends Node2D
## Cosmetic floor marks; no collision, damage, navigation or save data.
const LIMIT: int = 64
var world: GameWorld
var marks: Array[Dictionary] = []
var serial: int = 0

func add_mark(p: Vector2, element: String, radius: float = 24.0) -> bool:
	if world.village or not world.dungeon.walkable(p) or not world.dungeon.explored_position(p): return false
	if element not in ["fire","ice","acid","dust","bone"]: return false
	var cap: int = 24 if State.options.reduced_effects else LIMIT
	for mark: Dictionary in marks:
		if mark.kind==element and mark.p.distance_squared_to(p)<400:
			# Refresh a nearby patch instead of accumulating one per damage tick.
			mark.life=mark.duration
			return false
	while marks.size()>=cap: marks.pop_front()
	serial += 1
	var duration: float = 7.0 if element!="dust" else 2.5
	marks.append({"p":p,"kind":element,"radius":clampf(radius,12,46),"life":duration,"duration":duration,"seed":serial})
	queue_redraw()
	return true

func spell_mark(p: Vector2, spell: String, radius: float = 24.0) -> void:
	if spell in ["fire","fire_missile","flame_lash","ring_fire"]: add_mark(p,"fire",radius)
	elif spell in ["ice","frost_missile","blizzard","freeze"]: add_mark(p,"ice",radius)
	elif spell=="acid": add_mark(p,"acid",radius)

func _process(delta: float) -> void:
	var cap: int = 24 if State.options.reduced_effects else LIMIT
	while marks.size()>cap: marks.pop_front()
	for i: int in range(marks.size()-1,-1,-1):
		marks[i].life -= delta
		if marks[i].life<=0: marks.remove_at(i)
	if not marks.is_empty(): queue_redraw()
	elif not get_meta("empty",true): queue_redraw()
	set_meta("empty",marks.is_empty())

func _draw() -> void:
	for mark: Dictionary in marks:
		if not world.dungeon.explored_position(mark.p): continue
		var age: float = mark.duration-mark.life
		var fade: float = minf(1.0,mark.life/2.0)*(0.65 if State.options.reduced_effects else 1.0)
		var count: int = 5 if State.options.reduced_effects else 11
		for i: int in range(count):
			var a: float = i*2.39996+mark.seed*1.7
			var d: Vector2 = Vector2.from_angle(a)
			var p: Vector2 = mark.p+d*sqrt(float(i+1)/count)*mark.radius
			# Small fragments stay on open floor, including beside pillars and gates.
			if not world.dungeon.walkable(p,6) or not world.dungeon.explored_position(p): continue
			match String(mark.kind):
				"fire":
					draw_colored_polygon(PackedVector2Array([p-d*5,p+d.orthogonal()*3,p+d*6,p-d.orthogonal()*2]),Color(0.075,0.045,0.03,fade*0.42))
					if age<1.5: draw_line(p,p+d*3,Color(0.95,0.32,0.07,fade*(1-age/1.5)),1.3,true)
				"ice":
					draw_line(p-d*4,p+d*4,Color(0.55,0.81,0.88,fade*0.40),1.4,true)
					draw_line(p,p+d.rotated(0.85)*4,Color(0.78,0.93,0.96,fade*0.50),1.0,true)
				"acid":
					# Faded matte droplets clearly differ from the luminous active hazard.
					draw_circle(p,3.0+i%3,Color(0.21,0.29,0.08,fade*0.55))
					draw_arc(p,2.5,0.3,2.4,6,Color(0.45,0.53,0.20,fade*0.45),1.0,true)
				"bone":
					draw_line(p-d*3,p+d*3,Color(0.65,0.62,0.49,fade*0.85),2.0,true)
					draw_circle(p+d*3,1.7,Color(0.7,0.67,0.53,fade*0.85))
				"dust":
					draw_circle(p,3+age*1.4,Color(0.43,0.39,0.31,fade*0.12))
