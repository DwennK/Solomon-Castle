class_name GameWorld
extends Node2D

signal interaction(kind: String)
signal died
signal victory
signal floor_changed

const PLAYER_SCENE: PackedScene = preload("res://scenes/player.tscn")
const ENEMY_SCENE: PackedScene = preload("res://scenes/enemy.tscn")
var dungeon: Dungeon
var player: MagePlayer
var camera: Camera2D
var actors: Node2D
var shots: Node2D
var effects: SpellEffects
var combat: CombatSystem
var enemies: Array[TowerEnemy] = []
var props: Array[WorldProp] = []
var zones: Array[Dictionary] = []
var loot: Array = []
var floor_data: Dictionary = {}
var village: bool = false
var safe_position: Vector2 = Vector2.ZERO
var save_timer: float = 0.0
var reveal_timer: float = 0.0
var changing: bool = false
var hint: String = ""
var village_texture: Texture2D
var ended: bool = false
var gate_body: StaticBody2D
var audio_check: float = 0.0
var boss_music_hold: float = 0.0
var impact_trauma: float = 0.0
var visual_clock: float = 0.0

func _ready() -> void:
	combat = CombatSystem.new()
	combat.world = self
	load_floor(int(State.run.get("floor",0)),true)

func clear_world() -> void:
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	enemies.clear()
	props.clear()
	zones.clear()
	loot.clear()

func load_floor(number: int, resume: bool = false) -> void:
	var returning: bool = not State.run.get("return_position",[]).is_empty() and number==int(State.run.get("return_floor",1))
	changing = true
	Sound.stop_world()
	boss_music_hold = 0.0
	clear_world()
	impact_trauma = 0.0
	State.run.floor = number
	village = number == 0
	dungeon = Dungeon.new()
	add_child(dungeon)
	actors = Node2D.new()
	actors.y_sort_enabled = true
	add_child(actors)
	shots = Node2D.new()
	add_child(shots)
	effects = SpellEffects.new()
	effects.world = self
	add_child(effects)
	if village:
		setup_village()
	else:
		var key: String = str(number)
		if not State.run.floors.has(key): State.run.floors[key] = Dungeon.generate(State.run.seed,number,State.run.difficulty)
		floor_data = State.run.floors[key]
		dungeon.build(floor_data)
		dungeon.interior.mount_decorations(actors)
		loot = floor_data.loot
		for record: Dictionary in floor_data.props: add_prop(record)
		add_prop({"kind":"stairs","pos":floor_data.exit,"id":"exit"},"Sommet" if number==13 else "Étage suivant")
		add_prop({"kind":"portal","pos":floor_data.entry,"id":"entry"},"Village")
		setup_gate()
		for record: Dictionary in floor_data.enemies:
			if record.dead: continue
			var enemy: TowerEnemy = ENEMY_SCENE.instantiate() as TowerEnemy
			enemy.setup(self,record)
			actors.add_child(enemy)
			enemies.append(enemy)
	player = PLAYER_SCENE.instantiate() as MagePlayer
	player.world = self
	actors.add_child(player)
	if not village:
		player.visual.environment = dungeon.interior
		for enemy: TowerEnemy in enemies: enemy.visual.environment = dungeon.interior
	player.cooldowns = State.run.get("cooldowns",{}).duplicate()
	player.shield = float(State.run.get("shield",0.0))
	if village:
		player.position = Vector2(768,665)
	elif resume and State.run.position.size()==2:
		player.position = Dungeon.vec(State.run.position)
	elif not State.run.return_position.is_empty() and number == int(State.run.return_floor):
		player.position = Dungeon.vec(State.run.return_position)
		State.run.return_position = []
	else: player.position = Dungeon.vec(floor_data.entry)+Vector2(65,0)
	if not dungeon.walkable(player.position,18): player.position = Dungeon.vec(floor_data.entry)
	safe_position = player.position
	camera = Camera2D.new()
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 7
	player.add_child(camera)
	if village:
		camera.position = Vector2(768,510)-player.position
		camera.position_smoothing_enabled = false
	camera.make_current()
	var atmosphere: WorldAtmosphere = WorldAtmosphere.new()
	atmosphere.world = self
	add_child(atmosphere)
	State.run.deepest = maxi(int(State.run.deepest),number)
	if not resume:
		snapshot()
		State.mark_checkpoint("Retour au village" if village else ("Retour par le portail" if returning else "Arrivée dans l’étage"))
		State.save_game()
	Sound.listener_position = player.global_position
	Sound.set_music("village" if village else "exploration")
	if not resume: Sound.play("portal")
	ended = false
	changing = false
	floor_changed.emit()
	queue_redraw()

