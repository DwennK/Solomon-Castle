class_name InventoryView
extends Control

signal close_requested
signal section_requested(section: String)

const GAIN: Color = Color("9fd5ad")
const LOSS: Color = Color("efa59c")
const RARITIES: Array[String] = ["Enchanté", "Rare", "Épique"]
var selling: bool = false
var selected_uid: String = ""
var filter: String = "all"
var target_slot: String = "ring1"
var equipment_body: VBoxContainer
var bag_grid: GridContainer
var bag_scroll: ScrollContainer
var detail_header: VBoxContainer
var detail_body: VBoxContainer
var detail_scroll: ScrollContainer
var action_body: VBoxContainer
var wallet: Label
var filter_buttons: Dictionary = {}
var cells: Dictionary = {}

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade: ColorRect = ColorRect.new()
	shade.color = Color(0.015,0.018,0.024,0.9)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_"+side,28)
	add_child(margin)
	var frame: PanelContainer = PanelContainer.new()
	frame.add_theme_stylebox_override("panel",GameTheme.panel(Color("101113"),GameTheme.GOLD.darkened(0.3),22))
	margin.add_child(frame)
	var root: VBoxContainer = VBoxContainer.new();frame.add_child(root)
	var header: HBoxContainer = HBoxContainer.new();root.add_child(header)
	var title: Label = text(header,"Votre sac" if not selling else "Vendre à Basile",28)
	GameTheme.heading(title)
	wallet = text(header,"",16,GameTheme.GOLD)
	wallet.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var close: Button = action(header,"×",func()->void:close_requested.emit())
	close.custom_minimum_size = Vector2(44,44)
	close.size_flags_horizontal = Control.SIZE_SHRINK_END
	close.tooltip_text = "Fermer"
	var nav: HBoxContainer = HBoxContainer.new();root.add_child(nav)
	for entry: Array in [["inventory","Inventaire"],["skills","Grimoire"],["map","Carte"]]:
		var tab: Button = action(nav,entry[1],func()->void:
			if entry[0] != "inventory": section_requested.emit(entry[0]))
		if entry[0] == "inventory": tab.add_theme_stylebox_override("normal",GameTheme.panel(Color("34291a"),GameTheme.GOLD,8))
	root.add_child(HSeparator.new())
	var columns: HBoxContainer = HBoxContainer.new()
	columns.name = "InventoryColumns"
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation",22)
	root.add_child(columns)
	var left: VBoxContainer = column(columns,0.24)
	left.name = "EquipmentColumn"
	text(left,"ÉQUIPEMENT PORTÉ",14,GameTheme.GOLD)
	equipment_body = scroll_body(left)
	columns.add_child(VSeparator.new())
	var center: VBoxContainer = column(columns,0.38)
	center.name = "BagColumn"
	text(center,"DANS VOTRE SAC",14,GameTheme.GOLD)
	var filters: HBoxContainer = HBoxContainer.new();center.add_child(filters)
	filters.add_theme_constant_override("separation",6)
	for entry: Array in [["all","Tous"],["staff","Bâtons"],["ring","Anneaux"]]:
		var b: Button = action(filters,entry[1],func()->void:set_filter(entry[0]))
		filter_buttons[entry[0]] = b
	bag_scroll = ScrollContainer.new()
	bag_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	bag_scroll.follow_focus = true
	bag_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center.add_child(bag_scroll)
	bag_grid = GridContainer.new()
	bag_grid.name = "BagGrid"
	bag_grid.columns = 4
	bag_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bag_grid.add_theme_constant_override("h_separation",8)
	bag_grid.add_theme_constant_override("v_separation",8)
	bag_scroll.add_child(bag_grid)
	bag_scroll.resized.connect(fit_grid)
	columns.add_child(VSeparator.new())
	var right: VBoxContainer = column(columns,0.38)
	right.name = "DetailsColumn"
	text(right,"OBJET SÉLECTIONNÉ",14,GameTheme.GOLD)
	detail_header = VBoxContainer.new();right.add_child(detail_header)
	detail_body = scroll_body(right)
	detail_scroll = detail_body.get_parent()
	action_body = VBoxContainer.new();right.add_child(action_body)
	root.add_child(HSeparator.new())
	var footer: HBoxContainer = HBoxContainer.new();root.add_child(footer)
	text(footer,"Sélectionnez un objet pour comparer ses effets.",14,GameTheme.MUTED)
	if selling: action(footer,"Retour à l’échoppe",func()->void:section_requested.emit("merchant"))
	refresh()
	if cells.has(selected_uid): cells[selected_uid].grab_focus()
	GameTheme.enter(frame)

