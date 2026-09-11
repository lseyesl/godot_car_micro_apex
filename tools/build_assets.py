"""Reference-guided production meshes, Blender 4.5+. +Y front / Z up, meters.
Rebuild GLBs, editable source library and actual geometry preview sheets.
"""
import bpy, bmesh, math, json, random, sys
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[1]
random.seed(812)
bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
M={}
def mat(n,c,rough=.5,metal=0):
 m=bpy.data.materials.new(n);m.diffuse_color=(*c,1);m.use_nodes=True
 p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(*c,1);p.inputs['Roughness'].default_value=rough;p.inputs['Metallic'].default_value=metal
 p.inputs['Specular IOR Level'].default_value=.2
 M[n]=m;return m
for n,c in {'red':(.63,.018,.012),'yellow':(.95,.64,.018),'blue':(.025,.16,.63),'green':(.055,.32,.09)}.items():mat(n,c,.32,.16)
for n,c,r,met in [('rubber',(.018,.022,.026),.94,0),('trim',(.035,.045,.052),.62,0),('glass',(.025,.038,.05),.32,.05),('glass_glint',(.15,.19,.22),.24,.2),('metal',(.32,.36,.39),.28,.72),('rim',(.13,.16,.18),.3,.8),('disc',(.21,.23,.25),.6,.6),('white',(.85,.86,.81),.68,0),('lamp',(.83,.9,.92),.15,.3),('tail',(.62,.007,.009),.2,.2),('orange',(1,.17,.008),.6,0),('asphalt',(.12,.14,.15),.98,0),('dirt',(.48,.27,.12),1,0),('grass',(.25,.38,.09),1,0),('bark',(.23,.11,.045),1,0),('rock',(.35,.37,.34),1,0)]:mat(n,c,r,met)
for i in range(5):
 mat('dirt_%d'%i,(.43+i*.015,.25+i*.011,.12+i*.008),1)
 mat('leaf_%d'%i,(.19+i*.018,.31+i*.023,.065+i*.01),1)
 mat('stone_%d'%i,(.28+i*.025,.30+i*.025,.28+i*.026),1)

def mesh(n,v,f,m):
 me=bpy.data.meshes.new(n);me.from_pydata(v,[],f);me.update();o=bpy.data.objects.new(n,me);bpy.context.collection.objects.link(o);o.data.materials.append(M[m]);return o

def active(o):
 bpy.ops.object.select_all(action='DESELECT');o.select_set(True);bpy.context.view_layer.objects.active=o

def bevel(o,width=.02,segments=1):
 active(o);mod=o.modifiers.new('Small manufactured edge','BEVEL');mod.width=width;mod.segments=segments
 bpy.ops.object.modifier_apply(modifier=mod.name);return o

def box(n,loc,size,m,b=0):
 bpy.ops.mesh.primitive_cube_add(size=1,location=loc);o=bpy.context.object;o.name=n;o.dimensions=size;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);o.data.materials.append(M[m]);return bevel(o,b) if b else o

def cyl(n,loc,r,d,m,rot=(0,0,0),N=24):
 bpy.ops.mesh.primitive_cylinder_add(vertices=N,radius=r,depth=d,location=loc,rotation=rot);o=bpy.context.object;o.name=n;o.data.materials.append(M[m]);return o

def beam(n,a,b,r,m,N=6):
 a,b=Vector(a),Vector(b);o=cyl(n,(a+b)/2,r,(b-a).length,m,N=N);o.rotation_euler=(b-a).to_track_quat('Z','Y').to_euler();return o

def poly(n,vertices,m,normal=None):
 verts=[Vector(v) for v in vertices]
 if normal is not None and (verts[1]-verts[0]).cross(verts[2]-verts[0]).dot(Vector(normal))<0:verts.reverse()
 return mesh(n,verts,[tuple(range(len(verts)))],m)

def inset_patch(n,vertices,m,amount=.88,normal=(0,1,0)):
 c=sum((Vector(v) for v in vertices),Vector())/len(vertices)
 return poly(n,[c+(Vector(v)-c)*amount+Vector(normal)*.012 for v in vertices],m,normal)

def polyline(n,pts,r,m):
 for a,b in zip(pts,pts[1:]):beam(n,a,b,r,m)

