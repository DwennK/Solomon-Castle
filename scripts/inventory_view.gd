class_name InventoryView
extends Control

signal close_requested
signal section_requested(section: String)

const GAIN: Color = Color("234e2b")
const LOSS: Color = Color("7c2822")
const RARITIES: Array[String] = ["Enchanted", "Rare", "Epic"]
var selling: bool = false
var selected_uid: String = ""
var filter: String = "all"
var target_slot: String = "ring1"
var query: String = ""
var sort_mode: int = 0
var details_expanded: bool = false
var all_changes: VBoxContainer
var search_field: LineEdit
var result_count: Label
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
	var shell: CodexShell = CodexShell.new()
	shell.section = "inventory"
	shell.close_requested.connect(func()->void:close_requested.emit())
	shell.section_requested.connect(func(value: String)->void:section_requested.emit(value))
	add_child(shell)
	var left: VBoxContainer = shell.left
	left.name = "BagColumn"
	CodexShell.heading(left,"Inventory" if not selling else "Sell to Basile")
	text(left,"WORN EQUIPMENT",12,CodexShell.MUTED)
	equipment_body = VBoxContainer.new()
	equipment_body.name = "EquipmentColumn"
	left.add_child(equipment_body)
	left.add_child(HSeparator.new())
	var tools: HBoxContainer = HBoxContainer.new();left.add_child(tools)
	search_field = CodexShell.search(tools,"Search items…")
	search_field.text_changed.connect(func(value: String)->void:
		query=value
		bag_scroll.scroll_vertical=0
		refresh())
	var sorting: OptionButton = OptionButton.new()
	sorting.name="InventorySort"
	sorting.add_theme_font_size_override("font_size",14)
	for title: String in ["Bag order", "Name", "Rarity"]: sorting.add_item(title)
	sorting.tooltip_text="Sort bag items"
	sorting.item_selected.connect(func(index: int)->void:
		sort_mode=index
		bag_scroll.scroll_vertical=0
		refresh())
	tools.add_child(sorting)
	var filters: HBoxContainer = HBoxContainer.new();left.add_child(filters)
	filters.add_theme_constant_override("separation",6)
	for entry: Array in [["all","All"],["staff","Staves"],["ring","Rings"]]:
		filter_buttons[entry[0]] = action(filters,entry[1],func()->void:set_filter(entry[0]))
	result_count=text(left,"",13,CodexShell.MUTED)
	bag_scroll = ScrollContainer.new()
	bag_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	bag_scroll.follow_focus = true
	bag_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(bag_scroll)
	bag_grid = GridContainer.new()
	bag_grid.name = "BagGrid"
	bag_grid.columns = 4
	bag_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bag_grid.add_theme_constant_override("h_separation",8)
	bag_grid.add_theme_constant_override("v_separation",8)
	bag_scroll.add_child(bag_grid)
	bag_scroll.resized.connect(fit_grid)
	var right: VBoxContainer = shell.right
	right.name = "DetailsColumn"
	text(right,"SELECTED ITEM",12,CodexShell.MUTED)
	detail_header = VBoxContainer.new();right.add_child(detail_header)
	detail_body = scroll_body(right)
	detail_scroll = detail_body.get_parent()
	action_body = VBoxContainer.new();right.add_child(action_body)
	wallet = text(shell.footer,"",15,GameTheme.GOLD)
	var hint: Label=text(shell.footer,"Select to inspect · Esc to resume",14,GameTheme.MUTED)
	hint.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	if selling: action(shell.footer,"Back to the shop",func()->void:section_requested.emit("merchant"))
	refresh()
	if cells.has(selected_uid): cells[selected_uid].grab_focus()

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

func text(parent: Node, value: String, font_size: int = 16, color: Color = CodexShell.INK) -> Label:
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
	return "Staff" if slot == "staff" else "Ring "+slot[-1]

func visible_items() -> Array:
	var result: Array = State.run.inventory.filter(func(item: Dictionary)->bool:
		return (filter=="all" or item.slot==filter) and CodexShell.matches_query(item.name,query))
	if sort_mode==1: result.sort_custom(func(a: Dictionary,b: Dictionary)->bool:return a.name.naturalnocasecmp_to(b.name)<0)
	elif sort_mode==2: result.sort_custom(func(a: Dictionary,b: Dictionary)->bool:return int(a.rarity)>int(b.rarity) if a.rarity!=b.rarity else a.name.naturalnocasecmp_to(b.name)<0)
	return result

func fit_grid() -> void:
	bag_grid.columns = 1 if cells.is_empty() else maxi(2,mini(5,int((bag_scroll.size.x-14)/96)))

func set_filter(value: String) -> void:
	filter = value
	bag_scroll.scroll_vertical = 0
	refresh()

