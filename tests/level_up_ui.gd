extends Node

var main: Node
var checks: int = 0
var errors: Array[String] = []
var captures: Array = []

func _ready() -> void:
	if not State.qa: get_tree().quit(1);return
	process_mode = Node.PROCESS_MODE_ALWAYS
	State.save_path = "user://qa_level_up_cards.json"
	DirAccess.make_dir_recursive_absolute("res://outputs/level-up")
	call_deferred("run_all")

func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok: errors.append(message);push_error(message)

func run_all() -> void:
	State.fresh(42031)
	check(LevelUpView.kind_caption("fire")=="SPELL · PRIMARY","Primary spell category")
	check(LevelUpView.kind_caption("freeze")=="RITUAL · ACTIVE","Active ritual category")
	check(LevelUpView.kind_caption("life")=="PASSIVE · KNOWLEDGE","General passive category")
	check(LevelUpView.kind_caption("chain")=="PASSIVE · LIGHTNING","Elemental passive is not mislabeled a spell")
	check(LevelUpView.kind_caption("harden")=="PASSIVE · MAJOR","Major upgrade is passive")
	check(LevelUpView.kind_caption("blizzard")=="SPELL · FUSION","Fusion category")
	check(LevelUpView.advancement("freeze").current=="Lv. 0" and LevelUpView.advancement("freeze").next=="Lv. 1","New knowledge shows zero to one")
	State.run.skills.fire=2
	State.run.inventory=[{"uid":"rank_gear","slot":"staff","bonuses":{"skill:fire":2,"grant:mental_focus":1}}]
	State.run.equipped.staff="rank_gear"
	check(LevelUpView.advancement("fire").current=="Lv. 2" and LevelUpView.advancement("fire").next=="Lv. 3","Learned ranks remain distinct from equipment")
	check(LevelUpView.advancement("fire").note=="With equipment: Lv. 4 → 5","Effective rank comparison includes equipment")
	check(LevelUpView.advancement("focus").note=="With equipment: Lv. 1 → 1","Binary granted passive never promises an extra rank")
	State.run.level=30;State.learn("lightning");State.learn("ice");State.learn("blizzard")
	State.run.level=35
	check(LevelUpView.advancement("blizzard").current=="Snapshot Lv. 30" and LevelUpView.advancement("blizzard").next=="Snapshot Lv. 35","Fusion refresh shows captured character level, not invented skill rank")
	for kind: String in ["primary","secondary","passive","fusion"]:
		for id: String in Catalog.ids(kind):
			check(ResourceLoader.exists("res://assets/ui/level-up/"+LevelUpView.art_family(id)+".png"),"Illustration exists for "+id)
	if DisplayServer.get_name()!="headless": await native_checks()
	var report: Dictionary = {"checks":checks,"errors":errors,"captures":captures,"method":"Native Godot GPU, isolated QA save, mouse and keyboard events"}
	var file: FileAccess=FileAccess.open("res://outputs/level-up/report.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"));file.close()
	print("LEVEL_UP_UI ",JSON.stringify(report))
	Sound.stop_all()
	get_tree().quit(0 if errors.is_empty() else 1)

