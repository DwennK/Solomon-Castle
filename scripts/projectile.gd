class_name MagicProjectile
extends Node2D

var world: Node2D
var direction: Vector2 = Vector2.RIGHT
var profile: Dictionary = {}
var speed: float = 510.0
var lifetime: float = 2.1
var hostile: bool = false
var damage: float = 10.0
var color: Color = Color.WHITE
var history: Array[Vector2] = []
var pulse: float = 0.0
var homing: bool = false
var target: TowerEnemy
var impact_done: bool = false

func _ready() -> void:
	if not hostile:
		damage = profile.damage
		color = profile.color
		homing = "missile" in profile.elements
		speed *= 1.0+State.rank("potent",profile.snapshot)*0.2
		if profile.id == "ball_lightning":
			speed = 170.0
			lifetime = 3.0
	if homing: target = world.combat.nearest(position+direction*140,340)

func _physics_process(delta: float) -> void:
	lifetime -= delta
	if lifetime<=0:
		queue_free()
		return
	if homing:
		if not is_instance_valid(target) or target.dead: target = world.combat.nearest(position,340)
		if is_instance_valid(target): direction = direction.lerp(position.direction_to(target.position),minf(1,delta*6)).normalized()
	var step: Vector2 = direction*speed*delta
	var previous: Vector2 = position
	if not world.dungeon.visible_line(position,position+step):
		impact(null)
		return
	position += step
	history.push_front(position)
	if history.size()>7: history.pop_back()
	if hostile:
		if Geometry2D.get_closest_point_to_segment(world.player.position,previous,position).distance_to(world.player.position)<22:
			world.player.take_damage(damage)
			queue_free()
	else:
		if profile.id == "ball_lightning":
			pulse -= delta
			if pulse<=0:
				pulse = 0.25
				var victim: TowerEnemy = world.combat.nearest(position,125)
				if victim:
					world.beam(position,victim.position+Vector2(0,-15),color,3)
					victim.take_damage(damage*0.35)
		for enemy: TowerEnemy in world.enemies:
			if enemy.dead: continue
			if Geometry2D.get_closest_point_to_segment(enemy.position,previous,position).distance_to(enemy.position)<(36 if enemy.boss else 24):
				impact(enemy)
				return
	queue_redraw()

func impact(enemy: TowerEnemy) -> void:
	if impact_done: return
	impact_done = true
	if hostile:
		world.effect(position,color,20)
		queue_free()
		return
	var id: String = profile.id
	if enemy:
		enemy.take_damage(damage,direction*60)
		if id == "frost_missile" and not enemy.dead: enemy.freeze(0.8)
	var explosion_rank: int = State.rank("explode",profile.snapshot)
	if id == "fire_missile" or (id == "fire" and explosion_rank>0):
		world.combat.explosion(position,60+explosion_rank*18,damage*0.55,color)
	elif id == "frost_missile": world.combat.explosion(position,75,damage*0.3,color,0.5)
	else: world.effect(position,color,25)
	var ember_rank: int = State.rank("embers",profile.snapshot)
	if "fire" in profile.elements and ember_rank>0 and not profile.get("ember",false):
		for i: int in range(ember_rank*3):
			var child: Dictionary = profile.duplicate(true)
			child.damage = damage*0.25
			child.ember = true
			child.snapshot = {"embers":0}
			world.spawn_projectile(position,Vector2.RIGHT.rotated(i*TAU/(ember_rank*3)),child,0.3)
	Sound.play("impact")
	queue_free()

func _draw() -> void:
	for i: int in range(1,history.size()):
		draw_line(history[i]-position,history[i-1]-position,Color(color,0.45*(1.0-float(i)/history.size())),maxf(1,7-i),true)
	draw_circle(Vector2.ZERO,13 if profile.get("id","")=="ball_lightning" else 7,Color(color,0.2))
	draw_circle(Vector2.ZERO,7 if profile.get("id","")=="ball_lightning" else 4,color)
	draw_circle(Vector2(-1,-1),2,Color.WHITE)
