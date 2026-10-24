"""Validate checked-in authored asset provenance, not synthetic package fixtures."""
import hashlib,json,pathlib,unittest
ROOT=pathlib.Path(__file__).resolve().parents[1]
class CraftedCatalogTests(unittest.TestCase):
 def test_complete_catalogs_are_current_and_within_geometry_budget(self):
  originals={p.stem:p for p in (ROOT/'assets/models').glob('*.glb')}
  for style in ('bright_clay','paper_craft'):
   folder=ROOT/'assets/styles'/style;manifest=json.loads((folder/'manifest.json').read_text())
   self.assertTrue(manifest['complete']);self.assertEqual(manifest['style'],style)
   self.assertEqual({m['id'] for m in manifest['models']},set(originals))
   for record in manifest['models']:
    with self.subTest(style=style,model=record['id']):
     source=originals[record['id']];variant=folder/'models'/source.name
     self.assertEqual(hashlib.sha256(source.read_bytes()).hexdigest(),record['source_sha256'])
     self.assertEqual(hashlib.sha256(variant.read_bytes()).hexdigest(),record['variant_sha256'])
     self.assertEqual(variant.stat().st_size,record['variant_bytes'])
     self.assertLessEqual(record['triangles'],max(record['source_triangles']*2.6+64,1500))
     if record['id'].startswith(('prop_','foliage_')):self.assertLess(record['triangles'],10000)
     self.assertEqual(record['materials'],1)
if __name__=='__main__':unittest.main()
