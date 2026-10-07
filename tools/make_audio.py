"""Original dark-fantasy score / Foley. Rebuild: .tools-venv/bin/python tools/make_audio.py.
Requires numpy, scipy and soundfile (generation only). No external recordings or samples.
"""
from pathlib import Path
import hashlib
import json
import soundfile as sf
import tempfile
import wave
import numpy as np
from scipy.signal import butter, sosfilt

OUT = Path(__file__).resolve().parents[1] / 'assets/audio'
SR = 44100
OUT.mkdir(exist_ok=True)
REPORT = {}


def rng_for(name):
    return np.random.default_rng(int.from_bytes(hashlib.sha256(name.encode()).digest()[:8], 'little'))


def timeline(seconds):
    return np.arange(round(seconds * SR)) / SR


def noise(t, rng, low=100, high=5000):
    return sosfilt(butter(2, [low, high], btype='bandpass', fs=SR, output='sos'), rng.normal(0, 1, len(t)))


def osc(t, start, end=None):
    freq = start if end is None else start + (end-start)*t/max(t[-1], 1/SR)
    return np.sin(2*np.pi*np.cumsum(np.broadcast_to(freq, t.shape))/SR)


def env(t, decay=5, attack=.008):
    return (1-np.exp(-t/attack))*np.exp(-t*decay)


def bell(t, hz, decay=3):
    return sum(amp*osc(t, hz*ratio)*env(t, decay*(1+i*.7), .003)
               for i, (ratio, amp) in enumerate([(1, 1), (2.006, .32), (2.997, .12), (4.17, .06)]))


def reverb(x, wet=.2, wrap=False):
    result = x.copy()
    for delay, gain in [(.071, .5), (.113, .4), (.179, .32), (.269, .22), (.401, .14), (.593, .08)]:
        offset = round(delay*SR)
        if wrap:
            result += np.roll(x, offset, axis=0)*gain*wet
        elif offset < len(x):
            result[offset:] += x[:-offset]*gain*wet
    return result


