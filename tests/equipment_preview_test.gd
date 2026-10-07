extends Node

var errors: Array[String] = []
var checks: int = 0
var emitted: int = 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		errors.append(message)
		push_error(message)

func item(bonuses: Dictionary, slot: String = "ring") -> Dictionary:
	State.run.serial += 1
	var result: Dictionary = {"uid":"preview_%d" % State.run.serial,"name":"Test","slot":slot,"rarity":2,"bonuses":bonuses,"price":300}
	State.run.inventory.append(result)
	return result

func parity(uid: String, slot: String, remove: bool = false) -> Dictionary:
	var original: Dictionary = State.run.duplicate(true)
	var serialized: String = JSON.stringify(State.run)
	var signals_before: int = emitted
	var result: Dictionary = EquipmentPreview.compare(uid,slot,remove)
	check(JSON.stringify(State.run)==serialized,"Preview never changes live run, vitals, skills or fusion")
	check(emitted==signals_before,"Preview emits no live State signals")
	check(result.before==EquipmentPreview.capture(State),"Before equals actual state")
	if remove: State.unequip(slot)
	else: State.equip(uid,slot)
	check(result.after==EquipmentPreview.capture(State),"Preview equals actual equip/unequip including combat")
	State.run = original
	return result

func _ready() -> void:
	if not State.qa:
		get_tree().quit(1)
		return
	State.changed.connect(func()->void:emitted+=1)
	State.fresh(771)
	State.learn("missile");State.learn("shield")
	State.run.skills.life=2;State.run.skills.mana=1;State.run.skills.regen=2
	var all: Dictionary = item({"all_skills":2},"staff")
	var p: Dictionary = parity(all.uid,"staff")
	check(p.after.stats.max_hp==206 and p.after.stats.max_mana==184,"All-skills changes effective health and mana")
	check(p.after.stats.mana_regen==17.5,"All-skills changes actual mana regeneration")
	check(p.after.attacks.missile.damage>p.before.attacks.missile.damage,"Skill bonuses change real spell damage")
	check(p.after.attacks.shield.effect.contains("135"),"Shield rank changes real absorption")
	check(p.after.ranks.ice==0,"All-skills does not grant unknown skills")
	State.run.skills.economy=9;State.run.skills.resist=12;State.run.skills.shield=11
	p=parity(all.uid,"staff")
	check(p.before.stats.cost_reduction==0.8 and p.after.stats.cost_reduction==0.8,"Mana reduction stays capped at 80 percent")
	check(p.before.stats.resistance==0.75 and p.after.stats.resistance==0.75,"Damage reduction stays capped at 75 percent")
	check(p.after.ranks.shield==11,"Equipment skill rank cap is respected")
	check(not p.rows.any(func(row: Dictionary)->bool:return row.title.begins_with("Offensive mana cost reduction") and not row.get("neutral",false)),"No false gain for an already capped stat")
	State.fresh(772);State.learn("fire");State.learn("missile");State.learn("fire_missile")
	var frozen: Dictionary=State.run.fusion.duplicate(true)
	var spell: Dictionary=item({"skill:fire":2,"skill:explode":2})
	p=parity(spell.uid,"ring2")
	check(p.before.attacks.fire_missile==p.after.attacks.fire_missile,"Existing fusion keeps frozen ranks and specializations")
	check(State.run.fusion==frozen,"Fusion snapshot untouched")
	check(p.after.attacks.fire.damage>p.before.attacks.fire.damage,"Ordinary primary gets skill and splash changes")
	var general: Dictionary=item({"flat_damage":7,"cast_speed":0.5})
	p=parity(general.uid,"ring1")
	check(p.after.attacks.fire_missile.dps>p.before.attacks.fire_missile.dps,"General gear bonuses still affect frozen fusion")
	State.fresh(773);State.learn("shield")
	var focus: Dictionary=item({"grant:mental_focus":1,"grant:meditation":1,"mana_recovery":1.0})
	var duplicate: Dictionary=item({"grant:mental_focus":1})
	State.equip(focus.uid,"ring1")
	p=parity(duplicate.uid,"ring2")
	check(p.after.attacks.shield.cooldown==p.before.attacks.shield.cooldown,"Granted focus cannot stack")
	p=parity(duplicate.uid,"ring1")
	check(p.after.stats.mana_regen==7.5 and not p.after.stats.meditation,"Replacing ring correctly loses regeneration and meditation")
	p=parity(focus.uid,"ring1",true)
	check(p.after.attacks.shield.cooldown==2*p.before.attacks.shield.cooldown,"Removal previews lost ritual cooldown benefit")
	State.fresh(774);State.learn("teleport");State.learn("freeze")
	var granted: Dictionary=item({"skill:shield":2,"skill:lightning":1})
	p=parity(granted.uid,"ring1")
	check(p.after.active=="lightning","New temporary primary becomes active")
	check(not p.after.attacks.has("shield") and p.after.secondary.size()==2,"Granted ritual cannot bypass full ritual slots")
	check(p.rows.any(func(row: Dictionary)->bool:return row.text.contains("slots are occupied")),"Full ritual slots explained")
	State.run.level=20
	p=parity(granted.uid,"ring2")
	check(p.after.attacks.has("shield"),"Third ritual slot grants real shield availability")
	State.equip(granted.uid,"ring1")
	var other: Dictionary=item({"xp_bonus":1.0})
	State.equip(other.uid,"ring2")
	p=parity(granted.uid,"ring2")
	check(p.after.stats.xp_bonus==0 and p.after.ranks.lightning==1,"Moving a worn ring removes destination without double-counting")
	State.fresh(775);State.run.skills.poison_resist=4
	var poison: Dictionary=item({"poison_resistance":0.8})
	p=parity(poison.uid,"ring1")
	check(is_equal_approx(p.after.stats.poison_resistance,0.87),"Poison resistance combines multiplicatively with skills")
	# Exercise every recipe against both occupied ring slots, including losses.
	State.fresh(776);State.learn("missile");State.learn("fire");State.learn("shield")
	State.run.skills.regen=3;State.run.skills.power=2;State.run.skills.economy=8
	State.equip(item({"mana_recovery":1.0,"skill:life":2}).uid,"ring1")
	State.equip(item({"grant:mental_focus":1,"xp_bonus":1.0}).uid,"ring2")
	var rng: RandomNumberGenerator = RandomNumberGenerator.new();rng.seed=93
	for template: Dictionary in Equipment.templates():
		var gear: Dictionary=State.make_equipment(template,rng)
		State.run.inventory.append(gear)
		for slot: String in (["staff"] if gear.slot=="staff" else ["ring1","ring2"]): parity(gear.uid,slot)
		State.run.inventory.erase(gear)
	var report: Dictionary={"checks":checks,"errors":errors}
	var file: FileAccess=FileAccess.open("res://outputs/equipment-preview-tests.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"));file.close()
	print("EQUIPMENT_PREVIEW ",JSON.stringify(report))
	get_tree().quit(0 if errors.is_empty() else 1)
