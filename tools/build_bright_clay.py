#!/usr/bin/env python3
"""Create independent matte clay GLBs; retain geometry buffers and node contracts byte-for-byte."""
import copy, hashlib, json, pathlib, struct
ROOT = pathlib.Path(__file__).resolve().parents[1]
PALETTE = {'mint':(.12,.56,.30), 'red':(.74,.085,.055), 'yellow':(.88,.65,.12), 'blue':(.12,.34,.68), 'purple':(.64,.39,.80), 'orange':(.95,.48,.19), 'rubber':(.045,.06,.075), 'glass':(.10,.20,.27), 'lamp':(.93,.94,.83), 'tail':(.83,.18,.14), 'white':(.92,.90,.83), 'rim':(.40,.49,.54), 'metal':(.48,.55,.57), 'disc':(.23,.29,.32)}
def build():
    out = ROOT/'assets/styles/bright_clay/models'; out.mkdir(parents=True,exist_ok=True)
    records=[]
    for source in sorted((ROOT/'assets/models').glob('*.glb')):
        raw=source.read_bytes(); count,kind=struct.unpack_from('<II',raw,12)
        assert kind==0x4e4f534a
        doc=json.loads(raw[20:20+count]); original=copy.deepcopy(doc)
        for m in doc.get('materials',[]):
            name=m.get('name',''); p=m.setdefault('pbrMetallicRoughness',{}); old=p.get('baseColorFactor',[.5,.5,.5,1])
            color=PALETTE.get(name)
            if name.startswith('leaf'):color=[(.34,.60,.29),(.43,.68,.34),(.53,.75,.40),(.62,.81,.48)][int(name[-1])%4]
            if name=='trim' and source.stem.startswith('car_'):color=(.065,.09,.11)
            if name.startswith('asphalt'):color=(.18,.24,.28)
            if color is None:color=tuple(min(.94,v*.65+b) for v,b in zip(old[:3],(.24,.25,.23)))
            p.update(baseColorFactor=[*color,old[3]],metallicFactor=0.0,roughnessFactor=.94)
            m.setdefault('extensions',{}).setdefault('KHR_materials_specular',{})['specularFactor']=.10
        if 'KHR_materials_specular' not in doc.setdefault('extensionsUsed',[]):doc['extensionsUsed'].append('KHR_materials_specular')
        doc.setdefault('asset',{})['generator']='Micro Apex bright_clay material variant; unchanged rounded geometry'
        body=json.dumps(doc,separators=(',',':')).encode();body+=b' '*((-len(body))%4)
        binary=raw[20+count:]
        output=struct.pack('<III',0x46546c67,2,20+len(body)+len(binary))+struct.pack('<II',len(body),0x4e4f534a)+body+binary
        dest=out/source.name;dest.write_bytes(output)
        for key in ['nodes','meshes','accessors','bufferViews','buffers','animations','skins']:
            assert doc.get(key)==original.get(key),key
        records.append(dict(id=source.stem,source_sha256=hashlib.sha256(raw).hexdigest(),variant_sha256=hashlib.sha256(output).hexdigest(),geometry_chunk_sha256=hashlib.sha256(binary).hexdigest(),source_bytes=len(raw),variant_bytes=len(output)))
    (out.parent/'manifest.json').write_text(json.dumps({'style':'bright_clay','geometry':'identical; existing rounded/bevelled silhouettes retained','models':records},indent=2)+'\n')
    print(f'Built {len(records)} independent GLBs; geometry/node contracts unchanged')
if __name__=='__main__':build()