def recalc(o):
 bm=bmesh.new();bm.from_mesh(o.data);bmesh.ops.recalc_face_normals(bm,faces=bm.faces);bm.to_mesh(o.data);bm.free()

# A 12-point sculpted body section gives hood crown, shoulder and lower sill planes.
def body_shell(name,sections,color):
 v=[]
 for y,w,z0,z1 in sections:
  v.extend([(w*.84,y,z0),(w,y,z0+.10),(w,y,z1-.14),(w*.90,y,z1-.025),(w*.5,y,z1+.015),(0,y,z1+.03),(-w*.5,y,z1+.015),(-w*.90,y,z1-.025),(-w,y,z1-.14),(-w,y,z0+.10),(-w*.84,y,z0),(0,y,z0)])
 f=[tuple(reversed(range(12)))]
 for i in range(len(sections)-1):
  for j in range(12):f.append((i*12+j,i*12+(j+1)%12,(i+1)*12+(j+1)%12,(i+1)*12+j))
 f.append(tuple(range(len(v)-12,len(v))));o=mesh(name,v,f,color);recalc(o);return o

def ring(n,x,y,z,inner,outer,width,m,N=32):
 v=[]
 for xx,r in [(-width/2,inner),(-width/2,outer),(width/2,outer),(width/2,inner)]:
  for i in range(N):
   a=i*math.tau/N;v.append((x+xx,y+math.sin(a)*r,z+math.cos(a)*r))
 f=[]
 for j in range(4):
  for i in range(N):f.append((j*N+i,j*N+(i+1)%N,((j+1)%4)*N+(i+1)%N,((j+1)%4)*N+i))
 o=mesh(n,v,f,m);recalc(o);return o

def wheel(name,x,y,R,width,rally=False):
 before=set(bpy.context.scene.objects)
 # Rounded shoulder rather than a solid cylinder; sidewall remains distinctly black.
 profile=[(-width*.5,R*.70),(-width*.55,R*.9),(-width*.4,R), (width*.4,R),(width*.55,R*.9),(width*.5,R*.70)]
 v=[];N=32
 for xx,r in profile:
  for i in range(N):
   a=i*math.tau/N;v.append((x+xx,y+math.sin(a)*r,R+math.cos(a)*r))
 f=[]
 for j in range(len(profile)):
  for i in range(N):f.append((j*N+i,j*N+(i+1)%N,((j+1)%len(profile))*N+(i+1)%N,((j+1)%len(profile))*N+i))
 tire=mesh('Tire_carcass',v,f,'rubber');recalc(tire)
 s=1 if x>0 else -1;face=x+s*width*.56
 ring('Machined_rim_lip',face,y,R,R*.57,R*.70,.028,'metal')
 cyl('Brake_disc',(face-s*.045,y,R),R*.55,.025,'disc',(0,math.pi/2,0))
 caliper=box('Brake_caliper',(face-s*.02,y+R*.38,R),(.055,.07,.20),'red',.01)
 cyl('Hub',(face+s*.014,y,R),R*.16,.05,'rim',(0,math.pi/2,0),12)
 for i in range(6):
  a=i*math.tau/6
  spoke=box('Alloy_spoke',(face+s*.005,y+math.sin(a)*R*.39,R+math.cos(a)*R*.39),(.045,R*.13,R*.48),'rim',.008)
  spoke.rotation_euler.x=-a
  bolt_a=i*math.tau/6
  cyl('Lug',(face+s*.045,y+math.sin(bolt_a)*R*.09,R+math.cos(bolt_a)*R*.09),.013,.012,'metal',(0,math.pi/2,0),6)
 if rally:
  for i in range(26):
   a=i*math.tau/26
   for row in [-1,1]:
    tread=box('Tread_block',(x+row*width*.24,y+math.sin(a)*R,R+math.cos(a)*R),(width*.43,.075,.044),'trim',.004)
    tread.rotation_euler.x=-a
 root=bpy.data.objects.new(name,None);bpy.context.collection.objects.link(root);root.location=(x,y,R)
 for o in set(bpy.context.scene.objects)-before-{root,caliper}:
  o.parent=root;o.matrix_parent_inverse=root.matrix_world.inverted()
 # matrix_world of a new empty needs evaluation before computing parent inverse.
 bpy.context.view_layer.update()
 for o in root.children:o.matrix_parent_inverse=root.matrix_world.inverted()
 return root