func refresh() -> void:
	wallet.text = "%d / 48 items   ·   %d gold" % [State.run.inventory.size(),State.run.gold]
	var visible: Array = visible_items()
	result_count.text = "%d item%s" % [visible.size(),"s" if visible.size()!=1 else ""]
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
	if item.uid in State.run.equipped.values(): return "EQUIPPED"
	return "NEW" if not item.get("inspected",false) else RARITIES[clampi(int(item.rarity),0,2)]

func refresh_grid() -> void:
	clear(bag_grid);cells.clear()
	for key: String in filter_buttons:
		filter_buttons[key].add_theme_stylebox_override("normal",CodexShell.selected_style() if filter==key else GameTheme.panel(Color("29231f"),Color("68523d"),8))
	var visible: Array = visible_items()
	if visible.is_empty():
		bag_grid.columns=1
		text(bag_grid,"No items match your search." if not State.run.inventory.is_empty() else "Your bag is empty.",15,CodexShell.MUTED)
		return
	for item: Dictionary in visible:
		var cell: Button = action(bag_grid,"",func()->void:select_item(item.uid))
		cell.custom_minimum_size = Vector2(88,132)
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
		var caption: Label = text(inner,item.name,12,GameTheme.IVORY)
		caption.max_lines_visible=2
		caption.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
		caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		cells[item.uid] = cell
	fit_grid()

func refresh_equipment() -> void:
	clear(equipment_body)
	var row: HBoxContainer=HBoxContainer.new();equipment_body.add_child(row)
	for slot: String in ["staff","ring1","ring2"]:
		var item: Dictionary = State.find_item(State.run.equipped[slot])
		var b: Button = action(row,slot_name(slot)+("\nEmpty" if item.is_empty() else "\n"+RARITIES[clampi(int(item.rarity),0,2)]),func()->void:
			query="";search_field.text=""
			if filter!="all" and filter!=item.slot: filter=item.slot
			selected_uid=item.uid
			refresh()
			select_item(item.uid))
		b.icon=Catalog.texture("staff" if slot=="staff" else "ring")
		b.expand_icon=true;b.add_theme_constant_override("icon_max_width",30)
		b.custom_minimum_size.y=64
		b.disabled = item.is_empty()
		b.tooltip_text = item.get("name","Empty slot")
	var stats: Dictionary=State.stats()
	text(equipment_body,"Max. health %.0f · Max. mana %.0f\nRegeneration %.2f mana/s · Resistance %.0f %%" % [stats.max_hp,stats.max_mana,stats.mana_regen,stats.resistance*100],14,CodexShell.MUTED)

