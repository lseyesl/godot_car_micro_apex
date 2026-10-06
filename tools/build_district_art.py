"""Original miniature architecture and foliage, authored in Blender; metres, Z up.
Run: blender -b --python tools/build_district_art.py
Materials are named for runtime CC0 texture assignment. No reference game assets used.
"""
import bpy,math,random,json,sys
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[1];OUT=ROOT/'assets/models';random.seed(29013)
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
M={}
for name,color in {'plaster':(.65,.58,.43),'stone':(.43,.42,.36),'roof':(.38,.23,.14),'timber':(.18,.14,.10),'wood':(.40,.32,.21),'glass':(.10,.18,.20),'trim':(.63,.61,.50),'metal':(.21,.26,.25),'dark':(.06,.08,.07),'cloth':(.35,.16,.11),'leaf0':(.13,.24,.09),'leaf1':(.20,.31,.12),'leaf2':(.27,.37,.17),'leaf3':(.33,.40,.19)}.items():
 m=bpy.data.materials.new(name);m.diffuse_color=(*color,1);m.use_nodes=True
 bs=m.node_tree.nodes.get('Principled BSDF');bs.inputs['Base Color'].default_value=(*color,1);bs.inputs['Roughness'].default_value=.85 if name!='glass' else .28
 M[name]=m

def activate(o):
 bpy.ops.object.select_all(action='DESELECT');o.select_set(True);bpy.context.view_layer.objects.active=o

def box(name,p,size,mat,bevel=.035):
 bpy.ops.mesh.primitive_cube_add(size=1,location=p);o=bpy.context.object;o.name=name;o.dimensions=size;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);o.data.materials.append(M[mat])
 if bevel:
  m=o.modifiers.new('Soft manufactured edge','BEVEL');m.width=max(bevel,.13) if min(size)>1 else bevel;m.segments=3;bpy.ops.object.modifier_apply(modifier=m.name)
  m=o.modifiers.new('Weighted corner normals','WEIGHTED_NORMAL');m.keep_sharp=True;bpy.ops.object.modifier_apply(modifier=m.name)
 return o

def cyl(name,p,r,h,mat):
 bpy.ops.mesh.primitive_cylinder_add(vertices=12,radius=r,depth=h,location=p);o=bpy.context.object;o.name=name;o.data.materials.append(M[mat]);return o

def beam(name,a,b,r,mat):
 a,b=Vector(a),Vector(b);o=cyl(name,(a+b)/2,r,(b-a).length,mat);o.rotation_euler=(b-a).to_track_quat('Z','Y').to_euler();return o

def mesh(name,verts,faces,mat):
 m=bpy.data.meshes.new(name);m.from_pydata(verts,[],faces);m.update();o=bpy.data.objects.new(name,m);bpy.context.collection.objects.link(o);o.data.materials.append(M[mat]);return o

def window(x,y,z,side=0,w=1.9,h=1.75):
 # local facade window, normal initially toward negative Y
 objs=[];objs.append(box('Window stone surround',(x,y,z),(w+.30,.24,h+.30),'trim'))
 objs.append(box('Recessed blue glass',(x,y-.15,z),(w,.12,h),'glass',.015))
 objs.append(box('Window crossbar',(x,y-.23,z),(.075,.1,h),'timber',.005))
 objs.append(box('Window crossbar',(x,y-.23,z),(w,.1,.075),'timber',.005))
 objs.append(box('Projecting sill',(x,y-.32,z-h*.5-.14),(w+.55,.55,.18),'stone'))
 for k in [-1,1]:objs.append(box('Hinged shutter',(x+k*(w*.5+.37),y-.05,z),(.40,.20,h),'wood',.02))
 if side:
  for o in objs:
   px,py=o.location.x,o.location.y;o.location.x=px*math.cos(side)-py*math.sin(side);o.location.y=px*math.sin(side)+py*math.cos(side);o.rotation_euler.z+=side

