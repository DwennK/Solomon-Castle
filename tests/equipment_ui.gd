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
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
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
	await click_text("Ring 2")
	await click_text("Equip — ring 2")
	check(State.run.equipped.ring2==ring.uid and State.run.equipped.ring1.is_empty(),"Click equips the selected ring slot")
	check(State.stats().xp_bonus==1,"Equipped ring changes real XP multiplier")
	await capture("inventory-1440x900")
	await click_text("Remove · Ring 2")
	check(State.run.equipped.ring2.is_empty() and State.stats().xp_bonus==0,"Click removes ring and its bonus")
	await click_text("Ring 1")
	await click_text("Equip — ring 1")
	check(State.run.equipped.ring1==ring.uid,"Same ring can be placed in the first slot")
	State.equip(State.run.inventory[1].uid)
	State.equip(State.run.inventory[2].uid,"ring2")
	main.show_inventory()
	await capture("equipped-1440x900")
	main.show_skills()
	await capture("grimoire-1440x900")
	check(all_text(main.modal).contains("Equipment: +1"),"Grimoire shows earned and equipped ranks")
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
	main.modal.select_item(sale.uid)
	await settle()
	await click_text("Sell · %d gold"%maxi(1,int(sale.price/3)))
	check(State.find_item(sale.uid).is_empty() and State.run.gold==gold_before+maxi(1,int(sale.price/3)),"Sale button removes one item and pays exactly once: selected=%s sold=%s gold=%d expected=%d" % [main.modal.selected_uid,sale.uid,State.run.gold,gold_before+maxi(1,int(sale.price/3))])
	main.modal.select_item(State.run.equipped.ring2)
	await click_text("Remove · Ring 2")
	check(State.run.equipped.ring2.is_empty(),"Equipped item can be removed in sale mode")
	for size: Vector2i in [Vector2i(960,600)]:
		DisplayServer.window_set_size(size)
		main.show_inventory()
		await capture("inventory-960x600")
		main.modal.select_item(ring.uid)
		await click_text("Remove · Ring 1")
		check(State.run.equipped.ring1.is_empty(),"Remove remains usable in minimum desktop window")
	DisplayServer.window_set_size(Vector2i(1440,900))
	await full_inventory_checks()
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
	RenderingServer.force_draw()
	var rendered: Image=get_viewport().get_texture().get_image()
	rendered.save_png("res://outputs/equipment-ui/"+name+".png")
	captures.append({"name":name,"width":rendered.get_width(),"height":rendered.get_height()})

func fixture(id: String, rng: RandomNumberGenerator) -> Dictionary:
	for template: Dictionary in Equipment.templates():
		if template.id==id:
			var item: Dictionary=State.make_equipment(template,rng)
			State.run.inventory.append(item)
			return item
	return {}

