"""Render an 80-second audition of the living soundscape, not a gameplay capture."""
from pathlib import Path
import json
import numpy as np
import soundfile as sf

ROOT = Path(__file__).resolve().parents[1]
AUDIO = ROOT / 'assets/audio'
OUTPUT = ROOT / 'outputs/audio-living'
SR = 44100
mix = np.zeros((SR * 80, 2))
manifest = json.loads((AUDIO / 'audio_manifest.json').read_text())


def add(name, at, duration=None, offset=0, gain=1, pan=0, fade=.015):
    x, rate = sf.read(AUDIO / manifest[name]['file'], always_2d=True)
    assert rate == SR
    x = x[round(offset*SR):round((offset+duration)*SR) if duration else None].copy()
    if x.shape[1] == 1:
        x = x * np.array([[np.sqrt((1-pan)/2), np.sqrt((1+pan)/2)]])
    n = min(round(fade*SR), len(x)//2)
    x[:n] *= np.linspace(0,1,n)[:,None]
    x[-n:] *= np.linspace(1,0,n)[:,None]
    start = round(at*SR)
    count = min(len(x),len(mix)-start)
    mix[start:start+count] += x[:count] * gain


add('music_village',0,12,offset=10,gain=.45,fade=1.5)
add('ambience_village',0,12,gain=.35,fade=1.5)
add('village_merchant',3,gain=.45,pan=-.4)
add('book_open',6,gain=.55)
add('equip_ring',8,gain=.55)
add('trade',10,gain=.55)
add('ambience_cave',12,44,gain=.16,fade=2)
add('music_tower',12,22,offset=25,gain=.4,fade=2)
for index, style in enumerate(['crypt','library','prison','laboratory','chapel','ruins']):
    add('room_'+style,15+index*3.1,gain=.7,pan=(-.4 if index%2 else .4))
add('music_caverns',35,23,offset=36,gain=.4,fade=2)
for index, material in enumerate(['bone','flesh','metal','ethereal','stone']):
    at = 37+index*2.2
    add('missile',at,gain=.4)
    add('material_'+material,at+.35,gain=.65)
add('key_found',49,gain=.55)
add('seal_open',52,gain=.6)
add('music_boss',56,24,offset=20,gain=.42,fade=2)
for index, boss in enumerate(['king','plague','demon','lich']):
    add('boss_'+boss+'_warning',58+index*3.2,gain=.75,pan=.15)
add('boss_lich_death',72,gain=.65)
add('loot_epic',77,gain=.55)
mix *= min(1.0,.85/np.max(np.abs(mix)))
OUTPUT.mkdir(parents=True,exist_ok=True)
sf.write(OUTPUT/'apercu-bande-son.wav',mix,SR,subtype='PCM_16')
print(OUTPUT/'apercu-bande-son.wav')
