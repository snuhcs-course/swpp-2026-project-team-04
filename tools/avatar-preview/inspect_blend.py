import bpy,sys,json
from pathlib import Path
args=sys.argv[sys.argv.index('--')+1:]
bpy.ops.wm.open_mainfile(filepath=str(Path(args[0]).resolve()),load_ui=False,use_scripts=False)
info={'file':args[0],'objects':[],'actions':[]}
for obj in bpy.data.objects:
    item={'name':obj.name,'type':obj.type,'parent':obj.parent.name if obj.parent else None,'location':list(obj.location),'dimensions':list(obj.dimensions),'hidden':obj.hide_render}
    if obj.type=='ARMATURE':item['bones']=[{'name':b.name,'parent':b.parent.name if b.parent else None,'head':list(b.head_local),'tail':list(b.tail_local),'deform':b.use_deform} for b in obj.data.bones]
    info['objects'].append(item)
for a in bpy.data.actions:info['actions'].append({'name':a.name,'frames':list(a.frame_range)})
Path(args[1]).write_text(json.dumps(info,indent=2),encoding='utf-8')
print('INSPECTED',args[1],flush=True)
