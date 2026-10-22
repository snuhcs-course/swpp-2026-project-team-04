"""Blender --background --factory-startup --disable-autoexec --python expand_catalog.py.

Convert CC0 author downloads into camera-retargetable GLBs and real thumbnails.
Never executes scripts from an authoring file. Removes canned animation clips.
"""
import bpy, math, json, shutil, hashlib
from pathlib import Path
from mathutils import Vector

BASE = Path(__file__).resolve().parent
APP = BASE.parents[1] / 'gymrats_app/assets/avatar'
MODELS = APP / 'models'
THUMBS = APP / 'thumbnails'
THUMBS.mkdir(exist_ok=True)
KAY = ['Knight', 'Barbarian', 'Mage', 'Rogue', 'Rogue_Hooded', 'Skeleton_Mage', 'Skeleton_Minion', 'Skeleton_Rogue', 'Skeleton_Warrior']
LEGACY = ['astronaut', 'robot', 'mannequiny', 'xcvg']

def clear():
    bpy.ops.wm.read_factory_settings(use_empty=True)

def canonical(rig):
    aliases = {'Hips':'pelvis', 'hips':'pelvis', 'Neck':'neck_01', 'Head':'head'}
    for prefix, side in [('Left','l'), ('Right','r')]:
        for source, target in [('Arm','upperarm'),('ForeArm','lowerarm'),('Hand','hand'),('UpLeg','thigh'),('Leg','calf'),('Foot','foot'),('Toes','ball')]:
            aliases[prefix+source] = target+'_'+side
        for source, target in [('upperarm','upperarm'),('lowerarm','lowerarm'),('wrist','hand'),('hand','fingers'),('upperleg','thigh'),('lowerleg','calf'),('foot','foot'),('toes','ball')]:
            aliases[source+'.'+side] = target+'_'+side
    for bone in rig.data.bones:
        if bone.name in aliases:
            bone.name = aliases[bone.name]
    rig.animation_data_clear()
    for bone in rig.pose.bones:
        for c in list(bone.constraints): bone.constraints.remove(c)
        bone.location=(0,0,0); bone.rotation_mode='QUATERNION'
        bone.rotation_quaternion=(1,0,0,0); bone.scale=(1,1,1)

def export(name, texture=None):
    rigs=[o for o in bpy.data.objects if o.type=='ARMATURE']
    if len(rigs)!=1: raise RuntimeError(f'{name}: expected one rig')
    rig=rigs[0]
    canonical(rig)
    meshes=[o for o in bpy.data.objects if o.type=='MESH']
    if texture:
        mat=bpy.data.materials.new(name+' Skin'); mat.use_nodes=True
        node=mat.node_tree.nodes.new('ShaderNodeTexImage')
        node.image=bpy.data.images.load(str(texture)); node.interpolation='Closest'
        shader=mat.node_tree.nodes.get('Principled BSDF')
        mat.node_tree.links.new(node.outputs['Color'],shader.inputs['Base Color'])
        shader.inputs['Roughness'].default_value=.8
        for obj in meshes:
            obj.data.materials.clear(); obj.data.materials.append(mat)
    for image in bpy.data.images:
        if image.size[0]>512 or image.size[1]>512:
            image.scale(512,512)
    for obj in bpy.data.objects:
        obj.select_set(obj.type in ('MESH','ARMATURE'))
        obj.animation_data_clear()
    bpy.context.view_layer.objects.active=rig
    bpy.context.view_layer.update()
    path=MODELS/(name+'.glb')
    bpy.ops.export_scene.gltf(filepath=str(path),export_format='GLB',use_selection=True,export_animations=False,export_cameras=False,export_lights=False)
    shutil.copy2(path,BASE/'models'/path.name)
    print('EXPORTED',name,path.stat().st_size,flush=True)

def thumbnail(name):
    clear(); bpy.ops.import_scene.gltf(filepath=str(MODELS/(name+'.glb')))
    objects=[o for o in bpy.data.objects if o.type in ('ARMATURE','MESH','EMPTY')]
    meshes=[o for o in objects if o.type=='MESH']
    points=[o.matrix_world@Vector(c) for o in meshes for c in o.bound_box]
    lo=Vector(tuple(min(p[i] for p in points) for i in range(3)))
    hi=Vector(tuple(max(p[i] for p in points) for i in range(3)))
    height=hi.z-lo.z
    if height<=0: raise RuntimeError('Empty model '+name)
    target=(lo+hi)/2
    bpy.ops.object.camera_add(location=target+Vector((height*.9,-height*2.4,height*.45)))
    camera=bpy.context.object; camera.rotation_euler=(target-camera.location).to_track_quat('-Z','Y').to_euler()
    camera.data.type='ORTHO'; camera.data.ortho_scale=max(height*1.25,(hi.x-lo.x)*1.25)
    scene=bpy.context.scene; scene.camera=camera
    scene.render.engine='CYCLES'; scene.cycles.samples=8
    scene.render.resolution_x=160; scene.render.resolution_y=160; scene.render.resolution_percentage=100
    scene.render.image_settings.file_format='PNG'; scene.render.film_transparent=False
    scene.world=bpy.data.worlds.new('Backdrop'); scene.world.use_nodes=True
    scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.055,.07,.1,1)
    scene.world.node_tree.nodes['Background'].inputs[1].default_value=.6
    for offset,power in [((2,-3,4),700),((-2,-1,2),350)]:
        bpy.ops.object.light_add(type='AREA', location=target+Vector(offset)*height)
        light=bpy.context.object; light.data.energy=power*height*height; light.data.shape='DISK'; light.data.size=height*2
        light.rotation_euler=(target-light.location).to_track_quat('-Z','Y').to_euler()
    scene.render.filepath=str(THUMBS/(name+'.png'))
    bpy.ops.render.render(write_still=True)
    print('THUMBNAIL',name,flush=True)

catalog=list(LEGACY)
for pack in ['protagonists','retro','survivors']:
    source=BASE/'source-assets/kenney'/pack
    for texture in sorted((source/'Skins').glob('*.png')):
        name='kenney_'+texture.stem.lower()
        clear(); bpy.ops.import_scene.fbx(filepath=str(source/'Model/characterMedium.fbx'))
        export(name,texture); catalog.append(name)
    shutil.copy2(source/'License.txt',APP/('Kenney-'+pack+'-LICENSE.txt'))
for source_name in KAY:
    name='kaykit_'+source_name.lower()
    clear(); bpy.ops.import_scene.gltf(filepath=str(BASE/'source-assets/kaykit'/(source_name+'.glb')))
    export(name); catalog.append(name)
for pack in ['Adventurers','Skeletons']:
    shutil.copy2(BASE/'source-assets/kaykit'/(pack+'-LICENSE.txt'),APP/('KayKit-'+pack+'-LICENSE.txt'))
for name in catalog: thumbnail(name)
inventory=[{'asset':name,'bytes':(MODELS/(name+'.glb')).stat().st_size,'sha256':hashlib.sha256((MODELS/(name+'.glb')).read_bytes()).hexdigest()} for name in catalog]
(APP/'catalog-assets.json').write_text(json.dumps(inventory,indent=2)+'\n',encoding='utf-8')
print('CATALOG_COMPLETE',len(catalog),sum(r['bytes'] for r in inventory),flush=True)
