extends Node
var checks: int = 0
var failures: Array[String] = []
var world: GameWorld

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label);push_error(label)

func _ready() -> void:
	if not State.qa: get_tree().quit(1);return
	State.save_path="user://qa_reaction_remnants.json"
	call_deferred("run_all")

func fixture() -> Dictionary:
	var data: Dictionary = Dungeon.generate(419,1)
	var grid: Array[String] = []
	for y: int in range(Dungeon.HEIGHT):
		var row: String = ""
		for x: int in range(Dungeon.WIDTH): row += "." if Rect2i(4,4,23,18).has_point(Vector2i(x,y)) or Rect2i(30,4,6,6).has_point(Vector2i(x,y)) else "#"
		grid.append(row)
	data.grid=grid;data.rooms=[[4,4,23,18],[30,4,6,6]]
	data.entry=[800,760];data.exit=[1400,950]
	data.enemies=[];data.props=[];data.encounters=[];data.loot=[];data.revealed=[]
	return data

func enemy(kind: String, p: Vector2) -> TowerEnemy:
	var e: TowerEnemy = GameWorld.ENEMY_SCENE.instantiate()
	e.setup(world,{"id":"feedback_"+kind+str(world.enemies.size()),"kind":kind,"pos":Dungeon.pair(p),"hp":-1.0,"dead":false,"reward":{}})
	world.actors.add_child(e);world.enemies.append(e);e.set_physics_process(false)
	e.visual.environment=world.dungeon.interior
	return e

func capture(label: String) -> void:
	await get_tree().process_frame
	RenderingServer.force_draw()
	get_viewport().get_texture().get_image().save_png("res://outputs/reaction-remnants/"+label+".png")

