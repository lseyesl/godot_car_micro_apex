"""Recolor existing clay COLOR_0 buffers; leave all geometry/normal/UV bytes intact.
The legacy baseline is pinned so repeating this tool never compounds color changes.
"""
import hashlib,json,pathlib,struct,subprocess
try:
 from .clay_palette import pigment,legacy_pigment
except ImportError:
 from clay_palette import pigment,legacy_pigment
ROOT=pathlib.Path(__file__).resolve().parents[1]
BASELINE='e6209b8dc4fadf61ceae2a5a761b81be353f1738'
def read(raw):
 n=struct.unpack_from('<I',raw,12)[0];return json.loads(raw[20:20+n]),bytearray(raw[28+n:])
def write(doc,binary):
 data=json.dumps(doc,separators=(',',':')).encode();data+=b' '*((-len(data))%4)
 return struct.pack('<III',0x46546c67,2,28+len(data)+len(binary))+struct.pack('<II',len(data),0x4e4f534a)+data+struct.pack('<II',len(binary),0x004e4942)+binary
def non_color_buffer_hash(doc,binary):
 data=bytearray(binary)
 for index in {p['attributes']['COLOR_0'] for m in doc['meshes'] for p in m['primitives']}:
  a=doc['accessors'][index];v=doc['bufferViews'][a['bufferView']];stride=v.get('byteStride',int(a['type'][-1])*4);start=v.get('byteOffset',0)+a.get('byteOffset',0)
  for i in range(a['count']):data[start+i*stride:start+i*stride+12]=b'\0'*12
 return hashlib.sha256(data).hexdigest()
def recolor(doc,binary,materials):
 palette=[(legacy_pigment(m['name'],m['pbrMetallicRoughness']['baseColorFactor'][:3]),pigment(m['name'],m['pbrMetallicRoughness']['baseColorFactor'][:3])) for m in materials]
 original=bytes(binary);ranges=[];worst=0
 for index in sorted({p['attributes']['COLOR_0'] for m in doc['meshes'] for p in m['primitives']}):
  a=doc['accessors'][index];v=doc['bufferViews'][a['bufferView']];assert a['componentType']==5126 and a['type'] in ('VEC3','VEC4')
  components=int(a['type'][-1]);stride=v.get('byteStride',components*4);start=v.get('byteOffset',0)+a.get('byteOffset',0)
  for i in range(a['count']):
   pos=start+i*stride;c=struct.unpack_from('<fff',original,pos);choices=[]
   for old,new in palette:
    scale=sum(x*y for x,y in zip(c,old))/sum(x*x for x in old)
    error=sum((x-y*scale)**2 for x,y in zip(c,old))
    choices.append((error,scale,new))
   error,scale,new=min(choices,key=lambda x:x[0]);worst=max(worst,error)
   assert error<1e-9 and .973<scale<1.027,(error,scale)
   struct.pack_into('<fff',binary,pos,*[min(1,max(0,x*scale)) for x in new]);ranges.append((pos,pos+12))
 # Hash all other buffer bytes, explicitly preserving positions, normals and UVs.
 old=bytearray(original);new=bytearray(binary)
 for a,b in ranges:old[a:b]=b'\0'*(b-a);new[a:b]=b'\0'*(b-a)
 assert old==new
 return hashlib.sha256(old).hexdigest(),worst
if __name__=='__main__':
 manifest_path=ROOT/'assets/styles/bright_clay/manifest.json';manifest=json.loads(manifest_path.read_text())
 for row in manifest['models']:
  name=row['id'];rel=f'assets/styles/bright_clay/models/{name}.glb'
  baseline=subprocess.check_output(['git','show',BASELINE+':'+rel],cwd=ROOT)
  doc,binary=read(baseline);source,_=read((ROOT/'assets/models'/f'{name}.glb').read_bytes())
  geometry,error=recolor(doc,binary,source['materials']);doc['asset']['generator']='Micro Apex handmade clay; saturated linear corner pigments v2'
  raw=write(doc,binary);(ROOT/rel).write_bytes(raw)
  row.update(variant_sha256=hashlib.sha256(raw).hexdigest(),variant_bytes=len(raw),non_color_buffer_sha256=geometry)
  print(name,'unchanged geometry, max residual',error,flush=True)
 manifest['palette']='saturated_clay_v2';manifest['palette_baseline']=BASELINE
 manifest_path.write_text(json.dumps(manifest,indent=2)+'\n')
