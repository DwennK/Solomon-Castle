extends Node

var errors: Array[String] = []
var checks: int = 0

func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		errors.append(description)
		push_error(description)

func item(bonuses: Dictionary, slot: String = "ring") -> Dictionary:
	State.run.serial += 1
	var result: Dictionary = {"uid":"equipment_test_%d"%State.run.serial,"name":"Objet de test","slot":slot,"rarity":2,"bonuses":bonuses,"price":300}
	State.run.inventory.append(result)
	return result

func wear(bonuses: Dictionary, slot: String = "ring1") -> Dictionary:
	var result: Dictionary = item(bonuses,"staff" if slot=="staff" else "ring")
	check(State.equip(result.uid,slot),"Equip "+str(bonuses))
	return result

func _ready() -> void:
	if not State.qa:
		get_tree().quit(1)
		return
	call_deferred("run_tests")

func run_tests() -> void:
	State.save_path="user://qa_equipment.json"
	retired_xp_checks()
	State.fresh(903)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed=913
	var templates: Array[Dictionary] = Equipment.templates()
	check(templates.size()==92,"92 equipment recipes after removing XP rings")
	var counts: Dictionary = {}
	for template: Dictionary in templates:
		check(not template.bonuses.has("xp_bonus"),"No XP recipe: "+template.id)
		var generated: Dictionary = State.make_equipment(template,rng,5)
		counts[template.slot+str(template.rarity)] = int(counts.get(template.slot+str(template.rarity),0))+1
		for key: String in generated.bonuses:
			var bounds: Variant = template.bonuses[key]
			check((generated.bonuses[key]>=bounds[0] and generated.bonuses[key]<=bounds[1]) if bounds is Array else generated.bonuses[key]==bounds,"Roll within recipe: "+template.id+" "+key)
		check(not generated.name.contains("skill:") and not generated.name.contains("grant:"),"French equipment name")
	check(counts=={"staff0":4,"staff1":21,"staff2":30,"ring0":5,"ring1":20,"ring2":12},"Slot and rarity catalogue counts")
	var seeded_a: Dictionary = State.make_item(450,5)
	var seeded_b: Dictionary = State.make_item(450,5)
	check(seeded_a.bonuses==seeded_b.bonuses and seeded_a.template==seeded_b.template and seeded_a.uid!=seeded_b.uid,"Seeded loot is deterministic with unique ownership")
	State.fresh(903)
	var baseline: Dictionary = State.stats()
	var a: Dictionary = wear({"xp_bonus":0.5,"mana_recovery":0.75})
	var b: Dictionary = wear({"xp_bonus":0.5,"mana_recovery":0.75},"ring2")
	check(is_equal_approx(State.stats().mana_regen,18.75),"Two rings stack recovery additively")
	State.add_xp(10)
	check(State.run.xp==10,"Legacy XP bonuses cannot multiply rewards")
	State.unequip("ring1");State.unequip("ring2")
	check(State.stats()==baseline,"Unequip restores exact baseline")
	wear({"gold_bonus":5.0},"staff")
	State.add_gold(10)
	check(State.run.gold==200,"500 percent extra gold means six times the reward")
	check(State.sell(a.uid) and State.run.gold==300,"Sale proceeds never multiplied by gold find")
	State.fresh(904)
	State.learn("fire");State.learn("missile");State.learn("fire_missile")
	var fusion_before: Dictionary = State.run.fusion.duplicate(true)
	var combat: CombatSystem = CombatSystem.new()
	var damage: float = combat.profile("fire_missile").damage
	wear({"skill:fire":2,"all_skills":1})
	check(State.rank("fire")==4 and State.learned_rank("fire")==1,"Effective and learned ranks separated")
	check(State.rank("missile")==2 and State.rank("ice")==0,"All skills improves learned spells only")
	check(combat.profile("fire_missile").damage==damage,"Equipment ranks do not alter an existing fusion")
	check(State.run.fusion==fusion_before,"Existing fusion snapshot remains unchanged when equipping")
	State.learn("fire")
	State.unequip("ring1")
	check(State.rank("fire")==2,"Learning with gear does not bake in its ranks")
	check(combat.profile("fire_missile").damage==damage,"Removing gear restores fused spell snapshot")
	State.run.skills.fire=11
	wear({"skill:fire":2})
	check("fire" in State.eligible(24),"Gear does not block earned rank progression")
	State.fresh(905)
	wear({"skill:lightning":2})
	check(State.run.active=="lightning" and State.run.skills.is_empty(),"Equipment grants a temporary primary")
	check("blizzard" not in State.eligible(5),"Temporary primary cannot permanently unlock a fusion")
	State.unequip("ring1")
	check(State.run.active.is_empty(),"Unavailable equipped primary cleared on removal")
	wear({"skill:shield":1})
	check(State.secondary_skills()==["shield"] and State.run.secondary.is_empty(),"Equipment grants a temporary ritual")
	State.learn("teleport");State.learn("freeze")
	check(State.secondary_skills()==["teleport","freeze"],"Gear cannot bypass two ritual slots")
	State.run.level=20
	check(State.secondary_skills()==["teleport","freeze","shield"],"Third temporary ritual unlocks at level 20")
	State.unequip("ring1")
	check(State.secondary_skills()==["teleport","freeze"],"Temporary ritual disappears without altering learned rituals")
	State.run.skills.shield=10
	wear({"skill:shield":2,"all_skills":3})
	check(State.rank("shield")==11,"Shield equipment rank cap")
	State.fresh(906)
	State.learn("missile")
	var original: Dictionary = combat.profile("missile")
	wear({"flat_damage":15,"cast_speed":1.5})
	check(is_equal_approx(combat.profile("missile").damage,original.damage+15),"Flat damage reaches spell profile")
	check(is_equal_approx(combat.profile("missile").cooldown,original.cooldown/2.5),"150 percent cast speed reaches cadence")
	check(combat.secondary_profile("freeze").damage==23,"Flat damage reaches offensive rituals")
	State.unequip("ring1")
	var cooldown: float = combat.secondary_profile("shield").cooldown
	wear({"grant:mental_focus":1})
	wear({"grant:mental_focus":1},"ring2")
	check(combat.secondary_profile("shield").cooldown==cooldown/2,"Mental focus is binary and halves ritual cooldown")
	State.fresh(907)
	wear({"grant:meditation":1,"mana_recovery":1.0},"staff")
	wear({"grant:reach":1})
	wear({"poison_resistance":0.8,"hp_recovery":3.0},"ring2")
	var world: GameWorld = load("res://scenes/world.tscn").instantiate()
	add_child(world)
	world.player.qa_controlled=true
	world.player.set_physics_process(false)
	world.set_process(false);world.set_physics_process(false)
	State.run.mp=0
	world.player.resting=2
	world.player._physics_process(0.1)
	check(is_equal_approx(State.run.mp,6.0),"Granted meditation quadruples actual resting mana regeneration")
	check(world.player.cached_stats.pickup_radius==260,"Granted telekinesis increases real pickup range")
	world.loot=[{"kind":"gold","amount":10,"pos":Dungeon.pair(world.player.position+Vector2(200,0))}]
	world.collect_loot()
	check(world.loot.is_empty() and State.run.gold==150,"Telekinesis collects actual distant loot")
	check(is_equal_approx(State.stats().hp_regen,0.48),"Life recovery percentage applies to base regeneration")
	State.run.hp=100
	world.player.invulnerable=0
	world.player.shield=100
	world.player.take_damage(20,"poison")
	check(is_equal_approx(State.run.hp,96) and world.player.shield==100,"Poison reduction applies and poison bypasses shield")
	world.player.invulnerable=0;world.player.shield=0
	world.player.take_damage(20)
	check(is_equal_approx(State.run.hp,76),"Poison resistance does not reduce ordinary attacks")
	world.player.invulnerable=0
	world.hazard(world.player.position,60,20,0,Color.GREEN,3,"poison")
	world.update_zones(0.1)
	check(is_equal_approx(State.run.hp,72),"Real poison hazard carries its damage type")
	world.zones.clear()
	var restored: Dictionary = State.stats()
	State.mark_checkpoint()
	check(State.save_game(),"Save new equipment")
	State.fresh(1)
	check(State.load_game() and State.stats()==restored,"Equipment and effects survive disk round trip")
	State.unequip("ring1");State.die()
	check(State.stats()==restored,"Checkpoint restores equipment and effects")
	world.free()
	State.fresh(908)
	wear({"damage":0.12,"mana_regen":2.0},"staff")
	check(State.save_game() and State.load_game(),"Legacy item format remains loadable")
	check(is_equal_approx(State.stats().damage,1.12) and State.stats().mana_regen==9.5,"Legacy additive stat semantics preserved")
	var report: Dictionary = {"checks":checks,"errors":errors,"recipes":templates.size()}
	DirAccess.make_dir_recursive_absolute("res://outputs")
	var file: FileAccess = FileAccess.open("res://outputs/equipment-tests.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"));file.close()
	print("EQUIPMENT_TEST ",JSON.stringify(report))
	get_tree().quit(0 if errors.is_empty() else 1)

