extends Node

var main: Node
var viewport: SubViewport
var failures: Array[String] = []
var checks: int = 0
var captures: Dictionary = {}

func _ready() -> void:
	if not State.qa:
		get_tree().quit(1)
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	State.save_path = "user://qa_hud_v2.json"
	call_deferred("run_all")

func run_all() -> void:
	DirAccess.make_dir_recursive_absolute("res://outputs/hud-v2")
	viewport = SubViewport.new()
	viewport.size = Vector2i(1440,900)
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	main = load("res://scenes/main.tscn").instantiate()
	viewport.add_child(main)
	State.fresh(197903)
	main.start_game()
	freeze_world()
	await settle()
	check(main.hud.primary.disabled,"Unlearned primary is explicit and disabled")
	check(main.hud.spell_hint.text=="Parlez à Orme","First-magic guidance is preserved")
	await capture("01-village")
	State.learn("fire"); State.learn("missile"); State.learn("shield"); State.learn("teleport")
	main.world.enter_tower()
	freeze_world()
	State.run.hp = 66; State.run.mp = 42; State.run.xp = 28
	main.world.player.cooldowns.shield = 12
	for resolution: Vector2i in [Vector2i(1440,900),Vector2i(960,600),Vector2i(1920,1080)]:
		viewport.size = resolution
		await settle()
		check_layout()
		await capture("combat-%dx%d" % [resolution.x,resolution.y])
	viewport.size = Vector2i(1440,900)
	await settle()
	check(main.hud.rituals[0].cooldown_label.text=="12s","Cooldown uses explicit seconds")
	check(main.hud.rituals[2].disabled and main.hud.rituals[2].caption_label.text=="NIV. 20","Third ritual is locked before level 20")
	check("28 / 53 XP" in main.hud.xp_label.text,"XP has readable current and target values")
	var previous_hp: float = State.run.hp
	var potions: int = State.run.hp_potions
	await click(main.hud.hp_potion)
	check(State.run.hp>previous_hp and State.run.hp_potions==potions-1,"Potion icon click heals and consumes exactly one")
	await click(main.hud.primary)
	check(State.run.active=="missile","Primary slot click cycles magic")
	main.world.player.cooldowns.shield = 0
	State.run.mp = 100
	await settle()
	await click(main.hud.rituals[0])
	check(main.world.player.shield>0 and main.world.player.cooldowns.shield>0 and State.run.mp<100,"Ready ritual click casts, spends mana and starts cooldown")
	main.world.player.cooldowns.clear()
	State.run.hp = 18; State.run.mp = 0; State.run.hp_potions = 0; State.run.mp_potions = 0
	await settle()
	check(main.hud.hp.critical and main.hud.hp.title_label.text=="VIE FAIBLE","Low health has a persistent textual warning")
	check(main.hud.hp_potion.disabled and main.hud.mp_potion.disabled,"Empty potion reserves are disabled")
	check(main.hud.rituals[0].disabled and main.hud.rituals[0].caption_label.text=="MANA","Mana shortage is visible without relying on color")
	await capture("02-low-resources")
	await click(main.hud.hp_potion)
	check(State.run.hp==18 and State.run.hp_potions==0,"Disabled potion does not consume or heal")
	State.run.skills.economy = 2
	var item: Dictionary = State.make_item(81,3)
	item.bonuses = {"cost_reduction":0.1}
	State.run.inventory.append(item)
	State.equip(item.uid)
	main.world.player.refresh_stats()
	var profile: Dictionary = main.world.combat.secondary_profile("shield")
	var cost: float = State.mana_cost(profile.mana,profile.offensive)
	State.run.mp = cost
	await settle()
	check(not main.hud.rituals[0].disabled,"Ritual re-enables at its actual discounted mana cost")
	await click(main.hud.rituals[0])
	check(State.run.mp<0.001,"Displayed availability matches combat mana accounting: mana=%f, cost=%f, cooldown=%s" % [State.run.mp,cost,main.world.player.cooldowns])
	State.run.level = 20; State.learn("freeze"); State.run.mp = 100
	main.world.player.cooldowns.clear()
	await settle()
	check(main.hud.rituals[2].spell_id=="freeze" and not main.hud.rituals[2].disabled,"Third ritual becomes usable at level 20")
	Controls.setup({"hp_potion":KEY_H,"cycle_spell":KEY_BACKSPACE},{"secondary_0":JOY_BUTTON_Y})
	await settle()
	check(main.hud.hp_potion.key_label.text=="H" and main.hud.primary.key_label.text=="Backspace","Visible keycaps follow keyboard remapping")
	Controls.using_pad = true
	await settle()
	check(main.hud.rituals[0].key_label.text=="Y" and main.hud.mp_potion.key_label.text=="→","Visible keycaps follow gamepad remapping")
	check_layout()
	await capture("03-gamepad-unlocked")
	Controls.using_pad = false
	Controls.setup(State.options.bindings,State.options.pad_bindings)
	for action: String in ["inventory","skills","map","pause"]:
		await click(main.hud.navigation[action][0])
		check(main.modal_kind==action and get_tree().paused,"Navigation opens and pauses: "+action)
		main.close_modal()
		await settle()
	await click(main.hud.navigation.portal[0])
	check(main.world.village,"Portal button returns to village")
	freeze_world()
	await settle()
	check(main.hud.ritual_status.text=="Au village" and main.hud.rituals[0].disabled,"Village explains unavailable rituals")
	State.options.reduced_effects = true
	main.hud.rituals[0].ready_flash = 1
	await settle()
	check(main.hud.hp.liquid.material.get_shader_parameter("motion")==0.0 and main.hud.rituals[0].ready_flash==0,"Reduced effects disables liquid motion and ready flash")
	var report: Dictionary = {"checks":checks,"failures":failures,"captures":captures,"renderer":"Godot native SubViewport, original pixel dimensions"}
	var file: FileAccess = FileAccess.open("res://outputs/hud-v2/report.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"));file.close()
	print("HUD_V2 ",JSON.stringify(report))
	Sound.stop_all()
	get_tree().quit(0 if failures.is_empty() else 1)

