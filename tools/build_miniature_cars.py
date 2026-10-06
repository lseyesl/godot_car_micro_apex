"""Eight original chunky miniature racers. Blender: +Y forward, Z up, metres.
Rebuilds runtime GLBs; keeps earlier source libraries for comparison.
"""
from pathlib import Path
import json
source=Path(__file__).with_name('build_assets.py').read_text()
exec(compile(source.split('specs=')[0],str(Path(__file__).with_name('build_assets.py')),'exec'))
# Rounded manufactured edges, broad paint, enlarged cabin and wheels.
def rounded(name,p,size,paint,r=.10):
 o=box(name,p,size,paint)
 bevel(o,r,3)
 for f in o.data.polygons:f.use_smooth=True
 active(o);m=o.modifiers.new('Weighted normals','WEIGHTED_NORMAL');m.keep_sharp=True;bpy.ops.object.modifier_apply(modifier=m.name)
 return o
for name,color in [('scarlet',(.65,.06,.035)),('honey',(.95,.58,.04)),('azure',(.05,.32,.65)),('mint',(.09,.53,.32)),('apricot',(.92,.35,.07)),('ice',(.4,.71,.75)),('plum',(.40,.15,.57)),('sand',(.78,.57,.13))]:
 mat(name,color,.27,.12)