func column(parent: Node, ratio: float) -> VBoxContainer:
	var box: VBoxContainer = VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.size_flags_stretch_ratio = ratio
	parent.add_child(box)
	return box

func scroll_body(parent: Node) -> VBoxContainer:
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(scroll)
	var body: VBoxContainer = VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(body)
	return body

func text(parent: Node, value: String, font_size: int = 16, color: Color = GameTheme.IVORY) -> Label:
	var label: Label = Label.new()
	label.text = value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_color_override("font_color",color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

func action(parent: Node, value: String, callback: Callable) -> Button:
	var button: Button = Button.new()
	button.text = value
	button.custom_minimum_size.y = 42
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size",15)
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.pressed.connect(func()->void:Sound.play("ui");callback.call())
	parent.add_child(button)
	return button

func art(parent: Node, slot: String, height: float) -> TextureRect:
	var picture: TextureRect = TextureRect.new()
	picture.texture = Catalog.texture(slot)
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.custom_minimum_size = Vector2(height,height)
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(picture)
	return picture

func clear(parent: Node) -> void:
	for child: Node in parent.get_children():
		parent.remove_child(child)
		child.queue_free()

func rarity(item: Dictionary) -> Color:
	return [Color("bdc9c9"),Color("78bcd8"),Color("c7a1e5")][clampi(int(item.get("rarity",0)),0,2)]

func slot_name(slot: String) -> String:
	return "Bâton" if slot == "staff" else "Anneau "+slot[-1]

func visible_items() -> Array:
	return State.run.inventory.filter(func(item: Dictionary)->bool:return filter=="all" or item.slot==filter)

func fit_grid() -> void:
	bag_grid.columns = maxi(2,mini(5,int((bag_scroll.size.x-14)/96)))

func set_filter(value: String) -> void:
	filter = value
	bag_scroll.scroll_vertical = 0
	refresh()

func refresh() -> void:
	wallet.text = "%d / 48 objets   ·   %d or" % [State.run.inventory.size(),State.run.gold]
	var visible: Array = visible_items()
	if not visible.any(func(item: Dictionary)->bool:return item.uid==selected_uid):
		selected_uid = "" if visible.is_empty() else visible[0].uid
		choose_target()
	if not selected_uid.is_empty(): State.find_item(selected_uid)["inspected"] = true
	refresh_equipment()
	refresh_grid()
	refresh_details()

func choose_target() -> void:
	var item: Dictionary = State.find_item(selected_uid)
	if item.is_empty(): return
	if item.slot=="staff": target_slot="staff"
	elif target_slot=="staff": target_slot="ring1"
	for slot: String in State.run.equipped:
		if State.run.equipped[slot]==selected_uid: target_slot=slot

func select_item(uid: String) -> void:
	selected_uid = uid
	choose_target()
	State.find_item(uid)["inspected"] = true
	detail_scroll.scroll_vertical = 0
	# Keep grid nodes/focus and scroll position stable while selecting.
	for key: String in cells:
		var cell: Button = cells[key]
		cell.add_theme_stylebox_override("normal",GameTheme.panel(Color("30291e") if key==uid else Color("191a1d"),GameTheme.GOLD if key==uid else rarity(State.find_item(key)).darkened(0.45),8))
		var badge: Label = cell.get_node("Content/Badge")
		badge.text = badge_text(State.find_item(key))
	refresh_details()

func badge_text(item: Dictionary) -> String:
	if item.uid in State.run.equipped.values(): return "ÉQUIPÉ"
	return "NOUVEAU" if not item.get("inspected",false) else RARITIES[clampi(int(item.rarity),0,2)]

func refresh_grid() -> void:
	clear(bag_grid);cells.clear()
	for key: String in filter_buttons:
		filter_buttons[key].add_theme_stylebox_override("normal",GameTheme.panel(Color("34291a") if filter==key else Color("1d1c1a"),GameTheme.GOLD if filter==key else Color("514633"),8))
	var visible: Array = visible_items()
	if visible.is_empty():
		text(bag_grid,"Aucun objet." if not State.run.inventory.is_empty() else "Votre sac est vide.",15,GameTheme.MUTED)
		return
	for item: Dictionary in visible:
		var cell: Button = action(bag_grid,"",func()->void:select_item(item.uid))
		cell.custom_minimum_size = Vector2(88,118)
		cell.name = item.uid
		cell.tooltip_text = item.name+"\n"+RARITIES[clampi(int(item.rarity),0,2)]
		cell.add_theme_stylebox_override("normal",GameTheme.panel(Color("30291e") if selected_uid==item.uid else Color("191a1d"),GameTheme.GOLD if selected_uid==item.uid else rarity(item).darkened(0.45),8))
		var inner: VBoxContainer = VBoxContainer.new()
		inner.name = "Content"
		inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		inner.offset_left=5;inner.offset_right=-5;inner.offset_top=7;inner.offset_bottom=-7
		inner.add_theme_constant_override("separation",3)
		inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_child(inner)
		var badge: Label = text(inner,badge_text(item),10,rarity(item))
		badge.name = "Badge";badge.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		var icon: TextureRect = art(inner,item.slot,64)
		icon.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		var caption: Label = text(inner,"Bâton" if item.slot=="staff" else "Anneau",13)
		caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		cells[item.uid] = cell
	fit_grid()

func refresh_equipment() -> void:
	clear(equipment_body)
	for slot: String in ["staff","ring1","ring2"]:
		var item: Dictionary = State.find_item(State.run.equipped[slot])
		var line: HBoxContainer = HBoxContainer.new();equipment_body.add_child(line)
		art(line,"staff" if slot=="staff" else "ring",58)
		var b: Button = action(line,slot_name(slot)+("\nVide" if item.is_empty() else "\n"+RARITIES[clampi(int(item.rarity),0,2)]),func()->void:
			if filter!="all" and filter!=item.slot: set_filter(item.slot)
			select_item(item.uid))
		b.disabled = item.is_empty()
		b.tooltip_text = item.get("name","Emplacement vide")
		if not item.is_empty():
			for key: String in item.bonuses: text(equipment_body,Equipment.bonus_text(key,item.bonuses[key]),14,rarity(item))
		equipment_body.add_child(HSeparator.new())
	var s: Dictionary = State.stats()
	text(equipment_body,"VOTRE PERSONNAGE",14,GameTheme.GOLD)
	for line: String in ["Vie maximale   %.0f" % s.max_hp,"Mana maximal   %.0f" % s.max_mana,"Mana régénéré   %.2f/s" % s.mana_regen,"Résistance   %.0f %%" % (s.resistance*100)]: text(equipment_body,line,15)

func refresh_details() -> void:
	clear(detail_header);clear(detail_body);clear(action_body)
	var item: Dictionary = State.find_item(selected_uid)
	if item.is_empty():
		text(detail_body,"Sélectionnez un objet dans le sac.",17,GameTheme.MUTED)
		return
	var intro: HBoxContainer = HBoxContainer.new();detail_header.add_child(intro)
	art(intro,item.slot,88)
	var names: VBoxContainer = VBoxContainer.new();names.size_flags_horizontal=Control.SIZE_EXPAND_FILL;intro.add_child(names)
	text(names,RARITIES[clampi(int(item.rarity),0,2)],14,rarity(item))
	text(names,item.name,19)
	for key: String in item.bonuses: text(detail_header,Equipment.bonus_text(key,item.bonuses[key]),16,rarity(item))
	detail_header.add_child(HSeparator.new())
	if item.slot=="ring":
		var targets: HBoxContainer = HBoxContainer.new();detail_header.add_child(targets)
		for slot: String in ["ring1","ring2"]:
			var b: Button = action(targets,"Remplacer anneau "+slot[-1],func()->void:
				target_slot=slot
				refresh_details()
				focus_target.call_deferred())
			b.name = "Target_"+slot
			if target_slot==slot: b.add_theme_stylebox_override("normal",GameTheme.panel(Color("34291a"),GameTheme.GOLD,8))
	else: target_slot="staff"
	var current: Dictionary = State.find_item(State.run.equipped[target_slot])
	var removing: bool = current.get("uid","")==item.uid
	text(detail_body,"Après retrait" if removing else "Remplacement · "+slot_name(target_slot),17,GameTheme.GOLD)
	text(detail_body,"Actuellement : "+current.get("name","emplacement vide"),14,GameTheme.MUTED)
	var comparison: Dictionary = EquipmentPreview.compare(item.uid,target_slot,removing)
	text(detail_body,"AVANT → APRÈS",12,GameTheme.MUTED)
	if comparison.rows.is_empty(): text(detail_body,"Aucun changement effectif : bonus identiques, plafonnés ou déjà actifs.",16)
	for row: Dictionary in comparison.rows:
		var neutral: bool = row.get("neutral",false)
		var color: Color = GameTheme.IVORY if neutral else (GAIN if row.gain else LOSS)
		text(detail_body,row.title,14,GameTheme.MUTED)
		text(detail_body,("" if neutral else ("Gain · " if row.gain else "Perte · "))+row.text,15,color)
	if not State.run.fusion.is_empty(): text(detail_body,"Fusion : ses rangs et spécialisations restent figés à sa création.",13,GameTheme.MUTED)
	text(detail_body,"Valeurs après plafonds. DPS théoriques par ennemi, avant résistance et à mana disponible.",13,GameTheme.MUTED)
	var button: Button
	var action_uid: String = item.uid
	var action_slot: String = target_slot
	if selling:
		button = action(action_body,"Vendre · %d or" % maxi(1,int(item.price/3)),func()->void:
			State.sell(action_uid)
			refresh()
			focus_selection.call_deferred())
		button.disabled = item.uid in State.run.equipped.values()
		if button.disabled:
			for slot: String in State.run.equipped:
				if State.run.equipped[slot]!=item.uid: continue
				action(action_body,"Retirer · "+slot_name(slot),func()->void:
					State.unequip(slot)
					refresh()
					focus_selection.call_deferred())
	elif removing:
		button = action(action_body,"Retirer · "+slot_name(target_slot),func()->void:
			State.unequip(action_slot)
			refresh()
			focus_selection.call_deferred())
	else:
		button = action(action_body,"Équiper le bâton" if target_slot=="staff" else "Équiper — anneau "+target_slot[-1],func()->void:
			State.equip(action_uid,action_slot)
			refresh()
			focus_selection.call_deferred())
	button.name = "InventoryAction"
	button.add_theme_stylebox_override("normal",GameTheme.panel(Color("34291a"),GameTheme.GOLD,12))

func focus_selection() -> void:
	if not is_inside_tree(): return
	if cells.has(selected_uid): cells[selected_uid].grab_focus()
	else: filter_buttons[filter].grab_focus()

func focus_target() -> void:
	if not is_inside_tree(): return
	var target: Node = detail_header.find_child("Target_"+target_slot,true,false)
	if target: target.grab_focus()
