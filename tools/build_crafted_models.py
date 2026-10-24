"""Blender 4.3+: rebuild handmade-clay/paper variants from immutable original GLBs.
Geometry, corner colors and baked tangent normals are exported; no runtime shader work.
Run: blender -b -t 2 --python tools/build_crafted_models.py -- --style bright_clay
"""
import argparse, hashlib, json, math, re, struct, sys
from pathlib import Path
import bpy, bmesh
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[1]

def glb(path):
 raw=path.read_bytes();n,kind=struct.unpack_from('<II',raw,12);assert kind==0x4e4f534a
 return json.loads(raw[20:20+n]),raw[20+n:]
def save_glb(path,doc,binary):
 data=json.dumps(doc,separators=(',',':')).encode();data+=b' '*((-len(data))%4)
 path.write_bytes(struct.pack('<III',0x46546c67,2,20+len(data)+len(binary))+struct.pack('<II',len(data),0x4e4f534a)+data+binary)
def shared_surface_texture(doc,binary):
 # All models use one external normal map per style, avoiding 37 extracted
 # duplicate textures and independent GPU allocations after Godot import.
 image_views={image['bufferView'] for image in doc.get('images',[]) if 'bufferView' in image}
 for image in doc.get('images',[]):
  image.pop('bufferView',None);image.pop('mimeType',None);image['uri']='../textures/surface_normal.png'
 if not image_views:return binary
 payload=binary[8:];new_payload=bytearray();views=[];mapping={}
 for i,view in enumerate(doc['bufferViews']):
  if i in image_views:continue
  mapping[i]=len(views);offset=view.get('byteOffset',0);data=payload[offset:offset+view['byteLength']]
  while len(new_payload)%4:new_payload.append(0)
  copy=dict(view);copy['byteOffset']=len(new_payload);new_payload.extend(data);views.append(copy)
 for accessor in doc.get('accessors',[]):
  if 'bufferView' in accessor:accessor['bufferView']=mapping[accessor['bufferView']]
  for item in accessor.get('sparse',{}).values():
   if isinstance(item,dict) and 'bufferView' in item:item['bufferView']=mapping[item['bufferView']]
 while len(new_payload)%4:new_payload.append(0)
 doc['bufferViews']=views;doc['buffers'][0]['byteLength']=len(new_payload)
 return struct.pack('<II',len(new_payload),0x004e4942)+new_payload

def paths(doc):
 result={}
 def visit(i,parent=''):
  n=doc['nodes'][i];path=parent+'/'+n.get('name',str(i));result[path]=n
  for child in n.get('children',[]):visit(child,path)
 for i in doc['scenes'][doc.get('scene',0)]['nodes']:visit(i)
 return result
def restore_contract(doc,source):
 original=paths(source)
 def visit(i,parent=''):
  n=doc['nodes'][i];name=n.get('name',str(i));path=parent+'/'+name
  if path not in original:
   name=re.sub(r'\.\d{3}$','',name);path=parent+'/'+name
  assert path in original,('Unexpected exported node',path)
  n['name']=name;old=original[path]
  # Import/export round trips can normalize a quaternion or rename repeated
  # WheelMesh objects. Keep exact original pivot transforms and semantic paths.
  for key in ['matrix','translation','rotation','scale','extras']:
   if key in old:n[key]=old[key]
   else:n.pop(key,None)
  for child in n.get('children',[]):visit(child,path)
 for i in doc['scenes'][doc.get('scene',0)]['nodes']:visit(i)
 assert set(paths(doc))==set(original),'Semantic hierarchy changed'

def make_normal(path,style):
 path.parent.mkdir(parents=True,exist_ok=True);N=128
 def height(u,v):
  if style=='paper_craft':return .00065*math.sin(u*193+math.sin(v*71))+.00045*math.sin(v*173+u*21)
  r=math.sqrt((u-.47)**2*1.1+(v-.53)**2*.72+.0001)
  return .004*math.sin(95*r+math.sin(u*16))*math.exp(-r*r*7)+.006*math.sin(u*18+math.sin(v*13))+.002*math.cos(u*47-v*31)
 image=bpy.data.images.new('Craft surface normal',width=N,height=N,alpha=False)
 pixels=[]
 for y in range(N):
  for x in range(N):
   u=x/N;v=y/N;e=1/N
   dx=(height(u+e,v)-height(u-e,v))/(2*e);dy=(height(u,v+e)-height(u,v-e))/(2*e)
   n=Vector((-dx,-dy,1)).normalized();pixels.extend(((n.x+1)/2,(n.y+1)/2,(n.z+1)/2,1))
 # Changing a generated image's color space discards its pixel buffer. Set
 # metadata first, then fill and update; verify blue normals before saving.
 image.colorspace_settings.name='Non-Color';image.filepath_raw=str(path);image.file_format='PNG'
 image.pixels.foreach_set(pixels);image.update();assert image.pixels[2]>.8
 image.save();bpy.data.images.remove(image)

