extends Node

var checks: int = 0
var failures: Array[String] = []

func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok: failures.append(description); push_error(description)

func _ready() -> void:
	if not State.qa: get_tree().quit(1); return
	State.save_path = "user://qa_english.json"
	check(TranslationServer.get_locale().begins_with("en"),"English is used regardless of system language")
	check(OS.get_user_data_dir().ends_with("Godot/app_userdata/La Tour des Cendres"),"Historical save directory is preserved")
	check(ProjectSettings.get_setting("application/config/name")=="The Tower of Ash","English window title")
	check(Catalog.title("fire")=="Fireball" and Catalog.title("lich")=="The Ash Archivist","English spell and boss names")
	State.fresh(1907); State.learn("fire")
	var item: Dictionary = {"uid":"legacy_staff","name":"Bâton · +3 dégâts fixes","slot":"staff","rarity":0,"price":50,"bonuses":{"flat_damage":3}}
	State.run.inventory.append(item)
	State.run.equipped.staff = item.uid
	State.run.shop = [item.duplicate(true)]
	State.run.shop[0].uid = "legacy_shop"
	var floor_data: Dictionary = Dungeon.generate(1907,1)
	floor_data.loot = [{"kind":"item","item":item.duplicate(true),"pos":floor_data.entry}]
	State.run.floors["1"] = floor_data
	State.mark_checkpoint("Arrivée dans l’étage")
	var before: Dictionary = JSON.parse_string(JSON.stringify(State.run))
	check(State.save_game() and State.load_game(),"Legacy campaign loads from the normal save path")
	for saved: Dictionary in [State.run,State.checkpoint]:
		check(saved.inventory[0].name=="Staff · +3 flat damage","Saved inventory name translated")
		check(saved.shop[0].name=="Staff · +3 flat damage","Saved merchant name translated")
		check(saved.floors["1"].loot[0].item.name=="Staff · +3 flat damage","Saved floor loot name translated")
		check(saved.checkpoint_info.reason=="Floor entry","Saved checkpoint reason translated")
		check(saved.inventory[0].uid==before.inventory[0].uid and saved.inventory[0].bonuses==before.inventory[0].bonuses,"Item identity and bonuses preserved")
		check(saved.equipped==before.equipped and saved.skills==before.skills and saved.gold==before.gold,"Equipment, skills and currency preserved")
	var legacy: Dictionary = {"name":"Bâton de cristal de braise"}
	LegacyEnglish.translate_item(legacy)
	check(legacy.name=="Crystal Staff of Embers","Pre-catalogue affix names translated")
	var translated: String = JSON.stringify(State.run)
	LegacyEnglish.normalize(State.run)
	check(translated==JSON.stringify(State.run),"Save normalization is idempotent")
	check(State.save_game() and State.load_game(),"English campaign saves and reloads")
	print("ENGLISH_QA ",JSON.stringify({"checks":checks,"failures":failures,"user_data_dir":OS.get_user_data_dir()}))
	Sound.stop_all()
	get_tree().quit(0 if failures.is_empty() else 1)
