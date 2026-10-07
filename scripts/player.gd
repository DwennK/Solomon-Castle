class_name MagePlayer
extends CharacterBody2D

var world: Node2D
var visual: ActorVisual
var aim: Vector2 = Vector2.RIGHT
var fire_timer: float = 0.0
var shield: float = 0.0
var invulnerable: float = 0.0
var cooldowns: Dictionary = {}
var resting: float = 0.0
var qa_direction: Vector2 = Vector2.ZERO
var qa_fire: bool = false
var qa_controlled: bool = false
var cached_stats: Dictionary = {}

func _ready() -> void:
	visual = ActorVisual.new()
	visual.texture = Catalog.texture("mage")
	visual.target_height = 93
	add_child(visual)
	State.changed.connect(refresh_stats)
	refresh_stats()

func refresh_stats() -> void:
	cached_stats = State.stats()

func _physics_process(delta: float) -> void:
	if not is_instance_valid(world) or State.run.is_empty(): return
	var direction: Vector2 = Input.get_vector("move_left","move_right","move_up","move_down")
	if qa_controlled: direction = qa_direction
	elif not Input.get_connected_joypads().is_empty():
		var stick: Vector2 = Vector2(Input.get_joy_axis(0,JOY_AXIS_LEFT_X),Input.get_joy_axis(0,JOY_AXIS_LEFT_Y))
		if stick.length()>0.2: direction = stick.limit_length()
	velocity = direction*cached_stats.speed
	move_and_slide()
	var mouse_aim: Vector2 = get_global_mouse_position()-global_position
	var firing: bool = Input.is_action_pressed("fire")
	if qa_controlled:
		firing = qa_fire
	else:
		if mouse_aim.length()>8: aim = mouse_aim.normalized()
		if not Input.get_connected_joypads().is_empty():
			var right: Vector2 = Vector2(Input.get_joy_axis(0,JOY_AXIS_RIGHT_X),Input.get_joy_axis(0,JOY_AXIS_RIGHT_Y))
			if right.length()>0.23:
				aim = right.normalized()
				firing = true
	visual.moving = direction.length()>0.1
	visual.facing = aim
	fire_timer = maxf(0.0,fire_timer-delta)
	invulnerable = maxf(0.0,invulnerable-delta)
	for key: String in cooldowns: cooldowns[key] = maxf(0.0,cooldowns[key]-delta)
	resting = 0.0 if firing or direction.length()>0.1 else resting+delta
	var regen: float = cached_stats.mana_regen + (State.rank("meditation")*3.0 if resting>1.0 else 0.0)
	State.run.mp = minf(cached_stats.max_mana,float(State.run.mp)+regen*delta)
	State.run.hp = minf(cached_stats.max_hp,float(State.run.hp)+(cached_stats.hp_regen+(State.rank("meditation")*0.8 if resting>1.0 else 0.0))*delta)
	if firing and not world.village and not State.run.active.is_empty(): world.combat.fire(self,delta)
	for i: int in range(3):
		if Input.is_action_just_pressed("secondary_%d"%i): world.combat.secondary(self,i)
	if Input.is_action_just_pressed("hp_potion") and State.potion("hp"): Sound.play("potion")
	if Input.is_action_just_pressed("mp_potion") and State.potion("mp"): Sound.play("potion")
	queue_redraw()

func take_damage(amount: float) -> void:
	if invulnerable>0.0 or State.run.dead: return
	if shield>0.0:
		shield = maxf(0.0,shield-amount)
	else:
		State.run.hp -= amount*(1.0-cached_stats.resistance)
	invulnerable = 0.25
	visual.hit_flash = 1.0
	Sound.play("hurt")
	world.effect(global_position,Color("f1946a"),25)
	if State.run.hp<=0:
		world.player_died()

func _draw() -> void:
	if shield>0:
		draw_arc(Vector2(0,-30),47,0,TAU,48,Color(0.45,0.8,1,0.65),2,true)
	if not world or world.village: return
	draw_arc(aim*47+Vector2(0,-15),7,0,TAU,16,Color(0.75,0.91,0.9,0.65),1.5,true)
