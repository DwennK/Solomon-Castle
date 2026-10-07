from pathlib import Path
import json
root=Path(__file__).resolve().parents[1]
def write(kind,id,title,desc,values={},icon='',cap=5,level=1,req=''):
 d=root/'resources'/kind;d.mkdir(exist_ok=True)
 def gd(v):
  if isinstance(v,str):return json.dumps(v,ensure_ascii=False)
  if isinstance(v,dict):return '{'+', '.join(gd(k)+': '+gd(x) for k,x in v.items())+'}'
  if isinstance(v,list):return '['+', '.join(map(gd,v))+']'
  if isinstance(v,bool):return str(v).lower()
  return str(v)
 s='[gd_resource type="Resource" script_class="ContentDefinition" load_steps=2 format=3]\n\n[ext_resource type="Script" path="res://scripts/definition.gd" id="1"]\n\n[resource]\nscript = ExtResource("1")\n'
 for k,v in dict(id=id,title=title,description=desc,kind=kind,icon=icon,max_rank=cap,min_level=level,prerequisite=req,values=values).items():s+=f'{k} = {gd(v)}\n'
 (d/(id+'.tres')).write_text(s)
primaries=[('missile','Astral Missile','A homing projectile. +7 damage per rank.',18,6,0.38,False),('fire','Fireball','A powerful projectile. +11 damage per rank.',30,10,0.55,False),('lightning','Lightning','A precise, instant, continuous arc. +15 damage/s per rank.',44,17,0,True),('ice','Ice Stream','A continuous cone that slows enemies. +11 damage/s per rank.',32,14,0,True)]
for id,t,d,damage,mana,cd,ch in primaries:write('primary',id,t,d,dict(damage=damage,mana=mana,cooldown=cd,channel=ch),id,20)
secondary=[('teleport','Teleport','Returns to the last safe room. Costs 10 mana.',10,14,1,3),('shield','Magic Shield','Absorbs 45 damage per rank. Costs 30 mana.',30,22,5,4),('circle','Magic Circle','18 s zone: regeneration and slowing. Radius +25/rank.',35,38,5,3),('freeze','Flash Freeze','Freezes nearby enemies for 2 + rank seconds.',28,24,5,3),('ring_fire','Ring of Fire','Fire wave: 45 damage per rank and knockback.',32,20,5,3),('acid','Acid Rain','7 s zone dealing 14 damage/s per rank.',35,25,5,3),('undead','Turn Undead','Weakens undead and makes them flee for 4 + rank seconds.',24,22,5,3)]
for id,t,d,m,c,cap,level in secondary:write('secondary',id,t,d,dict(mana=m,cooldown=c),{'shield':'missile','circle':'missile','teleport':'portal','freeze':'ice','ring_fire':'fire','acid':'mana','undead':'lightning'}[id],cap,level)
passives=[('multishot','Multishot','One additional projectile; costs +2 mana.','missile',3,2),('potent','Swift Missiles','+20 % speed and stronger homing.','missile',5,2),('explode','Explosion','Explosive impact: radius 60 + 18 per rank.','fire',5,2),('embers','Embers','Three fire embers per rank on impact.','fire',3,3),('chain','Chain Lightning','Hits one additional enemy per rank.','lightning',5,2),('stun','Stun','Lightning interrupts attacks; duration +0.08 s/rank.','lightning',4,3),('cone','Ice Cone','Widens the stream by 0.12 rad and extends its range by 18 per rank.','ice',5,2),('chill','Chilling Wind','Stronger knockback and slowing.','ice',5,2),('life','Vitality','+24 maximum health.','',8,1),('mana','Mana pool','+28 maximum mana.','',8,1),('regen','Mana Channeling','+2.5 mana regenerated per second.','',6,1),('meditation','Meditation','While idle: +3 mana/s and +0.8 health/s per rank.','',5,3),('economy','Battle Mage','−9 % mana cost per rank (minimum 20 %).','',6,2),('haste','Rapid Casting','+12 % projectile cast speed per rank.','',5,5),('power','Siege Mage','+14 % damage per rank.','',6,5),('focus','Focus','−10 % secondary cooldown per rank.','',5,5),('rush','Haste','+7 % movement speed per rank.','',4,3),('resist','Resistance','−7 % damage taken per rank.','',5,4),('reach','Telekinesis','+45 pickup range per rank.','',4,3)]
for id,t,d,req,cap,level in passives:write('passive',id,t,d,{},req or 'book',cap,level,req)
fusions=[('fire_missile','Burning Missile','Explosive homing projectiles.','fire','missile'),('flame_lash','Flame Lash','A continuous burning arc that chains between targets.','fire','lightning'),('steam','Steam Jet','A wide cone that pierces groups.','fire','ice'),('ball_lightning','Ball Lightning','Slow homing orb with electrical pulses and chains.','missile','lightning'),('frost_missile','Frost Missile','A homing volley that bursts and freezes.','missile','ice'),('blizzard','Blizzard Beam','Piercing beam that freezes and chains between targets.','lightning','ice')]
for id,t,d,a,b in fusions:write('fusion',id,t,d,dict(elements=[a,b]),a,1,5)
enemies=[('skeleton','Skeleton',1,35,105,9,'melee'),('archer','Crypt Archer',2,27,83,8,'ranged'),('zombie','Plaguebearer',3,75,58,14,'poison'),('ghoul','Ghoul',4,26,170,7,'dash'),('sorcerer','Necromancer',5,43,72,12,'caster'),('knight','Blackguard',6,110,68,18,'tank'),('imp','Imp',7,35,133,10,'imp'),('ghost','Ghost',8,38,100,10,'ghost'),('king','The Unburied King',9,650,80,22,'boss_king'),('plague','The Bell Eater',10,900,62,24,'boss_plague'),('demon','The Ember Guardian',11,1200,95,28,'boss_demon'),('lich','The Ash Archivist',12,2000,88,30,'boss_lich')]
for id,t,i,hp,speed,damage,behavior in enemies:write('enemy',id,t,'',dict(hp=hp,speed=speed,damage=damage,behavior=behavior,sprite=i,undead=id not in ['imp','demon'],resistance=0.3 if id=='knight' else 0))
for i,(name,stat,value) in enumerate([('of Embers','damage',0.12),('of Clarity','max_mana',24),('of the Rampart','max_hp',22),('of the Spring','mana_regen',2),('of Swift Lightning','cast_speed',0.10),('of Restraint','cost_reduction',0.06),('of Dawn','hp_regen',0.35),('of the Pilgrim','speed',0.06),('of Bones','resistance',0.06),('of Stars','damage',0.18)]):
 write('affix','affix_'+str(i),name,'',dict(stat=stat,amount=value))
for id,t,stat,value in [('ash_staff','Ash Staff','damage',0.06),('crystal_staff','Crystal Staff','max_mana',14),('bone_staff','Bone Staff','mana_regen',1.2),('copper_ring','Copper Ring','max_hp',12),('silver_ring','Silver Ring','cost_reduction',0.03),('onyx_ring','Onyx Ring','resistance',0.04)]:
 write('item',id,t,'',dict(slot='staff' if 'staff' in id else 'ring',stat=stat,amount=value), 'staff' if 'staff' in id else 'ring')
write('progression','campaign','The Tower of Ash','Thirteen floors. Two secondary rituals, then three at level 20.',dict(floors=13,boss_floors=[4,8,11,13],difficulties=['Apprentice','Sorcerer','Archmage','Demigod','Eternal Trial']))
from skill_catalog import apply
apply(root)
paths=sorted((root/'resources').glob('*/*.tres'))
(root/'scripts/content_index.gd').write_text('extends RefCounted\n\nconst ALL: Array[Resource] = [\n'+''.join('\tpreload("res://'+p.relative_to(root).as_posix()+'"),\n' for p in paths)+']\n')
print(len(paths),'definitions')
