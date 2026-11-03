"""Broad physical cardboard cut edges and bounded recessed laminate seams."""
import bpy,bmesh

def category(asset,wheel):
 if wheel:return 'wheel'
 if asset.startswith('car_'):return 'vehicle'
 if asset.startswith(('foliage_','tree','district_oak','district_pine')):return 'foliage'
 if asset.startswith(('asphalt','dirt','curb')):return 'road'
 if asset=='prop_ferris_wheel':return 'landmark'
 return 'structure'

def boundaries(bm):
 edges={e for e in bm.edges if e.is_boundary};count=0;total=len(edges)
 while edges:
  seed=edges.pop();pending=list(seed.verts);count+=1
  while pending:
   v=pending.pop()
   for e in v.link_edges:
    if e in edges:edges.remove(e);pending.append(e.other_vert(v))
 return total,count

def component_data(bm):
 groups=[];remaining=set(bm.verts)
 for seed in list(bm.verts):
  if seed not in remaining:continue
  remaining.remove(seed);vertices={seed};pending=[seed]
  while pending:
   v=pending.pop()
   for e in v.link_edges:
    other=e.other_vert(v)
    if other in remaining:remaining.remove(other);vertices.add(other);pending.append(other)
  ordered=sorted(vertices,key=lambda v:v.index);indices={v:i for i,v in enumerate(ordered)}
  faces=sorted({f for v in vertices for f in v.link_faces},key=lambda f:f.index)
  groups.append(([v.co.copy() for v in ordered],[[indices[v] for v in f.verts] for f in faces],[f.material_index for f in faces]))
 return groups

def cut_edges(bm,span,asset,wheel,colors):
 role=category(asset,wheel);longest=max(span);thin=min(x for x in span if x>1e-5)
 boundary_before,loops_before=boundaries(bm);bm.verts.index_update();bm.faces.index_update()
 width=min(.025,longest*.03,thin*.20) if wheel else min(.12,longest*.025,thin*.20)
 limit={'wheel':8,'vehicle':20,'foliage':3,'road':6,'landmark':12,'structure':12}[role]
 edge_material=len(colors);colors.extend([(.58,.38,.20),(.32,.18,.085),(.74,.58,.37)])
 # Work independently on disconnected panels. Tiny trim cannot clamp broad cuts;
 # malformed joins are preserved rather than opening a hole when beveled.
 groups=component_data(bm);bm.clear();skipped=0;bevel_count=0
 for coords,polygons,indices in groups:
  temporary=bpy.data.meshes.new('Cardboard work panel');temporary.from_pydata(coords,[],polygons)
  part=bmesh.new();part.from_mesh(temporary);part.faces.ensure_lookup_table()
  for i,index in enumerate(indices):part.faces[i].material_index=index
  part.normal_update();part.edges.index_update();original=part.copy();before=boundaries(part)
  extent=[max(v.co[j] for v in part.verts)-min(v.co[j] for v in part.verts) for j in range(3)];nonzero=[x for x in extent if x>1e-5]
  part_width=min(width,min(nonzero)*.20) if nonzero else width
  edges=[e for e in part.edges if e.is_manifold and e.calc_length()>.12 and e.calc_face_angle()>.65 and min(f.calc_area() for f in e.link_faces)>part_width*e.calc_length()*.5]
  if edges:
   result=bmesh.ops.bevel(part,geom=edges,offset=part_width,segments=1,affect='EDGES',profile=.5,clamp_overlap=True,material=edge_material)
   after=boundaries(part)
   if after[1]>before[1] or (before[0]==0 and after[0]>0):
    part.free();part=original;original=None;skipped+=1
   else:bevel_count+=len(result['faces'])
  if original is not None:original.free()
  part.normal_update();part.to_mesh(temporary);bm.from_mesh(temporary);part.free();bpy.data.meshes.remove(temporary)
 bm.normal_update();candidates=[]
 for face in bm.faces:
  if face.material_index!=edge_material or len(face.verts)!=4:continue
  v=list(face.verts);lengths=[(v[(i+1)%4].co-v[i].co).length for i in range(4)]
  if min(lengths)<1e-5 or max(lengths)<min(lengths)*2.5:continue
  candidates.append((face.calc_area(),face))
 layered=0;depths=[];widths=[]
 for _,face in sorted(candidates,key=lambda x:x[0],reverse=True)[:limit]:
  if not face.is_valid or len(face.verts)!=4:continue
  vertices=list(face.verts)
  if (vertices[1].co-vertices[0].co).length<(vertices[2].co-vertices[1].co).length:vertices=vertices[1:]+vertices[:1]
  a,b,c,d=vertices;normal=face.normal.copy();band_width=min((a.co-d.co).length,(b.co-c.co).length);depth=min(width*.12,band_width*.10)
  if depth<1e-6:continue
  def split(start,end):
   _,v1=bmesh.utils.edge_split(bm.edges.get((start,end)),start,.28)
   _,v2=bmesh.utils.edge_split(bm.edges.get((v1,end)),v1,(.72-.28)/(1-.28))
   v1.co-=normal*depth;v2.co-=normal*depth
   return v1,v2
  u1,u2=split(a,d);v1,v2=split(b,c);bm.faces.remove(face)
  for points,index in [((a,b,v1,u1),edge_material+2),((u1,v1,v2,u2),edge_material+1),((u2,v2,c,d),edge_material)]:bm.faces.new(points).material_index=index
  layered+=1;depths.append(depth);widths.append(band_width)
 bm.normal_update();boundary_after,loops_after=boundaries(bm)
 assert loops_after<=loops_before and (boundary_before>0 or boundary_after==0),('New open seams',asset,role,loops_before,loops_after)
 return {'category':role,'requested_cut_width':width,'bevel_faces':bevel_count,'layered_edges':layered,'groove_depth_max':max(depths,default=0),'layer_width_max':max(widths,default=0),'boundary_components_before':loops_before,'boundary_components_after':loops_after,'boundary_edges_before':boundary_before,'boundary_edges_after':boundary_after,'protected_join_components':skipped}