roots=[];manifest=[]
def finalize(name,before,reference,version=2):
 objs=list(set(bpy.context.scene.objects)-before)
 root=bpy.data.objects.new(name,None);bpy.context.collection.objects.link(root)
 for o in objs:
  if o.parent is None:o.parent=root
 # Consolidate stationary parts and each wheel to reduce draw calls while retaining wheel pivots.
 groups=[[o for o in objs if o.type=='MESH' and o.parent==root]]
 for child in list(root.children):
  if child.type=='EMPTY':groups.append([o for o in child.children_recursive if o.type=='MESH'])
 for group in groups:
  if not group:continue
  bpy.ops.object.select_all(action='DESELECT')
  for o in group:o.select_set(True)
  bpy.context.view_layer.objects.active=group[0];bpy.ops.object.join();joined=bpy.context.object
  joined.name='Body' if joined.parent==root else 'WheelMesh'
 bpy.context.view_layer.update();active(root)
 for o in root.children_recursive:o.select_set(True)
 bpy.ops.export_scene.gltf(filepath=str(ROOT/'assets/models'/f'{name}.glb'),use_selection=True,export_format='GLB',export_yup=True,export_apply=True)
 tris=sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in root.children_recursive if o.type=='MESH')
 manifest.append({'name':name,'version':version,'triangles':tris,'reference':reference,'glb':f'assets/models/{name}.glb'})
 roots.append(root);return root

