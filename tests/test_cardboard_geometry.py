"""Check physical, non-coplanar cardboard seams in every actual shipped paper GLB."""
import collections,json,math,pathlib,struct,unittest
from tools.recolor_clay_models import read
ROOT=pathlib.Path(__file__).resolve().parents[1]
def accessor(doc,data,index):
 a=doc['accessors'][index];v=doc['bufferViews'][a['bufferView']];fmt={5121:'B',5123:'H',5125:'I',5126:'f'}[a['componentType']];n={'SCALAR':1,'VEC3':3,'VEC4':4}[a['type']];size=struct.calcsize('<'+fmt*n);start=v.get('byteOffset',0)+a.get('byteOffset',0);stride=v.get('byteStride',size)
 return [struct.unpack_from('<'+fmt*n,data,start+i*stride) for i in range(a['count'])]
def physical_seam(doc,data):
 light={(0.58,0.38,0.2),(0.74,0.58,0.37)};dark=(0.32,0.18,0.085)
 def point(p):return tuple(round(v,5) for v in p)
 for mesh in doc['meshes']:
  for primitive in mesh['primitives']:
   p=accessor(doc,data,primitive['attributes']['POSITION']);c=accessor(doc,data,primitive['attributes']['COLOR_0']);indices=[x[0] for x in accessor(doc,data,primitive['indices'])];by_point=collections.defaultdict(list);inner=[]
   for i in range(0,len(indices),3):
    tri=indices[i:i+3];color=tuple(round(x,4) for x in c[tri[0]][:3])
    if color not in light and color!=dark:continue
    if any(tuple(round(x,4) for x in c[k][:3])!=color for k in tri):continue
    vertices=[p[k] for k in tri]
    if color==dark:inner.append(vertices)
    else:
     for v in vertices:by_point[point(v)].append(vertices)
   for triangle in inner:
    a,b,c=triangle;u=[b[j]-a[j] for j in range(3)];v=[c[j]-a[j] for j in range(3)];normal=[u[1]*v[2]-u[2]*v[1],u[2]*v[0]-u[0]*v[2],u[0]*v[1]-u[1]*v[0]];length=math.sqrt(sum(x*x for x in normal))
    if length<1e-10:continue
    keys={point(x) for x in triangle}
    for vertex in triangle:
     for neighbor in by_point[point(vertex)]:
      if len(keys & {point(x) for x in neighbor})<2:continue
      if max(abs(sum((x[j]-a[j])*normal[j] for j in range(3)))/length for x in neighbor)>1e-6:return True
 return False
class CardboardGeometryTests(unittest.TestCase):
 def test_grass_is_one_closed_extruded_silhouette(self):
  for name in ('foliage_grass_green','foliage_grass_dry'):
   with self.subTest(model=name):
    doc,data=read((ROOT/'assets/styles/paper_craft/models'/f'{name}.glb').read_bytes())
    self.assertEqual(len(doc['meshes']),1);self.assertEqual(len(doc['meshes'][0]['primitives']),1)
    primitive=doc['meshes'][0]['primitives'][0];points=accessor(doc,data,primitive['attributes']['POSITION'])
    indices=[x[0] for x in accessor(doc,data,primitive['indices'])]
    weld=[tuple(round(x,5) for x in p) for p in points];depths={p[2] for p in weld}
    self.assertEqual(len(depths),4,'Two parallel faces and two recessed edge rings only')
    self.assertAlmostEqual(max(depths)-min(depths),.055,places=4)
    edges=collections.Counter();neighbors=collections.defaultdict(set)
    for i in range(0,len(indices),3):
     triangle=[weld[j] for j in indices[i:i+3]]
     self.assertEqual(len(set(triangle)),3)
     for a,b in zip(triangle,triangle[1:]+triangle[:1]):
      edges[tuple(sorted((a,b)))]+=1;neighbors[a].add(b);neighbors[b].add(a)
    self.assertTrue(all(n==2 for n in edges.values()),'Every welded edge must belong to a closed solid')
    pending=[weld[0]];seen=set()
    while pending:
     vertex=pending.pop()
     if vertex not in seen:seen.add(vertex);pending.extend(neighbors[vertex]-seen)
    self.assertEqual(seen,set(weld),'No detached blades or crossing cards')
    self.assertEqual(len(seen),13*4);self.assertEqual(len(indices)//3,100)
    node=next(n for n in doc['nodes'] if 'mesh' in n)
    self.assertAlmostEqual(min(p[1] for p in points)+node['translation'][1],-.08,places=5)
    self.assertTrue(all(len(c)==3 or c[3]>.999 for c in accessor(doc,data,primitive['attributes']['COLOR_0'])))
 def test_every_paper_model_has_real_recessed_lamination(self):
  folder=ROOT/'assets/styles/paper_craft'
  for record in json.loads((folder/'manifest.json').read_text())['models']:
   with self.subTest(model=record['id']):
    doc,data=read((folder/'models'/(record['id']+'.glb')).read_bytes());self.assertTrue(physical_seam(doc,data),'Colored seam must be physically non-coplanar')
 def test_complete_catalog_has_thickness_and_no_new_open_components(self):
  manifest=json.loads((ROOT/'assets/styles/paper_craft/manifest.json').read_text());self.assertEqual(len(manifest['models']),37)
  for record in manifest['models']:
   with self.subTest(model=record['id']):
    detail=record['cardboard'];self.assertGreater(detail['layered_edges'],0);self.assertGreater(detail['groove_depth_max'],1e-6)
    for part in detail['meshes']:
     self.assertLessEqual(part['boundary_components_after'],part['boundary_components_before'])
     if not part['boundary_edges_before']:self.assertEqual(part['boundary_edges_after'],0)
     self.assertGreater(part['requested_cut_width'],0);self.assertLessEqual(part['requested_cut_width'],.120001)
