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
primaries=[('missile','Projectile astral','Projectile guidé vers une cible. +7 dégâts par rang.',18,6,0.38,False),('fire','Boule de feu','Projectile puissant. +11 dégâts par rang.',30,10,0.55,False),('lightning','Éclair','Arc continu, précis et instantané. +15 dégâts/s par rang.',44,17,0,True),('ice','Jet de glace','Cône continu qui ralentit les ennemis. +11 dégâts/s par rang.',32,14,0,True)]
for id,t,d,damage,mana,cd,ch in primaries:write('primary',id,t,d,dict(damage=damage,mana=mana,cooldown=cd,channel=ch),id,20)
secondary=[('teleport','Téléportation','Vers la dernière salle sûre. Coût 10 mana.',10,14,1,3),('shield','Bouclier magique','Absorbe 45 dégâts par rang. Coût 30 mana.',30,22,5,4),('circle','Cercle magique','Zone de 18 s : régénération et ralentissement. Rayon +25/rang.',35,38,5,3),('freeze','Gel soudain','Gèle les ennemis proches pendant 2 + rang secondes.',28,24,5,3),('ring_fire','Anneau de feu','Onde de feu : 45 dégâts par rang et recul.',32,20,5,3),('acid','Pluie acide','Zone de 7 s infligeant 14 dégâts/s par rang.',35,25,5,3),('undead','Renvoi des morts','Affaiblit les morts-vivants et les fait fuir 4 + rang secondes.',24,22,5,3)]
for id,t,d,m,c,cap,level in secondary:write('secondary',id,t,d,dict(mana=m,cooldown=c),{'shield':'missile','circle':'missile','teleport':'portal','freeze':'ice','ring_fire':'fire','acid':'mana','undead':'lightning'}[id],cap,level)
passives=[('multishot','Projectiles multiples','Un projectile supplémentaire ; coût +2 mana.','missile',3,2),('potent','Projectiles véloces','+20 % vitesse, poursuite plus vive.','missile',5,2),('explode','Explosion','Impact explosif : rayon 60 + 18 par rang.','fire',5,2),('embers','Braises','Trois éclats de feu par rang à l’impact.','fire',3,3),('chain','Chaîne électrique','Un ennemi supplémentaire touché par rang.','lightning',5,2),('stun','Étourdissement','Les éclairs interrompent les attaques ; durée +0,08 s/rang.','lightning',4,3),('cone','Cône de glace','Élargit le jet de 0,12 rad et sa portée de 18 par rang.','ice',5,2),('chill','Vent glacial','Recul et ralentissement renforcés.','ice',5,2),('life','Vitalité','+24 points de vie maximum.','',8,1),('mana','Réserve de mana','+28 points de mana maximum.','',8,1),('regen','Canalisation du mana','+2,5 mana régénéré par seconde.','',6,1),('meditation','Méditation','Au repos : +3 mana/s et +0,8 vie/s par rang.','',5,3),('economy','Mage de bataille','−9 % coût de mana par rang (minimum 20 %).','',6,2),('haste','Incantation rapide','+12 % cadence des projectiles par rang.','',5,5),('power','Mage de siège','+14 % dégâts par rang.','',6,5),('focus','Concentration','−10 % temps de recharge secondaire par rang.','',5,5),('rush','Célérité','+7 % vitesse de déplacement par rang.','',4,3),('resist','Résistance','−7 % dégâts subis par rang.','',5,4),('reach','Télékinésie','+45 portée de ramassage par rang.','',4,3)]
for id,t,d,req,cap,level in passives:write('passive',id,t,d,{},req or 'book',cap,level,req)
fusions=[('fire_missile','Missile ardent','Projectiles guidés explosifs.','fire','missile'),('flame_lash','Fouet de flammes','Arc continu brûlant qui se propage.','fire','lightning'),('steam','Jet de vapeur','Large cône traversant les groupes.','fire','ice'),('ball_lightning','Orbe électrique','Orbe lente guidée, pulsations électriques et chaînes.','missile','lightning'),('frost_missile','Missile de givre','Salve guidée qui éclate et gèle.','missile','ice'),('blizzard','Rayon de blizzard','Rayon traversant qui fige et frappe en chaîne.','lightning','ice')]
for id,t,d,a,b in fusions:write('fusion',id,t,d,dict(elements=[a,b]),a,1,5)
enemies=[('skeleton','Squelette',1,35,105,9,'melee'),('archer','Archer des cryptes',2,27,83,8,'ranged'),('zombie','Porte-peste',3,75,58,14,'poison'),('ghoul','Goule',4,26,170,7,'dash'),('sorcerer','Nécromant',5,43,72,12,'caster'),('knight','Garde noir',6,110,68,18,'tank'),('imp','Diablotin',7,35,133,10,'imp'),('ghost','Spectre',8,38,100,10,'ghost'),('king','Le Roi sans tombe',9,650,80,22,'boss_king'),('plague','Le Mange-cloches',10,900,62,24,'boss_plague'),('demon','Le Gardien du brasier',11,1200,95,28,'boss_demon'),('lich','L’Archiviste des cendres',12,2000,88,30,'boss_lich')]
for id,t,i,hp,speed,damage,behavior in enemies:write('enemy',id,t,'',dict(hp=hp,speed=speed,damage=damage,behavior=behavior,sprite=i,undead=id not in ['imp','demon'],resistance=0.3 if id=='knight' else 0))
for i,(name,stat,value) in enumerate([('de braise','damage',0.12),('de lucidité','max_mana',24),('du rempart','max_hp',22),('de la source','mana_regen',2),('du vif-éclair','cast_speed',0.10),('de sobriété','cost_reduction',0.06),('de l’aube','hp_regen',0.35),('du pèlerin','speed',0.06),('des os','resistance',0.06),('des étoiles','damage',0.18)]):
 write('affix','affix_'+str(i),name,'',dict(stat=stat,amount=value))
for id,t,stat,value in [('ash_staff','Bâton de frêne','damage',0.06),('crystal_staff','Bâton de cristal','max_mana',14),('bone_staff','Bâton d’os','mana_regen',1.2),('copper_ring','Anneau de cuivre','max_hp',12),('silver_ring','Anneau d’argent','cost_reduction',0.03),('onyx_ring','Anneau d’onyx','resistance',0.04)]:
 write('item',id,t,'',dict(slot='staff' if 'staff' in id else 'ring',stat=stat,amount=value), 'staff' if 'staff' in id else 'ring')
write('progression','campaign','La Tour des Cendres','Treize étages. Deux rituels secondaires, puis trois au niveau 20.',dict(floors=13,boss_floors=[4,8,11,13],difficulties=['Apprenti','Sorcier','Archimage','Demi-dieu','Épreuve éternelle']))
from skill_catalog import apply
apply(root)
paths=sorted((root/'resources').glob('*/*.tres'))
(root/'scripts/content_index.gd').write_text('extends RefCounted\n\nconst ALL: Array[Resource] = [\n'+''.join('\tpreload("res://'+p.relative_to(root).as_posix()+'"),\n' for p in paths)+']\n')
print(len(paths),'definitions')
