extends Node

var main: Node
var errors: Array[String]=[]
var checks: int=0
var captures: Array[String]=[]

func _ready() -> void:
	if not State.qa or DisplayServer.get_name()=="headless":
		get_tree().quit(1);return
	process_mode=Node.PROCESS_MODE_ALWAYS
	State.save_path="user://qa_codex_ui.json"
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	State.options.fullscreen=false
	DisplayServer.window_set_size(Vector2i(1440,900))
	DirAccess.make_dir_recursive_absolute("res://outputs/codex-ui")
	main=load("res://scenes/main.tscn").instantiate();add_child(main)
	await settle()
	await capture("menu-desktop")
	State.fresh(9707)
	for id: String in ["missile","fire","ice","lightning","shield","freeze","regen","life","power","chain"]: State.learn(id)
	State.run.skills.regen=3
	main.start_game()
	main.world.player.qa_controlled=true
	main.world.player.set_physics_process(false)
	var rng: RandomNumberGenerator=RandomNumberGenerator.new();rng.seed=7
	for index: int in range(20):
		State.run.inventory.append(State.make_equipment(Equipment.templates()[index*4],rng))
	main.show_inventory()
	await settle()
	var inventory: InventoryView=main.modal
	check(inventory.cells.size()==20,"Initial inventory shows all items without a search")
	var staff: Dictionary=State.run.inventory[0]
	await click(inventory.cells[staff.uid])
	await capture("inventory-desktop")
	inventory=await compact_checks()
	var first_key: String=staff.bonuses.keys()[0]
	check(visible_text(inventory.detail_header).count(Equipment.bonus_text(first_key,staff.bonuses[first_key]))==1,"Generated names do not duplicate the intrinsic bonus line")
	var equipped_before: Dictionary=State.run.equipped.duplicate()
	await type_query(inventory.search_field,"zzzz")
	check(inventory.cells.is_empty() and inventory.selected_uid.is_empty(),"No search result clears the old item and action")
	check(inventory.action_body.get_child_count()==0,"Empty search cannot equip a stale item")
	await type_query(inventory.search_field,"Bâton")
	check(not inventory.cells.is_empty() and inventory.visible_items().all(func(item: Dictionary)->bool:return item.slot=="staff"),"Typed inventory search finds matching staves")
	await click(find_button(inventory,"Anneaux"))
	check(inventory.cells.is_empty(),"Category and search combine: filter=%s query=%s count=%d" % [inventory.filter,inventory.query,inventory.cells.size()])
	await type_query(inventory.search_field,"")
	check(not inventory.cells.is_empty(),"Clearing search restores the category")
	await click(find_button(inventory,"Tous"))
	var sorting: OptionButton=inventory.find_child("InventorySort",true,false)
	sorting.select(2);sorting.item_selected.emit(2)
	var sorted: Array=inventory.visible_items()
	var descending: bool=true
	for index: int in range(1,sorted.size()): descending=descending and int(sorted[index-1].rarity)>=int(sorted[index].rarity)
	check(descending,"Rarity sort orders the actual visible inventory")
	check(State.run.equipped==equipped_before,"Searching and sorting never equip an item")
	await click(find_button(inventory,"Grimoire"))
	check(main.modal_kind=="skills" and get_tree().paused,"Grimoire tab keeps gameplay paused")
	var grimoire: GrimoireView=main.modal
	var old_active: String=State.run.active
	var target: String="fire" if old_active!="fire" else "ice"
	await click(grimoire.entries[target])
	check(State.run.active==old_active,"Reading a spell does not activate it")
	await click(find_button(grimoire,"Utiliser cette magie"))
	check(State.run.active==target and grimoire.status.text.contains(Catalog.title(target)),"Activate changes the real spell and visible status")
	await capture("grimoire-desktop")
	await click(grimoire.tabs.passive)
	check(grimoire.entries.size()==4,"Savoirs chapter lists acquired passives")
	check(find_button(grimoire,"Utiliser cette magie")==null,"Passive knowledge has no misleading activation action")
	await type_query(grimoire.search_field,"zzzz")
	check(grimoire.entries.is_empty() and grimoire.selected_id.is_empty(),"Empty grimoire search removes stale selection")
	var ready_button: Button=grimoire.equipped.get_child(1).get_child(0)
	await click(ready_button)
	check(grimoire.chapter=="secondary" and grimoire.query.is_empty() and grimoire.search_field.text.is_empty(),"Ritual shortcut opens its chapter and clears the visible search")
	await capture("rituals-desktop")
	await click(grimoire.tabs.fusion)
	check(grimoire.entries.is_empty() and not State.run.fusion.has("id"),"Unlearned fusion stays unavailable")
	await capture("fusion-empty-desktop")
	for resolution: Vector2i in [Vector2i(1440,900),Vector2i(960,600),Vector2i(1920,1080)]:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(resolution);await settle()
		main.show_skills();await settle()
		var view: GrimoireView=main.modal
		check(get_viewport().get_visible_rect().encloses(view.actions.get_global_rect()),"Grimoire action fits "+str(resolution))
		check(get_viewport().get_visible_rect().encloses(view.equipped.get_global_rect()),"Ritual shortcuts fit "+str(resolution))
		check(view.detail_scroll.get_h_scroll_bar().max_value<=view.detail_scroll.size.x+1,"Grimoire details have no horizontal overflow "+str(resolution))
		await capture("grimoire-%dx%d" % [resolution.x,resolution.y])
		main.show_pause();await capture("pause-%dx%d" % [resolution.x,resolution.y])
		main.options_return="pause";main.show_options();await capture("options-%dx%d" % [resolution.x,resolution.y])
		check(get_viewport().get_visible_rect().encloses(main.content.get_parent().get_global_rect()),"Options scroll fits "+str(resolution))
	DisplayServer.window_set_size(Vector2i(1440,900));await settle()
	main.show_inventory();await settle()
	await click(find_button(main.modal,"Pause"))
	check(main.modal_kind=="pause","Codex pause navigation works")
	await click(find_button(main.modal,"Reprendre"))
	check(main.modal_kind.is_empty() and not get_tree().paused,"Resume closes the book and resumes gameplay")
	main.show_menu();await capture("menu-1440x900")
	var report: Dictionary={"checks":checks,"errors":errors,"captures":captures,"engine":"Godot native GPU; real mouse and keyboard input; QA-only save"}
	var output: FileAccess=FileAccess.open("res://outputs/codex-ui/report.json",FileAccess.WRITE)
	output.store_string(JSON.stringify(report,"\t"));output.close()
	print("CODEX_UI ",JSON.stringify(report))
	if errors.is_empty() and "--preview" in OS.get_cmdline_user_args():
		main.start_game()
		main.show_inventory()
		return
	Sound.stop_all();main.queue_free();await settle()
	get_tree().quit(0 if errors.is_empty() else 1)

