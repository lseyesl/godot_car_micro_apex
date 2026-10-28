"""Original short electronic race cues, deterministic PCM with smooth envelopes."""
import math,struct,wave
from pathlib import Path
RATE=22050
ROOT=Path(__file__).resolve().parents[1]/'assets/audio'
for name,duration in [('countdown',.16),('go',.38)]:
 values=[]
 for i in range(round(duration*RATE)):
  t=i/RATE;envelope=min(1,t/.008)*min(1,(duration-t)/.035)
  if name=='countdown':signal=.36*math.sin(math.tau*660*t)+.075*math.sin(math.tau*1320*t)
  else:signal=.24*math.sin(math.tau*880*t)+.19*math.sin(math.tau*1320*t)+.10*math.sin(math.tau*(660*t+440*t*t))
  values.append(round(signal*envelope*32767))
 assert max(map(abs,values))<32767
 with wave.open(str(ROOT/(name+'.wav')),'wb') as f:
  f.setparams((1,2,RATE,0,'NONE','not compressed'));f.writeframes(struct.pack('<'+'h'*len(values),*values))