func retired_xp_checks() -> void:
	State.fresh(902)
	var mixed: Dictionary = wear({"xp_bonus":1.0,"mana_recovery":0.75})
	var plain: Dictionary = wear({"xp_bonus":0.5},"ring2")
	mixed.name="Anneau · +100 % expérience / +75 % régénération de mana"
	plain.name="Anneau · +50 % expérience"
	State.run.shop=[plain.duplicate(true)]
	State.run.floors["1"]=Dungeon.generate(902,1)
	State.run.floors["1"].loot=[{"kind":"item","item":mixed.duplicate(true),"pos":[500,500]}, {"kind":"item","item":plain.duplicate(true),"pos":[550,500]}, {"kind":"gold","amount":10,"pos":[600,500]}]
	check(not State.stats().has("xp_bonus") and not State.equipment_bonuses().has("xp_bonus"),"Retired XP effect absent from effective stats even before migration")
	var preview: Dictionary = EquipmentPreview.compare(plain.uid,"ring2",true)
	check(preview.rows.is_empty(),"Removing an old XP-only ring has no fake comparison bonus")
	State.add_xp(53)
	check(State.run.level==2 and State.run.xp==0 and State.run.pending==[2],"Normal XP threshold and level offer are unchanged with legacy rings")
	State.run.xp=12
	State.mark_checkpoint()
	var mixed_uid: String = mixed.uid
	check(State.save_game(),"Write legacy XP inventory, shop, floor loot and checkpoint")
	State.fresh(1)
	check(State.load_game(),"Load legacy XP save")
	check(State.run.level==2 and State.run.xp==12 and State.run.pending.size()==1 and int(State.run.pending[0])==2,"Migration preserves earned XP, levels and pending choices")
	check(State.run.equipped.ring1==mixed_uid and State.run.equipped.ring2.is_empty() and State.run.inventory.size()==1,"Migration deletes XP-only ring and frees its slot while preserving mixed ring")
	for saved: Dictionary in [State.run,State.checkpoint]:
		var items: Array = saved.inventory+saved.shop+[saved.floors["1"].loot[0].item]
		for gear: Dictionary in items:
			check(not gear.bonuses.has("xp_bonus") and not gear.name.contains("expérience"),"XP effect and label removed from every saved item location")
		check(saved.inventory[0].bonuses=={"mana_recovery":0.75},"Migration keeps other item effects")
		check(saved.inventory.size()==1 and saved.shop.is_empty() and saved.equipped.ring2.is_empty(),"XP-only inventory and shop items deleted, including checkpoint slots")
		check(saved.floors["1"].loot.size()==2 and saved.floors["1"].loot[1].kind=="gold","XP-only ground loot deleted without touching gold or mixed items")
		check(saved.inventory[0].price==300,"Remaining item value is preserved")
	var migrated: Dictionary = State.run.duplicate(true)
	check(State.save_game() and State.load_game() and State.run==migrated,"Migration survives a second save/load unchanged")
	State.die()
	check(State.find_item(plain.uid).is_empty() and State.run.equipped.ring2.is_empty(),"Checkpoint restore cannot resurrect deleted XP items")
	State.add_xp(10)
	check(State.run.xp==22,"Restored checkpoint keeps normal XP awards")
	check(not State.equip(plain.uid,"ring2") and not State.sell(plain.uid),"Deleted XP ring cannot be equipped or sold")