func refresh_details() -> void:
	clear(detail_header);clear(detail_body);clear(action_body)
	var item: Dictionary = State.find_item(selected_uid)
	if item.is_empty():
		text(detail_body,"Select an item from your bag.",17,CodexShell.MUTED)
		return
	var intro: HBoxContainer = HBoxContainer.new();detail_header.add_child(intro)
	art(intro,item.slot,72)
	var names: VBoxContainer = VBoxContainer.new();names.size_flags_horizontal=Control.SIZE_EXPAND_FILL;intro.add_child(names)
	text(names,RARITIES[clampi(int(item.rarity),0,2)],14,rarity(item).darkened(0.58))
	# Generated catalogue names already contain every bonus; print those once below.
	var display_name: String = item.name
	if display_name==Equipment.item_name(item.slot,item.bonuses): display_name="Staff" if item.slot=="staff" else "Ring"
	var title: Label = text(names,display_name,22)
	title.tooltip_text=item.name
	title.mouse_filter=Control.MOUSE_FILTER_PASS
	title.add_theme_font_override("font",GameTheme.TITLE)
	var bonuses: Array[String] = []
	for key: String in item.bonuses: bonuses.append(Equipment.bonus_text(key,item.bonuses[key]))
	text(detail_header," · ".join(bonuses),15,CodexShell.INK)
	detail_header.add_child(HSeparator.new())
	if item.slot=="ring":
		var targets: HBoxContainer = HBoxContainer.new();detail_header.add_child(targets)
		for slot: String in ["ring1","ring2"]:
			var b: Button = action(targets,"Ring "+slot[-1],func()->void:
				target_slot=slot
				refresh_details()
				focus_target.call_deferred())
			b.name = "Target_"+slot
			if target_slot==slot: b.add_theme_stylebox_override("normal",GameTheme.panel(Color("34291a"),GameTheme.GOLD,8))
	else: target_slot="staff"
	var current: Dictionary = State.find_item(State.run.equipped[target_slot])
	var removing: bool = current.get("uid","")==item.uid
	var comparison: Dictionary = EquipmentPreview.compare(item.uid,target_slot,removing)
	var summary: Dictionary = EquipmentPreview.compact(comparison)
	text(detail_body,"IF YOU REMOVE IT" if removing else "IF YOU EQUIP IT",13,CodexShell.MUTED)
	if not summary.active.is_empty(): text(detail_body,"Active magic · "+Catalog.title(summary.active),15,CodexShell.INK)
	var metrics: VBoxContainer = VBoxContainer.new();detail_body.add_child(metrics)
	metrics.name="CompactMetrics"
	metrics.add_theme_constant_override("separation",7)
	for row: Dictionary in summary.metrics: compact_row(metrics,row)
	if not summary.effects.is_empty():
		detail_body.add_child(HSeparator.new())
		text(detail_body,"EFFECTS & SYNERGIES",12,CodexShell.MUTED)
		var effects: VBoxContainer = VBoxContainer.new();detail_body.add_child(effects)
		effects.name="CompactEffects"
		effects.add_theme_constant_override("separation",7)
		for row: Dictionary in summary.effects: compact_row(effects,row)
	if summary.metrics.is_empty() and summary.effects.is_empty():
		text(detail_body,"More effects in the details." if not comparison.rows.is_empty() else "No effective change.",15,CodexShell.MUTED)
	if not comparison.rows.is_empty():
		var toggle: Button = action(detail_body,"",func()->void:pass)
		toggle.name="ToggleChanges"
		toggle.toggle_mode=true
		toggle.button_pressed=details_expanded
		toggle.custom_minimum_size.y=34
		toggle.text=("▾" if details_expanded else "▸")+" All changes"
		toggle.add_theme_stylebox_override("normal",GameTheme.panel(Color(0,0,0,0),Color("84694c"),6))
		toggle.add_theme_stylebox_override("pressed",GameTheme.panel(Color(0,0,0,0),Color("84694c"),6))
		for state: String in ["font_color","font_pressed_color"]: toggle.add_theme_color_override(state,CodexShell.INK)
		all_changes=VBoxContainer.new();detail_body.add_child(all_changes)
		all_changes.name="AllChanges"
		all_changes.visible=details_expanded
		toggle.toggled.connect(func(expanded: bool)->void:
			details_expanded=expanded
			all_changes.visible=expanded
			toggle.text=("▾" if expanded else "▸")+" All changes")
		for row: Dictionary in comparison.rows:
			var neutral: bool = row.get("neutral",false)
			var color: Color = CodexShell.INK if neutral else (GAIN if row.gain else LOSS)
			text(all_changes,row.title,13,CodexShell.MUTED)
			text(all_changes,("" if neutral else ("Gain · " if row.gain else "Loss · "))+row.text,14,color)
		text(all_changes,"Values after caps. Theoretical DPS per enemy, before resistance and with mana available. Volleys and conditional effects are detailed separately.",13,CodexShell.MUTED)

	var button: Button
	var action_uid: String = item.uid
	var action_slot: String = target_slot
	if selling:
		button = action(action_body,"Sell · %d gold" % maxi(1,int(item.price/3)),func()->void:
			State.sell(action_uid)
			refresh()
			focus_selection.call_deferred())
		button.disabled = item.uid in State.run.equipped.values()
		if button.disabled:
			for slot: String in State.run.equipped:
				if State.run.equipped[slot]!=item.uid: continue
				action(action_body,"Remove · "+slot_name(slot),func()->void:
					State.unequip(slot)
					refresh()
					focus_selection.call_deferred())
	elif removing:
		button = action(action_body,"Remove · "+slot_name(target_slot),func()->void:
			State.unequip(action_slot)
			refresh()
			focus_selection.call_deferred())
	else:
		button = action(action_body,"Equip staff" if target_slot=="staff" else "Equip — ring "+target_slot[-1],func()->void:
			State.equip(action_uid,action_slot)
			refresh()
			focus_selection.call_deferred())
	button.name = "InventoryAction"
	button.add_theme_stylebox_override("normal",CodexShell.selected_style())

func focus_selection() -> void:
	if not is_inside_tree(): return
	if cells.has(selected_uid): cells[selected_uid].grab_focus()
	else: filter_buttons[filter].grab_focus()

func focus_target() -> void:
	if not is_inside_tree(): return
	var target: Node = detail_header.find_child("Target_"+target_slot,true,false)
	if target: target.grab_focus()

func compact_row(parent: Node, row: Dictionary) -> void:
	var line: HBoxContainer = HBoxContainer.new();parent.add_child(line)
	line.add_theme_constant_override("separation",12)
	line.tooltip_text=row.get("tooltip",row.title+" · "+row.text)
	line.focus_mode=Control.FOCUS_ALL
	line.mouse_filter=Control.MOUSE_FILTER_STOP
	var title: Label=text(line,row.title,15,CodexShell.MUTED)
	title.size_flags_stretch_ratio=1.0
	var value: Label=text(line,row.text,16,CodexShell.INK if row.get("neutral",false) else (GAIN if row.gain else LOSS))
	value.size_flags_stretch_ratio=1.15
	value.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	# Tooltip values must also be available to keyboard users.
	var exact: Label=text(parent,line.tooltip_text,13,CodexShell.MUTED)
	exact.visible=false
	line.focus_entered.connect(func()->void:exact.show())
	line.focus_exited.connect(func()->void:exact.hide())