GRASS_BOARDS={'foliage_grass_green','foliage_grass_dry'}

def single_grass_board(obj,bm,source_min,source_max,colors,asset):
 """One closed extruded grass silhouette, not crossed cards or separate leaves."""
 assert asset in GRASS_BOARDS
 assert all(abs(v)<1e-6 for v in obj.rotation_euler) and all(abs(v-1)<1e-6 for v in obj.scale)
 outline=[(0,0),(.08,.27),(.02,.65),(.22,.44),(.14,.85),(.37,.55),(.45,1),(.54,.62),(.76,.91),(.70,.44),(.94,.70),(.85,.27),(1,0)]
 if asset.endswith('_dry'):outline=[(0,0),(.12,.25),(.05,.63),(.28,.40),(.18,.82),(.39,.60),(.56,1),(.57,.59),(.80,.84),(.74,.36),(.96,.53),(.89,.20),(1,0)]
 low=source_min.copy();high=source_max.copy();thickness=.055;center=(low.y+high.y)*.5
 low.y=center-thickness*.5;high.y=center+thickness*.5
 # Existing scene ground boxes top out at -0.08; preserve the original node pivot.
 low.z=-obj.matrix_world.translation.z-.08
 edge=len(colors);colors.extend([(.58,.38,.20),(.32,.18,.085),(.74,.58,.37)])
 bm.clear();rings=[];max_inset=0
 for depth,shrink in [(-.5,1),(-1/6,.985),(1/6,.985),(.5,1)]:
  ring=[]
  for u,v in outline:
   x=low.x+(high.x-low.x)*(.5+(u-.5)*shrink);z=low.z+(high.z-low.z)*(.45+(v-.45)*shrink)
   ring.append(bm.verts.new((x,center+depth*thickness,z)))
   max_inset=max(max_inset,abs((high.z-low.z)*(v-.45)*(1-shrink)))
  rings.append(ring)
 bm.faces.new(rings[0][::-1]).material_index=0;bm.faces.new(rings[-1]).material_index=0
 for layer in range(3):
  for i in range(len(outline)):
   j=(i+1)%len(outline);face=bm.faces.new((rings[layer][i],rings[layer][j],rings[layer+1][j],rings[layer+1][i]));face.material_index=edge+[2,1,0][layer]
 bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.normal_update()
 count,loops=boundaries(bm);assert count==0
 stats={'category':'single_grass_board','single_board':True,'thickness':thickness,'outline_points':len(outline),'ground_y':-.08,'requested_cut_width':thickness,'bevel_faces':len(outline)*3,'layered_edges':len(outline),'groove_depth_max':max_inset,'layer_width_max':thickness,'boundary_components_before':0,'boundary_components_after':loops,'boundary_edges_before':0,'boundary_edges_after':count,'protected_join_components':0}
 return stats,low,high

