extends Node

var main: Node
var errors: Array[String] = []
var milestones: Array[String] = []
var choices: int = 0
var running: bool = false
var captures: bool = false
var started: int = 0

func start(owner_main: Node) -> void:
	DirAccess.make_dir_recursive_absolute("res://outputs/screenshots")
	main = owner_main
	captures = DisplayServer.get_name() != "headless"
	started = Time.get_ticks_msec()
	running = true
	await screenshot("01-menu")
	State.fresh(197903)
	State.learn("missile")
	main.start_game()
	await frames(4)
	await screenshot("02-village")
	# Exercise real shop, equipment, inventory, skill and save flows.
	main.world.player.position=Vector2(410,430)
	main.world.interact()
	await frames(3)
	check(main.modal_kind=="merchant","Village merchant interaction")
	await screenshot("03-merchant")
	var item: Dictionary = State.run.shop[0]
	State.run.gold=1000
	check(State.buy(item.uid),"Shop purchase")
	check(State.equip(item.uid),"Equip purchased item")
	main.show_inventory()
	await frames(3)
	await screenshot("04-inventory")
	main.close_modal()
	main.show_skills()
	await frames(3)
	await screenshot("05-grimoire")
	main.close_modal()
	main.world.snapshot()
	check(State.save_game(),"Save village")
	var uid: String = item.uid
	check(State.load_game() and not State.find_item(uid).is_empty(),"Restore equipment from disk")
	main.world.load_floor(0,true)
	# Explicit QA assistance: pre-trained build, unlimited recovery, accelerated time.
	for id: String in Catalog.ids("primary"): State.run.skills[id]=12
	for id: String in ["power","economy","regen","life","mana"]: State.run.skills[id]=6
	State.run.skills.multishot=3
	State.run.skills.explode=2
	State.run.skills.chain=3
	State.learn("shield")
	State.learn("teleport")
	main.world.player.refresh_stats()
	Engine.time_scale=5.0
	for floor_number: int in range(1,14):
		if floor_number==1: main.world.enter_tower()
		var world: GameWorld = main.world
		check(int(State.run.floor)==floor_number,"Reached floor %d"%floor_number)
		var forms: Array[String] = ["missile","fire","ice","lightning","fire_missile","frost_missile","flame_lash","steam","ball_lightning","blizzard"]
		var spell: String = forms[(floor_number-1)%forms.size()]
		if Catalog.definition(spell).kind=="fusion": State.learn(spell)
		State.run.active=spell
		world.player.qa_controlled=true
		world.player.refresh_stats()
		for room_index: int in range(world.floor_data.rooms.size()):
			if room_index==world.floor_data.rooms.size()-1 and not world.floor_data.get("gate_open",true):
				check(world.unlock_gate(),"Boss seal opens only after key / guardian")
				await frames(2)
			var room: Array = world.floor_data.rooms[room_index]
			var center: Vector2 = Dungeon.to_world(Dungeon.room_center(room))
			await navigate(center)
			await fight_room(room_index)
			for prop: WorldProp in world.props:
				if prop.record.kind=="chest" and world.dungeon.room_at(prop.position)==room_index and not prop.record.opened:
					await navigate(prop.position+Vector2(0,40))
					world.interact()
					await frames(3)
			if room_index==1 and floor_number in [1,4,8,13]:
				await screenshot("floor-%02d"%floor_number)
		if floor_number==2:
			var before: Dictionary = world.floor_data.duplicate(true)
			var pos: Vector2 = world.player.position
			var living_ids: Array = world.enemies.map(func(e: TowerEnemy)->String:return e.record.id)
			world.player.qa_fire=false
			world.player.qa_direction=Vector2.ZERO
			await frames(2)
			world.use_portal()
			await frames(160)
			check(world.village,"Portal reaches village")
			world.enter_tower()
			check(world.player.position.distance_to(pos)<2,"Portal restores exact position")
			check(world.floor_data.props==before.props,"Portal does not regenerate chest state")
			check(world.enemies.map(func(e: TowerEnemy)->String:return e.record.id)==living_ids,"Portal preserves surviving enemies and dormant sentries without respawning kills")
		await navigate(Dungeon.vec(world.floor_data.exit))
		world.player.qa_fire=false
		world.player.qa_direction=Vector2.ZERO
		while not State.run.pending.is_empty(): await frames(1)
		check(world.advance(),"Floor %d exit works"%floor_number)
		milestones.append("floor_%d_complete"%floor_number)
		print("QA floor ",floor_number," complete; levels ",State.run.level,"; remaining enemies ",world.enemies.size())
		await frames(4)
	check(State.run.victory and main.modal_kind=="victory","Real final boss and victory flow")
	await screenshot("06-victory")
	State.next_difficulty()
	main.close_modal()
	main.world.load_floor(0)
	check(State.run.difficulty==1,"Next difficulty entered")
	main.world.enter_tower()
	await frames(4)
	check(State.run.floor==1 and main.world.enemies.size()>0,"New campaign populated")
	await screenshot("07-next-difficulty")
	main.world.snapshot()
	check(State.save_game(),"Final QA save")
	Engine.time_scale=1.0
	running=false
	var report: Dictionary = {"errors":errors,"milestones":milestones,"level_choices":choices,"duration_seconds":(Time.get_ticks_msec()-started)/1000.0,"native_rendering":captures,"assistance":"QA ranks, invulnerability, mana recovery, 5x simulation, navigation via actual AStar and CharacterBody2D; actual spell hits and boss deaths"}
	var file: FileAccess = FileAccess.open("res://outputs/playthrough-native.json" if captures else "res://outputs/playthrough-headless.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"));file.close()
	print("QA_RESULT ",JSON.stringify(report))
	Sound.stop_all()
	await get_tree().create_timer(0.2,true).timeout
	get_tree().quit(0 if errors.is_empty() else 1)

