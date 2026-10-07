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
var footstep_distance: float = 0.0
var qa_direction: Vector2 = Vector2.ZERO
var qa_fire: bool = false
var qa_controlled: bool = false
var cached_stats: Dictionary = {}

func _ready() -> void:
	visual = ActorVisual.new()
	visual.texture = Catalog.texture("mage")
	visual.target_height = 116
	add_child(visual)
	State.changed.connect(refresh_stats)
	refresh_stats()

func refresh_stats() -> void:
	cached_stats = State.stats()

func _physics_process(delta: float) -> void:
	if not is_instance_valid(world) or State.run.is_empty(): return
	var direction: Vector2 = Input.get_vector("move_left","move_right","move_up","move_down")
	if qa_controlled: direction = qa_direction
	elif Controls.using_pad and Controls.pad_device in Input.get_connected_joypads():
		var stick: Vector2 = Vector2(Input.get_joy_axis(Controls.pad_device,JOY_AXIS_LEFT_X),Input.get_joy_axis(Controls.pad_device,JOY_AXIS_LEFT_Y))
		if stick.length()>0.2: direction = stick.limit_length()
	velocity = direction*cached_stats.speed
	var previous_position: Vector2 = global_position
	move_and_slide()
	Sound.listener_position = global_position
	footstep_distance += previous_position.distance_to(global_position)
	if footstep_distance>=68.0:
		footstep_distance = 0.0
		Sound.play("step_gravel" if world.village else "step_stone",global_position)
	var mouse_aim: Vector2 = get_global_mouse_position()-global_position
	var firing: bool = Input.is_action_pressed("fire")
	var hovered: Control = get_viewport().gui_get_hovered_control()
	if hovered is BaseButton and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT): firing = false
	if qa_controlled:
		firing = qa_fire
	else:
		if not Controls.using_pad and mouse_aim.length()>8: aim = mouse_aim.normalized()
		if Controls.using_pad and Controls.pad_device in Input.get_connected_joypads():
			var right: Vector2 = Vector2(Input.get_joy_axis(Controls.pad_device,JOY_AXIS_RIGHT_X),Input.get_joy_axis(Controls.pad_device,JOY_AXIS_RIGHT_Y))
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
	if resting>1.0 and cached_stats.meditation: regen *= 4.0
	State.run.mp = minf(cached_stats.max_mana,float(State.run.mp)+regen*delta)
	State.run.hp = minf(cached_stats.max_hp,float(State.run.hp)+(cached_stats.hp_regen+(State.rank("meditation")*0.8 if resting>1.0 else 0.0))*delta)
	if firing and not world.village and not State.run.active.is_empty(): world.combat.fire(self,delta)
	for i: int in range(3):
		if Input.is_action_just_pressed("secondary_%d"%i): world.combat.secondary(self,i)
	if Input.is_action_just_pressed("hp_potion") and State.potion("hp"): Sound.play("potion")
	if Input.is_action_just_pressed("mp_potion") and State.potion("mp"): Sound.play("mana")
	queue_redraw()

func take_damage(amount: float, damage_type: String = "physical") -> void:
	if invulnerable>0.0 or State.run.dead: return
	if damage_type=="poison": amount *= 1.0-cached_stats.poison_resistance
	if amount<=0.0: return
	var absorbed: bool = shield>0.0 and damage_type!="poison"
	if absorbed:
		shield = maxf(0.0,shield-amount)
	else:
		State.run.hp -= amount*(1.0-cached_stats.resistance)
	invulnerable = 0.25
	visual.hit_flash = 1.0
	world.impact_trauma = 0.65
	Sound.play("shield_hit" if absorbed else "hurt")
	world.effect(global_position,Color("f1946a"),25)
	if State.run.hp<=0:
		world.player_died()

func _draw() -> void:
	var time: float = visual.elapsed if visual else 0.0
	var color: Color = CombatSystem.COLORS.get(State.run.get("active","missile"),Color("83ddeb"))
	if shield>0:
		var center: Vector2 = Vector2(0,-40)
		ArcaneArt.glow(self,center,62,Color(0.35,0.7,1,0.24))
		for i: int in range(3):
			draw_arc(center,49+i*3,time*0.5+i*TAU/3,time*0.5+i*TAU/3+1.5,24,Color(0.55,0.85,1,0.65),1.5,true)
		ArcaneArt.rune(self,center,54,Color(0.6,0.87,1,0.5),-time*0.22,8)
	if not world or world.village: return
	draw_set_transform(Vector2(0,5),0,Vector2(1,0.42))
	ArcaneArt.rune(self,Vector2.ZERO,29,Color(color,0.35),time*0.2,8)
	draw_set_transform(Vector2.ZERO)
	var point: Vector2 = aim*55+Vector2(0,-15)
	draw_arc(point,6,time,time+PI*1.4,16,Color(color,0.8),1.4,true)
	draw_circle(point,1.5,Color(1,0.95,0.83,0.8))
