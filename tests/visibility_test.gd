extends Node

var checks: int = 0
var failures: Array[String] = []
var world: GameWorld

func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label);push_error(label)

func _ready() -> void:
	if not State.qa: get_tree().quit(1);return
	State.save_path="user://qa_visibility.json"
	call_deferred("run_all")

func fixture() -> Dictionary:
	var data: Dictionary = Dungeon.generate(829,1)
	var grid: Array[String] = []
	for y: int in range(Dungeon.HEIGHT):
		var row: String = ""
		for x: int in range(Dungeon.WIDTH):
			var open: bool = Rect2i(4,8,6,7).has_point(Vector2i(x,y)) or Rect2i(18,8,8,7).has_point(Vector2i(x,y)) or Rect2i(10,10,8,3).has_point(Vector2i(x,y))
			row += "." if open else "#"
		grid.append(row)
	data.grid=grid;data.rooms=[[4,8,6,7],[18,8,8,7]]
	data.entry=Dungeon.pair(Dungeon.to_world(Vector2i(16,11)))
	data.exit=Dungeon.pair(Dungeon.to_world(Vector2i(23,11)))
	data.enemies=[{"id":"hidden","kind":"skeleton","pos":Dungeon.pair(Dungeon.to_world(Vector2i(18,10))),"hp":-1.0,"dead":false}]
	data.props=[{"id":"hidden_chest","kind":"chest","pos":Dungeon.pair(Dungeon.to_world(Vector2i(20,10))),"opened":false},{"id":"torch_1","kind":"torch","pos":Dungeon.pair(Dungeon.to_world(Vector2i(22,9))),"opened":false}]
	data.encounters=[];data.loot=[];data.revealed=[]
	return data