specs=[('car_speed',4.6,1.94,1.18,'red',.35,1.42,-1.40),('car_agile',3.65,1.74,1.49,'yellow',.33,1.08,-1.12),('car_dirt',3.95,1.92,1.62,'blue',.405,1.22,-1.20),('car_balanced',4.3,1.83,1.44,'green',.34,1.29,-1.28)]
for idx,(name,L,W,H,color,R,front_axle,rear_axle) in enumerate(specs):
 before=set(bpy.context.scene.objects);speed=idx==0;rally=idx==2;sedan=idx==3;w=W/2
 base=.20 if not rally else .32;belt=.83 if speed else (.99 if rally else .92)
 # Distinct long hood / short hatch / rally stance / sedan trunk.
 sections=[(-L/2,w*.83,base,belt-.10),(-L*.43,w*.96,base,belt-.005),(rear_axle,w,base,belt+.015),(-L*.16,w*.98,base,belt-.035),(L*.10,w*.97,base,belt-.04),(front_axle,w,base,belt+.02),(L*.40,w*.96,base,belt-.04),(L/2,w*.82,base,belt-(.29 if speed else .14))]
 body=body_shell('Sculpted_body',sections,color)
 for y in [front_axle,rear_axle]:
  for s in [-1,1]:
   cutter=cyl('Arch_cut',(s*w,y,R),R+.042,.62,'rubber',(0,math.pi/2,0),N=32)
   active(body);mod=body.modifiers.new('Open wheel well','BOOLEAN');mod.operation='DIFFERENCE';mod.object=cutter;bpy.ops.object.modifier_apply(modifier=mod.name);bpy.data.objects.remove(cutter,do_unlink=True)
 bevel(body,.013)
 for y in [front_axle,rear_axle]:
  for s in [-1,1]:
   # Open arc arch trim: no hole across the hood or central floor.
   v=[];steps=16
   for i in range(steps+1):
    a=math.pi*i/steps
    for radius,xoff in [(R+.045,-.016),(R+(.12 if rally else .074),.014)]:
     v.append((s*(w+xoff),y+math.cos(a)*radius,R+math.sin(a)*radius))
   f=[(i*2,i*2+1,i*2+3,i*2+2) for i in range(steps)]
   poly_obj=mesh('Flared_wheel_arch',v,f,'trim' if rally else color)
   wheel('Wheel_'+('Front' if y==front_axle else 'Rear')+('_L' if s<0 else '_R'),s*(w-.075),y,R,.34 if rally else .26,rally)
 # Cabin envelope: separate windshield, roof, rear window, and two window panes per side.
 rear=-L*(.24 if speed or sedan else .395);front=L*(.19 if speed else .22)
 roof_rear=-L*(.135 if speed else (.18 if sedan else .30));roof_front=L*(.008 if speed else .025)
 bw=w*.85;rw=w*.74;z=belt+.025
 verts=[(-bw,rear,z),(bw,rear,z),(bw,front,z),(-bw,front,z),(-rw,roof_rear,H),(rw,roof_rear,H),(rw,roof_front,H),(-rw,roof_front,H)]
 cabin=mesh('Cabin_frame',verts,[(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7),(4,5,6,7),(3,2,1,0)],color);recalc(cabin);bevel(cabin,.045)
 waist_bottom=[(x+(math.copysign(.08,x)),y+(-.045 if y==rear else .045),belt-.10) for x,y,_ in verts[:4]]
 waist=mesh('Cabin_belt_shoulder',waist_bottom+verts[:4],[(i,(i+1)%4,(i+1)%4+4,i+4) for i in range(4)],color)
 inset_patch('Windshield',[verts[i] for i in [2,3,7,6]],'trim',.95,(0,.6,.4))
 inset_patch('Windshield_glass',[verts[i] for i in [2,3,7,6]],'glass',.85,(0,.62,.45))
 inset_patch('Rear_window',[verts[i] for i in [0,1,5,4]],'glass',.83,(0,-.8,.3))
 for s in [-1,1]:
  # Bilinear subdivision leaves body-colored A/C pillars and a narrow black B pillar.
  back_low=Vector((s*bw,rear,z));front_low=Vector((s*bw,front,z));back_high=Vector((s*rw,roof_rear,H));front_high=Vector((s*rw,roof_front,H))
  for a,b in [(0,.47),(.50,1)]:
   quad=[back_low.lerp(front_low,a),back_low.lerp(front_low,b),back_high.lerp(front_high,b),back_high.lerp(front_high,a)]
   inset_patch('Side_window',quad,'glass',.88,(s,0,.1))
  mid=back_low.lerp(front_low,.485);top=back_high.lerp(front_high,.485)
  beam('Black_B_pillar',mid+Vector((s*.013,0,0)),top+Vector((s*.013,0,0)),.026,'trim')
  # Door shut lines and handles. Coupe gets one long door; hatch/sedan get two.
  door_ys=[front-.10,rear+.10] if speed else [front-.10,(front+rear)*.5,rear+.1]
  for y in door_ys:polyline('Door_seam',[(s*(w*.991),y,z-.14),(s*(w*.991),y,base+.16)],.004,'trim')
  for y in ([rear+.2] if speed else [front-.5,rear+.3]):box('Door_handle',(s*(w*.998),y,z-.15),(.027,.15,.035),'trim',.008)
  box('Side_sill',(s*(w*.94),0,base+.025),(.1,L*.67,.09),'trim',.02)
  beam('Mirror_stalk',(s*bw*.94,front-.05,z+.10),(s*(w+.075),front-.1,z+.18),.028,'trim')
  box('Mirror_housing',(s*(w+.105),front-.10,z+.20),(.22,.20,.12),color if not rally else 'trim',.035)
  box('Mirror_glass',(s*(w+.105),front-.206,z+.20),(.15,.008,.065),'metal',.008)
 # Hood crease and hood-to-fender seam.
 for s in [-1,1]:
  polyline('Hood_shut_line',[(s*w*.62,L*.40,belt-.03),(s*w*.59,L*.29,belt+.027),(s*w*.58,front+.08,belt+.025)],.004,'trim')
 # Interpolate the painted shell to mount lights and louvers flush to its surface.
 def hood_height(x,y):
  for a,b in zip(sections,sections[1:]):
   if a[0]<=y<=b[0]:
    t=(y-a[0])/(b[0]-a[0]);ww=a[1]*(1-t)+b[1]*t;zz=a[3]*(1-t)+b[3]*t
    lateral=[(0,.03),(.5,.015),(.9,-.025),(1,-.14)];ratio=abs(x)/ww
    for (u,za),(v,zb) in zip(lateral,lateral[1:]):
     if ratio<=v:return zz+za+(zb-za)*(ratio-u)/(v-u)
    return zz-.14
  return belt
 # Front intake, shaped bumper and angular, inset headlamp units.
 nose=L/2; nose_top=sections[-1][3]
 grille_top=nose_top-(.065 if speed else .20)
 grille=[(-w*.49,nose+.018,base+.065),(w*.49,nose+.018,base+.065),(w*.40,nose+.018,grille_top),(-w*.40,nose+.018,grille_top)]
 poly('Main_intake',grille,'trim',(0,1,0))
 for height in [base+.16,base+.23,base+.30]:
  if height<grille_top-.02:box('Grille_slat',(0,nose+.023,height),(w*.80,.018,.014),'rubber')
 if not speed:box('Upper_grille',(0,nose+.022,nose_top-.085),(W*.47,.025,.075),'trim',.01)
 box('Front_splitter',(0,nose-.025,base+.005),(W*.9,.23,.065),'trim',.025)
 for s in [-1,1]:
  # Lights sit on the sloping outer nose, not floating on the flat front bumper.
  light_xy=[(s*w*.43,L*.475),(s*w*.79,L*.47),(s*w*.86,L*.419),(s*w*.56,L*.431)]
  lamp_vertices=[];lamp_faces=[];N=6
  for j in range(N+1):
   v=j/N
   for i in range(N+1):
    u=i/N
    a=Vector(light_xy[0]).lerp(Vector(light_xy[1]),u)
    b=Vector(light_xy[3]).lerp(Vector(light_xy[2]),u)
    q=a.lerp(b,v);lamp_vertices.append((q.x,q.y,hood_height(q.x,q.y)+.026))
  for j in range(N):
   for i in range(N):
    k=j*(N+1)+i;lamp_faces.append((k,k+1,k+N+2,k+N+1))
  lamp=mesh('Flush_headlight',lamp_vertices,lamp_faces,'trim');lamp.data.materials.append(M['lamp'])
  for face in lamp.data.polygons:
   i=face.index%N;j=face.index//N;face.material_index=1 if 0<i<N-1 and 0<j<N-1 else 0
  poly('Corner_intake',[(s*w*.58,nose+.028,base+.065),(s*w*.82,nose+.028,base+.085),(s*w*.81,nose+.028,grille_top-.005),(s*w*.60,nose+.028,grille_top+.015)],'trim',(0,1,0))
  if rally:
   cyl('Fog_lamp',(s*w*.67,nose+.018,base+.20),.068,.025,'lamp',(math.pi/2,0,0),N=12)
 # Rear lights, bumper and dual exhaust.
 for s in [-1,1]:
  box('Rear_lamp',(s*w*.58,-L/2-.012,belt-.22),(.40,.035,.105),'tail',.02)
  cyl('Exhaust',(s*w*.57,-L/2-.07,base+.065),.06,.17,'metal',(math.pi/2,0,0),N=12)
  cyl('Exhaust_bore',(s*w*.57,-L/2-.159,base+.065),.043,.008,'rubber',(math.pi/2,0,0),N=12)
 box('Rear_diffuser',(0,-L/2+.025,base+.025),(W*.8,.15,.11),'trim',.02)
 # Every design has characteristic rear aero, with thin plates and end caps.
 wing_y=-L*.435;wing_z=belt+(.25 if speed else (.27 if rally else .11))
 for s in [-1,1]:box('Wing_upright',(s*w*.63,wing_y,(belt+wing_z)*.5),(.045,.14,wing_z-belt),'trim')
 box('Wing_airfoil',(0,wing_y,wing_z),(W*.97,.26,.055),color if speed or sedan else 'trim',.015)
 if speed or rally:
  for s in [-1,1]:box('Wing_endplate',(s*w*.99,wing_y,wing_z+.02),(.038,.32,.19),color if speed else 'trim',.012)
 if speed:
  for s in [-1,1]:
   poly('Side_air_intake',[(s*(w+.005),-.40,.36),(s*(w+.005),-.72,.39),(s*(w+.005),-.87,.73),(s*(w+.005),-.50,.69)],'trim',(s,0,0))
  for j in range(5):
   yy=-L*.29-j*.095
   box('Engine_deck_louver',(0,yy,hood_height(0,yy)+.012),(W*.52,.045,.018),'trim')
 if rally:
  box('Roof_scoop',(0,-.08,H+.075),(.48,.45,.15),color,.04)
  box('Scoop_opening',(0,.152,H+.07),(.34,.012,.065),'rubber',.008)
  box('Front_skid_plate',(0,nose+.035,base+.035),(W*.57,.16,.13),'metal',.025)
  for s in [-1,1]:
   box('Hood_vent',(s*w*.53,L*.32,hood_height(s*w*.53,L*.32)+.014),(.16,.26,.025),'trim',.02)
   for y in [front_axle-.4,rear_axle-.4]:box('Mud_flap',(s*(w-.07),y,base+.08),(.27,.035,.25),'rubber')
 root=finalize(name,before,f'assets/references/{name}.png');root.location=(idx*6.2,0,0)