def save(name, x, loop=False, music=False, peak=.65):
    x = x - np.mean(x, axis=0)
    if not loop:
        n = min(round(.012*SR), len(x)//4)
        shape = (n, 1) if x.ndim == 2 else (n,)
        x[:n] *= np.linspace(0, 1, n).reshape(shape)
        x[-n:] *= np.linspace(1, 0, n).reshape(shape)
    else:
        # Remove the tiny residual boundary step without creating a silent seam.
        n = round(.015*SR)
        shape = (n, 1) if x.ndim == 2 else (n,)
        x[-n:] += np.linspace(0, 1, n).reshape(shape)*(x[0]-x[-1])
    x *= peak/max(np.max(np.abs(x)), 1e-9)
    pcm = np.round(x*32767).astype('<i2')
    path = OUT / (name + ('.ogg' if music else '.wav'))
    with tempfile.NamedTemporaryFile(suffix='.wav') as temp:
        with wave.open(temp.name, 'wb') as f:
            f.setparams((2 if x.ndim == 2 else 1, 2, SR, 0, 'NONE', 'not compressed'))
            f.writeframes(pcm.tobytes())
        if music:
            sf.write(path, x, SR, format='OGG', subtype='VORBIS')
        else:
            path.write_bytes(Path(temp.name).read_bytes())
    REPORT[name] = {'seconds': round(len(x)/SR, 3), 'loop': loop, 'peak_db': round(20*np.log10(peak), 2),
                    'rms_db': round(20*np.log10(np.sqrt(np.mean(x*x))), 2), 'channels': 2 if x.ndim == 2 else 1}


def effect(name, variation=0):
    rng = rng_for(name+str(variation))
    durations = {'death': 3.5, 'victory': 5.5, 'level_up': 2.5, 'portal': 1.8,
                 'teleport': 1.3, 'shield': 1.4, 'circle': 2, 'freeze': 1.5,
                 'ring_fire': 1.5, 'acid': 1.4, 'undead': 2, 'ritual': 1.8,
                 'chest': 1.1, 'potion': 1.15, 'mana': 1.25, 'boss_death': 2.8,
                 'ui': .12, 'step_stone': .18, 'step_gravel': .22}
    t = timeline(durations.get(name, .75))
    n = noise(t, rng)
    low = noise(t, rng, 35, 450)
    airy = noise(t, rng, 1300, 7000)
    pitch = 1 + rng.uniform(-.035, .035)
    if name in ['missile', 'fire_missile', 'frost_missile', 'ball_lightning']:
        x = .35*osc(t, 680*pitch, 160)*env(t, 10) + .28*n*env(t, 12)
        x += .13*bell(t, 1174*pitch, 8)
        if name == 'fire_missile': x += low*env(t, 6)+.3*n*env(t, 8)
        if name == 'frost_missile': x += .3*bell(t, 2093*pitch, 7)+airy*env(t, 9)*.15
        if name == 'ball_lightning': x += np.tanh(n*4)*osc(t, 90, 170)*env(t, 6)*.4
    elif name in ['fire', 'impact_fire', 'ring_fire']:
        x = low*env(t, 5)*1.6+n*env(t, 9)*.65+osc(t, 100, 35)*env(t, 11)*.45
        x += airy*(rng.random(len(t))>.998)*env(t, 4)*.4
    elif name in ['impact_ice', 'freeze', 'urn']:
        x = n*env(t, 22)*.65
        for i, hz in enumerate([1430, 1973, 2681, 3420, 4217]):
            offset = .022*i
            local = np.maximum(0, t-offset)
            x += bell(local, hz*pitch, 10+i)*.12*(t>=offset)
        if name == 'freeze': x += airy*env(t, 3, .1)*.3
    elif name in ['impact', 'impact_arcane', 'impact_lightning', 'shield_hit']:
        x = osc(t, 190, 55)*env(t, 22)*.7+n*env(t, 30)*.4
        if name != 'impact': x += bell(t, 740 if name == 'impact_arcane' else 1480, 9)*.2
        if name == 'impact_lightning': x += np.tanh(airy*5)*env(t, 18)*.3
    elif name in ['potion', 'mana']:
        x = osc(t, 350, 220)*env(t, 60)*.25
        for i in range(5):
            local = np.maximum(0, t-.08-i*.08)
            x += osc(local, 450+i*120, 850+i*180)*env(local, 24)*.19*(t>=.08+i*.08)
        for i, hz in enumerate([523, 659, 784] if name == 'potion' else [659, 988, 1318]):
            local = np.maximum(0, t-.35-i*.09)
            x += bell(local, hz, 5)*.16*(t>=.35+i*.09)
    elif name in ['loot', 'item', 'ui', 'spell_switch']:
        x = bell(t, {'loot': 1760, 'item': 880, 'ui': 740, 'spell_switch': 1108}[name]*pitch, 26 if name=='ui' else 11)*.45
        x += n*env(t, 80)*.15
        if name == 'item': x += bell(np.maximum(0,t-.12),1320,7)*.3*(t>=.12)
    elif name == 'chest':
        x = low*env(t, 14)*.9 + n*env(t, 50)*.3
        x += osc(t, 170, 290)*n*env(t, 6, .06)*.22
        for offset, hz in [(.25, 1174), (.36, 1480), (.46, 1760)]:
            x += bell(np.maximum(0,t-offset),hz,8)*.14*(t>=offset)
    elif name in ['step_stone', 'step_gravel']:
        x = low*env(t, 45)*.65+n*env(t, 48)*.35
        if name == 'step_gravel': x += airy*env(t, 26)*.3
    elif name in ['hurt', 'enemy', 'enemy_melee', 'enemy_bow', 'enemy_magic', 'enemy_death', 'boss_death', 'boss_attack']:
        x = low*env(t, 13)*.7+n*env(t, 25)*.4
        if name == 'enemy_bow': x = osc(t, 310, 120)*env(t, 24)*.2+airy*env(t, 16)*.3
        elif name == 'enemy_magic': x += osc(t, 330, 130)*env(t, 6)*.3
        elif name in ['enemy_death', 'boss_death']: x += osc(t, 160, 40)*env(t, 3 if name=='boss_death' else 8)*.4
        elif name == 'boss_attack': x += osc(t, 80, 45)*env(t, 6)*.6
        elif name == 'hurt': x += osc(t, 120, 65)*env(t, 17)*.4
    elif name in ['teleport', 'portal', 'ritual', 'shield', 'circle', 'acid', 'undead']:
        x = n*env(t, 3, .08)*.2 + osc(t, 130, 730)*env(t, 5, .04)*.2
        if name == 'acid':
            x = n*env(t, 3, .04)*.3
            for i in range(10):
                local = np.maximum(0,t-i*.09)
                x += osc(local,220+i*31,650)*env(local,30)*.13*(t>=i*.09)
        else:
            notes = [293.66, 440, 587.33] if name in ['shield','circle','undead'] else [220, 261.63, 329.63]
            for hz in notes: x += bell(t,hz,2.5)*.16
            if name=='undead': x += osc(t, 73.4)*env(t, 2, .1)*.3
    elif name in ['death', 'victory', 'level_up']:
        x = low*env(t, 3)*.2
        notes = [293.66,261.63,220,146.83] if name=='death' else [293.66,349.23,440,587.33,698.46,880]
        spacing = .38 if name=='death' else .19
        for i, hz in enumerate(notes):
            local = np.maximum(0,t-i*spacing)
            x += (bell(local,hz,1.4)*.22+osc(local,hz/2)*env(local,1.3,.1)*.09)*(t>=i*spacing)
    else:
        raise ValueError(name)
    return reverb(x, .22 if name not in ['ui','step_stone','step_gravel'] else .04)


def channel(name):
    t = timeline(3.2)
    rng = rng_for(name)
    wind = noise(t, rng, 500, 5000)
    rumble = noise(t, rng, 45, 600)
    electric = np.tanh(noise(t,rng,1000,6500)*3)*(.25+.75*np.sin(2*np.pi*15*t)**8)
    ice = wind*.2 + (osc(t, 1320)+osc(t, 1760))*.025*(.7+.3*np.sin(2*np.pi*2.5*t))
    fire = rumble*.7+wind*.1
    x = {'lightning': electric*.22+osc(t,100)*.04, 'ice': ice,
         'flame_lash': fire*.6+electric*.15, 'steam': wind*.33+rumble*.12,
         'blizzard': ice*.65+rumble*.4}[name]
    # Overlap the independent noise ends; no repeated attack or zero-amplitude gap.
    n = round(.15*SR)
    tail = x[-n:].copy()
    x[:n] = tail*np.linspace(1,0,n)+x[:n]*np.linspace(0,1,n)
    return x[:-n]


def hz(midi):
    return 440*2**((midi-69)/12)


def instrument(note, seconds, kind):
    t = timeline(seconds)
    f = hz(note)
    if kind == 'pluck':
        return sum(osc(t,f*i)*np.exp(-t*(2+i*1.2))/i**1.7 for i in range(1,9))*(1-np.exp(-t/.003))
    if kind == 'bell': return bell(t,f,1.7)
    if kind == 'flute':
        phase = 2*np.pi*f*t+.012*np.sin(2*np.pi*4.8*t)
        return (np.sin(phase)+.13*np.sin(phase*2)+.035*np.sin(phase*3))*np.minimum(1,t/.12)*np.minimum(1,(seconds-t)/.35)*.55
    if kind == 'strings':
        x = sum((osc(t,f*i*.9987)+osc(t,f*i*1.0013))/i**1.65 for i in range(1,7))*.22
        return x*np.minimum(1,t/.6)*np.minimum(1,(seconds-t)/.9)
    if kind == 'drum':
        return osc(t,95,38)*env(t,8)*.7 + noise(t,rng_for(str(note)+str(seconds)),45,900)*env(t,16)*.25
    raise ValueError(kind)


def score(name, bpm):
    beat = 60/bpm
    length = round(64*beat*SR)  # Sixteen bars; reverb and note tails wrap naturally.
    mix = np.zeros((length,2))
    def add(note, start, duration, kind, gain, pan=0):
        signal = instrument(note,duration,kind)*gain
        left, right = np.cos((pan+1)*np.pi/4), np.sin((pan+1)*np.pi/4)
        indices = (np.arange(len(signal))+round(start*SR))%length
        np.add.at(mix[:,0],indices,signal*left)
        np.add.at(mix[:,1],indices,signal*right)
    progression = [(38,53,57,60),(34,53,57,62),(41,53,57,60),(36,52,55,60),
                   (38,53,57,62),(34,50,53,57),(31,50,55,58),(33,49,52,57)]
    if name=='village': progression = [(41,53,57,60),(36,52,55,60),(38,53,57,62),(34,53,57,62)]*2
    melody = [[74,77,76,69],[72,69,65,69],[69,72,77,76],[67,64,67,72],
              [74,81,77,76],[74,69,65,62],[67,70,74,69],[73,76,69,73]]
    for bar in range(16):
        root,*chord = progression[bar%8]
        start=bar*4*beat
        for i,note in enumerate(chord):
            add(note,start,4*beat+.8,'strings',.11 if name!='boss' else .14,(i-1)*.5)
        add(root,start,4*beat+.3,'strings',.24,0)
        if name in ['menu','village']:
            pattern = [0,1,2,1,0,2,1,2]
            for j,index in enumerate(pattern):
                add(chord[index]+12,start+j*beat/2,1.8,'pluck',.11 if name=='village' else .07,(-1 if j%2 else 1)*.4)
            for j,note in enumerate(melody[bar%8]):
                if name=='menu' and j%2: continue
                add(note,start+j*beat,beat*1.5,'flute' if name=='village' else 'bell',.12 if name=='village' else .09,.1)
        elif name=='exploration':
            if bar%2==0: add(chord[1]+12,start+beat,3.8,'bell',.09,.5 if bar%4 else -.5)
            for j in [0,2.5]: add(root,start+j*beat,1.3,'drum',.075,0)
            if bar%4==3: add(chord[0]+12,start+beat,beat*2,'flute',.055,-.2)
        elif name=='boss':
            for j in range(8):
                add(chord[[0,2,1,2][j%4]],start+j*beat/2,beat*.7,'strings',.28,(-1 if j%2 else 1)*.3)
            for j in [0,1.5,2,3.5]: add(root,start+j*beat,.8,'drum',.42 if j in [0,2] else .22,0)
            if bar%2==0:
                add(melody[bar%8][0]-12,start,3*beat,'flute',.15,.15)
    mix=reverb(mix,.48,True)
    # Gentle saturation of percussion, headroom for spells. Stereo Ogg for streaming.
    mix=np.tanh(mix*1.2)
    save('music_'+name,mix,loop=True,music=True,peak=.56)


if __name__ == '__main__':
    variants = ['missile','fire','impact_arcane','impact_fire','impact_ice','impact_lightning',
                'enemy_melee','enemy_bow','enemy_magic','enemy_death','step_stone','step_gravel','loot','hurt']
    singles = ['fire_missile','frost_missile','ball_lightning','impact','enemy','potion','mana','item',
               'ui','spell_switch','chest','urn','teleport','portal','ritual','shield','shield_hit','circle',
               'freeze','ring_fire','acid','undead','death','victory','level_up','boss_death','boss_attack']
    for name in variants+singles:
        for v in range(3 if name in variants else 1):
            save(name+('' if v==0 else '_'+str(v+1)),effect(name,v),peak=.52 if name.startswith('step') or name=='ui' else .7)
    for name in ['lightning','ice','flame_lash','steam','blizzard']:
        save('channel_'+name,channel(name),loop=True,peak=.48)
    for name,bpm in [('menu',76),('village',88),('exploration',64),('boss',112)]:
        score(name,bpm)
        print('Composed',name,flush=True)
    (OUT/'audio_manifest.json').write_text(json.dumps(REPORT,indent=2)+'\n')
    print(f'{len(REPORT)} original audio assets generated.')