func setup_village() -> void:
	village_texture = Catalog.texture("village")
	var grid: Array[String] = []
	for y: int in range(Dungeon.HEIGHT):
		var row: String = ""
		for x: int in range(Dungeon.WIDTH): row += "." if x>=4 and x<=19 and y>=5 and y<=12 else "#"
		grid.append(row)
	floor_data = {"number":0,"grid":grid,"rooms":[[4,5,16,8]],"revealed":[],"entry":[768,665]}
	dungeon.build(floor_data)
	dungeon.visible = false
	add_prop({"id":"merchant","kind":"merchant","pos":[410,405]},"Basile · marchand")
	add_prop({"id":"teacher","kind":"teacher","pos":[1120,405]},"Maître Orme · savoir")
	add_prop({"id":"healer","kind":"healer","pos":[1050,715]},"Ysée · soins")
	add_prop({"id":"tower","kind":"portal","pos":[768,380]},"Entrer dans la tour")
	if State.run.shop.is_empty():
		for i: int in range(6): State.run.shop.append(State.make_item(int(State.run.seed)+i*337+int(State.run.deepest)*7,int(State.run.deepest)))

func add_prop(record: Dictionary, label: String = "") -> void:
	var prop: WorldProp = WorldProp.new()
	prop.record = record
	prop.label = label
	if not village: prop.environment = dungeon.interior
	actors.add_child(prop)
	props.append(prop)

func _physics_process(delta: float) -> void:
	if changing or ended or not is_instance_valid(player): return
	visual_clock += delta
	impact_trauma = maxf(0,impact_trauma-delta*2.5)
	camera.offset = Vector2.ZERO if State.options.reduced_effects else Vector2(sin(visual_clock*47),cos(visual_clock*53))*impact_trauma*3.0
	audio_check -= delta
	boss_music_hold = maxf(0.0,boss_music_hold-delta)
	if audio_check<=0.0 and not village:
		audio_check = 0.4
		for enemy: TowerEnemy in enemies:
			if enemy.boss and not enemy.dead and enemy.active and enemy.position.distance_to(player.position)<850 and (enemy.record.id!="boss" or floor_data.get("gate_open",true)):
				boss_music_hold = 5.0
		Sound.set_music("boss" if boss_music_hold>0.0 else "exploration")
	if village:
		player.position = player.position.clamp(Vector2(285,350),Vector2(1240,790))
		camera.position = Vector2(768,510)-player.position
		hint = "Parlez aux habitants, puis entrez dans la tour."
	else:
		reveal_timer -= delta
		if reveal_timer<=0:
			dungeon.reveal(player.position)
			reveal_timer = 0.25
		var room: int = dungeon.room_at(player.position)
		var safe: bool = true
		for enemy: TowerEnemy in enemies:
			if room>=0 and dungeon.room_at(enemy.position)==room:
				safe = false
				break
		if safe and room>=0: safe_position = player.position
		hint = "Explorez les salles et trouvez l’escalier." if floor_data.get("gate_open",true) else ("Clé trouvée : ouvrez le sceau du gardien." if floor_data.get("has_key",false) else "Trouvez la clé du gardien dans un coffre de cet étage.")
		update_zones(delta)
		collect_loot()
	var nearest_prop: WorldProp = closest_prop()
	if nearest_prop:
		var label: String = {"chest":"Ouvrir le coffre","urn":"Briser l’urne","merchant":"Parler à Basile","teacher":"Étudier avec Orme","healer":"Se reposer gratuitement","tower":"Entrer dans la tour","entry":"Retour au village","exit":"Monter à l’étage suivant","gate":"Ouvrir le sceau du gardien"}.get(nearest_prop.record.id,{"chest":"Ouvrir le coffre","urn":"Briser l’urne"}.get(nearest_prop.record.kind,"Interagir"))
		hint = "[%s]  %s"%[Controls.caption("interact"),label]
	if Input.is_action_just_pressed("interact"): interact()
	if Input.is_action_just_pressed("portal"): use_portal()
	if Input.is_action_just_pressed("cycle_spell"): cycle_spell()
	save_timer += delta
	if save_timer>15:
		snapshot()
		State.save_game()
		save_timer = 0
	queue_redraw()