M['glass'].node_tree.nodes.get('Principled BSDF').inputs['Base Color'].default_value=(.035,.10,.15,1)
M['glass'].node_tree.nodes.get('Principled BSDF').inputs['Roughness'].default_value=.19
specs=[('car_speed','scarlet',3.9,1.53,.47),('car_agile','honey',3.35,1.85,.48),('car_dirt','azure',3.65,2.0,.55),('car_balanced','mint',3.65,1.78,.49),('car_pickup','apricot',3.95,1.9,.53),('car_roadster','ice',3.5,1.44,.48),('car_muscle','plum',3.95,1.67,.50),('car_buggy','sand',3.45,1.85,.56)]
for idx,(name,paint,L,H,R) in enumerate(specs):
 before=set(bpy.context.scene.objects);w=1.10;front=L*.285;rear=-L*.29;belt=1.04 if idx!=7 else .77
 body=rounded('Rounded body',(0,0,.65),(2.22,L,.84),paint,.20)
 for y in [front,rear]:
  for side in [-1,1]:
   cutter=cyl('Wheel well',(side*w,y,R),R+.07,.82,'rubber',(0,math.pi/2,0),N=40)
   active(body);mod=body.modifiers.new('Open arch','BOOLEAN');mod.operation='DIFFERENCE';mod.object=cutter;bpy.ops.object.modifier_apply(modifier=mod.name);bpy.data.objects.remove(cutter,do_unlink=True)
   wheel('Wheel_'+('Front' if y==front else 'Rear')+('_L' if side<0 else '_R'),side*1.055,y,R,.36,idx in [2,4,7])
   pts=[(side*1.12,y+math.cos(a)* (R+.09),R+math.sin(a)*(R+.09)) for a in [math.pi*i/20 for i in range(21)]]
   polyline('Thick arch lip',pts,.055,'trim' if idx in [2,4,7] else paint)
 for side in [-1,1]:
  rounded('Headlamp bezel',(side*.72,L/2+.015,.81),(.55,.10,.31),'trim',.10)
  rounded('Headlamp lens',(side*.72,L/2+.075,.83),(.42,.055,.20),'lamp',.07)
  rounded('Tail lamp',(side*.75,-L/2-.035,.82),(.42,.08,.21),'tail',.06)
  rounded('Rocker',(side*1.08,0,.34),(.13,L*.63,.17),'trim',.06)
 rounded('Front bumper',(0,L/2-.01,.37),(2.12,.21,.23),'trim',.08)
 rounded('Main intake',(0,L/2+.1,.63),(.78,.055,.29),'rubber',.08)
 rounded('Rear bumper',(0,-L/2-.04,.35),(2.04,.18,.20),'trim',.06)
 if idx not in [5,7]:
  back=-L*(.10 if idx==4 else .31);ahead=L*.19
  rb=back+.15;rf=ahead-.22;bw=.96;rw=.81
  v=[(-bw,back,1.0),(bw,back,1.0),(bw,ahead,1.0),(-bw,ahead,1.0),(-rw,rb,H),(rw,rb,H),(rw,rf,H),(-rw,rf,H)]
  cabin=mesh('Plump cabin',v,[(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7),(4,5,6,7),(3,2,1,0)],paint);recalc(cabin);bevel(cabin,.12,4)
  for inds,norm in [([2,3,7,6],(0,.8,.3)),([0,1,5,4],(0,-.8,.3)),([1,2,6,5],(1,0,.1)),([3,0,4,7],(-1,0,.1))]:
   inset_patch('Window rubber',[v[i] for i in inds],'trim',.88,norm)
   inset_patch('Smoked glass',[v[i] for i in inds],'glass',.77,tuple(x*1.8 for x in norm))
  rounded('Roof crown',(0,(rb+rf)/2,H-.025),(1.7,rf-rb+.12,.16),paint,.075)
 else:
  rounded('Open cockpit',(0,-.25,1.08),(1.68,1.68,.12),'trim',.15)
  for x in [-.43,.43]:
   rounded('Bucket seat',(x,-.72,1.27),(.53,.28,.66),'trim',.11)
   rounded('Seat base',(x,-.42,1.11),(.53,.55,.20),'rubber',.07)
  if idx==5:
   v=[(-.94,.61,1.08),(.94,.61,1.08),(.81,.4,1.55),(-.81,.4,1.55)]
   poly('Windshield',v,'glass',(0,.8,.4))
   polyline('Screen frame',v[1:]+[v[0]],.047,'metal')
   for x in [-.43,.43]:polyline('Roll hoop',[(x-.22,-.82,1.14),(x-.22,-.82,1.59),(x+.22,-.82,1.59),(x+.22,-.82,1.14)],.06,'metal')
  else:
   for side in [-1,1]:polyline('Tube cage',[(side*.94,.8,.8),(side*.79,.37,1.85),(side*.79,-.74,1.85),(side*.94,-1.35,.8)],.08,'trim')
   for y in [.37,-.74]:beam('Cage crossbar',(-.79,y,1.85),(.79,y,1.85),.08,'trim')
   rounded('Roof panel',(0,-.20,1.87),(1.68,.96,.12),paint,.05)
 if idx==4:
  rounded('Open pickup bed',(0,-1.16,1.09),(1.7,1.36,.07),'trim',.04)
  for side in [-1,1]:rounded('Cargo rail',(side*.96,-1.17,1.22),(.17,1.52,.28),paint,.06)
  polyline('Cargo roll bar',[(-.77,-.48,1.1),(-.77,-.48,1.99),(.77,-.48,1.99),(.77,-.48,1.1)],.08,'metal')
 if idx in [0,6]:
  for side in [-1,1]:rounded('Wing support',(side*.71,-L*.38,1.22),(.12,.16,.5),'trim',.035)
  rounded('Rear wing',(0,-L*.38,1.49),(2.18,.42,.14),'trim',.06)
 if idx in [2,7]:
  for x in [-.47,.47]:cyl('Rally spot',(x,L*.19,H+.10),.14,.16,'lamp',(math.pi/2,0,0),N=24)
 if idx==6:rounded('Hood scoop',(0,L*.31,1.15),(.67,.54,.28),'trim',.07)
 for x in [-.24,.24]:rounded('Bonnet stripe',(x,L*.34,1.078),(.19,L*.27,.018),'white',.008)
 for side in [-1,1]:rounded('Mirror',(side*1.20,L*.13,1.17),(.24,.27,.19),paint,.075)
 if idx not in [4,5]:
  z=1.97 if idx==7 else H+.07
  rounded('Number roundel',(0,-.15,z),(.80,.74,.02),'white',.13)
  bpy.ops.object.text_add(location=(0,-.34,z+.014));o=bpy.context.object;o.name='Race number';o.data.body=str(20+idx*7);o.data.align_x='CENTER';o.data.size=.47;o.data.extrude=.002;o.data.materials.append(M['trim']);bpy.ops.object.convert(target='MESH')
 finalize(name,before,'Original miniature proportions: short wheelbase, broad cabin, oversize wheels',4)
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'assets/blender/micro_apex_miniature.blend'))
(ROOT/'assets/models/miniature-manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
