"""Build reference-guided low-poly assets. Run with Blender --background --python."""
import bpy, math, json
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[1]
bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
M={}
def mat(n,c):
 m=bpy.data.materials.new(n); m.diffuse_color=(*c,1); m.use_nodes=True
 p=m.node_tree.nodes.get('Principled BSDF'); p.inputs['Base Color'].default_value=(*c,1); p.inputs['Roughness'].default_value=.72
 M[n]=m; return m
for n,c in {'red':(.75,.025,.018),'yellow':(.95,.64,.015),'blue':(.035,.19,.7),'green':(.08,.43,.15),'rubber':(.025,.03,.035),'glass':(.055,.095,.12),'metal':(.3,.34,.37),'white':(.88,.9,.83),'orange':(1,.19,.015),'asphalt':(.105,.125,.14),'dirt':(.48,.27,.105),'grass':(.19,.36,.13),'bark':(.23,.12,.055),'rock':(.35,.37,.33)}.items():mat(n,c)
def mesh(n,v,f,m):
 me=bpy.data.meshes.new(n);me.from_pydata(v,[],f);me.update();o=bpy.data.objects.new(n,me);bpy.context.collection.objects.link(o);o.data.materials.append(M[m]);return o
def box(n,loc,sz,m,bevel=0):
 bpy.ops.mesh.primitive_cube_add(size=1,location=loc);o=bpy.context.object;o.name=n;o.dimensions=sz;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);o.data.materials.append(M[m])
 if bevel:
  mod=o.modifiers.new('edge_facets','BEVEL');mod.width=bevel;mod.segments=1;bpy.ops.object.modifier_apply(modifier=mod.name)
 return o
def cyl(n,loc,r,d,m,rot=(0,0,0),vertices=12):
 bpy.ops.mesh.primitive_cylinder_add(vertices=vertices,radius=r,depth=d,location=loc,rotation=rot);o=bpy.context.object;o.name=n;o.data.materials.append(M[m]);return o
def loft(n,rings,m):
 v=[]
 for y,w,z0,z1 in rings:v.extend([(-w,y,z0),(w,y,z0),(w,y,z1),(-w,y,z1)])
 f=[(3,2,1,0)]
 for i in range(len(rings)-1):
  for j in range(4):f.append((i*4+j,i*4+(j+1)%4,(i+1)*4+(j+1)%4,(i+1)*4+j))
 f.append(tuple(range(len(v)-4,len(v))));return mesh(n,v,[tuple(reversed(face)) for face in f],m)
manifest=[];roots=[]
def finish(name,before,ref):
 objs=[o for o in bpy.context.scene.objects if o not in before]
 root=bpy.data.objects.new(name,None);bpy.context.collection.objects.link(root)
 for o in objs:
  if o.parent is None:o.parent=root
 bpy.ops.object.select_all(action='DESELECT');root.select_set(True)
 for o in objs:o.select_set(True)
 bpy.context.view_layer.objects.active=root
 bpy.ops.export_scene.gltf(filepath=str(ROOT/'assets/models'/f'{name}.glb'),use_selection=True,export_format='GLB',export_yup=True)
 tris=sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in objs if o.type=='MESH')
 manifest.append({'name':name,'triangles':tris,'reference':ref,'glb':f'assets/models/{name}.glb'})
 roots.append(root);return root
