class_name WorldAtmosphere
extends Node2D
## World-space ambient motes, room light pools and local hero illumination.
var world: GameWorld
var time: float = 0.0

func _process(delta: float) -> void:
	time += delta
	queue_redraw()

func _draw() -> void:
	if not is_instance_valid(world.player): return
	var center: Vector2 = world.player.position
	if world.village: center = Vector2(768,510)
	if not world.village:
		# Hero-local fill preserves orientation; architectural pools now provide the room light.
		ArcaneArt.glow(self,world.player.position-Vector2(0,35),155,Color("9ce5e4",0.035))
	var count: int = 18 if State.options.reduced_effects else 48
	for i: int in range(count):
		var p: Vector2 = Vector2(fposmod(i*379.7+sin(time*0.13+i)*35,1600)-800,fposmod(i*231.3-time*(4+i%4),1000)-500)
		# Anchor to coarse world cells so particles do not stick to the camera.
		p += (center/Vector2(1600,1000)).floor()*Vector2(1600,1000)
		if not world.village and not world.dungeon.walkable(p): continue
		var alpha: float = (0.16+sin(time*0.7+i)*0.1)*(0.5 if State.options.reduced_effects else 1.0)
		draw_circle(p,1.0+i%2*0.5,Color("d5d5b1",alpha))
		if i%7==0: ArcaneArt.glow(self,p,10,Color("b4e2d9",alpha))
