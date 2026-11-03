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