# Blender +Y front exports to Godot -Z front; all assets are meter scale and ground based.
for idx,(name,L,W,H,col) in enumerate([('car_speed',4.6,1.94,1.14,'red'),('car_agile',3.55,1.72,1.48,'yellow'),('car_dirt',3.9,1.88,1.65,'blue'),('car_balanced',4.25,1.82,1.43,'green')]):
 before=set(bpy.context.scene.objects);dirt=name=='car_dirt';speed=name=='car_speed';R=.39 if dirt else .32;z=.39 if dirt else .22;belt=.93 if dirt else (.69 if speed else .8)
 body=loft('Body',[(-L/2,W*.44,z,belt*.94),(-L*.35,W*.5,z,belt),(L*.25,W*.5,z,belt),(L/2,W*.42,z,belt*.73)],col)
 for y in [-L*.31,L*.3]:
  for x in [-W*.5,W*.5]:
   cutter=cyl('arch_cut',(x,y,R),R+.04,.46,'rubber',(0,math.pi/2,0),16)
   bpy.context.view_layer.objects.active=body;mod=body.modifiers.new('wheel_arch','BOOLEAN');mod.operation='DIFFERENCE';mod.object=cutter;bpy.ops.object.modifier_apply(modifier=mod.name);bpy.data.objects.remove(cutter,do_unlink=True)
 for side,x in [('L',-W*.48),('R',W*.48)]:
  for end,y in [('Rear',-L*.31),('Front',L*.3)]:
   tire=cyl('Wheel_'+end+'_'+side,(x,y,R),R,.26 if not dirt else .34,'rubber',(0,math.pi/2,0),16)
   hub=cyl('Hub_'+end+'_'+side,(x+(-.145 if x<0 else .145),y,R),R*.58,.025,'metal',(0,math.pi/2,0));hub.parent=tire;hub.matrix_parent_inverse=tire.matrix_world.inverted()
 rear=-L*(.24 if speed or name=='car_balanced' else .36);front=L*.23;rt=-L*.17;ft=L*.015;rw=W*.37;bw=W*.43
 v=[(-bw,rear,belt),(bw,rear,belt),(bw,front,belt),(-bw,front,belt),(-rw,rt,H),(rw,rt,H),(rw,ft,H),(-rw,ft,H)]
 mesh('CabinGlass',v,[(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)],'glass')
 mesh('Roof',[(-rw,rt,H+.015),(rw,rt,H+.015),(rw,ft,H+.015),(-rw,ft,H+.015)],[(0,1,2,3)],col)
 def beam(n,a,b,width,m):
  a,b=Vector(a),Vector(b);o=box(n,(a+b)/2,(width,width,(b-a).length),m);o.rotation_euler=(b-a).to_track_quat('Z','Y').to_euler();return o
 for i,j in [(0,4),(1,5),(2,6),(3,7)]:beam('CabinPillar',v[i],v[j],.07,col)
 for s in [-1,1]:
  beam('WindowPillar',(s*bw,-L*.1,belt),(s*rw,-L*.1,H),.055,col)
  box('Mirror',(s*(W*.5+.07),L*.14,belt+.14),(.18,.24,.12),col,.03)
  box('Headlight',(s*W*.28,L*.49,belt*.77),(.4,.055,.13),'white',.025)
  box('TailLight',(s*W*.29,-L*.5,belt*.75),(.35,.045,.13),'red')
 box('FrontGrille',(0,L*.49,z+.14),(W*.51,.06,.17),'rubber')
 box('FrontSplitter',(0,L*.48,z),(W*.88,.23,.07),'rubber')
 if speed or dirt:
  for s in [-1,1]:box('WingSupport',(s*W*.3,-L*.4,belt+.17),(.065,.13,.34),'rubber')
  box('RearWing',(0,-L*.4,belt+.36),(W*1.02,.32,.075),col)
 else:box('RearLip',(0,-L*.44,belt+.035),(W*.86,.2,.075),col)
 if dirt:
  box('RoofScoop',(0,-.04,H+.07),(.5,.46,.15),col,.035);box('ScoopIntake',(0,.195,H+.06),(.37,.025,.075),'rubber')
 root=finish(name,before,f'assets/references/{name}.png');root.location=(idx*5.8,0,0)
# Roads use top z=0. Straight endpoints y=+-5, curves centered at origin, radius 9m, width 6m.
for surface in ['asphalt','dirt']:
 before=set(bpy.context.scene.objects);box('Road',(0,0,-.1),(6,10,.2),surface)
 for x in [-3.3,3.3]:box('GrassVerge',(x,0,-.11),(.6,10,.18),'grass')
 if surface=='asphalt':
  for x in [-2.8,2.8]:box('EdgeLine',(x,0,.006),(.08,10,.012),'white')
 root=finish(surface+'_straight',before,'assets/references/map_kit.png');root.location=(len(roots)*9,18,0)
 before=set(bpy.context.scene.objects);v=[];f=[]
 for i in range(25):
  a=math.pi/2*i/24
  for r,zv in [(6,0),(12,0),(6,-.2),(12,-.2)]:v.append((r*math.cos(a),r*math.sin(a),zv))
 for i in range(24):
  k=i*4;f.extend([(k,k+1,k+5,k+4),(k+2,k+6,k+7,k+3),(k,k+4,k+6,k+2),(k+1,k+3,k+7,k+5)])
 f.extend([(0,2,3,1),(96,97,99,98)]);mesh('Curve',v,f,surface)
 root=finish(surface+'_curve',before,'assets/references/map_kit.png');root.location=(len(roots)*9,18,0)
