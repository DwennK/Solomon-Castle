"""Validate generated and mixer-recorded audio; no playback or personal audio access."""
from pathlib import Path
import json
import numpy as np
import soundfile as sf

ROOT=Path(__file__).resolve().parents[1]
AUDIO=ROOT/'assets/audio'
manifest=json.loads((AUDIO/'audio_manifest.json').read_text())
failures=[]
report={}
for name,meta in manifest.items():
 path=AUDIO/(name+('.ogg' if name.startswith('music_') else '.wav'))
 x,sr=sf.read(path,always_2d=True)
 peak=float(np.max(np.abs(x)))
 rms=float(np.sqrt(np.mean(x*x)))
 seam=float(np.max(np.abs(x[0]-x[-1])))
 if sr!=44100 or x.shape[1]!=meta['channels']: failures.append(name+': format')
 if not np.isfinite(x).all() or peak>=.99 or rms<.0001: failures.append(name+': clipping/silence/nonfinite')
 if abs(len(x)/sr-meta['seconds'])>.002: failures.append(name+': duration')
 if meta['loop'] and seam>.025: failures.append(name+': loop seam')
 if not meta['loop'] and np.max(np.abs(x[[0,-1]]))>.001: failures.append(name+': boundary click')
 report[name]={'peak_db':round(20*np.log10(peak),2),'rms_db':round(20*np.log10(rms),2),'loop_seam':round(seam,6)}
recording=ROOT/'outputs/audio-qa/gameplay-mix.wav'
if recording.exists():
 x,sr=sf.read(recording,always_2d=True)
 report['mixer']={'seconds':len(x)/sr,'peak_db':round(float(20*np.log10(np.max(np.abs(x)))),2),'rms_db':round(float(20*np.log10(np.sqrt(np.mean(x*x)))) ,2)}
 if np.max(np.abs(x))>=.99 or np.sqrt(np.mean(x*x))<.0001: failures.append('Recorded mixer clips or is silent')
else: failures.append('Missing actual mixer recording')
output=ROOT/'outputs/audio-qa/assets.json'
output.parent.mkdir(parents=True,exist_ok=True)
output.write_text(json.dumps({'assets':len(manifest),'failures':failures,'measurements':report},indent=2)+'\n')
print(json.dumps({'assets':len(manifest),'failures':failures,'mixer':report.get('mixer')}))
raise SystemExit(bool(failures))