func freeze_world() -> void:
	main.world._physics_process(0)
	main.world.player.qa_controlled = true
	main.world.player.set_physics_process(false)
	main.world.set_physics_process(false)
	for enemy: Node in main.world.enemies: enemy.set_physics_process(false)

func check_layout() -> void:
	var controls: Array[Control] = [main.hud.primary,main.hud.hp_potion,main.hud.mp_potion,main.hud.hp,main.hud.mp]
	controls.append_array(main.hud.rituals)
	for entry: Array in main.hud.navigation.values(): controls.append(entry[0])
	var bounds: Rect2 = Rect2(Vector2.ZERO,Vector2(viewport.size))
	for i: int in range(controls.size()):
		check(bounds.encloses(controls[i].get_global_rect()),"Control inside %s: %s" % [viewport.size,controls[i].name])
		for j: int in range(i+1,controls.size()):
			check(not controls[i].get_global_rect().intersects(controls[j].get_global_rect()),"No overlap: %s / %s" % [controls[i].name,controls[j].name])
	check(main.hud.hint_panel.get_global_rect().end.y < main.hud.dock.get_global_rect().position.y,"Context prompt is above the console")

func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok: failures.append(description);push_error(description)

func settle() -> void:
	await get_tree().create_timer(0.25,true).timeout

func capture(title: String) -> void:
	await settle()
	await RenderingServer.frame_post_draw
	var rendered: Image = viewport.get_texture().get_image()
	rendered.save_png("res://outputs/hud-v2/"+title+".png")
	captures[title] = [rendered.get_width(),rendered.get_height()]

func click(control: Control) -> void:
	var point: Vector2 = control.get_global_rect().get_center()
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = point; motion.global_position = point
	viewport.push_input(motion,true)
	await get_tree().process_frame
	for down: bool in [true,false]:
		var event: InputEventMouseButton = InputEventMouseButton.new()
		event.position = point; event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT; event.pressed = down
		viewport.push_input(event,true)
		await get_tree().process_frame
	await settle()
