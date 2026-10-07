extends Node
var main: Node
var world: GameWorld
var errors: Array[String] = []
var checks: int = 0
var captures: Array[String] = []

func _ready() -> void:
	if not State.qa: get_tree().quit(1); return
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("run_qa")

func run_qa() -> void:
	DirAccess.make_dir_recursive_absolute("res://outputs/environment-v5")
	check_atlases()
	for seed_value: int in [17,80,197903]:
		for number: int in [1,2,4,8,11,13]: check_layout(seed_value,number)
	if DisplayServer.get_name() != "headless": await visual_qa()
	var report: Dictionary = {"checks":checks,"errors":errors,"captures":captures}
	var file: FileAccess = FileAccess.open("res://outputs/environment-v5/report.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	print("ENVIRONMENT_QA ",JSON.stringify(report))
	Sound.stop_all()
	get_tree().quit(0 if errors.is_empty() else 1)

func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: errors.append(label); push_error(label)

func check_atlases() -> void:
	for entry: Array in [[EnvironmentArt.FURNITURE,EnvironmentArt.FURNITURE_REGIONS],[EnvironmentArt.ARCHITECTURE,EnvironmentArt.ARCHITECTURE_REGIONS],[EnvironmentArt.PROPS,EnvironmentArt.PROP_REGIONS],[EnvironmentArt.STAIRS,[Rect2(340,109,575,958)]]]:
		var image: Image = entry[0].get_image()
		for rect: Rect2 in entry[1]:
			var r: Rect2i = Rect2i(rect)
			var alpha: float = 0.0
			for x: int in range(r.position.x,r.end.x): alpha = maxf(alpha,maxf(image.get_pixel(x,r.position.y).a,image.get_pixel(x,r.end.y-1).a))
			for y: int in range(r.position.y,r.end.y): alpha = maxf(alpha,maxf(image.get_pixel(r.position.x,y).a,image.get_pixel(r.end.x-1,y).a))
			check(alpha<0.20,"Atlas gutter without opaque neighbor: %s %s alpha=%f"%[entry[0].resource_path,rect,alpha])

func check_layout(seed_value: int,number: int) -> void:
	var data: Dictionary = Dungeon.generate(seed_value,number)
	var original: String = JSON.stringify(data)
	var d: Dungeon = Dungeon.new()
	d.build(data)
	var layout: DungeonInterior = d.interior
	check(JSON.stringify(data)==original,"Rendering preserves saved floor records")
	for edge: Dictionary in layout.boundaries:
		check(d.cells.has(edge.cell) and not d.cells.has(edge.cell+edge.side),"Walls follow actual closed edges")
	for prop: Dictionary in data.props:
		var p: Vector2 = layout.dressing.prop_positions.get(prop.id,Dungeon.vec(prop.pos))
		if prop.kind!="torch": check(d.walkable(p,18),"Interactive prop remains reachable")
	for index: int in layout.inlays:
		var panel: Rect2i = layout.inlays[index]
		for y: int in range(panel.position.y,panel.end.y):
			for x: int in range(panel.position.x,panel.end.x): check(layout.room_cells.get(Vector2i(x,y),-1)==index,"Stone inlay stays in its room")
	for i: int in range(layout.dressing.occupied.size()):
		for j: int in range(i+1,layout.dressing.occupied.size()):
			check(not layout.dressing.occupied[i].intersects(layout.dressing.occupied[j]),"Decorative bays do not overlap")
	for source: Dictionary in layout.lights: check(d.walkable(source.pos),"Light projection starts on traversable floor")
	var again: Dungeon = Dungeon.new(); again.build(data.duplicate(true))
	check(again.interior.dressing.prop_positions==layout.dressing.prop_positions,"Prop layout deterministic across reloads")
	check(again.interior.wall_details.size()==layout.wall_details.size(),"Furniture layout deterministic across reloads")
	again.free(); d.free()

func visual_qa() -> void:
	State.save_path = "user://qa_environment_v5.json"
	State.fresh(197903); State.learn("lightning")
	State.options.fullscreen = false; State.apply_options()
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1440,900))
	main = load("res://scenes/main.tscn").instantiate(); add_child(main)
	main.start_game(); world = main.world
	world.load_floor(1); freeze()
	check(find_prop("exit").texture==EnvironmentArt.prop("stairs"),"Stairs use the matching stone architecture")
	for index: int in range(6):
		world.player.position = Dungeon.to_world(Dungeon.room_center(world.floor_data.rooms[index]))+Vector2(0,-65)
		world.dungeon.reveal(world.player.position)
		world.camera.reset_smoothing()
		await capture("room-"+world.dungeon.interior.dressing.styles[index])
	for child: Node in world.dungeon.get_children():
		if child is DungeonLighting:
			check(not child.pools.is_empty(),"Clipped light meshes generated")
			for pool: Dictionary in child.pools:
				for cell: Vector2i in pool.cells:
					check(world.dungeon.cells.has(cell) and world.dungeon.interior.source_reaches(pool.source,Dungeon.to_world(cell)),"Light mesh excludes walls and occluded rooms")
	var chest: WorldProp
	for prop: WorldProp in world.props:
		if prop.record.kind=="chest": chest = prop; break
	var chest_id: String = chest.record.id
	world.player.position = chest.position+Vector2(0,48); world.camera.reset_smoothing()
	await capture("chest-closed")
	check(world.closest_prop()==chest,"Chest visual foot is the actual interaction position")
	world.interact()
	check(chest.record.opened and chest.texture==EnvironmentArt.prop("chest",true),"Chest interaction uses the matching open sprite")
	await capture("chest-open")
	var urn: WorldProp
	for prop: WorldProp in world.props:
		if prop.record.kind=="urn": urn = prop; break
	var urn_id: String = urn.record.id
	world.player.position = urn.position+Vector2(0,36)
	world.player.aim = Vector2.UP
	world.combat.channel(world.player,world.combat.profile("lightning"),1.0/60)
	check(urn.record.opened,"Urn still breaks from its displayed position")
	world.snapshot()
	world.load_floor(1,true); freeze()
	check(find_prop(chest_id).record.opened and find_prop(urn_id).record.opened,"Opened states survive reload with new layout")
	var route: PackedVector2Array = world.dungeon.path(Dungeon.vec(world.floor_data.entry),Dungeon.to_world(Dungeon.room_center(world.floor_data.rooms[1])))
	for point: Vector2 in route:
		if world.dungeon.room_at(point)<0:
			world.player.position = point; break
	world.camera.reset_smoothing(); await capture("corridor-junction")
	for number: int in [2,8,13]:
		world.load_floor(number); freeze()
		world.player.position = Dungeon.to_world(Dungeon.room_center(world.floor_data.rooms[1]))+Vector2(0,-65)
		world.camera.reset_smoothing(); await capture("floor-%02d"%number)
	State.options.reduced_effects = true
	await capture("reduced-effects")
	DisplayServer.window_set_size(Vector2i(960,600))
	await capture("compact")
	var timings: Array[float] = []
	var start: int = Time.get_ticks_usec()
	for i: int in range(120):
		await get_tree().process_frame
		var now: int = Time.get_ticks_usec(); timings.append((now-start)/1000.0); start = now
	timings.sort()
	print("ENVIRONMENT_FRAME_MS median=",timings[60]," p95=",timings[114])

func freeze() -> void:
	world._physics_process(0)
	world.player.qa_controlled = true; world.player.set_physics_process(false); world.set_physics_process(false)
	for enemy: TowerEnemy in world.enemies: enemy.set_physics_process(false)

func find_prop(id: String) -> WorldProp:
	for prop: WorldProp in world.props:
		if prop.record.id==id: return prop
	return null

func capture(label: String) -> void:
	world._physics_process(0)
	main.hud._process(0)
	await get_tree().create_timer(0.35,true).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://outputs/environment-v5/"+label+".png")
	captures.append(label)
	await get_tree().process_frame
