"""Check spell responsiveness, continuous energy and elemental source identities."""
from pathlib import Path
import json
import numpy as np
import soundfile as sf

ROOT=Path(__file__).resolve().parents[1]
AUDIO=ROOT/'assets/audio'
manifest=json.loads((AUDIO/'audio_manifest.json').read_text())
failures=[]
measurements={}
projectiles=['missile','fire','fire_missile','frost_missile','ball_lightning']
rituals=['teleport','shield','shield_hit','circle','freeze','ring_fire','acid','undead','orb_pulse','ether_pulse','ice_armor_hit']
channels=['lightning','ice','flame_lash','steam','blizzard']
impacts=['arcane','fire','ice','lightning','fire_missile','frost_missile','ball_lightning']
names=projectiles+rituals+['impact_'+x for x in impacts]+['cast_'+x for x in channels]+['release_'+x for x in channels]
for name in names:
 hashes=set()
 for suffix in ['', '_2', '_3']:
  key=name+suffix
  if key not in manifest:
   failures.append(key+': missing variation');continue
  meta=manifest[key]; hashes.add(meta['sha256'])
  x,sr=sf.read(AUDIO/meta['file']);active=np.flatnonzero(np.abs(x)>np.max(np.abs(x))*.1)
  onset=active[0]/sr if len(active) else 999
  duration=len(x)/sr
  measurements[key]={'onset_ms':round(onset*1000,2),'seconds':round(duration,3)}
  if name in projectiles and (onset>.025 or duration>.55): failures.append(key+': sluggish projectile feedback')
  if name.startswith('cast_') and (onset>.025 or duration>.35): failures.append(key+': sluggish channel attack')
  if name.startswith('release_') and duration>.32: failures.append(key+': excessive release tail')
 if len(hashes)!=3: failures.append(name+': duplicate variations')
for name in channels:
 key='channel_'+name; x,sr=sf.read(AUDIO/manifest[key]['file']);n=sr//10
 rms=np.sqrt(np.mean(x*x));floor=min(np.sqrt(np.mean(x[i:i+n]**2)) for i in range(0,len(x)-n,n))
 measurements[key]={'seconds':len(x)/sr,'minimum_100ms_rms_ratio':round(float(floor/rms),3)}
 if len(x)/sr<7.5 or floor/rms<.25: failures.append(key+': short or audibly interrupted sustain')
required={
 'fire':['Fire impact 1.wav'], 'missile':['Misc 02.wav'],
 'impact_fire_missile':['Fire impact 1.wav','Misc 02.wav'],
 'impact_frost_missile':['Ice attack 2.wav','Misc 02.wav'],
 'impact_ball_lightning':['qubodupElectricityDamage','Misc 02.wav'],
 'channel_steam':['steam hisses'], 'channel_flame_lash':['Fire impact 1.wav','qubodupElectricityDamage'],
 'channel_blizzard':['Ice attack 2.wav','qubodupElectricityDamage'],
}
for key,fragments in required.items():
 files=[s['file'] for s in manifest[key]['sources']]
 for fragment in fragments:
  if not any(fragment in file for file in files): failures.append(key+': elemental source missing: '+fragment)
out=ROOT/'outputs/spell-audio';out.mkdir(parents=True,exist_ok=True)
(out/'assets-check.json').write_text(json.dumps({'failures':failures,'measurements':measurements},indent=2)+'\n')
print(json.dumps({'spell_assets':len(measurements),'failures':failures}))
raise SystemExit(bool(failures))