func run_all() -> void:
	DirAccess.make_dir_recursive_absolute("res://outputs/reaction-remnants")
	State.fresh(419);State.learn("missile");State.learn("fire");State.learn("ice")
	State.run.floor=1;State.run.floors["1"]=fixture();State.run.position=[800,760]
	State.options.reduced_effects=false
	world=load("res://scenes/world.tscn").instantiate();add_child(world)
	world.set_physics_process(false);world.player.qa_controlled=true;world.player.set_physics_process(false)
	world.dungeon.reveal(world.player.position);world.camera.reset_smoothing()
	var layer: CanvasLayer=CanvasLayer.new();add_child(layer)
	var hud: GameHUD=GameHUD.new();hud.world=world;layer.add_child(hud)
	var bones: TowerEnemy=enemy("skeleton",Vector2(640,660))
	var armor: TowerEnemy=enemy("knight",Vector2(800,650))
	var cold: TowerEnemy=enemy("zombie",Vector2(980,650))
	var original: Vector2=armor.position
	var hp: float=armor.hp
	var frozen_before: float=armor.frozen
	armor.take_damage(1,Vector2.ZERO,false,armor.position-Vector2.RIGHT*80)
	check(armor.visual.hit_metal and armor.visual.hit_time>0,"Armored hit emits material reaction")
	check(armor.position==original and armor.knockback==Vector2.ZERO and armor.frozen==frozen_before,"Visual recoil changes neither collision position, force nor stun")
	check(is_equal_approx(hp-armor.hp,1.0-float(armor.definition.values.resistance)),"Reaction preserves damage calculation")
	armor.visual._process(.06)
	check(armor.visual.sprite.position.x>0,"Impact moves the artwork away from its source")
	armor.visual._process(.3)
	check(armor.visual.hit_time==0,"Recoil settles without a lingering offset")
	cold.freeze(1);cold.visual.frozen=true;cold.take_damage(1)
	check(cold.visual.hit_ice,"Hitting a frozen enemy draws fracture feedback")
	check(cold.frozen==1,"Ice fracture does not extend freeze duration")
	var held: float=cold.visual.hit_time
	cold.take_damage(.01,Vector2.ZERO,true)
	check(cold.visual.hit_time==held,"Continuous damage cannot restart the reaction every tick")
	var fire: MagicProjectile=MagicProjectile.new()
	fire.world=world;fire.profile=world.combat.profile("fire");fire.position=Vector2(625,760)
	world.shots.add_child(fire);fire.set_physics_process(false);fire.impact(null)
	check(world.remnants.marks.any(func(m: Dictionary)->bool:return m.kind=="fire"),"Actual fire projectile impact leaves a scorch mark")
	world.combat.explosion(Vector2(830,850),95,0,Color("b8eafa"),0,"freeze")
	check(world.remnants.marks.any(func(m: Dictionary)->bool:return m.kind=="ice"),"Frost area spell leaves ice on nearby open floor")
	world.friendly_zone(Vector2(995,790),"acid",70,.01,1)
	world.update_zones(.02)
	check(world.zones.is_empty() and world.remnants.marks.any(func(m: Dictionary)->bool:return m.kind=="acid"),"Acid residue remains cosmetic after the damage zone expires")
	var count: int=world.remnants.marks.size()
	world.remnants.add_mark(Vector2(995,790),"acid")
	check(world.remnants.marks.size()==count,"Repeated nearby marks merge")
	check(not world.remnants.add_mark(Vector2(64,64),"fire"),"Walls cannot receive floor marks")
	check(not world.remnants.add_mark(Dungeon.to_world(Vector2i(32,6)),"ice"),"Undiscovered room cannot reveal a spell trace")
	if DisplayServer.get_name()!="headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(Vector2i(1440,900))
		await get_tree().create_timer(1.1).timeout
	bones.take_damage(10000)
	check(bones.dead and world.remnants.marks.any(func(m: Dictionary)->bool:return m.kind=="bone"),"Skeleton death separates the body and leaves fading bone fragments")
	if DisplayServer.get_name()!="headless":
		await get_tree().create_timer(.18).timeout
		armor.visual.react_hit(Vector2.RIGHT,1,false,true);cold.visual.react_hit(Vector2.LEFT,1,true,false)
		await get_tree().create_timer(.05).timeout
		await capture("reactions-1440x900")
		DisplayServer.window_set_size(Vector2i(960,600))
		await capture("residue-960x600")
		State.options.reduced_effects=true
		await capture("reduced-effects-960x600")
	# Fill many distinct patches, then verify both budgets and real expiry.
	for i: int in range(150): world.remnants.add_mark(Vector2(350+(i%20)*45,350+(i/20)*45),"fire")
	check(world.remnants.marks.size()<=24,"Reduced effects caps ground marks at 24")
	State.options.reduced_effects=false
	for i: int in range(150): world.remnants.add_mark(Vector2(350+(i%20)*45,350+(i/20)*45),"ice")
	check(world.remnants.marks.size()<=64,"Normal effects caps ground marks at 64")
	world.remnants._process(8)
	check(world.remnants.marks.is_empty(),"All marks expire after their lifetime")
	world.remnants.add_mark(world.player.position,"fire")
	var life: float=world.remnants.marks[0].life
	get_tree().paused=true
	await get_tree().create_timer(.1,true).timeout
	check(world.remnants.marks[0].life==life,"Pausing the game pauses cosmetic lifetime")
	get_tree().paused=false
	world.load_floor(0)
	check(world.remnants.marks.is_empty(),"Floor transitions discard all cosmetic remnants")
	check(not world.remnants.add_mark(world.player.position,"fire"),"Village does not accumulate combat marks")
	var report: Dictionary={"checks":checks,"failures":failures,"renderer":DisplayServer.get_name()}
	FileAccess.open("res://outputs/reaction-remnants/report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("REACTION_REMNANTS ",JSON.stringify(report))
	layer.queue_free();world.queue_free();Sound.stop_all()
	get_tree().quit(0 if failures.is_empty() else 1)
