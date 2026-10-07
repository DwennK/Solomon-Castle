extends Node

var main: Node
var errors: Array[String] = []
var captures: Array = []

func check(ok: bool, message: String) -> void:
	if not ok:
		errors.append(message)
		push_error(message)

func _ready() -> void:
	if not State.qa or DisplayServer.get_name()=="headless":
		get_tree().quit(1)
		return
	process_mode=Node.PROCESS_MODE_ALWAYS
	State.save_path="user://qa_equipment_ui.json"
	DisplayServer.window_set_size(Vector2i(1440,900))
	DirAccess.make_dir_recursive_absolute("res://outputs/equipment-ui")
	main=load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await settle()
	State.fresh(3009)
	State.learn("missile");State.learn("shield")
	main.start_game()
	main.world.player.qa_controlled=true
	main.world.player.set_physics_process(false)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new();rng.seed=1
	for id: String in ["ring_0_07","staff_2_27","ring_1_14","staff_2_25"]:
		for template: Dictionary in Equipment.templates():
			if template.id==id: State.run.inventory.append(State.make_equipment(template,rng))
	main.show_inventory()
	await settle()
	var ring: Dictionary = State.run.inventory[0]
	await click_text("Équiper — anneau 2")
	check(State.run.equipped.ring2==ring.uid and State.run.equipped.ring1.is_empty(),"Click equips the selected ring slot")
	check(State.stats().xp_bonus==1,"Equipped ring changes real XP multiplier")
	await capture("inventory-1440x900")
	await click_prefix("Anneau 2 :")
	check(State.run.equipped.ring2.is_empty() and State.stats().xp_bonus==0,"Click removes ring and its bonus")
	await click_text("Équiper — anneau 1")
	check(State.run.equipped.ring1==ring.uid,"Same ring can be placed in the first slot")
	State.equip(State.run.inventory[1].uid)
	State.equip(State.run.inventory[2].uid,"ring2")
	main.show_inventory()
	await capture("equipped-1440x900")
	main.show_skills()
	await capture("grimoire-1440x900")
	check(all_text(main.modal).contains("Équipement : +1"),"Grimoire shows earned and equipped ranks")
	main.show_merchant()
	await capture("merchant-1440x900")
	var bought: Dictionary = State.run.shop[0]
	State.run.gold=10000
	main.show_merchant()
	await click_prefix(bought.name+" ·")
	check(not State.find_item(bought.uid).is_empty(),"Merchant button purchases catalogue item")
	main.show_inventory(true)
	await capture("selling-1440x900")
	var sale: Dictionary=State.run.inventory[3]
	var gold_before: int=State.run.gold
	await click_text("Vendre · %d or"%maxi(1,int(sale.price/3)))
	check(State.find_item(sale.uid).is_empty() and State.run.gold==gold_before+maxi(1,int(sale.price/3)),"Sale button removes one item and pays exactly once")
	for size: Vector2i in [Vector2i(960,600)]:
		DisplayServer.window_set_size(size)
		main.show_inventory()
		await capture("inventory-960x600")
		await click_prefix("Anneau 1 :")
		check(State.run.equipped.ring1.is_empty(),"Remove remains usable in minimum desktop window")
	DisplayServer.window_set_size(Vector2i(1440,900))
	var report: Dictionary={"errors":errors,"captures":captures,"interactions":"Native mouse clicks: equip each ring slot, remove, buy; grimoire, merchant and sale rendering"}
	var file: FileAccess=FileAccess.open("res://outputs/equipment-ui/report.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"));file.close()
	print("EQUIPMENT_UI ",JSON.stringify(report))
	main.close_modal();Sound.stop_all();main.queue_free()
	await settle()
	get_tree().quit(0 if errors.is_empty() else 1)

func settle() -> void:
	await get_tree().create_timer(0.25,true).timeout

func find_button(node: Node, text: String, prefix: bool) -> Button:
	if node is Button and not node.disabled and (node.text.begins_with(text) if prefix else node.text==text): return node
	for child: Node in node.get_children():
		var result: Button=find_button(child,text,prefix)
		if result: return result
	return null

func click_text(text: String) -> void:
	await click_button(find_button(main.modal,text,false))

func click_prefix(text: String) -> void:
	await click_button(find_button(main.modal,text,true))

func click_button(button: Button) -> void:
	check(button!=null,"Requested button exists")
	if not button: return
	var parent: Node=button.get_parent()
	while parent:
		if parent is ScrollContainer:
			parent.ensure_control_visible(button)
			break
		parent=parent.get_parent()
	await settle()
	var position: Vector2=get_viewport().get_final_transform()*button.get_global_rect().get_center()
	var motion: InputEventMouseMotion=InputEventMouseMotion.new();motion.position=position;motion.global_position=position
	Input.parse_input_event(motion)
	for pressed: bool in [true,false]:
		var event: InputEventMouseButton=InputEventMouseButton.new()
		event.position=position;event.global_position=position;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=pressed
		Input.parse_input_event(event)
		await get_tree().process_frame
	await settle()

func all_text(node: Node) -> String:
	var result: String=node.text if node is Label or node is Button else ""
	for child: Node in node.get_children(): result+="\n"+all_text(child)
	return result

func capture(name: String) -> void:
	await settle()
	await RenderingServer.frame_post_draw
	var rendered: Image=get_viewport().get_texture().get_image()
	rendered.save_png("res://outputs/equipment-ui/"+name+".png")
	captures.append({"name":name,"width":rendered.get_width(),"height":rendered.get_height()})