TREE_BOARDS={'tree','district_oak','district_pine'}

def tree_scene_board(asset,pigment):
 """Replace tree geometry by one closed silhouette; keep all semantic pivots."""
 from mathutils import Vector
 objects=[o for o in bpy.context.scene.objects if o.type=='MESH']
 anchor=next((o for o in objects if o.name=='timber'),objects[0])
 vertices=[o.matrix_world@v.co for o in objects for v in o.data.vertices]
 low=Vector([min(p[j] for p in vertices) for j in range(3)]);high=Vector([max(p[j] for p in vertices) for j in range(3)])
 materials=[m for o in objects for m in o.data.materials]
 bark=next(m for m in materials if any(s in m.name.lower() for s in ['bark','timber']))
 leaf=next(m for m in materials if 'leaf' in m.name.lower())
 colors=[pigment(bark,'paper_craft'),pigment(leaf,'paper_craft'),(.58,.38,.20),(.32,.18,.085),(.74,.58,.37)]
 outline=[(.43,0),(.57,0),(.57,.29),(.75,.30),(.95,.42),(1,.64),(.89,.80),(.72,.91),(.50,1),(.29,.95),(.08,.82),(0,.61),(.07,.42),(.27,.31),(.43,.29)]
 if asset=='tree':outline=[(.43,0),(.57,0),(.57,.28),(.80,.30),(1,.47),(.98,.70),(.82,.89),(.63,1),(.40,.97),(.18,.90),(0,.73),(.02,.49),(.15,.34),(.33,.29),(.43,.28)]
 if asset=='district_pine':outline=[(.44,0),(.56,0),(.56,.15),(1,.15),(.74,.39),(.90,.39),(.64,.64),(.77,.64),(.50,1),(.23,.64),(.36,.64),(.10,.39),(.26,.39),(0,.15),(.44,.15)]
 thickness=.10 if asset=='tree' else .12
 bm=bmesh.new();rings=[];inverse=anchor.matrix_world.inverted();groove=0
 for depth,shrink in [(-.5,1),(-1/6,.99),(1/6,.99),(.5,1)]:
  ring=[]
  for u,v in outline:
   x=low.x+(high.x-low.x)*(.5+(u-.5)*shrink);z=high.z*(.45+(v-.45)*shrink)
   ring.append(bm.verts.new(inverse@Vector((x,depth*thickness,z))))
   groove=max(groove,abs(high.z*(v-.45)*(1-shrink)))
  rings.append(ring)
 for index in [0,3]:
  for face,mat in [([0,1,2,14],0),(list(range(2,15)),1)]:
   if index==0:face=face[::-1]
   bm.faces.new([rings[index][i] for i in face]).material_index=mat
 for layer in range(3):
  for i in range(len(outline)):
   j=(i+1)%len(outline);bm.faces.new((rings[layer][i],rings[layer][j],rings[layer+1][j],rings[layer+1][i])).material_index=2+[2,1,0][layer]
 bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));assert boundaries(bm)==(0,0)
 mesh=bpy.data.meshes.new('Single cardboard tree');bm.to_mesh(mesh);bm.free();anchor.data=mesh
 for i,color in enumerate(colors):
  mat=bpy.data.materials.new('Tree board pigment '+str(i));mat.diffuse_color=(*color,1);mesh.materials.append(mat)
 # Empty semantic nodes preserve original names, transforms and hierarchy without
 # retaining hidden crowns, crossed cards or duplicate volumes.
 for obj in objects:
  if obj==anchor:continue
  name=obj.name;parent=obj.parent;matrix=obj.matrix_basis.copy();children=list(obj.children)
  bpy.data.objects.remove(obj,do_unlink=True);empty=bpy.data.objects.new(name,None);bpy.context.collection.objects.link(empty);empty.parent=parent;empty.matrix_basis=matrix
  for child in children:child.parent=empty
 return anchor,{'category':'single_tree_board','single_board':True,'thickness':thickness,'outline_points':len(outline),'ground_y':0,'requested_cut_width':thickness,'bevel_faces':45,'layered_edges':15,'groove_depth_max':groove,'layer_width_max':thickness,'boundary_components_before':0,'boundary_components_after':0,'boundary_edges_before':0,'boundary_edges_after':0,'protected_join_components':0}