func native_checks() -> void:
	State.fresh(42032)
	State.learn("lightning")
	State.run.level=3;State.run.pending=[3];State.run.offers=["freeze","chain","ring_fire"]
	main=load("res://scenes/main.tscn").instantiate();add_child(main)
	main.start_game();main.world.player.qa_controlled=true
	await resize_window(Vector2i(1440,900))
	var view: LevelUpView=main.modal
	check(get_tree().paused,"Level selection pauses the world")
	check(view.cards.size()==3,"Three initial cards")
	for id: String in view.offered:
		check(view.detail_labels[id].text==SkillDetails.text(id,true),"All previous combat detail text preserved for "+id)
		check(view.detail_scrolls[id].size.y>100,"Useful detail viewport for "+id)
		check(view.detail_scrolls[id].get_h_scroll_bar().max_value<=view.detail_scrolls[id].size.x+1,"No horizontal detail clipping for "+id)
	await click_card(view,"chain")
	check(view.selected_id=="chain" and State.learned_rank("chain")==0 and State.run.pending.size()==1,"Card click previews without spending choice")
	await capture("three-cards")
	check(get_viewport().get_visible_rect().encloses(view.confirm.get_global_rect()),"Confirmation stays inside viewport")
	await click(view.confirm)
	check(State.learned_rank("chain")==1 and State.run.pending.is_empty() and not get_tree().paused,"Explicit confirmation learns one upgrade and resumes: rank=%d pending=%s modal=%s" % [State.learned_rank("chain"),str(State.run.pending),main.modal_kind])
	State.run.pending=[4,5];State.run.level=5;State.run.offers=["chain","life","mana"]
	main.show_level();await settle();view=main.modal
	view.cards.life.grab_focus()
	await settle()
	await press_accept()
	check(get_viewport().gui_get_focus_owner()==view.confirm and State.learned_rank("life")==0,"Keyboard selection focuses confirmation without learning")
	await press_accept()
	check(State.learned_rank("life")==1 and State.run.pending.size()==1 and main.modal_kind=="level" and get_tree().paused,"Keyboard confirms once and opens next pending level")
	State.run.pending=[5];State.run.offers=["chain","life","mana"];State.run.insight=1
	main.show_level();await settle();view=main.modal
	await click(view.reroll)
	check(State.run.insight==0 and State.run.pending.size()==1,"Reroll consumes one shard and keeps pending choice")
	view=main.modal
	check(view.reroll.disabled,"Empty shard control disabled")
	check(view.selected_id in State.run.offers,"Reroll resets selection to a current offer")
	State.run.skills.merge({"missile":1,"fire":2,"explode":1,"embers":1,"ice":1,"cone":1,"chill":1,"lightning":1,"chain":1,"stun":1,"multishot":1,"potent":1,"creativity":1},true)
	State.run.level=30;State.run.pending=[30];State.run.offers=["immolation","ether_charge","hurricane","harden"]
	for resolution: Vector2i in [Vector2i(1440,900),Vector2i(960,600),Vector2i(1920,1080)]:
		await resize_window(resolution)
		main.show_level();await settle();view=main.modal
		check(view.cards.size()==4,"Creativity keeps four cards "+str(resolution))
		for card: Control in view.cards.values(): check(get_viewport().get_visible_rect().encloses(card.get_global_rect()),"Card visible "+str(resolution))
		check(get_viewport().get_visible_rect().encloses(view.footer.get_global_rect()),"Fixed footer visible "+str(resolution))
		await click_card(view,"harden")
		check(view.selected_id=="harden","Fourth card reachable "+str(resolution))
		await capture("four-cards-%dx%d" % [resolution.x,resolution.y])
	await click(view.confirm)
	check(State.learned_rank("harden")==1 and State.run.pending.is_empty(),"Fourth choice confirms correctly")
	await resize_window(Vector2i(1440,900))
	State.run.level=35;State.run.pending=[35];State.run.offers=["fire","blizzard","regen"]
	State.run.inventory=[{"uid":"rank_gear","slot":"staff","bonuses":{"skill:fire":2}}]
	State.run.equipped.staff="rank_gear"
	State.learn("blizzard")
	State.run.fusion.level=30
	main.show_level();await settle();view=main.modal
	await click_card(view,"blizzard")
	await capture("equipment-fusion-passive")
	check(view.detail_labels.blizzard.text.contains("Snapshot ranks"),"Fusion retains snapshot explanation")
	# Exhausted eligibility still has a visible continuation, without granting knowledge.
	for kind: String in ["primary","secondary","passive"]:
		for id: String in Catalog.ids(kind): State.run.skills[id]=Catalog.definition(id).max_rank
	State.run.level=99;State.run.pending=[99];State.run.offers=[]
	main.show_level();await settle();view=main.modal
	check(view.offered.is_empty() and view.confirm.text=="Continue","Exhausted choices have continuation")
	await click(view.confirm)
	check(State.run.pending.is_empty(),"Continuation consumes exhausted pending level")
	main.queue_free();await settle()

func resize_window(resolution: Vector2i) -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	await settle()
	DisplayServer.window_set_size(resolution)
	await settle()

func settle() -> void:
	await get_tree().create_timer(0.3,true).timeout

func click_card(view: LevelUpView, id: String) -> void:
	# Illustration is a stable, unobscured hit target above the scrolling text.
	await click(view.artworks[view.offered.find(id)])

func click(control: Control) -> void:
	await settle()
	var point: Vector2=control.get_global_rect().get_center()
	var motion: InputEventMouseMotion=InputEventMouseMotion.new();motion.position=point;get_viewport().push_input(motion,true)
	for down: bool in [true,false]:
		var event: InputEventMouseButton=InputEventMouseButton.new()
		event.position=point;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=down
		get_viewport().push_input(event,true);await get_tree().process_frame
	await settle()

func press_accept() -> void:
	for down: bool in [true,false]:
		var event: InputEventAction=InputEventAction.new();event.action="ui_accept";event.pressed=down
		get_viewport().push_input(event,true);await get_tree().process_frame
	await settle()

func capture(title: String) -> void:
	await settle();RenderingServer.force_draw()
	var rendered: Image=get_viewport().get_texture().get_image()
	rendered.save_png("res://outputs/level-up/"+title+".png")
	captures.append({"name":title,"pixels":str(rendered.get_size()),"viewport":str(get_viewport().get_visible_rect().size)})