def craft_material(style,normal_path):
 mat=bpy.data.materials.new('Handworked clay' if style=='bright_clay' else 'Folded paper');mat.use_nodes=True
 node=mat.node_tree.nodes.get('Principled BSDF');node.inputs['Roughness'].default_value=.94;node.inputs['Metallic'].default_value=0
 node.inputs['Specular IOR Level'].default_value=.12 if style=='bright_clay' else .06
 color=mat.node_tree.nodes.new('ShaderNodeVertexColor');color.layer_name='CraftColor';mat.node_tree.links.new(color.outputs['Color'],node.inputs['Base Color'])
 texture=mat.node_tree.nodes.new('ShaderNodeTexImage');texture.image=bpy.data.images.load(str(normal_path));texture.image.colorspace_settings.name='Non-Color'
 normal=mat.node_tree.nodes.new('ShaderNodeNormalMap');normal.inputs['Strength'].default_value=.7 if style=='bright_clay' else .3
 mat.node_tree.links.new(texture.outputs['Color'],normal.inputs['Color']);mat.node_tree.links.new(normal.outputs['Normal'],node.inputs['Normal'])
 return mat

def pigment(material,style):
 node=material.node_tree.nodes.get('Principled BSDF') if material and material.use_nodes else None
 c=list(node.inputs['Base Color'].default_value[:3] if node else material.diffuse_color[:3]);name=material.name.lower() if material else ''
 if any(x in name for x in ['rubber','trim']):c=[.032,.042,.044] if style=='bright_clay' else [.05,.052,.05]
 elif 'glass' in name:c=[.045,.085,.10] if style=='bright_clay' else [.07,.10,.115]
 elif any(x in name for x in ['rim','metal','disc']):c=[.53,.50,.42] if style=='bright_clay' else [.58,.56,.49]
 elif any(x in name for x in ['leaf','grass']):c=[max(.09,c[0]*.95),min(.65,c[1]*1.15+.06),max(.055,c[2]*1.25)]
 else:c=[min(.94,max(.025,x*.95+.035)) for x in c]
 if max(c)-min(c)>.25:c=[x*.72 for x in c]
 if style=='paper_craft':c=[min(.91,x*.88+.075) for x in c]
 return c

def build_mesh(obj,style,material):
 mesh=obj.data;original_materials=list(mesh.materials);colors=[pigment(m,style) for m in original_materials]
 source_min=Vector([min(v.co[j] for v in mesh.vertices) for j in range(3)]);source_max=Vector([max(v.co[j] for v in mesh.vertices) for j in range(3)])
 corners=[Vector(v) for v in obj.bound_box];span=Vector([max(v[j] for v in corners)-min(v[j] for v in corners) for j in range(3)])
 longest=max(span);wheel='WheelMesh' in obj.name
 bm=bmesh.new();bm.from_mesh(mesh)
 bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=.000001)
 if style=='bright_clay':
  limit=max(.22,min(.85,longest*.13))
  if obj.name.startswith("prop_ferris_wheel") or longest>20:limit=longest*2
  edges=[e for e in bm.edges if e.calc_length()>limit]
  if edges:bmesh.ops.subdivide_edges(bm,edges=edges,cuts=1,use_grid_fill=True)
  bm.normal_update();amplitude=min(.045,longest*(.003 if wheel else .012))
  for v in bm.verts:
   p=v.co;field=.52*math.sin(p.x*4.3+math.sin(p.z*3.1))+.31*math.cos(p.y*5.1+p.z*2.7)+.17*math.sin(p.x*13.3+p.y*9.7)
   v.co+=v.normal*(amplitude*field)
 else:
  bmesh.ops.dissolve_limit(bm,angle_limit=.20 if wheel else .55,verts=list(bm.verts),edges=list(bm.edges),delimit={'MATERIAL'},use_dissolve_boundaries=False)
  bm.normal_update();folds=[f for f in bm.faces if f.calc_area()>(.10 if not wheel else .25)]
  if folds:
   folded=bmesh.ops.poke(bm,faces=folds,offset=0,center_mode='MEAN_WEIGHTED')
   for v in folded['verts']:v.co+=v.normal*min(.012,longest*.0018)
  bm.normal_update()
  edges=[e for e in bm.edges if e.is_manifold and e.calc_length()>.12 and e.calc_face_angle()>.65]
  edge_material=len(colors);colors.append([.91,.875,.78])
  if edges:
   bmesh.ops.bevel(bm,geom=edges,offset=min(.012,longest*.005),segments=1,affect='EDGES',profile=.5,clamp_overlap=True,material=edge_material)
 bmesh.ops.triangulate(bm,faces=list(bm.faces));bm.normal_update();bm.to_mesh(mesh);bm.free();mesh.update()
 # Keep exact visual envelope, units and pivot clearance, including wheel radius.
 current_min=Vector([min(v.co[j] for v in mesh.vertices) for j in range(3)]);current_max=Vector([max(v.co[j] for v in mesh.vertices) for j in range(3)])
 for vertex in mesh.vertices:
  for j in range(3):
   span=current_max[j]-current_min[j]
   vertex.co[j]=source_min[j]+(vertex.co[j]-current_min[j])*(source_max[j]-source_min[j])/span if span>1e-8 else source_min[j]
 mesh.update()
 if mesh.has_custom_normals:mesh.normals_split_custom_set([(0,0,0)]*len(mesh.loops))
 if mesh.uv_layers.active is None:mesh.uv_layers.new(name='UVMap')
 if mesh.color_attributes.get('CraftColor') is None:mesh.color_attributes.new(name='CraftColor',type='FLOAT_COLOR',domain='CORNER')
 # Creating a CustomData layer invalidates previously held RNA layer pointers.
 # Reacquire both only after all layers exist; otherwise UV writes corrupt color.
 mesh.color_attributes.active_color=mesh.color_attributes['CraftColor']
 uv=mesh.uv_layers.active;attribute=mesh.color_attributes['CraftColor']
 for face in mesh.polygons:
  face.use_smooth=style=='bright_clay';base=colors[min(face.material_index,len(colors)-1)]
  # Keep coplanar paper pigment continuous so the importer can build useful
  # distance LODs. Physical folds/edge bands carry the paper geometry detail.
  variation=1.0
  axis=max(range(3),key=lambda j:abs(face.normal[j]));a,b=[j for j in range(3) if j!=axis]
  for loop in face.loop_indices:
   p=mesh.vertices[mesh.loops[loop].vertex_index].co
   uv.data[loop].uv=(p[a]*.8,p[b]*.8)
   tint=variation if style=='paper_craft' else 1+.025*math.sin(p.x*8.3+p.y*7.1+p.z*9.3)
   attribute.data[loop].color=(*[max(0,min(1,x*tint)) for x in base],1)
  face.material_index=0
 mesh.materials.clear();mesh.materials.append(material)
 return len(mesh.polygons)

