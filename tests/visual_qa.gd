extends Node

var main: Node
var samples: Array[float] = []
var fps_samples: Array[float] = []
var last_tick: int = 0
var measuring: bool = false
var report: Dictionary = {}

func start(owner_main: Node) -> void:
	main=owner_main
	State.fresh(197903)
	State.learn("missile")
	main.start_game()
	main.world.enter_tower()
	var world: GameWorld = main.world
	world.player.qa_controlled=true
	var route: PackedVector2Array = world.dungeon.path(world.player.position,Dungeon.to_world(Dungeon.room_center(world.floor_data.rooms[1])))
	var point_index: int = 1
	var before_count: int = world.enemies.size()
	var begin: int = Time.get_ticks_msec()
	# Real normal statistics: no health, damage or mana boost during this short session.
	for frame: int in range(1000):
		if main.modal_kind=="level":
			State.choose(State.offers()[0]);main.close_modal()
		if main.modal_kind=="death": break
		var enemy: TowerEnemy = world.combat.nearest(world.player.position,430)
		if enemy:
			world.player.aim=world.player.position.direction_to(enemy.position)
			world.player.qa_fire=true
			world.player.qa_direction=-world.player.aim if world.player.position.distance_to(enemy.position)<170 else Vector2.ZERO
		else:
			world.player.qa_fire=false
			if point_index<route.size():
				if world.player.position.distance_to(route[point_index])<22: point_index+=1
				if point_index<route.size(): world.player.qa_direction=world.player.position.direction_to(route[point_index])
		if State.run.hp<45: State.potion("hp")
		await get_tree().physics_frame
		if frame==800: await capture("08-normal-combat")
	world.player.qa_direction=Vector2.ZERO
	world.player.qa_fire=false
	report.normal_session={"seconds":(Time.get_ticks_msec()-begin)/1000.0,"enemy_kills":before_count-world.enemies.size(),"level":State.run.level,"hp":State.run.hp,"mp":State.run.mp,"deaths":State.run.deaths,"assistance":"Simulated navigation/aim only; normal stats and potion use; no invulnerability"}
	# Resolution and modal checks on the running native renderer.
	for resolution: Vector2i in [Vector2i(1440,900),Vector2i(1920,1080),Vector2i(960,600)]:
		DisplayServer.window_set_size(resolution)
		await frames(6)
		main.show_inventory()
		await frames(3)
		await capture("inventory-%dx%d"%[resolution.x,resolution.y])
		main.close_modal()
		await frames(3)
		await capture("game-%dx%d"%[resolution.x,resolution.y])
	DisplayServer.window_set_size(Vector2i(1440,900))
	await frames(5)
	if main.modal_kind=="death": main.close_modal()
	State.fresh(197903)
	State.learn("lightning")
	State.run.skills.chain=4
	State.run.skills.regen=6
	State.run.skills.economy=6
	State.run.floor=1
	var floor_value: Dictionary = Dungeon.generate(197903,1)
	floor_value.enemies=[]
	State.run.floors["1"]=floor_value
	world.load_floor(1)
	var room: Array = floor_value.rooms[1]
	var center: Vector2 = Dungeon.to_world(Dungeon.room_center(room))
	world.player.position=center
	world.player.qa_controlled=true
	world.player.qa_fire=true
	world.player.aim=Vector2.RIGHT
	for i: int in range(80):
		var point: Vector2 = center+Vector2((i%10-5)*40,(int(i/10)-4)*38)
		var record: Dictionary = {"id":"stress_%d"%i,"kind":["skeleton","archer","sorcerer","ghoul","knight","imp","zombie","ghost"][i%8],"pos":Dungeon.pair(point),"hp":100000.0,"dead":false}
		var enemy: TowerEnemy = load("res://scenes/enemy.tscn").instantiate()
		enemy.setup(world,record)
		world.actors.add_child(enemy)
		world.enemies.append(enemy)
		floor_value.enemies.append(record)
	for i: int in range(120):
		world.player.invulnerable=1
		await get_tree().physics_frame
	measuring=true
	last_tick=Time.get_ticks_usec()
	for i: int in range(600):
		world.player.invulnerable=1
		world.player.aim=Vector2.RIGHT.rotated(i*0.015)
		State.run.mp=100
		await get_tree().physics_frame
		if i==300: await capture("09-dense-combat-80-enemies")
	measuring=false
	samples.sort()
	fps_samples.sort()
	var total: float = 0
	for sample: float in samples: total+=sample
	report.performance={"machine":OS.get_processor_name(),"renderer":RenderingServer.get_rendering_device().get_device_name() if RenderingServer.get_rendering_device() else "Compatibility / Apple M4 OpenGL 4.1 Metal","enemies":80,"frames":samples.size(),"mean_frame_ms":total/maxi(1,samples.size()),"p95_frame_ms":samples[int(samples.size()*0.95)],"median_fps":fps_samples[int(fps_samples.size()*0.5)],"resolution":"1440x900","physics_fps":Engine.physics_ticks_per_second,"seconds":10,"conditions":"Invulnerable stationary QA mage, 80 high-HP enemies, real AI/collisions/projectiles/lightning, no time acceleration"}
	world.player.qa_fire=false
	world.snapshot()
	State.mark_checkpoint()
	world.player.invulnerable=0
	world.player.take_damage(100000)
	await frames(3)
	report.normal_death_modal = main.modal_kind=="death" and not State.run.dead
	await capture("11-death-normal")
	main.close_modal()
	world.load_floor(int(State.run.floor),true)
	State.fresh(8821,0,true)
	State.learn("fire")
	world.load_floor(0)
	world.player.invulnerable=0
	world.player.take_damage(100000)
	await frames(3)
	report.hardcore_death_modal = main.modal_kind=="death" and State.run.dead
	await capture("12-death-hardcore")
	main.close_modal()
	State.fresh(72931)
	State.learn("fire")
	var resume_item: Dictionary = State.make_item(81,3)
	State.run.inventory.append(resume_item)
	State.equip(resume_item.uid)
	world.load_floor(0)
	report.resume_seed = State.run.seed
	report.resume_item = resume_item.name
	main.show_options()
	await frames(3)
	await capture("10-options")
	main.close_modal()
	# Persist the current world to exercise restoration in a separate process next.
	world.snapshot()
	State.save_game()
	var file: FileAccess = FileAccess.open("res://outputs/visual-qa.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"));file.close()
	print("VISUAL_QA ",JSON.stringify(report))
	Sound.stop_all()
	await get_tree().create_timer(0.2,true).timeout
	get_tree().quit()

func _process(_delta: float) -> void:
	if measuring:
		var now: int = Time.get_ticks_usec()
		samples.append((now-last_tick)/1000.0)
		last_tick=now
		fps_samples.append(Engine.get_frames_per_second())

func frames(n: int) -> void:
	for i: int in range(n): await get_tree().physics_frame

func capture(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://outputs/screenshots/"+name+".png")
