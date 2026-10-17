"""Run with official Blender, --disable-autoexec. Export only the avatar to GLB."""
import bpy,sys,json
from pathlib import Path
base=Path(__file__).resolve().parent
kind=sys.argv[sys.argv.index('--')+1]
specs={
 'astronaut':('astronaut/Untitled.fbx','Human.rig'),
 'robot':('robot/corebreaker.blend','Player'),
 'mannequiny':('mannequiny.blend','root'),
 'xcvg':('xcvg/person_animated.fbx','Armature'),
}
source,rig_name=specs[kind]
source=base/'source-assets'/source
if source.suffix=='.fbx':
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.fbx(filepath=str(source))
else:bpy.ops.wm.open_mainfile(filepath=str(source),load_ui=False,use_scripts=False)
rig=bpy.data.objects.get(rig_name)
if rig is None:
    rigs=[o for o in bpy.data.objects if o.type=='ARMATURE']
    if len(rigs)!=1:raise RuntimeError('Ambiguous armature')
    rig=rigs[0]
keep={rig,*rig.children_recursive}
for obj in list(bpy.data.objects):
    if obj not in keep:bpy.data.objects.remove(obj,do_unlink=True)
# Do not execute source drivers/constraints. Export an inspectable bind pose.
rig.animation_data_clear()
for bone in rig.pose.bones:
    for constraint in list(bone.constraints):bone.constraints.remove(constraint)
    bone.location=(0,0,0);bone.rotation_mode='QUATERNION';bone.rotation_quaternion=(1,0,0,0);bone.scale=(1,1,1)
for obj in keep:
    obj.hide_set(False);obj.hide_viewport=False;obj.hide_render=False
    if obj!=rig:obj.animation_data_clear()
    obj.select_set(True)
bpy.context.view_layer.objects.active=rig
rig.location=(0,0,0)
# Source files sometimes have absolute author-machine texture paths.
for image in bpy.data.images:
    if image.packed_file:continue
    path=base/'source-assets'/'robot'/'textures'/Path(image.filepath).name
    if path.exists():image.filepath=str(path);image.reload()
bpy.context.scene.frame_set(0)
if kind in ('mannequiny','xcvg'):
    # Legacy Blender material alpha is zero despite the original opaque body.
    for mat in bpy.data.materials:
        mat.diffuse_color=(*mat.diffuse_color[:3],1)
        if mat.use_nodes:
            for node in mat.node_tree.nodes:
                if node.type=='BSDF_PRINCIPLED':
                    alpha=node.inputs.get('Alpha')
                    for link in list(alpha.links):mat.node_tree.links.remove(link)
                    alpha.default_value=1
bpy.context.view_layer.update()
out=base/'models'/(kind+'.glb')
bpy.ops.export_scene.gltf(filepath=str(out),export_format='GLB',use_selection=True,export_animations=True,export_animation_mode='ACTIONS',export_force_sampling=True,export_cameras=False,export_lights=False,export_yup=True)
print('EXPORTED',kind,out.stat().st_size,flush=True)
