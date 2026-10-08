"""Build the shipped soundtrack from attributed, free recordings and composed music.

Run with .tools-venv/bin/python tools/import_free_audio.py [--fetch].
Downloads are pinned by SHA-256 in assets/audio/sources.json and cached only in
outputs/audio-sources. No network access is needed by the game or normal builds.
"""
from pathlib import Path
import argparse
import hashlib
import json
import math
import shutil
import subprocess
from types import SimpleNamespace
import urllib.request
import zipfile

import numpy as np
import soundfile as sf
from scipy.signal import butter, resample_poly, sosfilt

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets/audio'
CACHE = ROOT / 'outputs/audio-sources'
SR = 44100
SOURCES = json.loads((OUT / 'sources.json').read_text())
MANIFEST = {}
USED = set()
RPG = '80-cc0-rpg-sfx'
FANTASY = 'fantasy-sound-effects-library'
VOICES = 'zombie-skeleton-monster-voice-effects'
STEPS = 'different-steps-on-wood-stone-leaves-gravel-and-mud'
FIRE = 'fire-staff-sound-effects'
ICE = 'ice-breakingshattering'
SPELL = 'spell-sounds'


def fetch_sources(fetch):
    for slug, source in SOURCES.items():
        folder = CACHE / slug
        folder.mkdir(parents=True, exist_ok=True)
        for download in source['downloads']:
            target = folder / download['file']
            if not target.exists():
                if not fetch:
                    raise SystemExit(f'Missing {target}; run again with --fetch')
                with urllib.request.urlopen(download['url'], timeout=60) as response:
                    target.write_bytes(response.read())
            if hashlib.sha256(target.read_bytes()).hexdigest() != download['sha256']:
                raise SystemExit(f'Source checksum mismatch: {target}')
            if target.suffix == '.zip' and not (folder / 'extracted').exists():
                with zipfile.ZipFile(target) as archive:
                    for name in archive.namelist():
                        if Path(name).is_absolute() or '..' in Path(name).parts:
                            raise ValueError('Unsafe archive member')
                    archive.extractall(folder / 'extracted')
            if target.suffix == '.7z' and not (folder / 'extracted').exists():
                tar = shutil.which('bsdtar')
                if not tar:
                    raise SystemExit('Rebuilding this source requires bsdtar (libarchive; bundled with macOS).')
                names = subprocess.check_output([tar, '-tf', str(target)], text=True).splitlines()
                if any(Path(name).is_absolute() or '..' in Path(name).parts for name in names):
                    raise ValueError('Unsafe archive member')
                (folder / 'extracted').mkdir()
                subprocess.run([tar, '-xf', str(target), '-C', str(folder / 'extracted')], check=True)


