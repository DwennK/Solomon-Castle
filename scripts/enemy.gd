class_name TowerEnemy
extends CharacterBody2D

var world: Node2D
var record: Dictionary
var definition: ContentDefinition
var visual: ActorVisual
var hp: float = 1.0
var max_hp: float = 1.0
var damage: float = 1.0
var speed: float = 1.0
var boss: bool = false
var dead: bool = false
var cooldown: float = 0.5
var path_timer: float = 0.0
var path_points: PackedVector2Array = PackedVector2Array()
var path_index: int = 1
var slow_time: float = 0.0
var slow_factor: float = 1.0
var frozen: float = 0.0
var fear: float = 0.0
var burn: float = 0.0
var knockback: Vector2 = Vector2.ZERO
var telegraph: float = 0.0
var attack_target: Vector2 = Vector2.ZERO
var phase: int = 0
var active: bool = false

func setup(owner_world: Node2D, value: Dictionary) -> void:
	world = owner_world
	record = value
	definition = Catalog.definition(record.kind)
	boss = definition.values.behavior.begins_with("boss")
	var floor_number: int = int(State.run.floor)
	var scaling: float = (1.0+float(floor_number-1)*0.16)*pow(1.65,int(State.run.difficulty))
	max_hp = float(definition.values.hp) * (pow(1.8,int(State.run.difficulty)) if boss else scaling)
	hp = max_hp if record.hp<0 else float(record.hp)
	damage = float(definition.values.damage)*(1.0+float(floor_number-1)*0.07)*pow(1.35,int(State.run.difficulty))
	speed = float(definition.values.speed)
	position = Dungeon.vec(record.pos)
	path_timer = float(get_instance_id()%100)/100.0

func _ready() -> void:
	visual = ActorVisual.new()
	visual.texture = Catalog.texture(record.kind)
	visual.target_height = 145 if boss else (96 if record.kind == "zombie" or record.kind == "knight" else 83)
	add_child(visual)
	if boss:
		var shape: CircleShape2D = CircleShape2D.new()
		shape.radius = 29
		$CollisionShape2D.shape = shape

func _physics_process(delta: float) -> void:
	if dead or not is_instance_valid(world.player): return
	if record.id == "boss" and not world.floor_data.get("gate_open",true): return
	var player: MagePlayer = world.player
	var distance: float = position.distance_to(player.position)
	if distance>1200:
		visual.moving = false
		return
	if distance<670: active = true
	if not active: return
	slow_time = maxf(0,slow_time-delta)
	frozen = maxf(0,frozen-delta)
	fear = maxf(0,fear-delta)
	if burn>0:
		burn -= delta
		take_damage(8.0*delta,Vector2.ZERO, true)
		if dead: return
	visual.tint = Color("8ac9ed") if frozen>0 or slow_time>0 else Color.WHITE
	if frozen>0:
		visual.moving = false
		return
	var local_delta: float = delta * (slow_factor if slow_time>0 else 1.0)
	cooldown -= local_delta
	var dir: Vector2 = (player.position-position).normalized()
	visual.facing = dir
	if telegraph>0:
		telegraph -= local_delta
		velocity = Vector2.ZERO
		if telegraph<=0: release_attack()
		queue_redraw()
		return
	var behavior: String = definition.values.behavior
	var line: bool = world.dungeon.visible_line(position,player.position)
	var preferred: float = 270 if behavior in ["ranged","caster","imp"] else (175 if behavior == "ghost" else 35)
	if boss: preferred = 240
	if cooldown<=0 and distance<(600 if boss else (500 if preferred>100 else 62)) and line:
		attack_target = player.position
		telegraph = 0.85 if boss else (0.45 if preferred>100 else 0.30)
		visual.attack = 1.0
		queue_redraw()
		return
	var motion: Vector2 = Vector2.ZERO
	if distance>preferred or not line:
		path_timer -= delta
		if line:
			motion = dir
		elif path_timer<=0:
			path_points = world.dungeon.path(position,player.position)
			path_index = 1
			path_timer = 0.55 + float(get_instance_id()%7)*0.06
		if not line and path_index<path_points.size():
			if position.distance_to(path_points[path_index])<18: path_index += 1
			if path_index<path_points.size(): motion = position.direction_to(path_points[path_index])
	elif preferred>100 and distance<preferred-65:
		motion = -dir
	if behavior == "dash" and int(Time.get_ticks_msec()/1000.0)%3 == 0: motion *= 1.65
	if behavior == "imp": motion = motion.rotated(sin(Time.get_ticks_msec()*0.003+get_instance_id())*0.6)
	if behavior == "ghost": motion = motion.rotated(sin(Time.get_ticks_msec()*0.002)*0.3)
	if fear>0: motion = -dir
	velocity = motion*speed*(slow_factor if slow_time>0 else 1.0)+knockback
	knockback = knockback.move_toward(Vector2.ZERO,delta*600)
	move_and_slide()
	visual.moving = velocity.length()>4
	queue_redraw()

