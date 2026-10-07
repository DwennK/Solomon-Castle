class_name GrimoireView
extends Control

signal close_requested
signal section_requested(section: String)

var chapter: String = "primary"
var selected_id: String = ""
var query: String = ""
var listing: VBoxContainer
var list_scroll: ScrollContainer
var detail: VBoxContainer
var detail_scroll: ScrollContainer
var actions: VBoxContainer
var equipped: VBoxContainer
var tabs: Dictionary = {}
var entries: Dictionary = {}
var count: Label
var search_field: LineEdit
var status: Label

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shell: CodexShell=CodexShell.new();shell.section="skills"
	shell.close_requested.connect(func()->void:close_requested.emit())
	shell.section_requested.connect(func(value: String)->void:section_requested.emit(value))
	add_child(shell)
	CodexShell.heading(shell.left,"Grimoire")
	CodexShell.text(shell.left,"Vos arts, classés par discipline.",16,CodexShell.MUTED)
	search_field=CodexShell.search(shell.left,"Rechercher un savoir…")
	search_field.text_changed.connect(func(value: String)->void:
		query=value;list_scroll.scroll_vertical=0;refresh_list())
	var chapters: HBoxContainer=HBoxContainer.new();shell.left.add_child(chapters)
	chapters.add_theme_constant_override("separation",5)
	for entry: Array in [["primary","Magies"],["secondary","Rituels"],["passive","Savoirs"],["fusion","Fusion"]]:
		var tab: Button=CodexShell.button(chapters,entry[1],func()->void:
			chapter=entry[0];list_scroll.scroll_vertical=0;refresh_list())
		tab.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		tabs[entry[0]]=tab
	count=CodexShell.text(shell.left,"",13,CodexShell.MUTED)
	list_scroll=ScrollContainer.new();shell.left.add_child(list_scroll)
	list_scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
	list_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	list_scroll.follow_focus=true
	listing=VBoxContainer.new();list_scroll.add_child(listing)
	listing.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	CodexShell.text(shell.right,"LE SAVOIR EN DÉTAIL",12,CodexShell.MUTED)
	detail_scroll=ScrollContainer.new();shell.right.add_child(detail_scroll)
	detail_scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
	detail_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	detail_scroll.follow_focus=true
	detail=VBoxContainer.new();detail_scroll.add_child(detail)
	detail.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	actions=VBoxContainer.new();shell.right.add_child(actions)
	shell.right.add_child(HSeparator.new())
	equipped=VBoxContainer.new();shell.right.add_child(equipped)
	status=CodexShell.text(shell.footer,"",15,GameTheme.GOLD)
	var hint: Label=CodexShell.text(shell.footer,"Sélectionner pour lire · Échap pour reprendre",14,GameTheme.MUTED)
	hint.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	selected_id=State.run.active
	if not State.run.fusion.is_empty() and selected_id==State.run.fusion.id: chapter="fusion"
	refresh_list()
	if entries.has(selected_id): entries[selected_id].grab_focus()

func clear(parent: Node) -> void:
	for child: Node in parent.get_children():
		parent.remove_child(child);child.queue_free()

func known_ids() -> Array[String]:
	var result: Array[String]=[]
	if chapter=="fusion":
		if not State.run.fusion.is_empty(): result.append(State.run.fusion.id)
	else:
		for id: String in Catalog.ids(chapter):
			if State.rank(id)>0: result.append(id)
	return result

func refresh_list() -> void:
	status.text="Niveau %d · %s" % [State.run.level,Catalog.title(State.run.active) if not State.run.active.is_empty() else "Aucune magie active"]
	clear(listing);entries.clear()
	for key: String in tabs:
		tabs[key].add_theme_stylebox_override("normal",CodexShell.selected_style() if chapter==key else GameTheme.panel(Color("29231f"),Color("68523d"),8))
	var all: Array[String]=known_ids()
	var visible: Array[String]=[]
	for id: String in all:
		if CodexShell.matches_query(Catalog.title(id),query): visible.append(id)
	count.text="%d / %d savoirs" % [visible.size(),all.size()]
	if selected_id not in visible: selected_id="" if visible.is_empty() else visible[0]
	if visible.is_empty():
		CodexShell.text(listing,"Aucun résultat." if not query.is_empty() else ("Les fusions se choisissent aux niveaux multiples de cinq, lorsque deux éléments sont connus." if chapter=="fusion" else "Aucun savoir acquis dans cette discipline."),17,CodexShell.MUTED)
	for id: String in visible:
		var d: ContentDefinition=Catalog.definition(id)
		var suffix: String="ACTIF" if State.run.active==id else ("Rang %d" % State.rank(id) if chapter!="fusion" else "Fusion")
		if chapter=="secondary": suffix="PRÊT" if id in State.secondary_skills() else "EN RÉSERVE"
		var title: String=d.title+"\n"+suffix
		if State.rank(id)>State.learned_rank(id) and chapter!="fusion": title+=" · Équipement : +%d" % (State.rank(id)-State.learned_rank(id))
		var entry: Button=CodexShell.button(listing,title,func()->void:select_skill(id))
		entry.custom_minimum_size.y=76
		entry.alignment=HORIZONTAL_ALIGNMENT_LEFT
		entry.icon=Catalog.skill_texture(id);entry.expand_icon=true
		entry.add_theme_constant_override("icon_max_width",48)
		entry.add_theme_stylebox_override("normal",CodexShell.selected_style() if selected_id==id else GameTheme.panel(Color("30291f"),Color("68523d"),10))
		entries[id]=entry
	refresh_detail()

