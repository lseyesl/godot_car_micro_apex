"""Original deterministic synth assets. No samples or third-party recordings."""
import math, wave, struct, random
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]/'assets'/'audio'
RATE=22050
random.seed(4107)
def save(name, duration, signal):
    samples=[]
    for i in range(int(duration*RATE)):
        value=max(-.95,min(.95,signal(i/RATE,i)))
        samples.append(int(value*32767))
    with wave.open(str(ROOT/(name+'.wav')),'wb') as f:
        f.setparams((1,2,RATE,0,'NONE','not compressed'))
        f.writeframes(struct.pack('<'+'h'*len(samples),*samples))
def tone(hz,t):return math.sin(math.tau*hz*t)
def note(midi):return 440*2**((midi-69)/12)
def melody(name,notes,step):
    save(name,len(notes)*step,lambda t,i: .32*tone(note(notes[min(int(t/step),len(notes)-1)]),t)*math.exp(-5*(t%step)/step)*min(1,(t%step)*300))
ROOT.mkdir(exist_ok=True)
save('engine',1,lambda t,i:.22*tone(60,t)+.12*tone(120,t)+.08*tone(180,t)+.04*tone(300,t))
save('dirt',1,lambda t,i:(random.random()-.5)*.35*(.65+.35*tone(20,t)))
save('impact',.22,lambda t,i:(random.random()-.5)*math.exp(-t*23)*.7)
melody('click',[76],.09)
melody('countdown',[72],.22)
melody('go',[84],.45)
melody('finish',[60,64,67,72,76,79,84,84],.18)
BPM=112
BEAT=60/BPM
CHORDS=[(45,60,64,67),(41,60,65,69),(48,60,64,67),(43,59,62,67)]
def music(t,i):
    beat=t/BEAT
    chord=CHORDS[int(beat/8)%4]
    sub=beat%1
    bass=.13*tone(note(chord[0]),t)*math.exp(-sub*4)
    arp=chord[1+int(beat*2)%3]+12
    lead=.10*tone(note(arp),t)*math.exp(-(beat*2%1)*5)
    kick=.12*tone(55+70*math.exp(-sub*30),t)*math.exp(-sub*16) if int(beat)%2==0 else 0
    hat=(random.random()-.5)*.045*math.exp(-(beat*2%1)*23)
    fade=min(1,t*4,(32*BEAT-t)*4)
    return (bass+lead+kick+hat)*fade
save('music',32*BEAT,music)
print('Generated eight original synth audio assets.')