def build(style,names):
 out=ROOT/'assets/styles'/style/'models';out.mkdir(parents=True,exist_ok=True)
 normal_path=out.parent/'textures/surface_normal.png';make_normal(normal_path,style)
 catalog=sorted(p.stem for p in (ROOT/'assets/models').glob('*.glb'))
 manifest_path=out.parent/'manifest.json';prior={}
 if manifest_path.exists():prior={r['id']:r for r in json.loads(manifest_path.read_text()).get('models',[]) if 'triangles' in r}
 for name in names or catalog:
  assert name in catalog,name
  source=ROOT/'assets/models'/(name+'.glb');original,_=glb(source)
  bpy.ops.wm.read_factory_settings(use_empty=True);bpy.ops.import_scene.gltf(filepath=str(source))
  material=craft_material(style,normal_path);triangles=0
  for obj in list(bpy.context.scene.objects):
   if obj.type=='MESH':triangles+=build_mesh(obj,style,material)
  dest=out/(name+'.glb')
  bpy.ops.export_scene.gltf(filepath=str(dest),export_format='GLB',export_yup=True,export_apply=True,export_materials='EXPORT',export_vertex_color='ACTIVE',export_cameras=False,export_lights=False)
  doc,binary=glb(dest);restore_contract(doc,original);binary=shared_surface_texture(doc,binary)
  for m in doc.get('materials',[]):assert m.get('alphaMode','OPAQUE')=='OPAQUE','No transparent craft overdraw'
  doc['asset']['generator']='Micro Apex '+style+' sculpted geometry + corner pigment + baked surface normals'
  save_glb(dest,doc,binary)
  source_triangles=sum(original['accessors'][p['indices']]['count']//3 for m in original['meshes'] for p in m['primitives'])
  import_path=Path(str(dest)+'.import')
  if import_path.exists():settings=import_path.read_text()
  else:
   settings=Path(str(source)+'.import').read_text().replace('res://assets/models/','res://assets/styles/'+style+'/models/')
   settings='\n'.join(line for line in settings.splitlines() if not line.startswith(('uid=','path=','dest_files=')))+'\n'
  settings=re.sub(r'^import_script/path=.*$', 'import_script/path="res://tools/import_crafted_models.gd"',settings,flags=re.M)
  import_path.write_text(settings)
  prior[name]={'id':name,'source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'variant_sha256':hashlib.sha256(dest.read_bytes()).hexdigest(),'source_triangles':source_triangles,'triangles':triangles,'source_bytes':source.stat().st_size,'variant_bytes':dest.stat().st_size,'nodes':len(doc['nodes']),'materials':len(doc.get('materials',[]))}
  print('CRAFT_MODEL',style,name,source_triangles,'->',triangles,flush=True)
 complete=set(prior)==set(catalog)
 manifest_path.write_text(json.dumps({'format':2,'style':style,'complete':complete,'geometry':'sculpted uneven clay' if style=='bright_clay' else 'faceted folded paper with physical edge bands','surface':'opaque corner pigment and baked tangent normal map','models':[prior[x] for x in sorted(prior)]},indent=2)+'\n')
 print('CRAFT_DONE',style,len(prior),'complete',complete,flush=True)
if __name__=='__main__':
 parser=argparse.ArgumentParser();parser.add_argument('--style',choices=['bright_clay','paper_craft'],required=True);parser.add_argument('--models',nargs='*')
 args=parser.parse_args(sys.argv[sys.argv.index('--')+1:]);build(args.style,args.models)
