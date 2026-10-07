class_name MagicProjectile
extends Node2D

var world: Node2D
var direction: Vector2 = Vector2.RIGHT
var profile: Dictionary = {}
var speed: float = CombatSystem.PROJECTILE_SPEED
var lifetime: float = CombatSystem.PROJECTILE_LIFETIME
var hostile: bool = false
var damage: float = 10.0
var color: Color = Color.WHITE
var history: Array[Vector2] = []
var pulse: float = 0.0
var homing: bool = false
var target: TowerEnemy
var impact_done: bool = false
var age: float = 0.0

func _ready() -> void:
	if not hostile:
		damage = profile.damage
		color = profile.color
		homing = "missile" in profile.elements and not profile.get("ember",false)
		if homing: speed *= 1.0+CombatSystem.missile_speed_bonus(State.rank("potent",profile.snapshot))
		if profile.id == "ball_lightning":
			speed = CombatSystem.ORB_SPEED
			lifetime = CombatSystem.ORB_LIFETIME
	if homing: target = world.combat.nearest(position+direction*140,340)

func _physics_process(delta: float) -> void:
	age += delta
	lifetime -= delta
	if lifetime<=0:
		if not hostile and profile.get("ember",false) and int(profile.get("detonate",0))>0:
			world.combat.explosion(position,65.0,damage*(1.0+0.2*int(profile.detonate)),color)
		queue_free()
		return
	if homing:
		if not is_instance_valid(target) or target.dead:
			target = world.combat.nearest(position,340) if State.rank("potent",profile.snapshot)>0 else null
		if is_instance_valid(target) and not target.dead: direction = direction.lerp(position.direction_to(target.position),minf(1,delta*6)).normalized()
	var step: Vector2 = direction*speed*delta
	var previous: Vector2 = position
	if not world.dungeon.visible_line(position,position+step):
		impact(null)
		return
	position += step
	history.push_front(position)
	if history.size()>(8 if hostile or State.options.reduced_effects else 18): history.pop_back()
	if hostile:
		if Geometry2D.get_closest_point_to_segment(world.player.position,previous,position).distance_to(world.player.position)<22:
			world.player.take_damage(damage)
			queue_free()
	else:
		if profile.id == "ball_lightning":
			pulse -= delta
			if pulse<=0:
				pulse = CombatSystem.ORB_PULSE_INTERVAL
				world.combat.orb_pulse(position,profile)
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
		if id == "frost_missile" and not enemy.dead:
			enemy.freeze(0.8)
			enemy.chill(1.0,maxf(0.1,0.55-State.rank("chill",profile.snapshot)*0.045))
			enemy.knockback+=direction*State.rank("chill",profile.snapshot)*20
	if world.combat.splash_ratio(profile)>0:
		world.combat.explosion(position,world.combat.splash_radius(profile),damage*world.combat.splash_ratio(profile),color,0.5 if id=="frost_missile" else 0.0)
	else: world.effect(position,color,25)
	world.combat.emit_embers(position,profile,damage)
	Sound.impact(id,global_position)
	queue_free()

func _draw() -> void:
	draw_set_transform(Vector2(0,-32))
	var id: String = profile.get("id","hostile")
	var fire: bool = id in ["fire","fire_missile"]
	var frost: bool = id=="frost_missile"
	var orb: bool = id=="ball_lightning"
	var head: float = 15.0 if orb else (9.0 if fire else 6.0)
	var glow: float = 0.35 if State.options.reduced_effects else 0.75
	if history.size()>1:
		var points: PackedVector2Array = PackedVector2Array()
		var core: PackedColorArray = PackedColorArray()
		var bloom: PackedColorArray = PackedColorArray()
		for i: int in range(history.size()):
			var f: float = 1.0-float(i)/history.size()
			points.append(history[i]-position)
			core.append(Color(color,f*0.8))
			bloom.append(Color(color,f*0.13))
		# Two batched polylines instead of two draw calls per trail segment.
		draw_polyline_colors(points,bloom,head*1.4,true)
		draw_polyline_colors(points,core,2.5,true)
		if not hostile and not State.options.reduced_effects:
			for i: int in range(3,history.size(),4):
				var f: float = 1.0-float(i)/history.size()
				var particle: Vector2 = points[i]+direction.orthogonal()*sin(age*16+i*1.7)*9*(1-f)
				if frost: ArcaneArt.crystal(self,particle,direction,4*f,Color(color,f))
				else: draw_circle(particle,1.5,Color(color,f))
	ArcaneArt.glow(self,Vector2.ZERO,head*4,Color(color,glow))
	if orb:
		ArcaneArt.rune(self,Vector2.ZERO,head+3,Color(color,0.8),age*3,8)
		for i: int in range(3):
			var a: float = age*5+i*TAU/3
			var d: Vector2 = Vector2.from_angle(a)
			draw_polyline(PackedVector2Array([d*8,d.rotated(0.2)*22,d.rotated(-0.15)*31]),Color(color,0.8),1.5,true)
	elif frost:
		ArcaneArt.crystal(self,Vector2.ZERO,direction,14,Color("a9ecff"))
	elif fire:
		for i: int in range(7,0,-1):
			var p: Vector2 = -direction*i*3+direction.orthogonal()*sin(age*28-i)*i*0.6
			draw_circle(p,head*(1-float(i)/9),Color(color,0.7))
		draw_circle(Vector2.ZERO,head*0.7,Color("ffd9a0"))
	else:
		ArcaneArt.crystal(self,Vector2.ZERO,direction,head*1.6,color)
	draw_circle(direction*2,3.0 if orb else 2.2,Color("fff5dc"))