for name in ['curb','safety_barrier','cone','tire_barrier','rock','tree','start_gantry']:
 before=set(bpy.context.scene.objects)
 if name=='curb':
  for i in range(6):box('Curb',(0,(i-2.5)*.5,.055),(.5,.5,.11),'red' if i%2 else 'white',.025)
 elif name=='safety_barrier':
  for i in range(4):loft('Barrier',[((i-2)*.75,.28,0,.7),((i-1)*.75,.28,0,.7)],'red' if i%2 else 'white')
 elif name=='cone':
  box('Base',(0,0,.045),(.42,.42,.09),'rubber',.025)
  bpy.ops.mesh.primitive_cone_add(vertices=12,radius1=.17,radius2=.025,depth=.54,location=(0,0,.36));bpy.context.object.data.materials.append(M['orange'])
  bpy.ops.mesh.primitive_cone_add(vertices=12,radius1=.112,radius2=.085,depth=.1,location=(0,0,.36));bpy.context.object.data.materials.append(M['white'])
 elif name=='tire_barrier':
  for x in [-.48,.48]:
   for z in [.15,.45,.75]:
    bpy.ops.mesh.primitive_torus_add(major_segments=12,minor_segments=6,location=(x,0,z),major_radius=.31,minor_radius=.13);bpy.context.object.data.materials.append(M['rubber'])
 elif name=='rock':
  bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1,radius=1,location=(0,0,.7));bpy.context.object.scale=(1.05,.75,.7);bpy.context.object.data.materials.append(M['rock'])
 elif name=='tree':
  cyl('Trunk',(0,0,.65),.16,1.3,'bark',vertices=7)
  for x,y,z,r in [(-.5,0,1.7,.8),(.45,.1,2,.85),(0,0,2.65,.7)]:
   bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1,radius=r,location=(x,y,z));bpy.context.object.data.materials.append(M['grass'])
 else:
  for x in [-3.65,3.65]:box('Post',(x,0,2),(.3,.35,4),'metal')
  box('Header',(0,0,3.7),(7.6,.35,.8),'white')
  for i in range(18):
   for j in range(2):
    if (i+j)%2:
     for y in [-.181,.181]:box('Checker',(-3.6+i*.4,y,3.5+j*.4),(.4,.012,.4),'rubber')
 root=finish(name,before,'assets/references/map_kit.png');root.location=((len(roots)-8)*4,-9,0)
# Preserve editable source with packed reference images.
for p in (ROOT/'assets/references').glob('*.png'):
 im=bpy.data.images.load(str(p));im.pack()
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=24
scene.world.color=(.3,.3,.3)
box('DisplayGround',(8,2,-.25),(180,100,.1),'white')
def camera(loc,target,scale):
 bpy.ops.object.camera_add(location=loc);o=bpy.context.object;o.rotation_euler=(Vector(target)-o.location).to_track_quat('-Z','Y').to_euler();o.data.type='ORTHO';o.data.ortho_scale=scale;scene.camera=o;return o
cam=camera((11,23,20),(8.5,0,0),24)
bpy.ops.object.light_add(type='AREA',location=(6,4,16));bpy.context.object.data.energy=2600;bpy.context.object.data.shape='DISK';bpy.context.object.data.size=12
bpy.ops.object.light_add(type='SUN',rotation=(.3,-.4,-.5));bpy.context.object.data.energy=2
scene.render.resolution_x=1600;scene.render.resolution_y=900;scene.render.resolution_percentage=100
scene.view_settings.view_transform='AgX'
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'assets/blender/micro_apex_assets.blend'))
for root in roots[4:]:
 for o in root.children_recursive:o.hide_render=True
scene.render.filepath=str(ROOT/'assets/previews/cars.png');bpy.ops.render.render(write_still=True)
# Reposition only for a compact kit contact sheet render.
for i,root in enumerate(roots):
 for o in root.children_recursive:o.hide_render=i<4
for i,root in enumerate(roots[4:]):
 root.location=(0,0,0);bpy.context.view_layer.update()
 points=[o.matrix_world@Vector(v) for o in root.children_recursive if o.type=='MESH' for v in o.bound_box]
 lo=Vector(tuple(min(v[j] for v in points) for j in range(3)));hi=Vector(tuple(max(v[j] for v in points) for j in range(3)))
 factor=8/max(hi-lo);root.scale=(factor,)*3
 root.location=Vector(((i%4)*12,(2-i//4)*12,0))-Vector(((lo.x+hi.x)/2*factor,(lo.y+hi.y)/2*factor,lo.z*factor))
cam.location=(23,-40,52);cam.rotation_euler=(Vector((18,12,0))-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.ortho_scale=54
scene.render.filepath=str(ROOT/'assets/previews/map_kit.png');bpy.ops.render.render(write_still=True)
(ROOT/'assets/models/manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
print('ASSET_BUILD_COMPLETE',len(manifest),sum(x['triangles'] for x in manifest))