def roof(w,d,base,height,hip=False):
 if hip:
  verts=[(-w/2,-d/2,base),(w/2,-d/2,base),(w/2,d/2,base),(-w/2,d/2,base),(-w*.22,0,base+height),(w*.22,0,base+height)]
  faces=[(0,1,5,4),(1,2,5),(2,3,4,5),(3,0,4)]
 else:
  verts=[(-w/2,-d/2,base),(w/2,-d/2,base),(w/2,d/2,base),(-w/2,d/2,base),(-w/2,0,base+height),(w/2,0,base+height)]
  faces=[(0,1,5,4),(2,3,4,5)]
  mesh('Plastered gable',verts,[(3,0,4),(1,2,5)],'plaster')
 mesh('Roof tile slopes',verts,faces,'roof')
 beam('Ridge cap',verts[4],verts[5],.15,'roof')
 for a,b in [(0,1),(2,3)]:beam('Eaves gutter',verts[a],verts[b],.12,'metal')
 if not hip:
  for a,b in [(0,4),(4,3),(1,5),(5,2)]:beam('Gable trim',verts[a],verts[b],.15,'timber')

def facade_sign(text,p,size=.7):
 # Own branding, actual mesh lettering so all export targets retain it.
 bpy.ops.object.text_add(location=p,rotation=(math.pi/2,0,0));o=bpy.context.object;o.name='Original sign '+text;o.data.body=text;o.data.align_x='CENTER';o.data.align_y='CENTER';o.data.size=size;o.data.extrude=.007;o.data.materials.append(M['trim']);bpy.ops.object.convert(target='MESH')

def building(variant):
 first=set(bpy.context.scene.objects);w=9.0;d=8.0;height=5.6 if variant in [0,1] else 4.7
 bodymat='plaster' if variant in [0,1,4] else ('wood' if variant in [2,3] else 'stone')
 box('Masonry foundation',(0,0,.35),(w+.5,d+.5,.7),'stone',.07)
 box('Main facade',(0,0,height/2+.45),(w,d,height),bodymat,.09)
 box('Raised stone pavement',(0,-.1,.05),(12.5,12.5,.1),'stone',.04)
 for z in [.85,3.25]:box('Storey string course',(0,0,z),(w+.16,d+.16,.16),'timber' if variant in [2,3] else 'trim',.02)
 if variant in [0,2,3,4]:
  roof(w+1.0,d+1.1,height+.45,2.3,hip=variant==0)
 else:
  box('Flat roof',(0,0,height+.55),(w+.5,d+.5,.35),'stone',.07)
  for x in [-w/2,w/2]:box('Parapet',(x,0,height+1),(.3,d+.6,.7),'plaster',.04)
  for y in [-d/2,d/2]:box('Parapet',(0,y,height+1),(w+.4,.3,.7),'plaster',.04)
  box('Utility room',(2,1,height+1.1),(2.7,3.2,1),'metal',.05)
 for side in [0,math.pi]:
  for x in [-2.7,2.7]:
   window(x,-d/2-.06,2.4,side)
   if variant in [0,1]:window(x,-d/2-.06,4.6,side,w=1.9,h=1.4)
 for side in [-math.pi/2,math.pi/2]:
  for x in [-2.6,1.6]:window(x,-w/2-.05,3.0,side,w=1.45,h=1.8)
 box('Recessed doorway',(0,-d/2-.04,1.65),(1.65,.18,2.8),'dark',.04)
 box('Paneled door',(0,-d/2-.17,1.6),(1.4,.18,2.5),'wood',.035)
 box('Door glass',(0,-d/2-.28,2.05),(.8,.08,.8),'glass',.015)
 cyl('Door handle',(.48,-d/2-.37,1.4),.06,.12,'metal').rotation_euler.x=math.pi/2
 for step in range(2):box('Entrance step',(0,-d/2-.6-step*.3,.28-step*.09),(2.2,1.1,.18),'stone',.04)
 if variant in [0,1,5]:
  box('Shop sign',(0,-d/2-.3,3.95),(8.8,.25,.8),'timber',.04)
  facade_sign(['APEX MOTOR CO.','BAY WORKSHOP','','','','REDSTONE SUPPLY'][variant],(0,-d/2-.46,3.95),.6)
  for stripe in range(10):
   o=box('Canvas shop awning',(-4.5+stripe, -d/2-.8,3.25),(1,.1,1.7),'cloth' if stripe%2 else 'trim',.012);o.rotation_euler.x=math.pi/2-.16
 if variant in [2,3,4]:
  box('Porch roof',(0,-d/2-.6,3.4),(10.8,1.5,.18),'roof',.025)
  for x in [-4.6,4.6]:
   beam('Porch column',(x,-d/2-1,.3),(x,-d/2-1,3.5),.12,'timber')
   beam('Porch brace',(x,-d/2-1,2.5),(x+(.8 if x<0 else -.8),-d/2-1,3.4),.07,'timber')
 for x in [-w/2+.15,w/2-.15]:
  beam('Rain downpipe',(x,d/2+.16,.4),(x,d/2+.16,height+.4),.08,'metal')
 if variant in [2,3]:
  for side in [-1,1]:
   for x in [-4.7,0,4.7]:box('Timber facade frame',(x,side*(d/2+.07),height*.5),(.15,.16,height),'timber',.02)
  beam('Gable timber',(-4.6,-d/2-.09,height+.5),(0,-d/2-.09,height+2.55),.1,'timber')
 box('Brick chimney',(-2,1,height+1.75),(1.15,1.3,3.5),'stone',.07)
 box('Chimney cap',(-2,1,height+3.5),(1.4,1.55,.24),'trim',.035)
 box('Chimney opening',(-2,1,height+3.65),(.8,.95,.08),'dark',.01)
 for x in [-4.6,4.6]:
  box('Door lamp',(x,-d/2-.32,3),(.35,.36,.55),'metal',.04)
  box('Lamp glass',(x,-d/2-.53,3),(.24,.12,.35),'trim',.02)
 export('district_art_'+str(variant),set(bpy.context.scene.objects)-first)