# Track kit: joinable surfaces with colored triangulation and modeled shoulders.
for i in range(4):mat('asphalt_%d'%i,(.105+i*.007,.122+i*.007,.13+i*.007),1)
for surface in ['asphalt','dirt']:
 for curved in [False,True]:
  before=set(bpy.context.scene.objects)
  def road_point(u,t,z=0):
   if curved:
    a=t*math.pi/2;r=9+u;return (r*math.cos(a),r*math.sin(a),z)
   return (u,-5+t*10,z)
  for row in range(20 if curved else 12):
   count=20 if curved else 12
   for col in range(6):
    u=col-3;t=row/count
    p=[road_point(u,t),road_point(u+1,t),road_point(u+1,(row+1)/count),road_point(u,(row+1)/count)]
    for face in [[p[0],p[1],p[2]],[p[0],p[2],p[3]]]:poly('Road_surface',face,surface+'_%d'%random.randrange(5 if surface=='dirt' else 4),(0,0,1))
  # Solid section walls and grass shoulders, without cracks between road tiles.
  count=20 if curved else 1
  for row in range(count):
   t=row/count;tn=(row+1)/count
   for s in [-1,1]:
    poly('Road_edge',[road_point(s*3,t,0),road_point(s*3,tn,0),road_point(s*3,tn,-.22),road_point(s*3,t,-.22)],'dirt')
    poly('Grass_verge',[road_point(s*3,t,-.015),road_point(s*3.65,t,-.04),road_point(s*3.65,tn,-.04),road_point(s*3,tn,-.015)],'grass',(0,0,1))
    poly('Earth_side',[road_point(s*3.65,t,-.04),road_point(s*3.65,tn,-.04),road_point(s*3.65,tn,-.22),road_point(s*3.65,t,-.22)],'dirt')
  if surface=='asphalt':
   for s in [-1,1]:
    for row in range(20 if curved else 1):
     count=20 if curved else 1;t=row/count;tn=(row+1)/count
     poly('White_edge_marking',[road_point(s*2.77,t,.008),road_point(s*2.86,t,.008),road_point(s*2.86,tn,.008),road_point(s*2.77,tn,.008)],'white',(0,0,1))
   for row in range(0,12,2):poly('Dashed_center_line',[road_point(-.05,row/12,.009),road_point(.05,row/12,.009),road_point(.05,(row+.8)/12,.009),road_point(-.05,(row+.8)/12,.009)],'white',(0,0,1))
  else:
   for i in range(16):
    x,y,z=road_point(random.choice([-1,1])*random.uniform(2.6,3.4),random.random())
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1,radius=random.uniform(.035,.08),location=(x,y,.015));bpy.context.object.data.materials.append(M['stone_2'])
  # End thickness closes the perimeter; top stays exactly at z=0 for connections.
  for t in [0,1]:poly('Tile_end',[road_point(-3.65,t,-.22),road_point(3.65,t,-.22),road_point(3.65,t,-.04),road_point(-3.65,t,-.04)],'dirt')
  root=finalize(surface+('_curve' if curved else '_straight'),before,'assets/references/map_kit.png');root.location=(len(roots)*15,20,0)

