"""Audition spell identities and optionally compare with cached pre-redesign assets.

These are labelled offline montages, not recordings of gameplay. Comparison
blocks have equal RMS; only a shared final gain prevents clipping, so a louder
asset alone cannot win the comparison. Timings are saved beside each montage.
"""
from pathlib import Path
import json
import numpy as np
import soundfile as sf

ROOT=Path(__file__).resolve().parents[1]
AUDIO=ROOT/'assets/audio'
OUT=ROOT/'outputs/spell-audio'
SR=44100
PROJECTILES=['missile','fire','fire_missile','frost_missile','ball_lightning']
CHANNELS=['lightning','ice','flame_lash','steam','blizzard']
IMPACTS={'missile':'arcane','fire':'fire','fire_missile':'fire_missile','frost_missile':'frost_missile','ball_lightning':'ball_lightning'}
OLD_IMPACTS={'missile':'arcane','fire':'fire','fire_missile':'fire','frost_missile':'ice','ball_lightning':'lightning'}


def read(folder,name):
 x,sr=sf.read(folder/(name+'.wav'));assert sr==SR
 return x


def place(out,x,t,gain=1):
 start=round(t*SR);n=min(len(x),len(out)-start)
 if n>0: out[start:start+n]+=x[:n]*gain


def block(folder,name,old=False):
 out=np.zeros(SR*3)
 if name in CHANNELS:
  x=read(folder,'channel_'+name);x=np.tile(x,1+round(2.1*SR)//len(x))[:round(2.1*SR)].copy()
  n=round(.065*SR);x[:n]*=np.linspace(0,1,n);x[-n:]*=np.linspace(1,0,n)
  place(out,x,.1,.28 if old else .224)
  if not old:
   place(out,read(folder,'cast_'+name),.1,.45)
   place(out,read(folder,'release_'+name),2.15,.18)
 elif name in PROJECTILES:
  for t in [.1,.65,1.2]:
   place(out,read(folder,name),t,.45)
   impact=(OLD_IMPACTS if old else IMPACTS)[name]
   place(out,read(folder,'impact_'+impact),t+.22,.355)
 else: place(out,read(folder,name),.1,.45)
 # A clean join and silence separate every identity.
 n=round(.08*SR);out[-n:]*=np.linspace(1,0,n)
 return out


def save(name,blocks):
 timeline=[];out=[];cursor=0.0
 for label,x in blocks:
  timeline.append({'seconds':round(cursor,2),'label':label})
  out.extend([x,np.zeros(round(.35*SR))]);cursor+=len(x)/SR+.35
 mix=np.concatenate(out);mix*=min(1,.85/max(np.max(np.abs(mix)),1e-6))
 sf.write(OUT/(name+'.wav'),mix,SR,subtype='PCM_16')
 (OUT/(name+'.json')).write_text(json.dumps({'kind':'offline audition','timeline':timeline},indent=2)+'\n')
 print(OUT/(name+'.wav'))


if __name__=='__main__':
 OUT.mkdir(parents=True,exist_ok=True)
 names=PROJECTILES+CHANNELS+['teleport','shield','freeze','ring_fire','acid','undead','circle']
 save('nouveaux-sorts',[(name,block(AUDIO,name)) for name in names])
 before=OUT/'before'
 if before.exists():
  blocks=[]
  for name in PROJECTILES+CHANNELS:
   pair=[block(before,name,True),block(AUDIO,name)]
   pair=[x*(.055/max(np.sqrt(np.mean(x*x)),1e-6)) for x in pair]
   blocks.extend([(name+' / AVANT',pair[0]),(name+' / APRÈS',pair[1])])
  save('avant-apres-sorts',blocks)