func closest_prop() -> WorldProp:
	var found: WorldProp
	var best: float = 120
	for prop: WorldProp in props:
		if prop.record.kind=="torch" or prop.record.get("opened",false): continue
		var distance: float = prop.position.distance_to(player.position)
		if distance<best:
			found = prop
			best = distance
	return found

func interact() -> void:
	var prop: WorldProp = closest_prop()
	if not prop: return
	var id: String = prop.record.id
	if village:
		match id:
			"tower":
				if State.run.active.is_empty(): interaction.emit("initial")
				else: enter_tower()
			"healer":
				State.run.hp = State.stats().max_hp
				State.run.mp = State.stats().max_mana
				State.message.emit("Ysée : Revenez avec votre chapeau. Et ce qu’il y a dessous.")
				Sound.play("potion")
			_: interaction.emit(id)
	elif id=="entry": use_portal()
	elif id=="exit": advance()
	elif id=="gate": unlock_gate()
	elif prop.record.kind in ["chest","urn"]: open_prop(prop)

func enter_tower() -> void:
	load_floor(int(State.run.return_floor))

func open_prop(prop: WorldProp) -> void:
	if prop.record.opened: return
	prop.record.opened = true
	if prop.record.id == floor_data.get("key_chest",""):
		floor_data.has_key = true
		State.message.emit("La clé du gardien a été trouvée. Le sceau peut être ouvert.")
	var gold: int = 8+int(State.run.floor)*3
	State.add_gold(gold)
	if prop.record.kind=="chest":
		var item: Dictionary = State.make_item(int(State.run.seed)+int(State.run.floor)*163+int(prop.record.id.hash()),int(State.run.floor))
		loot.append({"kind":"item","item":item,"pos":Dungeon.pair(prop.position+Vector2(35,25))})
		State.run.mp_potions += 1
		prop.refresh_texture()
		Sound.play("chest",prop.global_position)
	else:
		if int(prop.record.id.hash())%2==0: State.run.hp_potions += 1
		Sound.play("urn",prop.global_position)
	prop.queue_redraw()
	if prop.record.id == floor_data.get("key_chest",""): return
	State.message.emit("+%d or%s"%[gold," · potion de mana et équipement" if prop.record.kind=="chest" else ""])

func use_portal() -> void:
	if village:
		if State.run.active.is_empty(): interaction.emit("initial")
		else: enter_tower()
		return
	State.run.return_floor = State.run.floor
	State.run.return_position = Dungeon.pair(player.position)
	snapshot()
	load_floor(0)
	State.message.emit("Le portail garde votre position et l’état de l’étage.")

func advance() -> bool:
	if not floor_data.get("boss","").is_empty() and not floor_data.boss_dead:
		State.message.emit("Le gardien de cet étage scelle l’escalier.")
		return false
	if int(State.run.floor)==13:
		State.win()
		ended = true
		victory.emit()
		return true
	var next: int = int(State.run.floor)+1
	snapshot()
	State.run.return_floor = next
	State.run.return_position = []
	load_floor(next)
	State.message.emit("Étage %d · Un nouveau point de reprise a été créé."%next)
	return true

func snapshot() -> void:
	if not is_instance_valid(player): return
	State.run.position = Dungeon.pair(player.position)
	State.run.cooldowns = player.cooldowns.duplicate()
	State.run.shield = player.shield
	if village: return
	for enemy: TowerEnemy in enemies:
		if not is_instance_valid(enemy) or enemy.dead: continue
		enemy.record.hp = enemy.hp
		enemy.record.pos = Dungeon.pair(enemy.position)
	floor_data.revealed = dungeon.revealed.keys()
	floor_data.loot = loot
	State.run.floors[str(State.run.floor)] = floor_data