def tapered_barrier(y0,y1,color):
 profile=[(-.38,0),(.38,0),(.38,.13),(.20,.35),(.16,.82),(-.16,.82),(-.20,.35),(-.38,.13)]
 v=[(x,y,z) for y in [y0,y1] for x,z in profile];n=len(profile)
 f=[tuple(reversed(range(n))),tuple(range(n,2*n))]+[(j,(j+1)%n,(j+1)%n+n,j+n) for j in range(n)]
 o=mesh('Concrete_barrier',v,f,color);recalc(o);bevel(o,.014)

for name in ['curb','safety_barrier','cone','tire_barrier','rock','tree','start_gantry']:
 before=set(bpy.context.scene.objects)
 if name=='curb':
  for i in range(6):
   y=(i-3)*.5
   o=mesh('Kerb_block',[(-.27,y,0),(.27,y,0),(.27,y+.5,0),(-.27,y+.5,0),(-.27,y,.045),(.27,y,.14),(.27,y+.5,.14),(-.27,y+.5,.045)],[(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)],'red' if i%2 else 'white');bevel(o,.012)
 elif name=='safety_barrier':
  for i in range(4):tapered_barrier((i-2)*.75,(i-1)*.75,'red' if i%2 else 'white')
 elif name=='cone':
  box('Rubber_base',(0,0,.045),(.46,.46,.09),'rubber',.035)
  zs=[.09,.24,.34,.46,.55,.70];N=16;v=[]
  for z in zs:
   r=.2-(z-.09)/.61*.175
   for i in range(N):v.append((r*math.cos(i*math.tau/N),r*math.sin(i*math.tau/N),z))
  f=[]
  for j in range(len(zs)-1):
   for i in range(N):f.append((j*N+i,j*N+(i+1)%N,(j+1)*N+(i+1)%N,(j+1)*N+i))
  o=mesh('Cone_bands',v,f,'orange');o.data.materials.append(M['white'])
  for p in o.data.polygons:p.material_index=1 if p.index//N in [1,3] else 0
 elif name=='tire_barrier':
  for x in [-.82,0,.82]:
   for level in range(3):
    z=.14+level*.265
    bpy.ops.mesh.primitive_torus_add(major_segments=24,minor_segments=10,location=(x,0,z),major_radius=.29,minor_radius=.13);o=bpy.context.object;o.name='Stacked_tire';o.scale.z=.92;o.data.materials.append(M['rubber'])
    for zz in [z-.07,z+.07]:
     bpy.ops.mesh.primitive_torus_add(major_segments=24,minor_segments=4,location=(x,0,zz),major_radius=.398,minor_radius=.009);bpy.context.object.data.materials.append(M['trim'])
 elif name=='rock':
  for loc,scale in [((0,0,.65),(1,.8,.75)),((-.8,.45,.16),(.30,.24,.2)),((.85,.25,.2),(.32,.35,.25)),((.1,-.85,.12),(.2,.3,.15))]:
   bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2,radius=1,location=loc);o=bpy.context.object;o.name='Faceted_rock';o.scale=scale
   for vert in o.data.vertices:vert.co*=random.uniform(.87,1.12)
   for i in range(5):o.data.materials.append(M['stone_%d'%i])
   for face in o.data.polygons:face.material_index=random.randrange(5)
 elif name=='tree':
  beam('Trunk',(0,0,.02),(.08,0,2.2),.12,'bark',8)
  for a,b in [((0,0,.8),(-.65,.1,2)),((0,0,1.2),(.65,.15,2.45)),((.05,0,1.7),(-.35,-.3,2.7))]:beam('Branch',a,b,.075,'bark',7)
  for x,y,z,r in [(-.7,.05,1.9,.68),(.65,.1,2.45,.73),(-.34,-.2,2.7,.75),(.15,.4,3.12,.6),(0,-.2,2.12,.7)]:
   bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2,radius=r,location=(x,y,z));o=bpy.context.object;o.name='Polygon_canopy'
   for i in range(5):o.data.materials.append(M['leaf_%d'%i])
   for face in o.data.polygons:face.material_index=random.randrange(5)
 else:
  for x in [-3.65,3.65]:
   base=box('Red_base',(x,0,.3),(.9,.85,.6),'red',.07)
   box('White_base_band',(x,0,.40),(.91,.86,.12),'white',.04)
   for dx in [-.21,.21]:
    for y in [-.21,.21]:beam('Tower_chord',(x+dx,y,.6),(x+dx,y,4.05),.045,'metal')
   for j in range(5):
    z=.65+j*.65
    for y in [-.21,.21]:
     beam('Tower_diagonal',(x-.21,y,z),(x+.21,y,z+.62),.025,'metal')
     beam('Tower_rung',(x-.21,y,z),(x+.21,y,z),.035,'metal')
  for y in [-.21,.21]:
   for z in [3.48,4.05]:beam('Bridge_chord',(-3.65,y,z),(3.65,y,z),.05,'metal')
   for j in range(10):
    x=-3.65+j*.73
    beam('Bridge_diagonal',(x,y,3.48),(x+.73,y,4.05),.027,'metal')
  box('Checker_banner',(0,0,3.7),(7.3,.06,.58),'white')
  for i in range(24):
   for j in range(2):
    if (i+j)%2:
     for y in [-.037,.037]:box('Checker',(-3.65+(i+.5)*7.3/24,y,3.555+j*.29),(7.3/24,.012,.29),'rubber')
 root=finalize(name,before,'assets/references/map_kit.png');root.location=((len(roots)-8)*5,-12,0)

