"""Author elemental spell attacks, impacts, sustained textures and releases.

Run with .tools-venv/bin/python tools/design_spell_audio.py [--fetch].
Only spell assets and their manifest entries change. The full import pipeline
calls the same build_spells function. No sound-generation service is required.
"""
from pathlib import Path
import argparse
import json
import numpy as np
from scipy.signal import butter, sosfilt

MAGIC = 'magic-sfx-sample'
ELECTRIC = 'ice-electricity-magic'
COLD = 'ice-spells'
STEAM = 'steam-release-sounds'
WATER = '40-cc0-water-splash-slime-sfx'


def build_spells(a):
    sr = a.SR

    def shape(x, duration, attack=.004, release=.08):
        x = x[:round(duration*sr)].copy()
        x = np.pad(x, (0, max(0, round(duration*sr)-len(x))))
        n, m = min(len(x)//2, round(attack*sr)), min(len(x)//2, round(release*sr))
        x[:n] *= np.linspace(0, 1, n)**.65
        x[-m:] *= np.linspace(1, 0, m)**1.4
        return x

    def band(x, low=100, high=8500):
        return sosfilt(butter(2, [low, high], btype='bandpass', fs=sr, output='sos'), x)

    def source(slug, file, speed=1, start=0, duration=None):
        x = a.trim(a.read(slug, file, speed=speed, start=start, seconds=duration))
        x = band(x)
        # Balance each layer before composing; quiet source recordings cannot disappear.
        x *= min(.19/max(np.sqrt(np.mean(x*x)), 1e-6), .8/max(np.max(np.abs(x)), 1e-6))
        return x

    def delayed(x, seconds):
        return np.pad(x, (round(seconds*sr), 0))

    def air(i=0):
        return source(MAGIC, 'Wind effects 5.wav', speed=1.1+i*.06)

    def arcane(i=0):
        # A compact magical resonance and an airy release, without a looping note sequence.
        return source(MAGIC, 'Misc 02.wav', speed=1.16+i*.055)

    def fire(i=0):
        return source(MAGIC, 'Fire impact 1.wav', speed=.91+i*.065)

    def ice(i=0):
        return source(MAGIC, 'Ice attack 2.wav', speed=.92+i*.055)

    def crack(i=0):
        return source(COLD, 'coldsnap.wav' if i%2==0 else 'ice.wav', speed=.95+i*.07)

    def electric(i=0):
        return source(ELECTRIC, f'qubodupElectricityDamage0{1+i%2}.flac', speed=.9+i*.08)

    def steam(i=0):
        return source(STEAM, f'steam hisses - Marker #{1+i%5}.wav', speed=.9+i*.05)

    def cast(name, i):
        if name=='missile': x = a.mix(shape(arcane(i),.28), shape(air(i),.19)*.3)
        elif name=='fire': x = a.mix(shape(fire(i),.43,release=.19), shape(air(i),.29)*.24)
        elif name=='fire_missile': x = a.mix(shape(arcane(i),.30)*.55, shape(fire(i),.46)*.8)
        elif name=='frost_missile': x = a.mix(shape(arcane(i),.28)*.5, shape(ice(i),.40)*.7, shape(crack(i),.22)*.4)
        else: x = a.mix(shape(arcane(i),.40)*.6, shape(electric(i),.50)*.75)
        return x

    for i in range(3):
        suffix = '' if i==0 else '_'+str(i+1)
        for name in ['missile','fire','fire_missile','frost_missile','ball_lightning']:
            a.save(name+suffix, cast(name,i), rms=.16)
        for name in ['arcane','fire','ice','lightning','fire_missile','frost_missile','ball_lightning']:
            if name=='arcane': x = shape(arcane(i),.23)
            elif name=='fire': x = shape(fire(i),.65,release=.32)
            elif name=='ice': x = a.mix(shape(crack(i),.38), shape(ice(i),.55)*.35)
            elif name=='lightning': x = shape(electric(i),.32)
            elif name=='fire_missile': x = a.mix(shape(fire(i),.66), delayed(shape(arcane(i),.24)*.45,.025))
            elif name=='frost_missile': x = a.mix(shape(crack(i),.48), shape(ice(i),.70)*.5, shape(arcane(i),.22)*.2)
            else: x = a.mix(shape(electric(i),.58), delayed(shape(arcane(i),.30)*.55,.055))
            a.save('impact_'+name+suffix, x, rms=.15)

        # Utility and area spells carry their own semantic identity, not creature cries.
        rituals = {
            'teleport': lambda: a.mix(shape(air(i)[::-1],.13,attack=.05,release=.025), delayed(shape(arcane(i),.52),.075)),
            'shield': lambda: a.mix(shape(arcane(i),.58), delayed(shape(ice(i),.45)*.22,.10)),
            'shield_hit': lambda: a.mix(shape(arcane(i),.19), shape(ice(i),.16)*.3),
            'circle': lambda: shape(source(MAGIC,'Healing Full.wav',speed=.9+i*.03),1.1,release=.45),
            'freeze': lambda: a.mix(shape(crack(i),.85), shape(ice(i),.95)*.65),
            'ring_fire': lambda: a.mix(shape(fire(i),1.15,release=.50), shape(air(i),.65)*.4),
            'acid': lambda: a.mix(shape(source(WATER,f'slime_{i+4:02d}.ogg'),.6), delayed(shape(steam(i),.7)*.3,.08)),
            'undead': lambda: a.mix(shape(band(arcane(i)[::-1],160,2300),1.05,attack=.08,release=.4), shape(band(air(i),90,1300),.70)*.7),
            'orb_pulse': lambda: shape(electric(i),.16,release=.07),
            'ether_pulse': lambda: a.mix(shape(arcane(i),.64), shape(air(i),.4)*.5),
            'ice_armor_hit': lambda: shape(crack(i),.26),
        }
        for name, recipe in rituals.items(): a.save(name+suffix, recipe(), rms=.14)

    def texture(recipe, duration, interval, seed):
        # Overlapping grains with irregular timing avoid a short, metronomic loop.
        rng = np.random.default_rng(seed)
        x = np.zeros(round(sr*duration)); t = -.5
        while t<duration:
            grain = recipe(int(rng.integers(0,3)))
            grain = shape(grain, min(len(grain)/sr,.65), attack=.035,release=.14)
            start = round(t*sr)
            idx = (np.arange(len(grain))+start)%len(x)
            np.add.at(x,idx,grain*rng.uniform(.5,.9))
            t += interval*rng.uniform(.65,1.35)
        return x

    recipes = {
        'lightning': lambda i: electric(i),
        'ice': lambda i: a.mix(ice(i)*.65, crack(i)*.55, air(i)*.20),
        'flame_lash': lambda i: a.mix(fire(i)*.75,electric(i)*.45),
        'steam': lambda i: steam(i),
        'blizzard': lambda i: a.mix(ice(i)*.65, electric(i)*.35, air(i)*.3),
    }
    for j,(name,recipe) in enumerate(recipes.items()):
        # Eight seconds of authored texture, no dead gaps and no repeated casting transient.
        body = texture(recipe,8.4,.21 if name=='lightning' else .30,410+j)
        body = band(body,120,5700 if name=='lightning' else 7200)
        body = a.loop(body,.4)
        # Match the endpoint after the overlap: even bright broadband textures
        # cross the wrap without an isolated discontinuity (a 3 ms correction).
        n = round(.003*sr)
        body[-n:] += (body[0]-body[-1])*(.5-.5*np.cos(np.linspace(0,np.pi,n)))
        a.save('channel_'+name,body,looping=True,rms=.105)
        for i in range(3):
            suffix = '' if i==0 else '_'+str(i+1)
            attack = shape(recipe(i),.30,release=.12)
            a.save('cast_'+name+suffix,attack,rms=.15)
            # The release is a falling remnant of the same matter; no new loud impact.
            tail = recipe(i)
            start = min(round(.12*sr),len(tail)//3)
            a.save('release_'+name+suffix,shape(tail[start:],.27,attack=.012,release=.22),rms=.08)


if __name__=='__main__':
    import import_free_audio as a
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--fetch',action='store_true')
    a.fetch_sources(parser.parse_args().fetch)
    a.MANIFEST.update(json.loads((a.OUT/'audio_manifest.json').read_text()))
    build_spells(a)
    (a.OUT/'audio_manifest.json').write_text(json.dumps(a.MANIFEST,indent=2)+'\n')
    print(f'Spell sound design complete; {len(a.MANIFEST)} total assets.')
