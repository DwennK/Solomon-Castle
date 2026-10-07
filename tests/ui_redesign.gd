extends Node

var main: Node
var errors: Array[String] = []
var captures: Array[String] = []
var rendered_sizes: Dictionary = {}

func _ready() -> void:
	if not State.qa:
		push_error("UI verification requires --qa to isolate save data")
		get_tree().quit(1)
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	DirAccess.make_dir_recursive_absolute("res://outputs/ui-redesign")
	DisplayServer.window_set_size(Vector2i(1440,900))
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await settle()
	await capture("01-menu")
	main.show_new(); await capture("02-new-game")
	State.fresh(197903)
	main.start_game()
	main.world.player.qa_controlled = true
	main.show_initial(); await capture("03-first-magic")
	var focused: Control = get_viewport().gui_get_focus_owner()
	check(focused is Button and focused.text=="Choisir", "Initial magic has keyboard focus on a choice")
	var accept: InputEventKey = InputEventKey.new()
	accept.keycode=KEY_ENTER;accept.physical_keycode=KEY_ENTER;accept.pressed=true
	Input.parse_input_event(accept)
	await get_tree().process_frame
	accept = InputEventKey.new();accept.keycode=KEY_ENTER;accept.physical_keycode=KEY_ENTER;accept.pressed=false
	Input.parse_input_event(accept)
	await settle()
	check(State.run.active=="fire" and main.modal_kind.is_empty(),"Keyboard accepts first magic and resumes gameplay")
	State.learn("fire");State.learn("shield");State.learn("teleport")
	main.close_modal()
	main.world.enter_tower()
	main.world.player.qa_controlled = true
	main.world.player.set_physics_process(false)
	for enemy: Node in main.world.enemies: enemy.set_physics_process(false)
	State.run.hp=66;State.run.mp=42
	main.world.player.cooldowns.shield=12
	await capture("04-hud")
	check(absf(main.hud.hp.target-0.6)<0.01,"Health orb follows real health")
	check(absf(main.hud.mp.target-0.42)<0.01,"Mana orb follows real mana")
	check(main.hud.rituals[0].cooldown_label.text=="12s","Cooldown displayed")
	check(main.hud.rituals[2].caption_label.text=="NIV. 20","Third ritual unlock shown")
	var before: float = State.run.hp
	await click(main.hud.hp_potion)
	check(State.run.hp>before and State.run.hp_potions==2,"HUD potion consumes a potion and heals")
	State.learn("missile")
	await click(main.hud.primary)
	check(State.run.active=="missile","HUD primary switches magic")
	Controls.setup({"hp_potion":KEY_H})
	await settle()
	check(main.hud.hp_potion.text.begins_with("H"),"HUD follows custom bindings")
	Controls.setup(State.options.bindings,State.options.pad_bindings)
	for i: int in range(3): State.run.inventory.append(State.make_item(81+i,3))
	State.equip(State.run.inventory[0].uid)
	await click(main.hud.navigation.inventory[0])
	check(main.modal_kind=="inventory" and get_tree().paused,"HUD inventory pauses gameplay")
	await capture("05-inventory")
	var tab: Button = find_button(main.modal,"Grimoire")
	check(tab!=null,"Grimoire tab exists")
	if tab: await click(tab)
	check(main.modal_kind=="skills","Inventory tab opens grimoire with real click")
	await capture("06-grimoire")
	main.show_merchant(); await capture("07-merchant")
	main.show_pause(); await capture("08-pause")
	main.options_return="pause"
	main.show_options(); await capture("09-options")
	main.close_modal()
	State.run.level=5;State.run.pending=[5];State.run.offers=[]
	main.show_level(); await capture("10-level")
	State.run.pending=[];State.run.offers=[]
	main.close_modal()
	main.show_death(); await capture("11-death")
	main.show_victory(); await capture("12-victory")
	main.close_modal()
	for resolution: Vector2i in [Vector2i(1920,1080),Vector2i(960,600)]:
		DisplayServer.window_set_size(resolution)
		await settle()
		await capture("hud-%dx%d"%[resolution.x,resolution.y])
		main.show_inventory(); await capture("inventory-%dx%d"%[resolution.x,resolution.y])
		main.close_modal()
	DisplayServer.window_set_size(Vector2i(1440,900))
	main.show_menu(); await capture("13-final-menu")
	var report: Dictionary = {"errors":errors,"captures":captures,"rendered_sizes":rendered_sizes,"checks":"Live native render, health/mana, cooldowns, locked slots, potion, spell cycling, bindings, modal pause, three window sizes"}
	var file: FileAccess = FileAccess.open("res://outputs/ui-redesign/report.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"));file.close()
	print("UI_REDESIGN ",JSON.stringify(report))
	Sound.stop_all()
	main.queue_free()
	await get_tree().create_timer(0.25,true).timeout
	get_tree().quit(0 if errors.is_empty() else 1)

func check(ok: bool, description: String) -> void:
	if not ok: errors.append(description);push_error(description)

func settle() -> void:
	await get_tree().create_timer(0.4,true).timeout

func capture(title: String) -> void:
	await settle()
	await RenderingServer.frame_post_draw
	var rendered: Image = get_viewport().get_texture().get_image()
	rendered.save_png("res://outputs/ui-redesign/"+title+".png")
	rendered_sizes[title] = [rendered.get_width(),rendered.get_height()]
	captures.append(title)

func click(control: Control) -> void:
	await get_tree().process_frame
	var point: Vector2 = control.get_global_rect().get_center()
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position=point;motion.global_position=point
	Input.parse_input_event(motion)
	await get_tree().process_frame
	for down: bool in [true,false]:
		var event: InputEventMouseButton = InputEventMouseButton.new()
		event.position=point;event.global_position=point
		event.button_index=MOUSE_BUTTON_LEFT;event.pressed=down
		Input.parse_input_event(event)
		await get_tree().process_frame
	await settle()

func find_button(node: Node, text: String) -> Button:
	if node is Button and node.text==text: return node
	for child: Node in node.get_children():
		var found: Button = find_button(child,text)
		if found: return found
	return null
