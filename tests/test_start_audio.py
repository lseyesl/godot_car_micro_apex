import math,pathlib,struct,unittest,wave
ROOT=pathlib.Path(__file__).resolve().parents[1]/'assets/audio'
class StartAudioTests(unittest.TestCase):
 def test_pcm_headroom_and_envelopes(self):
  for name,duration in [('countdown',.16),('go',.38)]:
   with self.subTest(name=name),wave.open(str(ROOT/(name+'.wav')),'rb') as f:
    self.assertEqual((f.getnchannels(),f.getsampwidth(),f.getframerate()),(1,2,22050))
    data=struct.unpack('<'+'h'*f.getnframes(),f.readframes(f.getnframes()));self.assertAlmostEqual(len(data)/22050,duration,places=3)
    self.assertLess(max(map(abs,data))/32768,.60);self.assertLess(abs(sum(data)/len(data))/32768,.002)
    self.assertEqual(data[0],0);self.assertLess(abs(data[-1]),50)
    self.assertGreater(math.sqrt(sum(x*x for x in data)/len(data))/32768,.12)
 def test_spectral_identity(self):
  powers=[]
  for name in ['countdown','go']:
   with wave.open(str(ROOT/(name+'.wav')),'rb') as f:d=struct.unpack('<'+'h'*f.getnframes(),f.readframes(f.getnframes()))
   def energy(hz):return abs(sum(x*complex(math.cos(2*math.pi*hz*i/22050),math.sin(2*math.pi*hz*i/22050)) for i,x in enumerate(d)))
   powers.append((energy(660),energy(880)))
  self.assertGreater(powers[0][0],powers[0][1]*10);self.assertGreater(powers[1][1],powers[1][0]*4)
