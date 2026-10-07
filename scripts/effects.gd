class_name SpellEffects
extends Node2D

var world: Node2D
var effects: Array[Dictionary] = []
var clock: float = 0.0
var serial: int = 0

func add_burst(p: Vector2,color: Color,radius: float,style: String = "impact") -> void:
	if effects.size()>=160: return
	serial += 1
	var duration: float = 0.65 if radius<100 else 1.0
	effects.append({"type":"burst","p":p,"color":color,"radius":radius,"life":duration,"max":duration,"seed":serial,"style":style})

func add_beam(a: Vector2,b: Vector2,color: Color,width: float,life: float,cone: bool,style: String = "lightning") -> void:
	if effects.size()>=160: return
	serial += 1
	effects.append({"type":"beam","a":a,"b":b,"color":color,"width":width,"life":life,"max":life,"cone":cone,"seed":serial,"style":style})

func _process(delta: float) -> void:
	clock += delta
	for i: int in range(effects.size()-1,-1,-1):
		effects[i].life -= delta
		if effects[i].life<=0: effects.remove_at(i)
	queue_redraw()

func _draw() -> void:
	if is_instance_valid(world) and not world.village:
		for drop: Dictionary in world.loot:
			var pos: Vector2 = Dungeon.vec(drop.pos)
			var texture: Texture2D = Catalog.texture("staff" if drop.kind=="item" and drop.item.slot=="staff" else ("ring" if drop.kind=="item" else drop.kind))
			var color: Color = Color("ce9cfa") if drop.kind=="item" else Color("edbe69")
			ArcaneArt.glow(self,pos,35,Color(color,0.4))
			if drop.kind=="item":
				for i: int in range(4):
					var f: float = fposmod(clock*0.4+i*0.25,1)
					draw_line(pos+Vector2(0,-15),pos+Vector2(sin(i*7.0)*4,-65*f),Color(color,(1-f)*0.18),6,true)
				ArcaneArt.rune(self,pos,22,Color(color,0.4),clock*0.25,8)
			if texture: draw_texture_rect(texture,Rect2(pos-Vector2(20,35+sin(clock*2+pos.x)*2),Vector2(40,40)),false)
		for zone: Dictionary in world.zones: draw_zone(zone)
	for e: Dictionary in effects:
		if e.type=="burst": draw_burst(e)
		else: draw_beam(e)

func draw_zone(z: Dictionary) -> void:
	var color: Color = z.color
	var waiting: bool = z.delay>0
	var intensity: float = 0.24 if waiting else 0.40
	ArcaneArt.glow(self,z.pos,z.radius*1.2,Color(color,intensity))
	ArcaneArt.rune(self,z.pos,z.radius,Color(color,0.7),clock*0.13)
	if waiting:
		var progress: float = clampf(1-z.delay/1.3,0,1)
		draw_arc(z.pos,z.radius*progress,0,TAU,64,Color(color,0.7),2,true)
		for i: int in range(8):
			var d: Vector2 = Vector2.from_angle(i*TAU/8)
			draw_line(z.pos+d*(z.radius-9),z.pos+d*(z.radius+5),Color(color,0.9),2,true)
	else:
		var amount: int = 10 if State.options.reduced_effects else 24
		for i: int in range(amount):
			var a: float = i*2.39996+clock*0.2
			var r: float = sqrt(float(i+1)/amount)*z.radius*0.88
			var t: float = fposmod(clock*0.6+i*0.37,1)
			var p: Vector2 = z.pos+Vector2.from_angle(a)*r-Vector2(0,t*25)
			if z.kind=="acid": draw_arc(p,3+t*5,0,TAU,12,Color(color,(1-t)*0.65),1,true)
			else: ArcaneArt.crystal(self,p,Vector2.UP,3.0,Color(color,sin(t*PI)*0.8))