# Save editable production source with packed references before presentation changes.
for p in (ROOT/'assets/references').glob('*.png'):
 im=bpy.data.images.load(str(p));im.pack()
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=32
scene.world.use_nodes=True;scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.65,.68,.72,1);scene.world.node_tree.nodes['Background'].inputs[1].default_value=.45
mat('studio',(.71,.70,.67),.85)
floor=box('Studio_floor',(0,0,-.09),(240,180,.15),'studio')
def camera_at(loc,target,scale):
 bpy.ops.object.camera_add(location=loc);o=bpy.context.object;o.rotation_euler=(Vector(target)-o.location).to_track_quat('-Z','Y').to_euler();o.data.type='ORTHO';o.data.ortho_scale=scale;scene.camera=o;return o
cam=camera_at((9,11,8),(0,0,.65),7)
for loc,power,size in [((2,5,9),1400,7),((-6,-1,6),1000,6),((1,-6,8),1200,5)]:
 bpy.ops.object.light_add(type='AREA',location=loc);o=bpy.context.object;o.data.energy=power;o.data.shape='DISK';o.data.size=size;o.rotation_euler=(Vector((0,0,.5))-o.location).to_track_quat('-Z','Y').to_euler()
scene.render.resolution_x=1200;scene.render.resolution_y=900;scene.render.resolution_percentage=100
scene.view_settings.view_transform='AgX'
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'assets/blender/micro_apex_assets.blend'))
(ROOT/'assets/models/manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')

