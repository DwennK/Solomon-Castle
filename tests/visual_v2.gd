extends Node

var main: Node
var world: GameWorld
var captures: Array[String] = []
var errors: Array[String] = []

func _ready() -> void:
	if not State.qa:
		get_tree().quit(1)
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	DisplayServer.window_set_size(Vector2i(1440,900))
	State.options.reduced_effects = false
	State.fresh(197903)
	for id: String in ["missile","fire","ice","lightning","shield","circle","acid","freeze","ring_fire","teleport","undead"]: State.run.skills[id] = 3
	State.run.level = 40
	State.run.active = "fire"
	State.run.secondary = ["shield","circle","acid"]
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	main.start_game()
	world = main.world
	world.player.qa_controlled = true
	await frames(12)
	await capture("01-village")
	world.enter_tower()
	world.player.qa_controlled = true
	world.player.set_physics_process(false)
	world.player.position = Dungeon.to_world(Dungeon.room_center(world.floor_data.rooms[1]))
	world.camera.reset_smoothing()
	for enemy: TowerEnemy in world.enemies: enemy.set_physics_process(false)
	await frames(12)
	await capture("02-dungeon")
	var origin: Vector2 = world.player.position
	for id: String in CombatSystem.COLORS:
		clear_effects()
		State.run.active = id
		State.run.fusion = {"id":id,"snapshot":{"fire":3,"missile":3,"ice":3,"lightning":3}} if Catalog.definition(id).kind=="fusion" else {}
		world.player.aim = Vector2.RIGHT
		world.player.visual.attack = 1.0
		var profile: Dictionary = world.combat.profile(id)
		if profile.channel:
			world.beam(origin,origin+Vector2(320,-60),profile.color,13 if id in ["ice","steam"] else 4,2.0,id in ["ice","steam"],id)
		else:
			for i: int in range(3): world.spawn_projectile(origin+Vector2(0,(i-1)*30),Vector2(1,-0.15).normalized(),profile)
		await frames(15)
		await capture("spell-"+id)
		check(not world.effects.effects.is_empty() or world.shots.get_child_count()>0,"Rendered effect for "+id)
	clear_effects()
	State.run.fusion = {}
	State.run.active = "ice"
	world.player.shield = 100
	world.friendly_zone(origin,"circle",140,20,1)
	world.friendly_zone(origin+Vector2(210,25),"acid",100,20,1)
	world.hazard(origin+Vector2(-180,-90),95,1,10,Color("ff8d5c"))
	for enemy: TowerEnemy in world.enemies:
		if enemy.position.distance_to(origin)<400:
			enemy.visual.frozen = true
	await frames(20)
	await capture("03-rituals-and-shield")
	world.effect(origin,Color("ff984f"),250)
	await frames(12)
	await capture("04-fire-impact")
	clear_effects()
	world.zones.clear()
	world.player.shield = 0
	# Death animation must finish and must not keep a dead enemy targetable.
	var victim: TowerEnemy = world.enemies[0]
	var old_count: int = world.enemies.size()
	victim.take_damage(100000)
	if not main.modal_kind.is_empty(): main.close_modal()
	check(world.enemies.size()==old_count-1,"Dead enemy removed immediately from gameplay list")
	check(is_instance_valid(victim),"Death visual remains briefly")
	await frames(50)
	check(not is_instance_valid(victim),"Death visual is freed after dissolve")
	# Native bestiary staged in a real room; all actor materials and complete silhouettes.
	for enemy: TowerEnemy in world.enemies: enemy.hide()
	var kinds: Array[String] = ["skeleton","archer","zombie","ghoul","sorcerer","knight","imp","ghost","king","plague","demon","lich"]
	for i: int in range(kinds.size()):
		var actor: ActorVisual = ActorVisual.new()
		actor.texture = Catalog.texture(kinds[i]); actor.kind = kinds[i]
		actor.target_height = 140 if i>=8 else 112
		actor.position = origin+Vector2((i%4-1.5)*150,(int(i/4)-1)*150-40)
		actor.moving = i%2==0
		world.actors.add_child(actor)
	world.player.position = origin+Vector2(0,220)
	world.camera.position = Vector2(0,-220)
	world.camera.reset_smoothing()
	await frames(20)
	await capture("05-bestiary")
	State.options.reduced_effects = true
	world.effect(origin,Color("b4eaff"),220)
	await frames(15)
	await capture("06-reduced-effects")
	State.options.reduced_effects = false
	var file: FileAccess = FileAccess.open("res://outputs/visual-v2/report.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"errors":errors,"captures":captures,"viewport":"1440x900 native renderer","note":"Staged visual coverage of all ten primary/fusion spells, zones, shield, death lifecycle, and twelve enemy designs. Separate playthrough checks gameplay."},"\t"))
	print("VISUAL_V2 ",JSON.stringify({"errors":errors,"captures":captures.size()}))
	Sound.stop_all()
	get_tree().quit(0 if errors.is_empty() else 1)

func clear_effects() -> void:
	world.effects.effects.clear()
	for shot: Node in world.shots.get_children():
		world.shots.remove_child(shot)
		shot.queue_free()

func frames(count: int) -> void:
	for i: int in range(count): await get_tree().physics_frame

func capture(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://outputs/visual-v2/"+name+".png")
	captures.append(name)

func check(ok: bool,label: String) -> void:
	if not ok: errors.append(label)
