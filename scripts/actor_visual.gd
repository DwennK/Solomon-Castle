class_name ActorVisual
extends Node2D

class HitOverlay extends Node2D:
	var visual: ActorVisual
	func _draw() -> void:
		visual.draw_hit(self)

var hit_overlay: HitOverlay
const CLOTH: Shader = preload("res://assets/shaders/character.gdshader")
var texture: Texture2D
var target_height: float = 90.0
var moving: bool = false
var facing: Vector2 = Vector2.DOWN
var phase: float = 0.0
var attack: float = 0.0
var hit_flash: float = 0.0
var tint: Color = Color.WHITE
var kind: String = "mage"
var dying: float = 0.0
var frozen: bool = false
var burning: bool = false
var sprite: Sprite2D
var cloth: ShaderMaterial
var gait: float = 0.0
var elapsed: float = 0.0
var environment: DungeonInterior
var environment_clock: float = 0.0
var environment_target: Color = Color.WHITE
var environment_color: Color = Color.WHITE
var light_direction: Vector2 = Vector2(-0.6,-0.8)
var light_strength: float = 0.0
var hit_time: float = 0.0
var hit_direction: Vector2 = Vector2.ZERO
var hit_weight: float = 1.0
var hit_ice: bool = false
var hit_metal: bool = false

func react_hit(direction: Vector2, weight: float, ice: bool, metal: bool) -> bool:
	# Presentation only: never move the collider or interrupt an enemy action.
	if hit_time>0.08: return false
	hit_time = 0.22
	hit_direction = direction.normalized()
	hit_weight = clampf(weight,0.25,1.0)
	hit_ice = ice
	hit_metal = metal
	hit_flash = 0.45
	return true

func _ready() -> void:
	phase = float(get_instance_id()%29)*0.21
	sprite = Sprite2D.new()
	sprite.texture = texture
	cloth = ShaderMaterial.new()
	cloth.shader = CLOTH
	sprite.material = cloth
	add_child(sprite)
	hit_overlay = HitOverlay.new()
	hit_overlay.visual = self
	add_child(hit_overlay)

func _process(delta: float) -> void:
	elapsed += delta
	if environment:
		environment_clock -= delta
		if environment_clock<=0:
			environment_clock = 0.12
			var sample: Dictionary = environment.sample_light(global_position)
			environment_target = sample.color
			light_direction = sample.direction
			light_strength = sample.strength
		environment_color = environment_color.lerp(environment_target,minf(1.0,delta*6.0))
	gait = move_toward(gait,1.0 if moving and not frozen else 0.0,delta*7.0)
	phase += delta*lerpf(2.0,10.0,gait)*(0.0 if frozen else 1.0)
	attack = maxf(0.0,attack-delta*4.0)
	hit_flash = maxf(0.0,hit_flash-delta*5.0)
	hit_time = maxf(0.0,hit_time-delta)
	if sprite and texture:
		var spirit: bool = kind in ["ghost","lich","sorcerer"]
		var breath: float = sin(phase)*0.012
		var hop: float = absf(sin(phase))*3.0*gait + (sin(elapsed*2.6)*4.0+5.0 if spirit else 0.0)
		var ratio: float = target_height/texture.get_height()
		var flip: float = -1.0 if facing.x < -0.15 else 1.0
		sprite.scale = Vector2(flip*(1.0-breath+attack*0.035),1.0+breath-attack*0.035)*ratio
		sprite.position = Vector2(facing.x*attack*9.0,-target_height/2.0+8-hop-dying*22)
		sprite.rotation = sin(phase)*gait*0.035+facing.x*attack*0.10
		var recoil: float = sin((1.0-hit_time/0.22)*PI)*hit_weight*(0.35 if State.options.reduced_effects else 1.0) if hit_time>0 else 0.0
		sprite.position += hit_direction*recoil*(3.0 if hit_metal else 8.0)
		sprite.rotation += hit_direction.x*recoil*(0.035 if hit_metal else 0.09)
		sprite.modulate = tint
		if kind in ["skeleton","archer"] and dying>0: sprite.modulate.a *= maxf(0.0,1.0-dying*5.0)
		cloth.set_shader_parameter("motion",0.0 if State.options.reduced_effects or frozen else 0.5+gait)
		cloth.set_shader_parameter("clock",phase)
		cloth.set_shader_parameter("flash",hit_flash*(0.2 if State.options.reduced_effects else 1.0))
		cloth.set_shader_parameter("dissolve",dying)
		cloth.set_shader_parameter("rim_color",aura())
		cloth.set_shader_parameter("environment_color",environment_color)
		cloth.set_shader_parameter("light_direction",light_direction)
		cloth.set_shader_parameter("light_strength",light_strength)
	queue_redraw()
	hit_overlay.queue_redraw()

