import hashlib,json,pathlib,struct,unittest
from tools.clay_palette import pigment,linear
from tools.recolor_clay_models import read
ROOT=pathlib.Path(__file__).resolve().parents[1]
class ClayPaletteTests(unittest.TestCase):
 def test_named_srgb_anchors_encoded_once_as_linear(self):
  for name,hex_value in [('scarlet','FF574F'),('azure','28BDF4'),('honey','FFD21F'),('scenery_leaf','55D936')]:
   self.assertEqual(pigment(name,[.1,.2,.3]),linear(hex_value))
   self.assertGreater(max(pigment(name,[0,0,0]))-min(pigment(name,[0,0,0])),.65)
 def test_dark_details_and_neutral_marks_keep_contrast(self):
  self.assertLess(max(pigment('rubber',[0,0,0])),.05)
  self.assertGreater(min(pigment('white',[0,0,0])),.70)
  with self.assertRaises(ValueError):pigment('unexpected_material',[0,0,0])
 def test_every_recolored_model_preserves_recorded_non_color_buffers(self):
  folder=ROOT/'assets/styles/bright_clay';manifest=json.loads((folder/'manifest.json').read_text());self.assertEqual(manifest['palette'],'saturated_clay_v2')
  for row in manifest['models']:
   with self.subTest(model=row['id']):
    doc,data=read((folder/'models'/(row['id']+'.glb')).read_bytes());max_color=0
    for index in {p['attributes']['COLOR_0'] for m in doc['meshes'] for p in m['primitives']}:
     a=doc['accessors'][index];v=doc['bufferViews'][a['bufferView']];step=v.get('byteStride',int(a['type'][-1])*4);start=v.get('byteOffset',0)+a.get('byteOffset',0)
     for i in range(a['count']):
      offset=start+i*step;colors=struct.unpack_from('<fff',data,offset)
      self.assertTrue(all(0<=c<=1 for c in colors));max_color=max(max_color,*colors);data[offset:offset+12]=b'\0'*12
    self.assertGreater(max_color,.01)
    self.assertEqual(hashlib.sha256(data).hexdigest(),row['non_color_buffer_sha256'])
 def test_all_car_pigments_are_present_in_actual_buffers(self):
  for car,material in [('car_speed','scarlet'),('car_agile','honey'),('car_dirt','azure'),('car_balanced','mint'),('car_pickup','apricot'),('car_roadster','ice'),('car_muscle','plum'),('car_buggy','sand')]:
   doc,data=read((ROOT/'assets/styles/bright_clay/models'/(car+'.glb')).read_bytes());target=pigment(material,[0,0,0]);found=False
   for mesh in doc['meshes']:
    for p in mesh['primitives']:
     a=doc['accessors'][p['attributes']['COLOR_0']];v=doc['bufferViews'][a['bufferView']];stride=v.get('byteStride',int(a['type'][-1])*4)
     for i in range(a['count']):
      color=struct.unpack_from('<fff',data,v.get('byteOffset',0)+a.get('byteOffset',0)+i*stride)
      if all(abs(c-t)<.026 for c,t in zip(color,target)):found=True;break
   self.assertTrue(found,car+' body pigment missing')