func spawn_projectile(pos: Vector2, direction: Vector2, profile: Dictionary, lifetime: float = 2.1) -> void:
	var shot: MagicProjectile = MagicProjectile.new()
	shot.world = self
	shot.position = pos
	shot.direction = direction
	shot.profile = profile
	shot.lifetime = lifetime
	shots.add_child(shot)

func enemy_bolt(pos: Vector2,direction: Vector2,damage: float,speed: float,color: Color) -> void:
	var shot: MagicProjectile = MagicProjectile.new()
	shot.world = self
	shot.position = pos
	shot.direction = direction
	shot.hostile = true
	shot.damage = damage
	shot.speed = speed
	shot.color = color
	shot.lifetime = 4
	shots.add_child(shot)

func enemy_killed(enemy: TowerEnemy) -> void:
	enemies.erase(enemy)
	State.add_xp((19.0+int(State.run.floor)*4.5)*(9 if enemy.boss else 1))
	loot.append({"kind":"gold","amount":6+int(State.run.floor)*2,"pos":Dungeon.pair(enemy.position)})
	if enemy.boss:
		if enemy.record.id == "boss":
			floor_data.boss_dead = true
			State.run.insight = int(State.run.get("insight",1))+1
		if enemy.record.id == "guardian": floor_data.guardian_dead = true
		loot.append({"kind":"item","item":State.make_item(int(State.run.seed)+int(State.run.floor)*97,int(State.run.floor)+4),"pos":Dungeon.pair(enemy.position+Vector2(40,0))})
		State.message.emit("%s vaincu.%s"%[enemy.definition.title," +1 Éclat de savoir." if enemy.record.id=="boss" else ""])
		if int(State.run.floor)==13 and enemy.record.id == "boss":
			State.message.emit("L’Archiviste est tombé. Rejoignez le sceau du sommet pour achever l’ascension.")
	elif int(enemy.record.id.hash())%13==0:
		loot.append({"kind":"health","pos":Dungeon.pair(enemy.position+Vector2(20,15))})
	effect(enemy.position,Color("acbaac"),50 if enemy.boss else 25)
	Sound.play("boss_death" if enemy.boss else "enemy_death",enemy.global_position)

func collect_loot() -> void:
	for i: int in range(loot.size()-1,-1,-1):
		var drop: Dictionary = loot[i]
		if player.position.distance_to(Dungeon.vec(drop.pos))>player.cached_stats.pickup_radius: continue
		if drop.kind=="item":
			if State.run.inventory.size()>=48:
				State.notify_limited("bag_full","Sac plein (48/48) : l’objet reste au sol. Vendez un objet au village.")
				continue
			State.run.inventory.append(drop.item)
			State.message.emit("Objet trouvé : "+drop.item.name)
		elif drop.kind=="gold": State.add_gold(int(drop.amount))
		elif drop.kind=="health": State.run.hp_potions += 1
		loot.remove_at(i)
		Sound.play("item" if drop.kind=="item" else ("potion" if drop.kind=="health" else "loot"))

func hazard(pos: Vector2,radius: float,damage: float,delay: float,color: Color,duration: float = 0.2, damage_type: String = "physical") -> void:
	zones.append({"pos":pos,"radius":radius,"damage":damage,"delay":delay,"life":duration,"color":color,"kind":"hostile","damage_type":damage_type,"tick":0.0})

func friendly_zone(pos: Vector2,kind: String,radius: float,duration: float,power: float) -> void:
	zones.append({"pos":pos,"radius":radius,"damage":power,"delay":0.0,"life":duration,"color":Color("98cf8d") if kind=="acid" else Color("86bfcf"),"kind":kind,"tick":0.0})