func check(value: bool, message: String) -> void:
	checks+=1
	if not value: errors.append(message);push_error(message)

func settle() -> void:
	await get_tree().create_timer(0.3,true).timeout

func click(control: Control) -> void:
	check(control!=null,"Requested control exists")
	if not control: return
	await settle()
	var point: Vector2=get_viewport().get_final_transform()*control.get_global_rect().get_center()
	var motion: InputEventMouseMotion=InputEventMouseMotion.new();motion.position=point;Input.parse_input_event(motion)
	for down: bool in [true,false]:
		var event: InputEventMouseButton=InputEventMouseButton.new()
		event.position=point;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=down
		Input.parse_input_event(event);await get_tree().process_frame
	await settle()

func type_query(edit: LineEdit, value: String) -> void:
	await click(edit)
	edit.text="";edit.text_changed.emit("")
	for character: String in value:
		var key: InputEventKey=InputEventKey.new()
		key.keycode=character.to_upper().unicode_at(0)
		key.physical_keycode=key.keycode
		key.unicode=character.unicode_at(0);key.pressed=true
		Input.parse_input_event(key);await get_tree().process_frame
		key=key.duplicate();key.pressed=false;Input.parse_input_event(key)
	await settle()

func find_button(node: Node, title: String) -> Button:
	if node is Button and node.text==title: return node
	for child: Node in node.get_children():
		var found: Button=find_button(child,title)
		if found: return found
	return null