func _process(_delta: float) -> void:
	if not running or not is_instance_valid(main): return
	if main.modal_kind=="level":
		var options: Array = State.offers()
		if not options.is_empty():
			State.choose(options[0]);choices+=1;main.close_modal()
	if is_instance_valid(main.world) and is_instance_valid(main.world.player):
		main.world.player.invulnerable=1.0
		State.run.mp=State.stats().max_mana
		main.world.player.cached_stats.speed=600.0

func frames(count: int) -> void:
	for i: int in range(count): await get_tree().physics_frame

func navigate(destination: Vector2) -> void:
	var world: GameWorld = main.world
	var player: MagePlayer = world.player
	player.qa_controlled=true
	var points: PackedVector2Array = world.dungeon.path(player.position,destination)
	check(not points.is_empty(),"QA path to "+str(destination))
	for i: int in range(1,points.size()):
		var deadline: int = 180
		while player.position.distance_to(points[i])>30 and deadline>0:
			player.qa_direction=player.position.direction_to(points[i])
			var enemy: TowerEnemy = world.combat.nearest(player.position,450)
			player.qa_fire=enemy!=null
			if enemy: player.aim=player.position.direction_to(enemy.position)
			await frames(1)
			deadline-=1
		if deadline==0:
			check(false,"Navigation stuck at "+str(player.position)+" toward "+str(points[i]))
			break
	player.qa_direction=Vector2.ZERO

func fight_room(room_index: int) -> void:
	var world: GameWorld = main.world
	var player: MagePlayer = world.player
	var limit: int = 1500
	while limit>0:
		var target: TowerEnemy
		for enemy: TowerEnemy in world.enemies:
			if enemy.is_targetable() and world.dungeon.room_at(enemy.position)==room_index:
				target=enemy
				break
		if not target: break
		player.aim=player.position.direction_to(target.position)
		var distance: float = player.position.distance_to(target.position)
		player.qa_direction=player.aim if distance>235 else Vector2.ZERO
		player.qa_fire=true
		if limit==1490 and room_index>0 and int(State.run.floor) in [1,4,13]: await screenshot("combat-%02d"%int(State.run.floor))
		await frames(1)
		limit-=1
	if limit == 0:
		for enemy: TowerEnemy in world.enemies:
			if enemy.is_targetable() and world.dungeon.room_at(enemy.position)==room_index: print("STUCK_ENEMY ",enemy.record.kind," hp=",enemy.hp," enemy=",enemy.position," player=",player.position," spell=",State.run.active," line=",world.dungeon.visible_line(player.position,enemy.position))
	check(limit>0,"Room %d floor %d cleared with spells"%[room_index,State.run.floor])
	player.qa_fire=false
	player.qa_direction=Vector2.ZERO

func check(condition: bool,text: String) -> void:
	if not condition:
		errors.append(text)
		push_error("QA: "+text)

func screenshot(name: String) -> void:
	if not captures: return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://outputs/screenshots")
	get_viewport().get_texture().get_image().save_png("res://outputs/screenshots/"+name+".png")