func aura() -> Color:
	if kind=="mage": return CombatSystem.COLORS.get(State.run.get("active","missile"),Color("72d9e3"))
	return {"ghost":Color("73cfe5"),"lich":Color("c096ff"),"sorcerer":Color("b48be2"),"demon":Color("ff753e"),"imp":Color("ff823d"),"plague":Color("a4bc54")}.get(kind,Color("6f9b9e"))

func _draw() -> void:
	var color: Color = aura()
	if environment:
		var grounded: float = (1.0-dying)*(0.65 if kind=="ghost" else 1.0)
		# Tight foot contact plus a softer shadow opposite the nearest source.
		draw_set_transform(Vector2(-light_direction.x*light_strength*12,5),0,Vector2(1,0.24))
		ArcaneArt.glow(self,Vector2.ZERO,target_height*0.32,Color(0,0,0,0.8*grounded))
		draw_set_transform(Vector2(0,5),0,Vector2(1,0.25))
		ArcaneArt.glow(self,Vector2.ZERO,target_height*0.16,Color(0,0,0,0.95*grounded))
	draw_set_transform(Vector2.ZERO,0,Vector2(1,0.35))
	ArcaneArt.glow(self,Vector2.ZERO,target_height*0.44,Color(0.0,0.0,0.0,0.85*(1.0-dying)))
	if kind in ["mage","ghost","lich","demon"]:
		ArcaneArt.glow(self,Vector2.ZERO,target_height*0.56,Color(color,0.22*(1.0-dying)))
	draw_set_transform(Vector2.ZERO)
	if kind in ["skeleton","archer"] and dying>0 and texture:
		# Separate pieces of the actual creature art, rather than a generic burst.
		var part: Vector2 = texture.get_size()/Vector2(3,4)
		var ratio: float = target_height/texture.get_height()
		var spread: float = dying*(0.35 if State.options.reduced_effects else 1.0)
		var flip: float = -1.0 if facing.x < -0.15 else 1.0
		for row: int in range(4):
			for col: int in range(3):
				var center: Vector2 = (Vector2(col+0.5,row+0.5)*part-texture.get_size()*0.5)*ratio+Vector2(0,-target_height*0.5+8)
				center += Vector2((col-1)*35,dying*65-25)*spread
				center.x *= flip
				draw_set_transform(center,(col-1)*spread*0.9,Vector2(flip,1))
				draw_texture_rect_region(texture,Rect2(-part*ratio*0.5,part*ratio),Rect2(Vector2(col,row)*part,part),Color(tint*environment_color,1.0-dying))
		draw_set_transform(Vector2.ZERO)
	if attack>0.05:
		var hand: Vector2 = Vector2(facing.x*target_height*0.25,-target_height*0.53)
		ArcaneArt.glow(self,hand,32+attack*15,Color(color,attack*0.8))
		for i: int in range(5):
			var p: Vector2 = hand+Vector2.from_angle(i*TAU/5+elapsed*4)*(1-attack)*27
			draw_circle(p,1.7,Color(color,attack))
	if frozen:
		for i: int in range(5):
			ArcaneArt.crystal(self,Vector2((i-2)*11,5),Vector2(0.15*(i-2),-1).normalized(),15+5*(i%2),Color(0.5,0.87,1,0.7))
	if burning:
		for i: int in range(7):
			var t: float = fposmod(elapsed*1.6+i*0.17,1.0)
			var p: Vector2 = Vector2(sin(i*6.3+t*3)*19,-t*target_height)
			ArcaneArt.glow(self,p,12*(1.0-t)+3,Color(1,0.32,0.06,0.7*(1-t)))

func draw_hit(canvas: Node2D) -> void:
	if hit_time>0 and (hit_ice or hit_metal):
		var fade: float = hit_time/0.22
		var origin: Vector2 = Vector2(0,-target_height*0.52)
		var count: int = 3 if State.options.reduced_effects else 7
		for i: int in range(count):
			var d: Vector2 = Vector2.from_angle(i*2.39996)
			if hit_ice:
				var mid: Vector2 = origin+d*target_height*0.16
				canvas.draw_polyline(PackedVector2Array([origin,mid+d.orthogonal()*4,origin+d*target_height*0.30]),Color(0.78,0.95,1,fade),1.5,true)
			else:
				var p: Vector2 = origin+d*(6+(1-fade)*25)
				canvas.draw_line(p,p-d*7,Color(1,0.78,0.36,fade),1.5,true)