func capture(title: String) -> void:
	await settle();RenderingServer.force_draw()
	get_viewport().get_texture().get_image().save_png("res://outputs/codex-ui/"+title+".png")
	print("CAPTURE ",title," ",get_viewport().get_texture().get_size())
	captures.append(title)

func compact_checks() -> InventoryView:
	var original: Dictionary=State.run.duplicate(true)
	State.fresh(9901)
	State.learn("lightning");State.run.active="lightning"
	for index: int in range(20):
		State.run.inventory.append({"uid":"compact_ui_%d"%index,"name":"Bâton des orages" if index==0 else "Bâton du voyageur", "slot":"staff","rarity":1,"price":300,"bonuses":{"skill:lightning":2,"skill:chain":2} if index==0 else {"flat_damage":3}})
	main.show_inventory();await settle()
	var view: InventoryView=main.modal
	check(not view.details_expanded and not view.all_changes.visible,"Full comparison is collapsed initially")
	check(view.find_child("CompactMetrics",true,false).get_child_count()==4,"Lightning summary has two metrics with keyboard detail labels")
	check(view.find_child("CompactEffects",true,false)!=null,"Lightning chain synergy is visible")
	check(not visible_text(view).contains("Remplace") and not visible_text(view).contains("Actuellement :"),"No replacement-name line or redundant comparison heading")
	var button: Button=view.action_body.get_node("InventoryAction")
	var action_bounds: Rect2=button.get_global_rect()
	await capture("compact-lightning-1440x900")
	await click(view.find_child("ToggleChanges",true,false))
	check(view.all_changes.visible,"Mouse opens all changes in place")
	check(button.get_global_rect()==action_bounds,"Expanding details keeps Equip fixed")
	await capture("compact-expanded-1440x900")
	await click(view.cells.compact_ui_1)
	check(view.details_expanded and view.all_changes.visible,"Browsing retains disclosure preference")
	await click(view.find_child("ToggleChanges",true,false))
	check(not view.all_changes.visible,"Mouse collapses all changes")
	await click(view.cells.compact_ui_0)
	var metric: Control=view.find_child("CompactMetrics",true,false).get_child(0)
	metric.grab_focus();await settle()
	check(view.find_child("CompactMetrics",true,false).get_child(1).visible,"Keyboard focus exposes exact before/after values")
	view.cells.compact_ui_0.grab_focus();await settle()
	check(not view.find_child("CompactMetrics",true,false).get_child(1).visible,"Exact values disappear on focus exit")
	check(State.run.equipped.staff.is_empty(),"Browsing details never equips")
	await click(view.action_body.get_node("InventoryAction"))
	check(State.run.equipped.staff=="compact_ui_0","Compact card equips with explicit action")
	check(visible_text(view).contains("SI TU LE RETIRES"),"Equipped card clearly describes removal")
	for resolution: Vector2i in [Vector2i(960,600),Vector2i(1440,900)]:
		DisplayServer.window_set_size(resolution);await settle()
		await click(view.cells.compact_ui_1)
		check(get_viewport().get_visible_rect().encloses(view.action_body.get_global_rect()),"Compact action fits "+str(resolution))
		check(view.detail_scroll.get_v_scroll_bar().max_value<=view.detail_scroll.size.y+1,"Simple compact card needs no vertical scroll "+str(resolution))
		await capture("compact-loss-%dx%d"%[resolution.x,resolution.y])
	State.run=original
	main.show_inventory();await settle()
	return main.modal

func visible_text(node: Node) -> String:
	if node is Control and not node.is_visible_in_tree(): return ""
	var result: String=node.text+"\n" if node is Label or node is Button else ""
	for child: Node in node.get_children(): result+=visible_text(child)
	return result
