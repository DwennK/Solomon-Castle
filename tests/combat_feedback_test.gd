extends Node

var checks: int = 0
var failures: Array[String] = []
var world: GameWorld
var target: TowerEnemy
var draws: int = 0

func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label);push_error(label)

func _ready() -> void:
	if not State.qa: get_tree().quit(1);return
	State.save_path="user://qa_combat_feedback.json"
	call_deferred("run_all")

func run_all() -> void:
	State.fresh(821);State.learn("ice");State.run.floor=1
	var data: Dictionary = Dungeon.generate(821,1)
	var grid: Array[String] = []
	for y: int in range(Dungeon.HEIGHT):
		var row: String = ""
		for x: int in range(Dungeon.WIDTH): row+="." if Rect2i(3,3,22,18).has_point(Vector2i(x,y)) else "#"
		grid.append(row)
	data.grid=grid;data.rooms=[[3,3,22,18]];data.props=[];data.enemies=[];data.encounters=[]
	data.entry=[800,800];data.exit=[1200,1000]
	State.run.floors["1"]=data;State.run.position=[800,800]
	world=load("res://scenes/world.tscn").instantiate();add_child(world)
	world.set_physics_process(false);world.player.set_physics_process(false);world.player.qa_controlled=true
	world.player.aim=Vector2.RIGHT
	target=load("res://scenes/enemy.tscn").instantiate()
	target.setup(world,{"id":"feedback_target","kind":"skeleton","pos":[980,800],"hp":-1.0,"dead":false})
	world.actors.add_child(target);world.enemies.append(target);target.set_physics_process(false)
	target.visual.environment=world.dungeon.interior
	target.max_hp=1000;target.hp=1000;target.active=true
	for spell: String in ["ice","steam","blizzard"]:
		for rank_value: int in [1,5,10]:
			State.run.skills={"ice":1,"fire":1,"lightning":1,"cone":1,"chill":rank_value}
			if spell!="ice": State.learn(spell)
			world.enemy_bolt(world.player.position+Vector2(100,0),Vector2.LEFT,10,100,Color.RED)
			var shot: MagicProjectile = world.shots.get_child(0)
			shot.set_physics_process(false)
			var before: Vector2 = shot.position
			target.knockback=Vector2.ZERO
			world.combat.channel(world.player,world.combat.profile(spell),0.1)
			check(shot.direction==Vector2.LEFT and shot.position==before and shot.speed==100 and shot.hostile,"%s rank %d leaves hostile projectile unchanged"%[spell,rank_value])
			check(target.knockback.x>0,"%s keeps enemy knockback"%spell)
			shot.free()
	State.run.skills={"lightning":1,"hurricane":5}
	world.enemy_bolt(world.player.position+Vector2(100,0),Vector2.LEFT,10,100,Color.RED)
	var shot: MagicProjectile = world.shots.get_child(0);shot.set_physics_process(false)
	world.combat.hurricane(world.player,0.1)
	check(shot.direction==Vector2.LEFT,"Hurricane does not redirect hostile projectiles")
	world.player.shield=0;world.player.ice_armor=0;world.player.invulnerable=0
	var hp: float = State.run.hp
	shot._physics_process(0.9)
	check(State.run.hp<hp,"Incoming projectile can still hit the mage after knockback effects")
	shot.free()
	target.hp=target.max_hp;target.knockback=Vector2.ZERO;target.slow_time=0;target.cooldown=100
	target.freeze(5);target._physics_process(0)
	var position_before: Vector2 = target.position
	target.take_damage(200)
	target._physics_process(0.1)
	check(target.hp==800 and target.frozen>0 and target.position==position_before,"Frozen enemy loses health without moving or thawing")
	target.take_damage(100,Vector2.ZERO,true)
	check(target.hp==700,"Quiet channel damage reaches frozen enemy")
	target.burn=1;hp=target.hp;target._physics_process(0.1)
	check(target.hp<hp and target.frozen>0,"Burn continues to hurt a frozen enemy")
	target.burn=0
	if DisplayServer.get_name()!="headless": await visual_checks()
	target.take_damage(10000)
	check(target.dead and target.record.dead,"Frozen enemy still dies from lethal damage")
	var report: Dictionary = {"checks":checks,"failures":failures,"renderer":DisplayServer.get_name(),"engine":Engine.get_version_info().string}
	DirAccess.make_dir_recursive_absolute("res://outputs/combat-feedback")
	var file: FileAccess = FileAccess.open("res://outputs/combat-feedback/report.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"));file.close()
	print("COMBAT_FEEDBACK_QA ",JSON.stringify(report))
	world.queue_free();Sound.stop_all();get_tree().quit(0 if failures.is_empty() else 1)

func visual_checks() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1440,900))
	var layer: CanvasLayer = CanvasLayer.new();add_child(layer)
	var hud: GameHUD = GameHUD.new();hud.world=world;layer.add_child(hud)
	target.draw.connect(func()->void: draws+=1)
	target.hp=target.max_hp;target.queue_redraw()
	await render_frame()
	var before: int = draws
	target.take_damage(250)
	var image_a: Image = await capture("frozen-75-percent-1440x900")
	check(draws>before,"Damage redraws a frozen enemy even when its AI never requests a redraw")
	before=draws
	target.take_damage(500,Vector2.ZERO,true)
	var image_b: Image = await capture("frozen-25-percent-1440x900")
	check(draws>before,"Quiet damage redraws frozen health bar")
	var left: Vector2i = Vector2i(target.get_global_transform_with_canvas()*Vector2(-24,-115))
	var filled_a: int = bar_pixels(image_a,left)
	var filled_b: int = bar_pixels(image_b,left)
	check(filled_a>=34 and filled_a<=38 and filled_b>=10 and filled_b<=14,"Rendered bar shrinks from 75 percent to 25 percent while frozen (%d to %d pixels)"%[filled_a,filled_b])
	DisplayServer.window_set_size(Vector2i(960,600))
	await capture("frozen-25-percent-960x600")

func bar_pixels(picture: Image,left: Vector2i) -> int:
	var filled: int = 0
	for x: int in range(48):
		var pixel: Color = picture.get_pixel(left.x+x,left.y)
		if pixel.r>pixel.g*1.3 and pixel.r>0.4: filled+=1
	return filled

func render_frame() -> void:
	world.camera.reset_smoothing()
	for i: int in range(4): await get_tree().process_frame
	RenderingServer.force_draw()

func capture(label: String) -> Image:
	DirAccess.make_dir_recursive_absolute("res://outputs/combat-feedback")
	await render_frame()
	var picture: Image = get_viewport().get_texture().get_image()
	picture.save_png("res://outputs/combat-feedback/"+label+".png")
	return picture
