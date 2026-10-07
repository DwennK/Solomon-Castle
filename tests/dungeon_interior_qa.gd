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
	DirAccess.make_dir_recursive_absolute("res://outputs/dungeon-v3")
	State.save_path = "user://qa_dungeon_interior.json"
	State.fresh(197903)
	State.learn("fire")
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
	State.options.reduced_effects = true
	await frames(10)
	await capture("reduced-effects")
	DisplayServer.window_set_size(Vector2i(960,600))
	await frames(10)
	await capture("compact-960x600")
	var report: Dictionary = {"errors":errors,"captures":captures,"native_renderer":true,"mobile":"Desktop native game; compact supported viewport 960x600 verified."}
	var file: FileAccess = FileAccess.open("res://outputs/dungeon-v3/report.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	print("DUNGEON_INTERIOR_QA ",JSON.stringify(report))
	Sound.stop_all()
	get_tree().quit(0 if errors.is_empty() else 1)

func frames(count: int) -> void:
	for i: int in range(count): await get_tree().process_frame

func capture(label: String) -> void:
	RenderingServer.force_draw()
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://outputs/dungeon-v3/"+label+".png")
	captures.append(label)
	print("CAPTURE ",label)

func check(ok: bool,label: String) -> void:
	if not ok: errors.append(label)
