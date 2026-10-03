"""Original expansion silhouettes. Run with Blender; preserves existing car assets."""
from pathlib import Path
import json
source=Path(__file__).with_name('build_assets.py').read_text()
exec(compile(source.split('specs=')[0],str(Path(__file__).with_name('build_assets.py')),'exec'))
for name,color in [('amber',(.75,.31,.055)),('silver',(.38,.62,.68)),('violet',(.35,.12,.50)),('sand',(.72,.51,.13))]:mat(name,color,.34,.18)
for kind,name,color,L,H,R in [(0,'car_pickup','amber',4.6,1.7,.43),(1,'car_roadster','silver',4.25,1.15,.34),(2,'car_muscle','violet',4.9,1.35,.37),(3,'car_buggy','sand',3.8,1.6,.47)]:
 before=set(bpy.context.scene.objects);w=1.02;front=L*.3;rear=-L*.29;belt=.9 if kind!=3 else .65
 sections=[(-L/2,.8,.25,belt-.06),(rear,w,.25,belt),(0,w*.95,.25,belt),(front,w,.25,belt),(L/2,.83,.25,belt-.18)]
 body=body_shell('Body_shell',sections,color)
 for y in [front,rear]:
  for side in [-1,1]:
   cutter=cyl('Arch_cut',(side*w,y,R),R+.06,.7,'rubber',(0,math.pi/2,0),N=24)
   active(body);mod=body.modifiers.new('Wheel well','BOOLEAN');mod.operation='DIFFERENCE';mod.object=cutter;bpy.ops.object.modifier_apply(modifier=mod.name);bpy.data.objects.remove(cutter,do_unlink=True)
   wheel('Wheel_'+('Front' if y==front else 'Rear')+('_L' if side<0 else '_R'),side*.96,y,R,.30,kind in [0,3])
 for side in [-1,1]:
  box('Headlamp',(side*.62,L/2+.01,.63),(.42,.05,.18),'lamp',.035)
  box('Tail_lamp',(side*.65,-L/2-.02,.64),(.34,.055,.15),'tail',.025)
  box('Sill',(side*.99,0,.31),(.10,L*.6,.13),'trim',.02)
 box('Grille',(0,L/2+.03,.48),(.72,.04,.23),'trim',.02)
 box('Bumper',(0,L/2+.08,.27),(1.85,.15,.14),'metal' if kind==0 else 'trim',.025)
 if kind in [0,2]:
  back=-.35 if kind==0 else -1.2;roof_back=-.25 if kind==0 else -.85
  v=[(-.84,back,.91),(.84,back,.91),(.84,.95,.91),(-.84,.95,.91),(-.69,roof_back,H),(.69,roof_back,H),(.69,.5,H),(-.69,.5,H)]
  cabin=mesh('Cabin',v,[(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7),(4,5,6,7)],color);bevel(cabin,.035)
  for inds,norm in [([2,3,7,6],(0,.8,.4)),([0,1,5,4],(0,-.8,.4)),([1,2,6,5],(1,0,.2)),([3,0,4,7],(-1,0,.2))]:inset_patch('Window',[v[i] for i in inds],'glass',.85,norm)
 if kind==0:
  box('Open_cargo_bed',(0,-1.24,.915),(1.64,1.62,.045),'trim')
  for side in [-1,1]:box('Bed_rail',(side*.91,-1.28,1.03),(.13,1.7,.28),color,.035)
  for x in [-.68,.68]:beam('Bed_roll_bar',(x,-.6,.95),(x,-.6,1.78),.065,'metal')
  beam('Bed_crossbar',(-.68,-.6,1.78),(.68,-.6,1.78),.065,'metal')
  for x in [-.42,0,.42]:cyl('Roof_spotlight',(x,-.57,1.88),.10,.13,'lamp',(math.pi/2,0,0),N=16)
 elif kind in [1,3]:
  box('Open_cockpit',(0,-.27,belt+.035),(1.42,1.7,.08),'trim',.06)
  for x in [-.39,.39]:
   box('Seat_back',(x,-.73,belt+.25),(.46,.19,.55),'trim',.06)
   box('Seat_cushion',(x,-.43,belt+.08),(.46,.55,.14),'rubber',.04)
  if kind==1:
   poly('Windshield',[(-.78,.65,.92),(.78,.65,.92),(.69,.39,1.3),(-.69,.39,1.3)],'glass',(0,.8,.4))
   beam('Screen_top',(-.69,.39,1.3),(.69,.39,1.3),.035,'metal')
   for x in [-.39,.39]:
    for side in [-1,1]:beam('Roll_hoop',(x+side*.22,-.86,.95),(x+side*.22,-.86,1.28),.04,'metal')
    beam('Roll_hoop',(x-.22,-.86,1.28),(x+.22,-.86,1.28),.04,'metal')
  else:
   for side in [-1,1]:
    polyline('Tubular_cage',[(side*.8,.9,.6),(side*.67,.4,1.6),(side*.67,-.7,1.6),(side*.8,-1.35,.6)],.065,'trim')
    beam('Diagonal_cage',(side*.8,-1.35,.6),(-side*.67,-.7,1.6),.045,'metal')
   for y in [.4,-.7]:beam('Cage_crossbar',(-.67,y,1.6),(.67,y,1.6),.06,'trim')
   box('Roof_panel',(0,-.15,1.63),(1.35,.8,.045),color,.015)
   for x in [-.45,.45]:cyl('Rally_lamp',(x,.43,1.68),.12,.14,'lamp',(math.pi/2,0,0),N=16)
 else:
  box('Hood_scoop',(0,1.22,1.05),(.6,.75,.26),'trim',.04)
  for x in [-.3,.3]:box('Hood_stripe',(x,1.57,.918),(.18,.8,.018),'white')
  box('Rear_spoiler',(0,-2.02,1.04),(1.94,.32,.1),'trim',.02)
 for x in [-.7,.7]:box('Mirror',(x*1.48,.64,1.0),(.2,.2,.13),color,.035)
 finalize(name,before,'Original expansion vehicle: pickup / open roadster / muscle / tubular buggy',3)
# Separate editable source and manifest, preserving the original library.
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'assets/blender/micro_apex_expansion.blend'))
(ROOT/'assets/models/expansion-manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