func update_zones(delta: float) -> void:
	for i: int in range(zones.size()-1,-1,-1):
		var z: Dictionary = zones[i]
		if z.delay>0:
			z.delay -= delta
			continue
		z.life -= delta
		if z.life<=0:
			zones.remove_at(i)
			continue
		if z.kind=="hostile":
			z.tick -= delta
			if z.tick<=0 and player.position.distance_to(z.pos)<z.radius:
				player.take_damage(z.damage,z.get("damage_type","physical"))
				z.tick = 0.8
		else:
			for enemy: TowerEnemy in enemies.duplicate():
				if enemy.position.distance_to(z.pos)<z.radius and dungeon.visible_line(z.pos,enemy.position):
					if z.kind=="acid": enemy.take_damage(z.damage*delta,Vector2.ZERO,true)
					else: enemy.chill(0.2,0.4)
			if z.kind=="circle":
				if player.position.distance_to(z.pos)<z.radius:
					State.run.hp = minf(State.stats().max_hp,State.run.hp+6*delta)
					State.run.mp = minf(State.stats().max_mana,State.run.mp+18*delta)
				for shot: Node in shots.get_children():
					if shot.hostile and shot.position.distance_to(z.pos)<z.radius: shot.position -= shot.direction*shot.speed*delta*0.6

func player_died() -> void:
	if ended: return
	ended = true
	State.die()
	Sound.stop_world()
	Sound.set_music("")
	Sound.play("death")
	died.emit()

func cycle_spell() -> void:
	var learned: Array[String] = []
	for id: String in Catalog.ids("primary"):
		if State.rank(id)>0: learned.append(id)
	if not State.run.fusion.is_empty(): learned.append(State.run.fusion.id)
	if learned.is_empty(): return
	State.run.active = learned[(learned.find(State.run.active)+1)%learned.size()]
	Sound.stop_channel()
	Sound.play("spell_switch")
	State.message.emit(Catalog.title(State.run.active))

func effect(pos: Vector2,color: Color,radius: float,style: String = "impact") -> void:
	if effects: effects.add_burst(pos,color,radius,style)
	if radius>=100 and is_instance_valid(player) and pos.distance_to(player.position)<650:
		impact_trauma = minf(1.0,impact_trauma+radius/350.0)

func beam(a: Vector2,b: Vector2,color: Color,width: float,life: float = 0.1,cone: bool = false,style: String = "lightning") -> void:
	if effects: effects.add_beam(a,b,color,width,life,cone,style)

func _draw() -> void:
	if village:
		if village_texture: draw_texture_rect(village_texture,Rect2(0,0,1536,1024),false)
		else:
			var texture: Texture2D = Catalog.texture("floor_village")
			if texture: draw_texture_rect(texture,Rect2(250,300,1050,550),true)

func setup_gate() -> void:
	gate_body = null
	if floor_data.get("gate_open",true): return
	var gate_cells: Array = floor_data.get("gate_cells",[])
	if gate_cells.is_empty(): return
	gate_body = StaticBody2D.new()
	gate_body.collision_layer = 1
	add_child(gate_body)
	for cell: Array in gate_cells:
		var c: Vector2i = Vector2i(cell[0],cell[1])
		dungeon.cells.erase(c)
		dungeon.astar.set_point_solid(c,true)
		var shape: CollisionShape2D = CollisionShape2D.new()
		var rectangle: RectangleShape2D = RectangleShape2D.new()
		rectangle.size = Vector2.ONE*Dungeon.CELL
		shape.shape = rectangle
		shape.position = Dungeon.to_world(c)
		gate_body.add_child(shape)
	var mid: Array = gate_cells[1]
	add_prop({"kind":"portal","id":"gate","pos":Dungeon.pair(Dungeon.to_world(Vector2i(mid[0],mid[1]))-Vector2(45,0))},"Sceau du gardien")
	dungeon.queue_redraw()

func unlock_gate() -> bool:
	if floor_data.get("gate_open",true): return true
	if not floor_data.get("has_key",false):
		State.message.emit("Il vous faut la clé cachée dans un coffre de cet étage.")
		return false
	if not floor_data.get("guardian_dead",true):
		State.message.emit("Le Gardien du brasier protège encore le sceau.")
		return false
	floor_data.gate_open = true
	for cell: Array in floor_data.gate_cells:
		var c: Vector2i = Vector2i(cell[0],cell[1])
		dungeon.cells[c] = true
		dungeon.astar.set_point_solid(c,false)
	if is_instance_valid(gate_body): gate_body.queue_free()
	for prop: WorldProp in props:
		if prop.record.id == "gate": prop.record.opened=true;prop.hide()
	dungeon.queue_redraw()
	State.message.emit("Le sceau se dissipe. Le gardien vous attend.")
	Sound.play("ritual")
	return true