func run_all() -> void:
	var d: Dungeon = Dungeon.new()
	var data: Dictionary = fixture()
	data.number=0
	d.build(data)
	d.reveal(Dungeon.to_world(Vector2i(16,11)))
	check(d.revealed.has("12,11"),"Straight corridor is visible")
	check(not d.revealed.has("18,11") and d.visited_rooms.is_empty(),"Open doorway does not discover an unentered room")
	d.reveal(Dungeon.to_world(Vector2i(18,11)))
	check(d.visited_rooms.has(1) and d.revealed.has("20,11"),"Crossing the threshold uncovers the entered room")
	check(not d.visited_rooms.has(0) and not d.revealed.has("9,11"),"Seeing through a corridor never enters the room at its far end")
	# In an already entered room, a pillar still blocks minimap discovery.
	d.revealed.clear();d.cells.erase(Vector2i(21,11))
	d.reveal(Dungeon.to_world(Vector2i(20,11)))
	check(not d.revealed.has("22,11"),"Minimap respects a pillar inside an entered room")
	check(d.revealed.has("20,12"),"Adjacent unobstructed tiles remain discoverable")
	d.cells.erase(Vector2i(21,10));d.cells.erase(Vector2i(20,9))
	check(not d.discovery_line(Dungeon.to_world(Vector2i(20,10)),Dungeon.to_world(Vector2i(21,9))),"Diagonal corner never leaks through two touching walls")
	check(not d.discovery_line(Dungeon.to_world(Vector2i(19,11)),Vector2(21*64+0.01,10*64+0.01)),"Subpixel ray cannot skip a blocking wall")
	for y: int in range(10,13): d.cells.erase(Vector2i(14,y))
	d.revealed.clear();d.reveal(Dungeon.to_world(Vector2i(16,11)))
	check(not d.revealed.has("12,11"),"Closed gate blocks corridor discovery")
	for y: int in range(10,13): d.cells[Vector2i(14,y)]=true
	d.reveal(Dungeon.to_world(Vector2i(16,11)))
	check(d.revealed.has("12,11"),"Opening the gate restores sight")
	# A bend is not discovered until the observer can see around it.
	d.cells.clear();d.visited_rooms.clear();d.data.rooms=[];d.revealed.clear()
	for x: int in range(10,17): d.cells[Vector2i(x,11)]=true
	for y: int in range(11,17): d.cells[Vector2i(16,y)]=true
	d.reveal(Dungeon.to_world(Vector2i(12,11)))
	check(not d.revealed.has("16,15"),"Corridor bend hides its far leg")
	d.reveal(Dungeon.to_world(Vector2i(16,12)))
	check(d.revealed.has("16,15"),"Rounding the bend discovers its far leg")
	d.free()
	State.fresh(829);State.learn("missile");State.run.floor=1
	State.run.floors["1"]=fixture();State.run.position=State.run.floors["1"].entry
	world=load("res://scenes/world.tscn").instantiate();add_child(world);freeze()
	var fog: DungeonFog = get_fog()
	fog.refresh()
	check(not fog.clear_cells.has(Vector2i(20,11)),"Fog covers unexplored room floor")
	check(fog.clear_cells.has(Vector2i(16,11)),"Fog leaves corridor readable")
	check(world.enemies[0].modulate.a==0,"Tall enemy sprite cannot spill from a black room")
	var hidden: WorldProp = WorldProp.new()
	hidden.record={"id":"hidden_hint","kind":"blood_font","pos":[18*64+5,11*64+32],"opened":false}
	world.actors.add_child(hidden);world.props.append(hidden)
	world.player.position=Vector2(18*64-5,11*64+32)
	check(world.closest_prop()!=hidden,"Unentered room cannot leak its interaction hint across the threshold")
	world.props.erase(hidden);hidden.queue_free()
	world.player.position=Dungeon.vec(world.floor_data.entry)
	if DisplayServer.get_name()!="headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(Vector2i(1440,900))
		var layer: CanvasLayer = CanvasLayer.new();add_child(layer)
		var hud: GameHUD = GameHUD.new();hud.world=world;layer.add_child(hud)
		await capture("corridor-1440x900")
		DisplayServer.window_set_size(Vector2i(960,600))
		await capture("corridor-960x600")
		DisplayServer.window_set_size(Vector2i(1440,900))
	world.player.position=Vector2(18*64+1,11*64+32)
	world.reveal_timer=1;world._physics_process(0);fog.refresh()
	check(world.dungeon.visited_rooms.has(1),"Room entry updates immediately even between discovery ticks")
	check(fog.clear_cells.has(Vector2i(20,11)) and world.enemies[0].modulate.a==1,"Entry reveals room and enemy together")
	if DisplayServer.get_name()!="headless": await capture("room-entered-1440x900")
	world.player.position=Dungeon.to_world(Vector2i(16,11));world._physics_process(0);fog.refresh()
	check(fog.clear_cells.has(Vector2i(20,11)),"Visited room stays readable after leaving it")
	world.snapshot();State.mark_checkpoint()
	check(State.save_game() and State.load_game(),"Exploration roundtrips through actual save file")
	world.load_floor(1,true);freeze()
	check(world.dungeon.visited_rooms.has(1) and world.dungeon.revealed.has("20,11"),"Visited rooms and minimap survive save/reload")
	check(not world.dungeon.visited_rooms.has(0),"Reload never reveals another room")
	var grid_before: Array = world.floor_data.grid.duplicate()
	world.floor_data.erase("visibility_version")
	world.floor_data.revealed=["5,11","20,11"]
	world.load_floor(1,true);freeze()
	check(not world.dungeon.revealed.has("5,11") and not world.dungeon.revealed.has("20,11"),"Legacy through-wall discovery is discarded")
	check(world.floor_data.grid==grid_before and world.enemies.size()==1,"Legacy exploration migration preserves floor and enemies")
	# Exercise the actual generated gate, including its persistent hidden state.
	world.load_floor(4);freeze()
	var gate: WorldProp
	for prop: WorldProp in world.props:
		if prop.record.id=="gate": gate=prop
	var gate_cell: Vector2i = Vector2i((gate.position/Dungeon.CELL).floor())
	for side: Vector2i in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
		var approach: Vector2 = Dungeon.to_world(gate_cell+side)
		if world.dungeon.walkable(approach) and world.dungeon.room_at(approach)!=world.floor_data.rooms.size()-1:
			world.player.position=approach;break
	world.dungeon.reveal(world.player.position);get_fog().refresh()
	check(gate.modulate.a==1 and world.closest_prop()==gate,"Approaching a closed seal keeps it visible and usable")
	world.floor_data.has_key=true;world.floor_data.guardian_dead=true;world.unlock_gate()
	world.dungeon.reveal(world.player.position);get_fog().refresh()
	check(not gate.visible,"Fog never restores a seal hidden by unlocking")
	if DisplayServer.get_name()!="headless":
		world.load_floor(1);freeze()
		State.run.floors.erase("1")
		world.load_floor(1);freeze()
		await capture("generated-entry-1440x900")
		var route: PackedVector2Array = world.dungeon.path(world.player.position,Dungeon.to_world(Dungeon.room_center(world.floor_data.rooms[1])))
		for point: Vector2 in route:
			world.player.position=point;world.dungeon.reveal(point)
			if world.dungeon.room_at(point)<0: break
		await capture("generated-corridor-1440x900")
	var report: Dictionary = {"checks":checks,"failures":failures,"engine":Engine.get_version_info().string,"renderer":DisplayServer.get_name()}
	DirAccess.make_dir_recursive_absolute("res://outputs/visibility")
	var file: FileAccess = FileAccess.open("res://outputs/visibility/report.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"));file.close()
	print("VISIBILITY_QA ",JSON.stringify(report))
	world.queue_free();Sound.stop_all();get_tree().quit(0 if failures.is_empty() else 1)

func get_fog() -> DungeonFog:
	for child: Node in world.get_children():
		if child is DungeonFog: return child
	return null

func freeze() -> void:
	world.set_physics_process(false);world.player.qa_controlled=true;world.player.set_physics_process(false)
	for enemy: TowerEnemy in world.enemies: enemy.set_physics_process(false)

func capture(label: String) -> void:
	DirAccess.make_dir_recursive_absolute("res://outputs/visibility")
	world.dungeon.reveal(world.player.position)
	world.camera.reset_smoothing()
	for i: int in range(12): await get_tree().process_frame
	RenderingServer.force_draw()
	get_viewport().get_texture().get_image().save_png("res://outputs/visibility/"+label+".png")