def read(slug, filename, speed=1.0, start=0.0, seconds=None, stereo=False):
    matches = sorted((CACHE / slug).rglob(filename))
    if len(matches) != 1:
        raise ValueError((slug, filename, matches))
    path = matches[0]
    USED.add((slug, path.relative_to(CACHE / slug).as_posix()))
    x, rate = sf.read(path, always_2d=True)
    x = x[round(start * rate):round((start + seconds) * rate) if seconds else None]
    if not stereo:
        x = x.mean(axis=1)
    elif x.shape[1] == 1:
        x = np.repeat(x, 2, axis=1)
    effective = round(rate * speed)
    gcd = math.gcd(effective, SR)
    x = resample_poly(x, SR // gcd, effective // gcd, axis=0)
    return x


def trim(x):
    energy = np.abs(x) if x.ndim == 1 else np.max(np.abs(x), axis=1)
    indices = np.flatnonzero(energy > max(float(energy.max()) * .008, .0001))
    return x[max(0, indices[0] - 220):min(len(x), indices[-1] + 1103)] if len(indices) else x


def mix(*layers):
    x = np.zeros(max(len(layer) for layer in layers))
    for layer in layers:
        x[:len(layer)] += layer
    return x


def echo(x, wet=.18):
    result = np.pad(x, (0, round(.48 * SR)))
    for delay, gain in [(.083, wet), (.191, wet*.62), (.337, wet*.35)]:
        n = round(delay * SR)
        result[n:n+len(x)] += x * gain
    return result


def lowpass(x, cutoff):
    return sosfilt(butter(2, cutoff, fs=SR, output='sos'), x, axis=0)


def loop(x, overlap=.4):
    n = min(round(overlap * SR), len(x)//4)
    w = np.linspace(0, 1, n)
    if x.ndim == 2:
        w = w[:, None]
    return np.concatenate((x[n:-n], x[-n:] * (1-w) + x[:n] * w))


def save(name, x, looping=False, music=False, rms=.12):
    if not len(x) or not np.isfinite(x).all() or np.max(np.abs(x))<.0001:
        raise ValueError('Silent or invalid source segment: '+name)
    x = x - np.mean(x, axis=0)
    if not looping:
        x = trim(x)
        n = min(round(.009 * SR), len(x)//4)
        fade = np.linspace(0, 1, n)
        if x.ndim == 2:
            fade = fade[:, None]
        x[:n] *= fade
        x[-n:] *= fade[::-1]
    x *= min(rms / max(float(np.sqrt(np.mean(x*x))), 1e-6), .78 / max(float(np.max(np.abs(x))), 1e-6))
    suffix = '.ogg' if music or name.startswith('ambience_') else '.wav'
    path = OUT / (name + suffix)
    # Small writes avoid libsndfile/Vorbis pre-extrapolation failures on long scores.
    with sf.SoundFile(path, 'w', samplerate=SR, channels=1 if x.ndim==1 else x.shape[1],
                      subtype='VORBIS' if suffix=='.ogg' else 'PCM_16') as output:
        for offset in range(0, len(x), 16384):
            output.write(x[offset:offset+16384])
    decoded, rate = sf.read(path, always_2d=True)
    MANIFEST[name] = {
        'file': path.name, 'seconds': round(len(decoded)/rate, 3), 'loop': looping,
        'peak_db': round(20*np.log10(np.max(np.abs(decoded))), 2),
        'rms_db': round(20*np.log10(np.sqrt(np.mean(decoded*decoded))), 2),
        'channels': decoded.shape[1],
        'sources': [{'collection': slug, 'file': file} for slug, file in sorted(USED)],
        'sha256': hashlib.sha256(path.read_bytes()).hexdigest(),
    }
    USED.clear()


def rpg(name, **kwargs):
    return read(RPG, name+'.ogg', **kwargs)


def fantasy(name, **kwargs):
    return read(FANTASY, name+'.wav', **kwargs)


def living_soundscape():
    water = '40-cc0-water-splash-slime-sfx'
    for name, slug, filename in [('tower', 'dark-tower-ambience', 'DarkTowerAmbience_0.mp3'),
                                  ('caverns', 'the-deeper-caverns', 'the_deeper_caverns.flac')]:
        save('music_'+name, read(slug, filename, stereo=True), music=True, rms=.10)
    save('ambience_village', loop(read('park-ambiences', 'park_ambience_birds.wav', start=12, seconds=55, stereo=True), 3), True, rms=.07)

    # Sparse textures with irregular spacing leave room for the combat mix.
    def scatter(recipe, offsets, duration=24):
        x = np.zeros(round(SR*duration))
        for offset in offsets:
            layer = recipe()
            start = round(SR*offset); count = min(len(layer), len(x)-start)
            x[start:start+count] += layer[:count]
        return x
    recipes = {
        'crypt': lambda: echo(lowpass(read(water, 'bubble_02.ogg', speed=.7), 1900), .7),
        'library': lambda: lowpass(rpg('wood_03', speed=.5), 2100),
        'prison': lambda: echo(rpg('chain_02', speed=.7), .35),
        'laboratory': lambda: read(water, 'loop_bubbles_02.ogg', seconds=3),
        'chapel': lambda: echo(lowpass(fantasy('Spell_04', speed=.55), 1000), .8),
        'ruins': lambda: echo(lowpass(rpg('stones_04', speed=.6), 2100), .3),
    }
    for style, recipe in recipes.items():
        save('ambience_'+style, scatter(recipe, [1.3, 8.7, 16.2]), True, rms=.045)
        save('room_'+style, recipe(), rms=.09)

    for i in range(3):
        suffix = '' if i==0 else '_'+str(i+1)
        for material, recipe in [
            ('bone', lambda: mix(rpg('stones_0'+str(i+1)), rpg('chain_01', speed=1.3)*.25)),
            ('flesh', lambda: read(water, f'slime_{i+1:02d}.ogg')),
            ('metal', lambda: rpg('metal_0'+str(i+1))),
            ('ethereal', lambda: echo(rpg('spell_02', speed=.75+i*.08), .5)),
            ('stone', lambda: rpg('stones_0'+str(i+1), speed=.85)),
        ]: save('material_'+material+suffix, recipe(), rms=.11)

    for name, recipe in [
        ('inventory_open', lambda: fantasy('Inventory_Open_00')),
        ('book_open', lambda: mix(rpg('book_04'), rpg('book_02')*.35)),
        ('equip_staff', lambda: mix(rpg('wood_04'), rpg('spell_01')*.15)),
        ('equip_ring', lambda: mix(rpg('item_gem_02'), rpg('metal_01')*.2)),
        ('unequip', lambda: fantasy('Inventory_Open_01')),
        ('trade', lambda: rpg('item_coins_03')),
        ('key_found', lambda: mix(rpg('lock_02'), fantasy('Spell_01')*.35)),
        ('seal_open', lambda: echo(mix(rpg('stones_04', speed=.7), fantasy('Spell_03')*.7), .4)),
        ('loot_rare', lambda: mix(rpg('item_gem_03'), fantasy('Spell_01')*.3)),
        ('loot_epic', lambda: echo(mix(rpg('item_gem_03'), fantasy('Jingle_Achievement_00')*.4), .2)),
        ('encounter', lambda: echo(lowpass(rpg('creature_roar_03', speed=.55), 1000), .35)),
        ('village_merchant', lambda: mix(rpg('metal_02'), rpg('wood_04')*.4)),
        ('village_teacher', lambda: rpg('book_04')),
        ('village_healer', lambda: read(water, 'splash_02.ogg')),
    ]: save(name, recipe(), rms=.10)

    # Recognizable identities: iron/chain, wet plague, fire/roar, spectral magic.
    for boss in ['king','plague','demon','lich']:
        for event in ['alert','warning','death']:
            warning = event=='warning'
            speed = 1.05 if warning else (.65 if event=='death' else .8)
            if boss=='king':
                x = mix(rpg('metal_03', speed=speed), rpg('chain_03', speed=speed)*.6)
                if not warning: x = mix(x, read(VOICES, 'humanDeath2.wav', speed=speed)*.6)
            elif boss=='plague':
                x = mix(read(water, 'slime_06.ogg', speed=speed), read(VOICES, 'zombieYell8.wav', speed=speed)*.7)
            elif boss=='demon':
                x = mix(fantasy('Dragon_Growl_01', speed=speed, seconds=.6 if warning else None),
                        read(FIRE, 'LEGIT_FIR_Fire_Staff 12-Audio.wav', speed=speed, seconds=.5 if warning else 1.7)*.5)
            else:
                x = mix(fantasy('Spell_02', speed=speed), read(VOICES, 'zombieYell7.wav', speed=.6)*.25)
            if warning: x = x[:round(SR*.62)]
            else: x = echo(x, .6 if event=='death' else .3)
            save('boss_'+boss+'_'+event, x, rms=.14)


def build():
    for name, slug, filename in [
        ('menu', 'dark-chamber', 'Dark chamber.mp3'),
        ('village', 'town-theme-rpg', 'TownTheme.mp3'),
        ('exploration', 'dungeon-ambience', 'dungeon002_0.ogg'),
        ('boss', 'dark-descent', 'Dark Descent_0.mp3'),
    ]:
        x = trim(read(slug, filename, stereo=True))
        save('music_'+name, x if name=='exploration' else loop(x, 1.5), name!='exploration', True, .10)
    save('ambience_cave', loop(read(FANTASY, 'Ambience_Cave_00.wav', stereo=True), 2), True, rms=.08)
    save('ambience_torch', loop(read('fireplace-sound-loop', 'fire.wav'), 1), True, rms=.12)

    # Replace every old effect, including its variants: no old synthetic layer is mixed in.
    for i in range(3):
        suffix = '' if i == 0 else '_'+str(i+1)
        def emit(name, x, **kwargs):
            save(name+suffix, x, **kwargs)
        emit('missile', echo(rpg('spell_0'+str(1+i%2), speed=1+i*.045), .12))
        emit('fire', read(FIRE, f'LEGIT_FIR_Fire_Staff {i+1}-Audio.wav', seconds=1.25))
        for element, recipe in [
            ('arcane', lambda: rpg('spell_02', speed=.9+i*.06)),
            ('fire', lambda: rpg('spell_fire_0'+str(i+3))),
            ('ice', lambda: read(ICE, ['LedasLuzta.ogg','LedasLuzta2.ogg','LedasLuzta4.ogg'][i])),
            ('lightning', lambda: read(SPELL, 'electricspell.ogg', start=1+i*.45, seconds=.35)),
        ]:
            emit('impact_'+element, echo(recipe(), .08))
        emit('loot', rpg('item_coins_0'+str(i+1)), rms=.07)
        emit('hurt', read(VOICES, f'humanYell{i+1}.wav'))
        emit('enemy_melee', rpg('blade_0'+str(i+1)))
        emit('enemy_bow', rpg('blade_0'+str(i+1), speed=1.3))
        emit('enemy_magic', fantasy('Spell_01', speed=.88+i*.07))
        emit('enemy_death', rpg('creature_die_01', speed=.9+i*.1))
        emit('step_stone', read(STEPS, 'stone01.ogg', speed=.93+i*.07), rms=.08)
        emit('step_gravel', fantasy('Footstep_Dirt_0'+str(i)), rms=.08)

    for name, recipe in [
        ('fire_missile', lambda: mix(read(FIRE, 'LEGIT_FIR_Fire_Staff 5-Audio.wav', seconds=1.4), rpg('spell_01')*.4)),
        ('frost_missile', lambda: mix(read(ICE, 'LedasLuzta5.ogg'), fantasy('Spell_01')*.3)),
        ('ball_lightning', lambda: read(SPELL, 'electricspell2.ogg', start=3.1, seconds=1.2)),
        ('impact', lambda: rpg('stones_01')),
        ('enemy', lambda: rpg('creature_monster_03')),
        ('boss_attack', lambda: fantasy('Dragon_Growl_00', speed=.85)),
        ('boss_death', lambda: echo(fantasy('Dragon_Growl_01', speed=.75), .32)),
        ('potion', lambda: mix(fantasy('Footstep_Water_00'), read(SPELL, 'healing.ogg', start=11.2, seconds=1.4)*.35)),
        ('mana', lambda: read(SPELL, 'healing.ogg', start=14.0, seconds=1.8, speed=1.1)),
        ('item', lambda: rpg('item_gem_01')),
        ('ui', lambda: rpg('book_01', seconds=.15)),
        ('spell_switch', lambda: rpg('book_03', seconds=.28)),
        ('chest', lambda: mix(rpg('wood_02'), rpg('lock_01')*.6)),
        ('urn', lambda: mix(rpg('stones_03'), read(ICE, 'LedasLuzta33.ogg')*.4)),
        ('ritual', lambda: echo(fantasy('Spell_02'), .15)),
        ('teleport', lambda: read(SPELL, 'teleport.ogg', seconds=2.1)),
        ('portal', lambda: fantasy('Spell_03')),
        ('shield', lambda: fantasy('Spell_00')),
        ('shield_hit', lambda: rpg('metal_02')),
        ('circle', lambda: echo(fantasy('Spell_04', speed=.85), .25)),
        ('freeze', lambda: echo(read(ICE, 'LedasLuzta4.ogg', speed=.8), .3)),
        ('ring_fire', lambda: read(FIRE, 'LEGIT_FIR_Fire_Staff 12-Audio.wav', seconds=2)),
        ('acid', lambda: mix(rpg('creature_slime_02'), rpg('creature_slime_04')*.5)),
        ('undead', lambda: echo(fantasy('Goblin_04', speed=.7), .4)),
        ('death', lambda: fantasy('Jingle_Lose_00')),
        ('victory', lambda: fantasy('Jingle_Win_00')),
        ('level_up', lambda: fantasy('Jingle_Achievement_00')),
    ]:
        save(name, recipe())

    for family in ['skeleton', 'zombie', 'beast', 'armor', 'wraith', 'imp', 'demon']:
        for event in ['idle','alert','attack','hurt','death','step']:
            for i in range(3):
                suffix = '' if i == 0 else '_'+str(i+1)
                if event == 'step':
                    if family in ['skeleton','armor']:
                        x = rpg(('chain_' if family=='armor' else 'stones_')+f'{i+1:02d}')
                    elif family in ['zombie','beast','demon']:
                        x = fantasy('Footstep_Dirt_0'+str(i), speed=.75 if family=='demon' else 1)
                    else:
                        x = lowpass(rpg('blade_0'+str(i+1), speed=.7), 1400)
                elif family == 'skeleton':
                    x = mix(rpg('stones_0'+str(i+1)), rpg('chain_0'+str(i+1))*.35)
                    if event == 'death': x = echo(mix(x, rpg('stones_04')), .1)
                    elif event == 'alert': x = echo(x, .2)
                elif family == 'armor':
                    x = mix(rpg('metal_0'+str(i+1)), rpg('chain_0'+str(i+1))*.4)
                    if event in ['attack','hurt','death']:
                        x = mix(x, read(VOICES, 'humanDeath1.wav' if event=='death' else f'humanYell{i+1}.wav', speed=.85)*.55)
                elif family == 'zombie':
                    x = read(VOICES, f'zombieDeath{i+1}.wav' if event=='death' else f'zombieYell{1+i+ (3 if event in ["hurt","attack"] else 6)}.wav', speed=.72 if event=='idle' else .86)
                    x = echo(x, .12)
                elif family == 'imp':
                    x = fantasy('Goblin_0'+str((i+{'idle':0,'alert':1,'attack':2,'hurt':3,'death':4}[event])%5), speed=1.1)
                elif family == 'wraith':
                    x = read(VOICES, f'zombieYell{i+7}.wav', speed=.55 if event=='death' else .7)
                    if event=='idle': x = x[::-1].copy()
                    x = echo(lowpass(x, 2600), .65)
                elif family == 'demon':
                    x = fantasy('Dragon_Growl_0'+str(i%2), speed=.7+i*.045, seconds=1.5 if event in ['idle','hurt','attack'] else None)
                    x = echo(x, .2)
                else:
                    stem = {'idle':'creature_monster_','alert':'creature_roar_','attack':'creature_roar_','hurt':'creature_hurt_','death':'creature_die_'}[event]
                    variant = 1 if event=='death' else 1+i%(2 if event=='hurt' else 3)
                    x = rpg(stem+f'{variant:02d}', speed=.85+i*.04)
                save(f'creature_{family}_{event}'+suffix, x, rms=.09 if event=='step' else .14)

    # Long, non-tonal channels are assembled from sampled textures, not oscillator tones.
    for name in ['lightning','ice','flame_lash','steam','blizzard']:
        if name == 'lightning':
            x = read(SPELL, 'electricspell.ogg', start=10, seconds=3.5)
        elif name == 'flame_lash':
            x = read('fireplace-sound-loop', 'fire.wav', start=4, seconds=6)
        elif name == 'steam':
            x = lowpass(read('fireplace-sound-loop', 'fire.wav', start=12, seconds=6), 2400)
        else:
            ice = read(ICE, 'LedasLuzta4.ogg', speed=.55)
            x = np.zeros(SR*6)
            for offset in [.1, .9, 1.7, 2.9, 3.8, 4.7]:
                start = round(offset*SR); count = min(len(ice), len(x)-start)
                x[start:start+count] += ice[:count]*.45
            x = lowpass(x, 4200 if name=='ice' else 2200)
        save('channel_'+name, loop(x), True, rms=.07)
    for i in range(3):
        suffix = '' if i==0 else '_'+str(i+1)
        save('dungeon_creak'+suffix, echo(rpg('wood_0'+str(i+1), speed=.65), .5), rms=.07)
        save('dungeon_stone'+suffix, echo(rpg('stones_0'+str(i+1), speed=.65), .6), rms=.08)
    living_soundscape()
    # Spell-specific art direction replaces the old generic spell excerpts.
    from design_spell_audio import build_spells
    build_spells(SimpleNamespace(**globals()))
    (OUT/'audio_manifest.json').write_text(json.dumps(MANIFEST, indent=2)+'\n')
    print(f'Built {len(MANIFEST)} assets from {len(SOURCES)} free sources.')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--fetch', action='store_true')
    fetch_sources(parser.parse_args().fetch)
    build()