func release_attack() -> void:
	var direction: Vector2 = position.direction_to(attack_target)
	var behavior: String = definition.values.behavior
	cooldown = 2.8 if boss else (1.65 if behavior in ["ranged","caster","imp"] else 1.0)
	if boss:
		phase += 1
		match behavior:
			"boss_king":
				if phase%2 == 0:
					world.hazard(attack_target,110,damage,0.9,Color("eec98a"))
				else:
					for i: int in range(9): world.enemy_bolt(position,Vector2.RIGHT.rotated(i*TAU/9.0),damage,210,Color("d8b080"))
			"boss_plague":
				for i: int in range(3): world.hazard(attack_target+Vector2(i*90-90,0),85,damage,1.1,Color("9caf49"),5.0)
			"boss_demon":
				for i: int in range(5): world.enemy_bolt(position,direction.rotated((i-2)*0.22),damage,260,Color("ff9757"))
				if phase%2 == 0: world.hazard(attack_target,150,damage,1.2,Color("ed8a48"))
			"boss_lich":
				if phase%3 == 0:
					for i: int in range(14): world.enemy_bolt(position,Vector2.RIGHT.rotated(i*TAU/14.0+phase),damage,220,Color("b48fe8"))
				elif phase%3 == 1:
					world.hazard(attack_target,165,damage*1.3,1.1,Color("b8a0ff"))
				else:
					for i: int in range(3): world.enemy_bolt(position,direction.rotated((i-1)*0.25),damage,340,Color("8ad9ff"))
	elif behavior == "ghost":
		world.beam(position+Vector2(0,-30),world.player.position+Vector2(0,-25),Color("9bd3e3"),3,0.4)
		if position.distance_to(world.player.position)<260 and world.dungeon.visible_line(position,world.player.position):
			State.run.mp = maxf(0,float(State.run.mp)-12)
			world.player.take_damage(damage*0.5)
	elif behavior in ["ranged","caster","imp"]:
		world.enemy_bolt(position,direction,damage,310 if behavior == "ranged" else 220,Color("d6b690") if behavior == "ranged" else Color("b384e5"))
		if behavior == "caster":
			world.enemy_bolt(position,direction.rotated(0.22),damage,220,Color("b384e5"))
			world.enemy_bolt(position,direction.rotated(-0.22),damage,220,Color("b384e5"))
	else:
		if position.distance_to(world.player.position)<78: world.player.take_damage(damage)
		if behavior == "poison": world.hazard(position,60,damage*0.4,0.3,Color("8aab61"),3.0)
	Sound.play("enemy")
	queue_redraw()

func take_damage(amount: float, force: Vector2 = Vector2.ZERO, quiet: bool = false) -> void:
	if dead: return
	active = true
	hp -= maxf(0.0,amount)*(1.0-float(definition.values.resistance))*(1.35 if fear>0 else 1.0)
	knockback += force * (0.2 if boss else 1.0)
	if not quiet: visual.hit_flash = 0.6
	if hp<=0:
		dead = true
		record.dead = true
		record.hp = 0.0
		world.enemy_killed(self)
		queue_free()

func chill(duration: float, factor: float = 0.5) -> void:
	slow_time = maxf(slow_time,duration)
	slow_factor = maxf(0.3,factor) if boss else factor

func freeze(duration: float) -> void:
	frozen = maxf(frozen,minf(duration,0.35) if boss else duration)

func _draw() -> void:
	if dead: return
	if hp<max_hp or boss:
		var width: float = 95 if boss else 48
		draw_rect(Rect2(-width/2,-(152 if boss else 95),width,4),Color("1a2026"))
		draw_rect(Rect2(-width/2,-(152 if boss else 95),width*maxf(0,hp/max_hp),4),Color("c8986c") if boss else Color("a56360"))
	if telegraph>0:
		draw_arc(Vector2.ZERO,52 if boss else 27,0,TAU,32,Color(1,0.55,0.3,0.8),3,true)
