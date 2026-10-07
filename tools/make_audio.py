"""Original deterministic procedural score and effects. No sampled external audio."""
from pathlib import Path
import wave, math, random, struct
out=Path(__file__).resolve().parents[1]/'assets/audio';out.mkdir(exist_ok=True)
SR=22050
rng=random.Random(324)
def save(name,seconds,fn):
 with wave.open(str(out/(name+'.wav')),'wb') as f:
  f.setparams((1,2,SR,0,'NONE','not compressed'))
  f.writeframes(b''.join(struct.pack('<h',int(max(-0.9,min(0.9,fn(i/SR)))*32767)) for i in range(int(SR*seconds))))
for name,freq,dur in [('missile',540,.22),('fire',150,.32),('impact',100,.14),('hurt',85,.24),('enemy',120,.16),('potion',780,.45),('loot',1050,.2),('ui',650,.10),('ritual',300,.8),('channel',420,.16),('chest',240,.42),('death',90,1.2),('victory',520,2.2)]:
 def tone(t,freq=freq,dur=dur,name=name):
  env=math.sin(math.pi*min(1,t/dur))**.4*math.exp(-t/dur*4)
  pitch=freq*(1-t/dur*.5)
  v=math.sin(2*math.pi*pitch*t)*.22+math.sin(2*math.pi*pitch*2.01*t)*.07
  if name in ('fire','impact','hurt','enemy','channel'): v+=rng.uniform(-.13,.13)
  if name=='victory':v=sum(math.sin(2*math.pi*freq*k*t) for k in [1,1.25,1.5,2])*.08
  return v*env
 save(name,dur,tone)
def music(t):
 # D minor / B-flat / G minor / A suspended, slowly changing bells over a drone.
 chord=[(146.83,174.61,220),(116.54,146.83,174.61),(98,146.83,174.61),(110,146.83,164.81)][int(t/6)%4]
 pulse=t%1.5;note=chord[int(t/1.5)%3]*2
 pad=sum(math.sin(2*math.pi*f*t+.3*math.sin(t*.3)) for f in chord)*.025
 bell=math.sin(2*math.pi*note*t)*math.exp(-pulse*3)*.06
 return (pad+bell+math.sin(2*math.pi*49*t)*.02)*min(1,t/2,(24-t)/2)
save('ambience',24,music)