func select_skill(id: String) -> void:
	selected_id=id
	detail_scroll.scroll_vertical=0
	for key: String in entries:
		entries[key].add_theme_stylebox_override("normal",CodexShell.selected_style() if selected_id==key else GameTheme.panel(Color("30291f"),Color("68523d"),10))
	refresh_detail()

func refresh_detail() -> void:
	clear(detail);clear(actions);clear(equipped)
	refresh_loadout()
	if selected_id.is_empty():
		CodexShell.heading(detail,"Une page à écrire",25)
		CodexShell.text(detail,"Sélectionnez un savoir, ou explorez une autre discipline.",17,CodexShell.MUTED)
		return
	var d: ContentDefinition=Catalog.definition(selected_id)
	var icon: TextureRect=TextureRect.new()
	icon.texture=Catalog.skill_texture(selected_id)
	icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size=Vector2(0,112);detail.add_child(icon)
	CodexShell.heading(detail,d.title,27)
	if d.kind!="fusion":
		CodexShell.text(detail,"Rang %d · Appris : %d · Équipement : +%d" % [State.rank(selected_id),State.learned_rank(selected_id),maxi(0,State.rank(selected_id)-State.learned_rank(selected_id))],14,CodexShell.MUTED)
		if State.rank(selected_id)<State.learned_rank(selected_id): CodexShell.text(detail,"Rang historique conservé : %d · effet à rang unique" % State.learned_rank(selected_id),14,CodexShell.MUTED)
	CodexShell.text(detail,d.description,17)
	detail.add_child(HSeparator.new())
	CodexShell.text(detail,SkillDetails.text(selected_id,false),16)
	if d.kind!="passive": CodexShell.text(detail,"DPS théorique par ennemi, avant résistance et à mana disponible. Portées en unités du monde, limitées par les murs.",13,CodexShell.MUTED)
	if d.kind=="fusion": CodexShell.text(detail,"Figée au niveau %d. Les changements d’équipement n’altèrent pas ses rangs." % State.run.fusion.level,14,CodexShell.MUTED)
	if d.kind in ["primary","fusion"]:
		var activate: Button=CodexShell.button(actions,"Magie active" if State.run.active==selected_id else "Utiliser cette magie",activate_selected)
		activate.disabled=State.run.active==selected_id
		activate.add_theme_stylebox_override("normal",CodexShell.selected_style())
	elif d.kind=="secondary":
		CodexShell.text(actions,"Rituel prêt : utilisez le raccourci indiqué ci-dessous." if selected_id in State.secondary_skills() else "Rituel fourni par l’équipement : emplacements occupés. Les rituels appris sont prioritaires.",15,CodexShell.MUTED)
	else: CodexShell.text(actions,"Savoir passif · effet appliqué automatiquement.",15,CodexShell.MUTED)

func activate_selected() -> void:
	State.run.active=selected_id
	refresh_list()
	if entries.has(selected_id): entries[selected_id].grab_focus()

func refresh_loadout() -> void:
	var ready: Array=State.secondary_skills()
	CodexShell.text(equipped,"RITUELS PRÊTS · %d / %d" % [ready.size(),3 if State.run.level>=20 else 2],12,CodexShell.MUTED)
	var row: HBoxContainer=HBoxContainer.new();equipped.add_child(row)
	for index: int in range(3):
		var id: String=ready[index] if index<ready.size() else ""
		var value: String="Niv. 20" if index==2 and State.run.level<20 else "Libre"
		if not id.is_empty(): value=Controls.caption("secondary_%d" % index)+" · "+Catalog.title(id)
		var slot: Button=CodexShell.button(row,value,func()->void:
			chapter="secondary";query="";selected_id=id
			search_field.text=""
			refresh_list())
		slot.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		slot.disabled=id.is_empty()
		slot.add_theme_font_size_override("font_size",12)
		slot.custom_minimum_size.y=58
		slot.tooltip_text="Consulter le rituel · "+Catalog.title(id) if not id.is_empty() else value
