"""Author nine low-poly original scenery GLBs; derive clay variants afterwards.
Run: blender -b --python tools/build_scenery_additions.py
Opaque foliage, shared palette, joined surfaces; no collisions or animation.
"""
import bpy, math, random
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'assets/models'
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
M={}
for name,color in {'scenery_cream':(.58,.53,.40),'scenery_teal':(.12,.32,.31),'scenery_coral':(.53,.22,.15),'scenery_glass':(.12,.23,.27),'scenery_leaf':(.23,.36,.14),'scenery_flower':(.74,.46,.24),'scenery_dry':(.50,.43,.23)}.items():
 m=bpy.data.materials.new(name);m.diffuse_color=(*color,1);m.use_nodes=True
 bs=m.node_tree.nodes.get('Principled BSDF');bs.inputs['Base Color'].default_value=(*color,1);bs.inputs['Roughness'].default_value=.9
 M[name]=m

def box(p,size,mat):
 bpy.ops.mesh.primitive_cube_add(size=1,location=p);o=bpy.context.object;o.dimensions=size
 bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
 o.data.materials.append(M[mat]);b=o.modifiers.new('Soft edge','BEVEL');b.width=min(min(size)*.12,.12);b.segments=2;bpy.ops.object.modifier_apply(modifier=b.name)
 return o

def beam(a,b,r,mat):
 a,b=Vector(a),Vector(b);bpy.ops.mesh.primitive_cylinder_add(vertices=8,radius=r,depth=(b-a).length,location=(a+b)*.5)
 o=bpy.context.object;o.rotation_euler=(b-a).to_track_quat('Z','Y').to_euler();o.data.materials.append(M[mat]);return o

def ball(p,size,mat):
 bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1,radius=1,location=p);o=bpy.context.object;o.scale=size;o.data.materials.append(M[mat]);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
 for f in o.data.polygons:f.use_smooth=True

def export(name):
 for mat in M.values():
  objs=[o for o in bpy.context.scene.objects if o.type=='MESH' and o.data.materials[0]==mat]
  if not objs:continue
  bpy.ops.object.select_all(action='DESELECT')
  for o in objs:o.select_set(True)
  bpy.context.view_layer.objects.active=objs[0];bpy.ops.object.join();o=bpy.context.object;o.name=mat.name
  bpy.ops.object.transform_apply(location=False,rotation=True,scale=True)
 bpy.ops.object.select_all(action='SELECT')
 bpy.ops.export_scene.gltf(filepath=str(OUT/(name+'.glb')),export_format='GLB',use_selection=True,export_yup=True)
 bpy.ops.object.delete(use_global=False)

# Wheel lies in X/Z; Z-up authoring becomes Y-up Godot. Static cabins stay upright.
for depth in [-.75,.75]:
 for i in range(32):
  a=i*math.tau/32;b=(i+1)*math.tau/32
  beam((12*math.cos(a),depth,15+12*math.sin(a)),(12*math.cos(b),depth,15+12*math.sin(b)),.22,'scenery_cream')
 for i in range(12):
  a=i*math.tau/12;beam((0,depth,15),(12*math.cos(a),depth,15+12*math.sin(a)),.10,'scenery_teal')
for side in [-1,1]:
 for y in [-2.8,2.8]:beam((side*6,y,0),(0,y*.3,15),.38,'scenery_teal')
beam((0,-2,15),(0,2,15),.6,'scenery_coral')
for i in range(12):
 a=i*math.tau/12;x=12*math.cos(a);z=15+12*math.sin(a)
 beam((x,0,z),(x,0,z-1.5),.1,'scenery_cream');box((x,0,z-2.1),(2.4,2,1.4),'scenery_coral' if i%2 else 'scenery_teal');box((x,0,z-1.3),(2.6,2.2,.25),'scenery_cream')
export('prop_ferris_wheel')
# Clock faces on four sides with solid hands (no alpha decals).
box((0,0,5),(5,5,10),'scenery_cream');box((0,0,10.4),(6,6,.6),'scenery_coral');box((0,0,12),(4,4,3),'scenery_teal')
for side in [-1,1]:
 box((0,side*2.55,8),(2.6,.15,2.6),'scenery_teal');box((.3,side*2.68,8.1),(.9,.12,.15),'scenery_cream');box((0,side*2.68,8.6),(.15,.12,1.2),'scenery_cream')
 box((side*2.55,0,8),(.15,2.6,2.6),'scenery_teal');box((side*2.68,.3,8.1),(.12,.9,.15),'scenery_cream');box((side*2.68,0,8.6),(.12,.15,1.2),'scenery_cream')
export('prop_clock_tower')
box((0,0,2.2),(12,7,4.4),'scenery_cream');box((0,0,4.6),(13,8,.6),'scenery_teal')
for x in [-4,0,4]:
 box((x,-3.55,2),(2.6,.12,2.8),'scenery_glass');box((x,-4.1,3.7),(3.7,1.8,.3),'scenery_coral');box((x,-4.4,.7),(3,1.4,1.2),'scenery_teal')
export('prop_market_hall')
box((0,0,.2),(8,8,.4),'scenery_cream')
for x in [-3,3]:
 for y in [-3,3]:beam((x,y,.4),(x,y,4),.22,'scenery_cream')
bpy.ops.mesh.primitive_cone_add(vertices=8,radius1=5.2,radius2=0,depth=2,location=(0,0,4.8));bpy.context.object.data.materials.append(M['scenery_teal'])
box((0,0,.9),(4,1.3,.6),'scenery_coral');export('prop_pavilion')
for i in range(7):
 a=i*2.399;ball((math.cos(a)*.65,math.sin(a)*.65,.25+(i%3)*.32),(1,.85,.7),'scenery_leaf')
export('foliage_leaf_cluster')
for flower in [False,True]:
 for i in range(5):
  a=i*2.399;ball((math.cos(a)*.65,math.sin(a)*.65,.55),(1,.9,.65),'scenery_leaf')
 if flower:
  for i in range(7):
   a=i*2.399;ball((math.cos(a),math.sin(a),1.08),(.18,.18,.18),'scenery_flower')
 export('foliage_shrub_flower' if flower else 'foliage_shrub_round')
for dry in [False,True]:
 for i in range(9):
  a=i*2.399;r=(i%3)*.13;x=math.cos(a)*r;y=math.sin(a)*r
  bpy.ops.mesh.primitive_cone_add(vertices=4,radius1=.12,radius2=0,depth=.6+(i%3)*.18,location=(x,y,.35+(i%3)*.09));o=bpy.context.object;o.rotation_euler=(math.sin(a)*.25,math.cos(a)*.25,a);o.data.materials.append(M['scenery_dry' if dry else 'scenery_leaf'])
 export('foliage_grass_dry' if dry else 'foliage_grass_green')
print('SCENERY_ADDITIONS models=9')