func full_inventory_checks() -> void:
	await settle()
	State.fresh(881)
	for id: String in ["missile","fire","life","mana","regen","shield"]: State.learn(id)
	State.run.skills.life=2;State.run.skills.regen=2
	var rng: RandomNumberGenerator=RandomNumberGenerator.new();rng.seed=81
	var staff: Dictionary=fixture("staff_2_27",rng)
	var ring_a: Dictionary=fixture("ring_1_19",rng)
	var ring_b: Dictionary=fixture("ring_0_07",rng)
	var candidate: Dictionary=fixture("ring_1_17",rng)
	State.equip(staff.uid,"staff");State.equip(ring_a.uid,"ring1");State.equip(ring_b.uid,"ring2")
	for i: int in range(44): State.run.inventory.append(State.make_item(1100+i,8))
	main.show_inventory()
	await settle()
	var view: InventoryView=main.modal
	check(view.cells.size()==48,"Full bag renders all 48 objects")
	await click_button(view.cells[candidate.uid])
	await click_text("Ring 1")
	check(view.selected_uid==candidate.uid and view.target_slot=="ring1","Mouse selects candidate and first ring comparison")
	var detail: String=all_text(view.detail_body)
	check(detail.contains("Gain ·") and detail.contains("Loss ·") and detail.contains("→"),"Comparison shows real before/after gains and losses together")
	check(State.run.equipped.ring1==ring_a.uid,"Selecting comparison never equips")
	await capture("comparison-full-bag-1440x900")
	var bounds: Rect2=view.detail_body.get_parent().get_global_rect()
	view.bag_scroll.scroll_vertical=500
	await settle()
	check(view.bag_scroll.scroll_vertical>0,"Full bag scrolls")
	check(view.detail_body.get_parent().get_global_rect()==bounds,"Detail column stays fixed while bag scrolls")
	var last: Dictionary=State.run.inventory[-1]
	check(view.cells[last.uid].get_node("Content/Badge").text=="NEW","Uninspected loot marked new")
	await click_button(view.cells[last.uid])
	check(last.get("inspected",false),"Selecting loot marks it inspected")
	check(view.cells[last.uid].get_node("Content/Badge").text!="NEW","New marker disappears on inspection")
	var scroll_before: int=view.bag_scroll.scroll_vertical
	await click_button(view.action_body.get_node("InventoryAction"))
	check(view.selected_uid==last.uid and view.bag_scroll.scroll_vertical==scroll_before,"Equipping retains selection and bag scroll")
	check(get_viewport().gui_get_focus_owner()==view.cells[last.uid],"Keyboard focus survives equipment action")
	await click_text("Staves")
	check(view.visible_items().all(func(item: Dictionary)->bool:return item.slot=="staff"),"Staff filter contains only staves")
	check(view.cells.size()==view.visible_items().size(),"Filter updates visible grid")
	await click_text("Rings")
	check(view.visible_items().all(func(item: Dictionary)->bool:return item.slot=="ring"),"Ring filter contains only rings")
	await click_text("All")
	check(view.cells.size()==48,"All filter restores all items")
	await click_button(view.cells[candidate.uid])
	await click_text("Ring 2")
	check(view.target_slot=="ring2","Second ring can be compared independently")
	check(State.run.equipped.ring2!=candidate.uid,"Ring target selection remains read-only")
	await capture("comparison-ring2-1440x900")
	await click_text("Equip — ring 2")
	check(State.run.equipped.ring2==candidate.uid,"Comparison action equips the chosen second ring")
	# Check the same open panel at desktop window sizes, without reconstruction.
	for size: Vector2i in [Vector2i(1600,1000),Vector2i(960,600)]:
		DisplayServer.window_set_size(size)
		await settle()
		for name: String in ["EquipmentColumn","BagColumn","DetailsColumn"]:
			var column: Control=view.find_child(name,true,false)
			check(get_viewport().get_visible_rect().encloses(column.get_global_rect()),"Column fits viewport: "+name+str(size))
		check(view.detail_body.size.x<=view.detail_scroll.size.x,"Detail content fits column: %s / %s" % [view.detail_body.size.x,view.detail_scroll.size.x])
		check(view.detail_scroll.get_h_scroll_bar().max_value<=view.detail_scroll.size.x+1,"Detail has no horizontal overflow: %s / %s" % [view.detail_scroll.get_h_scroll_bar().max_value,view.detail_scroll.size.x])
		check(view.bag_scroll.get_h_scroll_bar().max_value<=view.bag_scroll.size.x+1,"Bag has no horizontal overflow")
		await capture("full-bag-%dx%d" % [size.x,size.y])
	DisplayServer.window_set_size(Vector2i(1440,900))
	await settle()
	await click_text("Grimoire")
	check(main.modal_kind=="skills","Inventory navigation opens grimoire")
	main.show_inventory()
	var key: InputEventKey=InputEventKey.new();key.keycode=KEY_ESCAPE;key.physical_keycode=KEY_ESCAPE;key.pressed=true
	Input.parse_input_event(key)
	await settle()
	key=InputEventKey.new();key.keycode=KEY_ESCAPE;key.physical_keycode=KEY_ESCAPE;key.pressed=false
	Input.parse_input_event(key)
	check(main.modal_kind.is_empty() and not get_tree().paused,"Escape closes inventory and resumes gameplay")
	main.show_inventory()
	# Empty bag and an empty filter retain a reachable close/navigation path.
	State.run.equipped={"staff":"","ring1":"","ring2":""};State.run.inventory=[]
	view=main.modal;view.refresh()
	check(view.cells.is_empty() and all_text(view.detail_body).contains("Select"),"Empty bag clears stale selection and comparison")
	fixture("staff_0_00",rng)
	view.refresh()
	await click_text("Rings")
	check(view.cells.is_empty() and view.selected_uid.is_empty(),"Empty filter clears stale item")
	await capture("empty-filter-1440x900")