def visible(root,on):
 for o in root.children_recursive:o.hide_render=not on
for r in roots:visible(r,False)
for i,r in enumerate(roots[:4]):
 r.location=(0,0,0);visible(r,True)
 cam.location=(6.5,9,5.2);cam.rotation_euler=(Vector((0,0,.7))-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.ortho_scale=6.1
 scene.render.filepath=str(ROOT/'assets/previews'/f'{r.name}-v2.png');bpy.ops.render.render(write_still=True)
 visible(r,False)
# Single comparison sheet of the actual four rebuilt vehicles.
for i,r in enumerate(roots[:4]):r.location=((i%2)*6,(i//2)*7,0);visible(r,True)
cam.location=(11,16,15);cam.rotation_euler=(Vector((3,3.5,.4))-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.ortho_scale=16
scene.render.resolution_x=1600;scene.render.resolution_y=1200
scene.render.filepath=str(ROOT/'assets/previews/cars.png');bpy.ops.render.render(write_still=True)
for r in roots[:4]:visible(r,False)
for i,r in enumerate(roots[4:]):
 r.location=(0,0,0);visible(r,True);bpy.context.view_layer.update()
 pts=[o.matrix_world@Vector(v) for o in r.children_recursive if o.type=='MESH' for v in o.bound_box]
 lo=Vector(tuple(min(v[j] for v in pts) for j in range(3)));hi=Vector(tuple(max(v[j] for v in pts) for j in range(3)))
 factor=8/max(hi-lo);r.scale=(factor,)*3
 r.location=Vector(((i%4)*12,(2-i//4)*12,0))-Vector(((lo.x+hi.x)/2*factor,(lo.y+hi.y)/2*factor,lo.z*factor))
cam.location=(22,-40,52);cam.rotation_euler=(Vector((18,12,0))-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.ortho_scale=54
for light in [o for o in scene.objects if o.type=='LIGHT']:
 light.location+=Vector((18,12,10));light.data.energy*=5;light.data.size=15;light.rotation_euler=(Vector((18,12,0))-light.location).to_track_quat('-Z','Y').to_euler()
scene.render.resolution_x=1600;scene.render.resolution_y=1100
scene.render.filepath=str(ROOT/'assets/previews/map_kit.png');bpy.ops.render.render(write_still=True)
print('ASSET_V2_COMPLETE',len(manifest),[(r['name'],r['triangles']) for r in manifest])
