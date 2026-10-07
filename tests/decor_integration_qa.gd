extends Node
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
	DirAccess.make_dir_recursive_absolute("res://outputs/decor-fix")
	State.save_path = "user://qa_decor_integration.json"
	State.fresh(197903)
	State.learn("lightning")
	State.options.fullscreen = false
	State.apply_options()
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1440,900))
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	main.start_game()
	world = main.world
	stage(2,1)
	await frames(18)
	if "--decor-before" in OS.get_cmdline_user_args():
		await capture("before-floor-02")
		Sound.stop_all()
		get_tree().quit()
		return
	await capture("after-floor-02")
	check_atlas_edges()
	for index: int in range(6):
		stage(1,index)
		await frames(18)
		await capture("after-"+world.dungeon.interior.dressing.styles[index])
	stage(1,1)
	await frames(18)
	await check_depth_sort()
	check(not world.dungeon.path(Dungeon.vec(world.floor_data.entry),Dungeon.vec(world.floor_data.exit)).is_empty(),"Entry-exit navigation preserved")
	DisplayServer.window_set_size(Vector2i(960,600))
	await frames(12)
	await capture("after-compact")
	var report: Dictionary = {"errors":errors,"captures":captures}
	var file: FileAccess = FileAccess.open("res://outputs/decor-fix/report.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	print("DECOR_INTEGRATION_QA ",JSON.stringify(report))
	Sound.stop_all()
	get_tree().quit(0 if errors.is_empty() else 1)

func stage(number: int,index: int) -> void:
	world.load_floor(number)
	world.player.qa_controlled = true
	world.player.set_physics_process(false)
	for enemy: TowerEnemy in world.enemies: enemy.set_physics_process(false)
	world.player.position = Dungeon.to_world(Dungeon.room_center(world.floor_data.rooms[index]))+Vector2(0,-65)
	world.camera.reset_smoothing()

func frames(count: int) -> void:
	for i: int in range(count): await get_tree().process_frame

func capture(label: String) -> void:
	await get_tree().create_timer(0.12,true).timeout
	main.hud._process(0)
	RenderingServer.force_draw()
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://outputs/decor-fix/"+label+".png")
	captures.append(label)
	print("CAPTURE ",label," floor=",State.run.floor)
	# Do not mutate the next room from inside frame_post_draw.
	await get_tree().create_timer(0.05,true).timeout

func check(ok: bool,label: String) -> void:
	if not ok: errors.append(label)

func check_atlas_edges() -> void:
	var image: Image = DungeonDressing.DECOR.get_image()
	for index: int in range(DungeonDressing.DECOR_REGIONS.size()):
		var r: Rect2i = Rect2i(DungeonDressing.DECOR_REGIONS[index])
		var edge_alpha: float = 0
		for x: int in range(r.position.x,r.end.x):
			edge_alpha = maxf(edge_alpha,maxf(image.get_pixel(x,r.position.y).a,image.get_pixel(x,r.end.y-1).a))
		for y: int in range(r.position.y,r.end.y):
			edge_alpha = maxf(edge_alpha,maxf(image.get_pixel(r.position.x,y).a,image.get_pixel(r.end.x-1,y).a))
		check(edge_alpha<0.20,"Sprite %d has transparent gutters, no sliced opaque neighbor"%index)

func check_depth_sort() -> void:
	var target: DungeonDecoration
	var decor_count: int = 0
	for child: Node in world.actors.get_children():
		if child is DungeonDecoration:
			decor_count += 1
			var decor: DungeonDecoration = child
			var wall_base: float = float(decor.get_meta("wall_base_y"))
			check(decor.position.y-decor.size.y>=wall_base-DungeonInterior.WALL_FACE_HEIGHT-16,"Decoration fits facade height")
			if decor.get_meta("decoration_kind")==1 and decor.grounded and world.dungeon.room_at(decor.position+Vector2(0,32))==1: target = decor
	check(decor_count==world.dungeon.interior.wall_details.size(),"Every decoration participates in actor Y-sort")
	check(is_instance_valid(target),"Bookcase available for occlusion test")
	if not is_instance_valid(target): return
	world.player.position = target.position+Vector2(0,175)
	world.camera.reset_smoothing()
	await frames(16)
	var atlas: AtlasTexture = target.texture
	var image: Image = atlas.atlas.get_image()
	var region: Rect2i = Rect2i(atlas.region)
	var sample_uv: Vector2 = Vector2.ZERO
	for y: int in range(int(region.size.y*0.55),int(region.size.y*0.75),3):
		for x: int in range(int(region.size.x*0.35),int(region.size.x*0.65),3):
			if image.get_pixel(region.position.x+x,region.position.y+y).a>0.98:
				sample_uv = Vector2(x,y)/Vector2(region.size)
				break
		if sample_uv!=Vector2.ZERO: break
	check(sample_uv!=Vector2.ZERO,"Opaque surface found for depth probe")
	var sample_world: Vector2 = target.position+(sample_uv-Vector2(0.5,1))*target.size
	var probe: Polygon2D = Polygon2D.new()
	probe.color = Color.MAGENTA
	probe.polygon = PackedVector2Array([Vector2(-target.size.x,-target.size.y),Vector2(target.size.x,-target.size.y),Vector2(target.size.x,12),Vector2(-target.size.x,12)])
	probe.position = target.position-Vector2(0,6)
	world.actors.add_child(probe)
	await frames(8)
	await RenderingServer.frame_post_draw
	var pixel: Vector2i = Vector2i(world.get_global_transform_with_canvas()*sample_world)
	var behind: Color = get_viewport().get_texture().get_image().get_pixelv(pixel)
	check(not is_magenta(behind),"Opaque decoration covers an actor behind its foot")
	await get_tree().process_frame
	probe.position.y = target.position.y+6
	await frames(8)
	await RenderingServer.frame_post_draw
	var front: Color = get_viewport().get_texture().get_image().get_pixelv(pixel)
	check(is_magenta(front),"Actor in front covers decoration")
	await get_tree().process_frame
	world.actors.remove_child(probe)
	probe.queue_free()
	world.player.position = target.position+Vector2(0,30)
	world.camera.reset_smoothing()
	await frames(16)
	await capture("after-bookcase-close")

func is_magenta(color: Color) -> bool:
	return color.r>0.3 and color.b>0.3 and color.g<0.1