def export(name,objects):
 # One mesh surface per material is far cheaper than hundreds of prop nodes.
 groups={mat.name:[o for o in objects if o.type=='MESH' and len(o.data.materials) and o.data.materials[0]==mat] for mat in M.values()}
 for mat in M.values():
  chosen=groups[mat.name]
  if not chosen:continue
  bpy.ops.object.select_all(action='DESELECT')
  for o in chosen:o.select_set(True)
  bpy.context.view_layer.objects.active=chosen[0]
  bpy.ops.object.join();o=bpy.context.object;o.name=mat.name
 bpy.ops.object.select_all(action='SELECT')
 bpy.ops.export_scene.gltf(filepath=str(OUT/(name+'.glb')),export_format='GLB',use_selection=True,export_materials='EXPORT',export_yup=True)
 for o in list(bpy.context.scene.objects):bpy.data.objects.remove(o,do_unlink=True)

def tree(pine):
 beam('Tree trunk',(0,0,0),(.2,0,5.8),.22,'timber')
 for i in range(65):
  angle=i*2.399
  if pine:
   z=2+i/65*6.2;r=(8.8-z)*.38;rad=random.uniform(.45,.80)
   p=(math.cos(angle)*r*random.uniform(.4,1),math.sin(angle)*r*random.uniform(.4,1),z)
  else:
   z=4+random.random()*3.2;r=random.uniform(.4,2.6);rad=random.uniform(.65,1.05);p=(math.cos(angle)*r,math.sin(angle)*r,z)
  if i%15==0:beam('Branch',(.1,0,3),p,.055,'timber')
  bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2,radius=rad,location=p);o=bpy.context.object;o.scale=(1.2,.85,.7 if pine else 1)
  bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);o.data.materials.append(M['leaf'+str(i%4)])
  for f in o.data.polygons:f.use_smooth=True
 export('district_pine' if pine else 'district_oak',set(bpy.context.scene.objects))

def outcrop():
 bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=3,radius=1,location=(0,0,0));o=bpy.context.object;o.name='Sculpted rock mass';o.data.materials.append(M['stone'])
 for v in o.data.vertices:
  d=v.co.normalized();r=1+.13*math.sin(d.x*9+d.y*5)+.075*math.cos(d.y*14+d.z*8);v.co*=r
  v.co.z=(v.co.z+1)*.5
  if v.co.z<.16:v.co.z=0
 for f in o.data.polygons:f.use_smooth=True
 export('district_outcrop',set(bpy.context.scene.objects))

if '--nature-only' not in sys.argv:
 for i in range(6):building(i)
tree(True);tree(False);outcrop()
print('DISTRICT_ART complete')
