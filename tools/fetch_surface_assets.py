"""Fetch pinned 1K CC0 Poly Haven material maps; preserve provenance and checksums."""
import concurrent.futures,hashlib,json,pathlib,urllib.request
ROOT=pathlib.Path(__file__).resolve().parents[1]
OUT=ROOT/'assets/textures/surfaces';OUT.mkdir(parents=True,exist_ok=True)
IDS=['asphalt_02','clean_asphalt','grass_ground','cobblestone_floor_03','grass_path_3','brown_mud_dry','rough_plaster_brick','clay_roof_tiles','weathered_brown_planks','marble_cliff_02','concrete_wall_005']
PINNED=json.loads((OUT/'manifest.json').read_text()) if (OUT/'manifest.json').exists() else []
HEADERS={'User-Agent':'MicroApexArtDevelopment/0.9 contact local-development'}
def read(url):return urllib.request.urlopen(urllib.request.Request(url,headers=HEADERS),timeout=45).read()
def get(asset):
 pinned=next((entry for entry in PINNED if entry['id']==asset),None)
 if pinned:
  for item in pinned['maps'].values():
   file=OUT/item['file'];data=file.read_bytes() if file.exists() else read(item['url'])
   assert hashlib.sha256(data).hexdigest()==item['sha256'],asset
   if not file.exists():file.write_bytes(data)
  print('Verified pinned',asset,flush=True);return pinned
 metadata=json.loads(read('https://api.polyhaven.com/files/'+asset));maps={}
 for channel in ['Diffuse','nor_gl','AO']:
  if channel not in metadata:continue
  item=metadata[channel]['1k']['jpg'];data=read(item['url'])
  assert hashlib.md5(data).hexdigest()==item['md5'],asset
  name=asset+'_'+{'Diffuse':'albedo','nor_gl':'normal','AO':'ao'}[channel]+'.jpg';(OUT/name).write_bytes(data)
  maps[channel]={'file':name,'url':item['url'],'sha256':hashlib.sha256(data).hexdigest()}
 print('Fetched',asset,flush=True)
 return {'id':asset,'source':'https://polyhaven.com/a/'+asset,'license':'CC0-1.0','maps':maps}
with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:assets=list(pool.map(get,IDS))
(OUT/'manifest.json').write_text(json.dumps(assets,indent=2)+'\n')
if not (ROOT/'assets/legal/PolyHaven-CC0.txt').exists():(ROOT/'assets/legal/PolyHaven-CC0.txt').write_text('Material textures: Poly Haven\nSource: https://polyhaven.com/\nAsset policy: https://polyhaven.com/license\nLicense: CC0 1.0 Universal\nLegal text: https://creativecommons.org/publicdomain/zero/1.0/legalcode\n\nAsset-by-asset source URLs and file checksums: assets/textures/surfaces/manifest.json\nThese textures may be used commercially, modified and redistributed under CC0.\nMini Motor Racing reference screenshots are not included in game assets.\n')