func draw_burst(e: Dictionary) -> void:
	var t: float = 1.0-e.life/e.max
	var fade: float = (1-t)*(1-t)
	var color: Color = e.color
	var radius: float = e.radius*(0.18+sqrt(t)*0.95)
	var strength: float = 0.35 if State.options.reduced_effects else 0.9
	ArcaneArt.glow(self,e.p,e.radius*(0.8+t),Color(color,fade*strength))
	draw_arc(e.p,radius,0,TAU,64,Color(color,fade*0.75),maxf(1,4*(1-t)),true)
	if e.radius>80:
		ArcaneArt.rune(self,e.p,radius*0.76,Color(color,fade*0.6),e.seed*0.3+t*0.15)
	var amount: int = 8 if State.options.reduced_effects else 22
	for i: int in range(amount):
		var angle: float = i*2.39996+e.seed*0.7
		var d: Vector2 = Vector2.from_angle(angle)
		var reach: float = radius*(0.4+fposmod(i*0.618,0.8))
		var p: Vector2 = e.p+d*reach+Vector2(0,35*t*t)
		if color.b>color.r and color.g>0.65:
			ArcaneArt.crystal(self,p,d,(3+i%5)*(1-t),Color(color,1-t))
		else:
			draw_line(p-d*(4+11*(1-t)),p,Color(color,1-t),1.5,true)
			draw_circle(p,1.5*(1-t),Color(1,0.92,0.75,1-t))

func draw_beam(e: Dictionary) -> void:
	var fade: float = e.life/e.max
	var color: Color = e.color
	var delta: Vector2 = e.b-e.a
	if delta.length()<1: return
	draw_set_transform(Vector2(0,-32))
	var d: Vector2 = delta.normalized()
	var side: Vector2 = d.orthogonal()
	var style: String = e.style
	var count: int = 10 if State.options.reduced_effects else 24
	ArcaneArt.glow(self,e.a,28,Color(color,fade*0.5))
	if e.cone or style in ["blizzard","steam","ice"]:
		var spread: float = 65 if e.cone else 35
		draw_colored_polygon(PackedVector2Array([e.a,e.b+side*spread,e.b-side*spread]),Color(color,0.08*fade))
		for i: int in range(count):
			var t: float = fposmod(clock*2.3+i*0.618,1.0)
			var width: float = sin(i*12.3+e.seed*0.04)*spread*t
			var p: Vector2 = e.a+delta*t+side*width
			if style=="steam":
				ArcaneArt.glow(self,p,12+t*30,Color(color,fade*0.5*sin(t*PI)))
				draw_arc(p,8+t*14,clock+i,clock+i+PI*0.8,12,Color(0.92,0.98,1,fade*0.20*sin(t*PI)),1.2,true)
			else:
				ArcaneArt.crystal(self,p,d.rotated(sin(i*7.0)*0.6),4+t*8,Color(color,fade*sin(t*PI)*0.9))
				draw_line(p-d*12,p,Color(color,fade*0.3),1,true)
		if style=="blizzard":
			var spine: PackedVector2Array = PackedVector2Array()
			for j: int in range(25):
				var t: float = float(j)/24
				spine.append(e.a+delta*t+side*sin(t*28-clock*13)*12*sin(t*PI))
			draw_polyline(spine,Color(color,fade*0.16),14,true)
			draw_polyline(spine,Color(0.85,0.98,1,fade*0.65),1.3,true)
	elif style=="flame_lash":
		var path: PackedVector2Array = PackedVector2Array()
		for i: int in range(25):
			var t: float = float(i)/24
			path.append(e.a+delta*t+side*sin(t*18-clock*17)*sin(t*PI)*19)
		draw_polyline(path,Color(color,fade*0.12),22,true)
		draw_polyline(path,Color("f47935",fade*0.7),9,true)
		draw_polyline(path,Color("ffe1a0",fade),2.5,true)
		for i: int in range(8):
			var t: float = fposmod(clock*1.6+i*0.13,1)
			ArcaneArt.glow(self,e.a+delta*t+side*sin(i*8.0+clock)*22,14,Color(color,fade*0.5))
	else:
		var points: PackedVector2Array = PackedVector2Array()
		var segments: int = maxi(3,int(delta.length()/22))
		for i: int in range(segments+1):
			var t: float = float(i)/segments
			points.append(e.a+delta*t+side*sin(i*17.4+e.seed*9.1)*13*sin(t*PI))
		draw_polyline(points,Color(color,fade*0.10),e.width*5,true)
		draw_polyline(points,Color(color,fade*0.65),e.width*1.6,true)
		draw_polyline(points,Color(1,0.98,0.87,fade),1.5,true)
		if not State.options.reduced_effects:
			for i: int in range(2,points.size()-1,4):
				var end: Vector2 = points[i]+d*23+side*sin(i*31.0)*35
				draw_polyline(PackedVector2Array([points[i],points[i].lerp(end,0.5)-d*8,end]),Color(color,fade*0.6),1,true)
	ArcaneArt.glow(self,e.b,30,Color(color,fade*0.4))
	draw_set_transform(Vector2.ZERO)
