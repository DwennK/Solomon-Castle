"""Focused skill definitions. Kept separate so full content regeneration preserves fixes."""
from pathlib import Path
import json, re

PATCHES = {
    'teleport': {'values': {'mana': 10, 'cooldown': 14, 'equipment_cap': 1}},
    'potent': {'description': 'Speeds up missiles and allows them to retarget. Costs +1 mana per rank.', 'values': {'equipment_cap': 10}},
    'multishot': {'max_rank': 7, 'values': {'equipment_cap': 12}},
    'explode': {'max_rank': 6, 'description': 'Adds an explosion; power and radius increase with rank.', 'values': {'equipment_cap': 11}},
    'embers': {'max_rank': 5, 'description': 'Three embers per rank on impact; requires Explosion.', 'values': {'requires': ['explode'], 'equipment_cap': 10}},
    'chain': {'values': {'equipment_cap': 10}},
    'stun': {'values': {'equipment_cap': 10}},
    'chill': {'values': {'equipment_cap': 10}},
    'cone': {'max_rank': 6, 'values': {'equipment_cap': 11}},
    'meditation': {'max_rank': 1, 'min_level': 8, 'description': 'After one second idle: mana regeneration multiplied by four.', 'values': {'equipment_cap': 1}},
    'focus': {'title': 'Mental Focus', 'max_rank': 1, 'min_level': 9, 'description': 'Halves ritual cooldowns. Does not stack.', 'values': {'equipment_cap': 1, 'requires_secondary': True}},
    'reach': {'max_rank': 1, 'min_level': 10, 'description': 'Picks up loot at four times the normal distance.', 'values': {'equipment_cap': 1}},
    'haste': {'max_rank': 4, 'min_level': 25, 'description': '+10 % projectile cast speed per rank. Does not affect continuous streams.', 'values': {'equipment_cap': 9}},
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
    'immolation': {'title': 'Immolation', 'description': 'Fireball embers explode at the end of their flight. Does not affect fusions.', 'kind': 'passive', 'icon': 'fire', 'prerequisite': 'fire', 'max_rank': 5, 'min_level': 30, 'values': {'requires': ['explode', 'embers'], 'major': True, 'equipment_cap': 8}},
    'ether_charge': {'title': 'Ether Charge', 'description': 'Builds charges while idle; firing an astral missile releases a wave that reduces enemy maximum health.', 'kind': 'passive', 'icon': 'missile', 'prerequisite': 'missile', 'max_rank': 5, 'min_level': 30, 'values': {'requires': ['multishot', 'potent'], 'major': True, 'equipment_cap': 8}},
    'hurricane': {'title': 'Hurricane', 'description': 'A storm damages and deflects enemies and their shots while casting Lightning. Does not affect fusions.', 'kind': 'passive', 'icon': 'lightning', 'prerequisite': 'lightning', 'max_rank': 5, 'min_level': 30, 'values': {'requires': ['chain', 'stun'], 'major': True, 'equipment_cap': 8}},
    'harden': {'title': 'Ice Armor', 'description': 'Ice Stream builds armor that absorbs damage, including poison. Lost when the stream stops.', 'kind': 'passive', 'icon': 'ice', 'prerequisite': 'ice', 'max_rank': 5, 'min_level': 30, 'values': {'requires': ['cone', 'chill'], 'major': True, 'equipment_cap': 10}},
    'creativity': {'title': 'Creativity', 'description': 'Offers four skills instead of three on future level-ups.', 'kind': 'passive', 'icon': 'book', 'prerequisite': '', 'max_rank': 1, 'min_level': 7, 'values': {'equipment_cap': 1}},
    'poison_resist': {'title': 'Poison resistance', 'description': 'Reduces poison damage only: 10 %, 20 %, then 30 %.', 'kind': 'passive', 'icon': 'mana', 'prerequisite': '', 'max_rank': 3, 'min_level': 6, 'values': {'equipment_cap': 9}},
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
