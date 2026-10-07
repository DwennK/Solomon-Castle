extends Node
## Real renderer coverage and regression checks for the environment-only pass.
var main: Node
var world: GameWorld
var errors: Array[String] = []
var captures: Array[String] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not State.qa:
		get_tree().quit(1)
		return
	call_deferred("run_qa")

func run_qa() -> void:
	DirAccess.make_dir_recursive_absolute("res://outputs/dungeon-v4")
	State.options.reduced_effects = false
	State.save_path = "user://qa_dungeon_sprint.json"
	State.fresh(197903)
	State.learn("fire")
	State.options.fullscreen = false
	State.apply_options()
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1440,900))
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	main.start_game()
	world = main.world
	for floor_number: int in [1,8,13]:
		world.load_floor(floor_number)
		world.player.qa_controlled = true
		world.player.set_physics_process(false)
		for enemy: TowerEnemy in world.enemies: enemy.set_physics_process(false)
		world.player.position = Dungeon.to_world(Dungeon.room_center(world.floor_data.rooms[1]))
		world.camera.reset_smoothing()
		await frames(15)
		check(world.dungeon.interior!=null,"Interior exists floor %d"%floor_number)
		check(world.dungeon.walkable(world.player.position,18),"Room center walkable")
		var route_end: Vector2 = Dungeon.vec(world.floor_data.exit) if world.floor_data.gate_open else Dungeon.to_world(Dungeon.room_center(world.floor_data.rooms[1]))
		check(not world.dungeon.path(Dungeon.vec(world.floor_data.entry),route_end).is_empty(),"Route through unlocked rooms preserved")
		await capture("floor-%02d"%floor_number)
		if floor_number==1:
			var types_seen: Array[String] = []
			for room_index: int in range(world.floor_data.rooms.size()):
				var style: String = world.dungeon.interior.dressing.styles[room_index]
				if style not in types_seen: types_seen.append(style)
				world.player.position = Dungeon.to_world(Dungeon.room_center(world.floor_data.rooms[room_index]))+Vector2(0,-88)
				world.camera.reset_smoothing()
				await frames(15)
				await capture("room-"+style)
			check(types_seen.size()==6,"Six distinct room identities")
			var interior: DungeonInterior = world.dungeon.interior
			var warm: Vector2 = interior.lights[-1].pos
			var sample: Dictionary = interior.sample_light(warm)
			check(sample.strength>0.8,"Actors sample local light near a source")
			check(world.player.visual.environment==interior,"Player receives room lighting")
			check(world.enemies[0].visual.environment==interior,"Enemies receive room lighting")
			world.player.position = Dungeon.to_world(Dungeon.room_center(world.floor_data.rooms[1]))
			world.camera.reset_smoothing()
			world.hazard(world.player.position+Vector2(170,0),80,1,10,Color("ff7755"))
			world.friendly_zone(world.player.position+Vector2(-140,90),"circle",95,20,1)
			world.spawn_projectile(world.player.position,Vector2.RIGHT,world.combat.profile("fire"))
			await frames(8)
			await capture("combat-readability")
			world.zones.clear()
			# Closed/open state still reaches the same live prop.
			var chest: WorldProp
			for prop: WorldProp in world.props:
				if prop.record.id=="chest_1": chest = prop
			world.open_prop(chest)
			check(chest.record.opened,"Chest opens with new interior")
			await frames(4)
			await capture("chest-open")
			world.player.position = Dungeon.vec(world.floor_data.entry)
			world.camera.reset_smoothing()
			await frames(10)
			await capture("entry")
			var route: PackedVector2Array = world.dungeon.path(Dungeon.vec(world.floor_data.entry),Dungeon.to_world(Dungeon.room_center(world.floor_data.rooms[1])))
			for point: Vector2 in route:
				if world.dungeon.room_at(point)==-1:
					world.player.position = point
					break
			world.camera.reset_smoothing()
			await frames(10)
			await capture("corridor")
	var timings: Array[float] = []
	var start: int = Time.get_ticks_usec()
	for frame: int in range(180):
		await get_tree().process_frame
		var now: int = Time.get_ticks_usec()
		timings.append((now-start)/1000.0)
		start = now
	timings.sort()
	print("NATIVE_FRAME_TIMES_MS median=",timings[90]," p95=",timings[171])
	State.options.reduced_effects = true
	await frames(10)
	await capture("reduced-effects")
	DisplayServer.window_set_size(Vector2i(960,600))
	await frames(10)
	await capture("compact-960x600")
	var report: Dictionary = {"frame_ms_median":timings[90],"frame_ms_p95":timings[171],"errors":errors,"captures":captures,"native_renderer":true,"mobile":"Desktop native game; compact supported viewport 960x600 verified."}
	var file: FileAccess = FileAccess.open("res://outputs/dungeon-v4/report.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	print("DUNGEON_SPRINT_QA ",JSON.stringify(report))
	Sound.stop_all()
	get_tree().quit(0 if errors.is_empty() else 1)

func frames(count: int) -> void:
	for i: int in range(count): await get_tree().process_frame

func capture(label: String) -> void:
	RenderingServer.force_draw()
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://outputs/dungeon-v4/"+label+".png")
	captures.append(label)
	print("CAPTURE ",label)

func check(ok: bool,label: String) -> void:
	if not ok: errors.append(label)
