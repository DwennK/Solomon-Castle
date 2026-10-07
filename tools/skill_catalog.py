"""Focused skill definitions. Kept separate so full content regeneration preserves fixes."""
from pathlib import Path
import json, re

PATCHES = {
    'teleport': {'values': {'mana': 10, 'cooldown': 14, 'equipment_cap': 1}},
    'potent': {'description': 'Accélère les missiles et leur permet de changer de cible. Coût +1 mana par rang.', 'values': {'equipment_cap': 10}},
    'multishot': {'max_rank': 7, 'values': {'equipment_cap': 12}},
    'explode': {'max_rank': 6, 'description': 'Ajoute une explosion ; puissance et rayon augmentent avec le rang.', 'values': {'equipment_cap': 11}},
    'embers': {'max_rank': 5, 'description': 'Trois braises par rang à l’impact ; nécessite Explosion.', 'values': {'requires': ['explode'], 'equipment_cap': 10}},
    'chain': {'values': {'equipment_cap': 10}},
    'stun': {'values': {'equipment_cap': 10}},
    'chill': {'values': {'equipment_cap': 10}},
    'cone': {'max_rank': 6, 'values': {'equipment_cap': 11}},
    'meditation': {'max_rank': 1, 'min_level': 8, 'description': 'Après une seconde sans agir : régénération du mana multipliée par quatre.', 'values': {'equipment_cap': 1}},
    'focus': {'title': 'Concentration mentale', 'max_rank': 1, 'min_level': 9, 'description': 'Divise par deux la recharge des rituels. Effet non cumulable.', 'values': {'equipment_cap': 1, 'requires_secondary': True}},
    'reach': {'max_rank': 1, 'min_level': 10, 'description': 'Ramasse le butin à quatre fois la distance normale.', 'values': {'equipment_cap': 1}},
    'haste': {'max_rank': 4, 'min_level': 25, 'description': '+10 % cadence des projectiles par rang. Sans effet sur les jets continus.', 'values': {'equipment_cap': 9}},
    'power': {'min_level': 25, 'values': {'equipment_cap': 11}},
    'economy': {'min_level': 5, 'values': {'equipment_cap': 11}},
    'life': {'max_rank': 4, 'values': {'equipment_cap': 4}},
    'mana': {'max_rank': 4, 'values': {'equipment_cap': 4}},
    'regen': {'max_rank': 4, 'values': {'equipment_cap': 9}},
    'rush': {'max_rank': 3, 'values': {'equipment_cap': 8}},
    'resist': {'values': {'legacy': True}},
    'shield': {'max_rank': 6, 'values': {'mana': 30, 'cooldown': 22, 'equipment_cap': 11, 'early_cap': 4}},
    'ring_fire': {'max_rank': 10, 'values': {'mana': 32, 'cooldown': 20, 'equipment_cap': 15}},
    'acid': {'max_rank': 10, 'min_level': 6, 'values': {'mana': 35, 'cooldown': 25, 'equipment_cap': 15}},
    'undead': {'min_level': 6, 'values': {'mana': 24, 'cooldown': 22, 'equipment_cap': 8}},
    'immolation': {'title': 'Immolation', 'description': 'Les braises de Boule de feu explosent en fin de course. Sans effet sur les fusions.', 'kind': 'passive', 'icon': 'fire', 'prerequisite': 'fire', 'max_rank': 5, 'min_level': 30, 'values': {'requires': ['explode', 'embers'], 'major': True, 'equipment_cap': 8}},
    'ether_charge': {'title': 'Charge d’éther', 'description': 'Accumule des charges au repos ; le tir astral libère une onde qui réduit la vie maximale des ennemis.', 'kind': 'passive', 'icon': 'missile', 'prerequisite': 'missile', 'max_rank': 5, 'min_level': 30, 'values': {'requires': ['multishot', 'potent'], 'major': True, 'equipment_cap': 8}},
    'hurricane': {'title': 'Ouragan', 'description': 'Une tempête blesse et dévie les ennemis et leurs tirs pendant Éclair. Sans effet sur les fusions.', 'kind': 'passive', 'icon': 'lightning', 'prerequisite': 'lightning', 'max_rank': 5, 'min_level': 30, 'values': {'requires': ['chain', 'stun'], 'major': True, 'equipment_cap': 8}},
    'harden': {'title': 'Armure de glace', 'description': 'Jet de glace construit une armure qui absorbe les dégâts, poison inclus. Elle disparaît à l’arrêt du jet.', 'kind': 'passive', 'icon': 'ice', 'prerequisite': 'ice', 'max_rank': 5, 'min_level': 30, 'values': {'requires': ['cone', 'chill'], 'major': True, 'equipment_cap': 10}},
    'creativity': {'title': 'Créativité', 'description': 'Propose quatre compétences au lieu de trois aux prochains niveaux.', 'kind': 'passive', 'icon': 'book', 'prerequisite': '', 'max_rank': 1, 'min_level': 7, 'values': {'equipment_cap': 1}},
    'poison_resist': {'title': 'Résistance au poison', 'description': 'Réduit uniquement les dégâts de poison : 10 %, 20 %, puis 30 %.', 'kind': 'passive', 'icon': 'mana', 'prerequisite': '', 'max_rank': 3, 'min_level': 6, 'values': {'equipment_cap': 9}},
}

def apply(root):
    root=Path(root)
    for id, fields in PATCHES.items():
        matches=list((root/'resources').glob('*/'+id+'.tres'))
        path=matches[0] if matches else root/'resources/passive'/f'{id}.tres'
        s=path.read_text() if path.exists() else '[gd_resource type="Resource" script_class="ContentDefinition" load_steps=2 format=3]\n\n[ext_resource type="Script" path="res://scripts/definition.gd" id="1"]\n\n[resource]\nscript = ExtResource("1")\nid = '+json.dumps(id)+'\n'
        for key,value in fields.items():
            line=key+' = '+json.dumps(value,ensure_ascii=False)
            if re.search(r'^'+key+r' = .*$',s,re.M): s=re.sub(r'^'+key+r' = .*$',lambda _:line,s,flags=re.M)
            else: s+=line+'\n'
        path.write_text(s)
    paths=sorted((root/'resources').glob('*/*.tres'))
    (root/'scripts/content_index.gd').write_text('extends RefCounted\n\nconst ALL: Array[Resource] = [\n'+''.join('\tpreload("res://'+p.relative_to(root).as_posix()+'"),\n' for p in paths)+']\n')

if __name__=='__main__': apply(Path(__file__).resolve().parents[1])
