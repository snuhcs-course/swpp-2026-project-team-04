"""Build light, skinned sportswear shells from the Apache-2.0 NVIDIA SOMA rig."""
import bpy, bmesh, math, os, sys
from mathutils import Vector

# Blender invocation: blender --background --python create_soma_sportswear.py -- /path/to/soma.glb /path/to/output/
args=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else []
if len(args)!=2: raise SystemExit('Pass the converted SOMA GLB and output directory after --')
SOURCE=os.path.abspath(args[0])
OUT=os.path.abspath(args[1])+os.sep
os.makedirs(OUT,exist_ok=True)
styles = {
    'soma_training': dict(top=(.045,.12,.22,1), bottom=(.035,.045,.065,1), trim=(.08,.19,.28,1), top_kind='tee', long=False),
    'soma_active': dict(top=(.70,.16,.12,1), bottom=(.035,.07,.15,1), trim=(.85,.30,.22,1), top_kind='tank', long=False),
    'soma_studio': dict(top=(.16,.37,.31,1), bottom=(.12,.15,.19,1), trim=(.24,.46,.38,1), top_kind='tee', long=False),
}

def material(name, color, roughness=.8):
    m=bpy.data.materials.new(name)
    m.diffuse_color=color
    m.use_nodes=True
    bsdf=m.node_tree.nodes.get('Principled BSDF')
    bsdf.inputs['Base Color'].default_value=color
    bsdf.inputs['Roughness'].default_value=roughness
    return m

def select_face(face, obj, part, spec):
    p=obj.matrix_world @ face.calc_center_median()
    x,y,z=p.x,p.y,p.z
    # Tight athletic fabric follows the source body and inherits its skinning.
    if part=='top':
        collar=1.51
        return .92 <= z <= collar and (abs(x)<.235 or (spec['top_kind']=='tee' and abs(x)<.29 and z>1.20))
    if part=='bottom':
        low=.105 if spec['long'] else .67
        return low <= z < 1.00 and abs(x)<.26
    if part=='shoe': return z<.105 and abs(x)<.27
    return False

def shell(source, armature, part, spec, mat, trim):
    obj=source.copy();obj.data=source.data.copy();bpy.context.collection.objects.link(obj)
    obj.name='Sportswear_'+part
    source.data.update()
    bm=bmesh.new();bm.from_mesh(obj.data);bm.faces.ensure_lookup_table()
    bmesh.ops.remove_doubles(bm, verts=list(bm.verts), dist=0.00001)
    zcuts={'top':[.92,.955,1.20,1.48,1.51], 'bottom':([.105,.14,.965,1.00] if spec['long'] else [.67,.705,.965,1.00]), 'shoe':[.035,.105]}[part]
    for z in zcuts:
        bmesh.ops.bisect_plane(bm,geom=list(bm.verts)+list(bm.edges)+list(bm.faces),dist=0.00001,plane_co=source.matrix_world.inverted() @ Vector((0,0,z)),plane_no=source.matrix_world.to_3x3().transposed() @ Vector((0,0,1)))
    for x in (-.29,-.267,-.235,.235,.267,.29) if part=='top' else (-.26,.26):
        bmesh.ops.bisect_plane(bm,geom=list(bm.verts)+list(bm.edges)+list(bm.faces),dist=0.00001,plane_co=source.matrix_world.inverted() @ Vector((x,0,0)),plane_no=source.matrix_world.to_3x3().transposed() @ Vector((1,0,0)))
    bmesh.ops.delete(bm,geom=[f for f in bm.faces if not select_face(f,source,part,spec)],context='FACES')
    bmesh.ops.delete(bm,geom=[v for v in bm.verts if not v.link_faces],context='VERTS')
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    bm.to_mesh(obj.data);bm.free();obj.data.update()
    # Lift the fabric away from the body, making hems and sleeves visibly loose.
    scale=source.matrix_world.to_scale().x
    for v in obj.data.vertices:
        p=source.matrix_world @ v.co
        if part=='top':
            offset=.028 + .016 * max(0, min(1, (1.23-p.z)/.23))
        elif part=='bottom':
            offset=.023 if spec['long'] else .037 + .012 * max(0,min(1,(.83-p.z)/.16))
        else: offset=.020
        v.co += v.normal * (offset / scale)
    obj.data.update()
    obj.data.materials.clear();obj.data.materials.append(mat);obj.data.materials.append(trim)
    # Contrasting fabric bands give the clothing clear hems and a waistband.
    for poly in obj.data.polygons:
        p=source.matrix_world @ poly.center
        x,z=abs(p.x),p.z
        if part=='top':
            is_trim=(z<.955 or z>1.48 or (spec['top_kind']=='tee' and x>.267 and z>1.20))
        elif part=='bottom':
            is_trim=(z>.965 or (not spec['long'] and z<.705) or (spec['long'] and z<.14))
        else: is_trim=z<.035
        poly.material_index=0
    # Smooth offsets around seams before giving the fabric a physical edge.
    smooth=obj.modifiers.new('Relax fabric', 'SMOOTH')
    smooth.factor=1.1
    smooth.iterations=20
    bpy.context.view_layer.objects.active=obj
    obj.select_set(True)
    while obj.modifiers.find(smooth.name)>0:
        bpy.ops.object.modifier_move_up(modifier=smooth.name)
    bpy.ops.object.modifier_apply(modifier=smooth.name)
    obj.select_set(False)
    # Physical thickness creates visible fabric edges instead of a painted surface.
    solid=obj.modifiers.new('Fabric thickness and hems','SOLIDIFY')
    solid.thickness=.009 / scale
    solid.offset=-1
    solid.material_offset_rim=1
    bpy.context.view_layer.objects.active=obj
    obj.select_set(True)
    while obj.modifiers.find(solid.name)>0:
        bpy.ops.object.modifier_move_up(modifier=solid.name)
    bpy.ops.object.modifier_apply(modifier=solid.name)
    obj.select_set(False)
    return obj

def hide_body_under_clothes(body, spec):
    # Skin under the garments is not visible; removing it prevents poke-through
    # when the rig bends, while leaving a small margin at each garment opening.
    bm=bmesh.new();bm.from_mesh(body.data)
    inv=body.matrix_world.inverted()
    normal_matrix=body.matrix_world.to_3x3().transposed()
    for z in (.94,.99,1.18,1.22,1.49,.69):
        bmesh.ops.bisect_plane(bm,geom=list(bm.verts)+list(bm.edges)+list(bm.faces),dist=.00001,plane_co=inv @ Vector((0,0,z)),plane_no=normal_matrix @ Vector((0,0,1)))
    for x in (-.28,-.225,.225,.28):
        bmesh.ops.bisect_plane(bm,geom=list(bm.verts)+list(bm.edges)+list(bm.faces),dist=.00001,plane_co=inv @ Vector((x,0,0)),plane_no=normal_matrix @ Vector((1,0,0)))
    def hidden(f):
        p=body.matrix_world @ f.calc_center_median()
        x,z=abs(p.x),p.z
        shirt=(.94<z<1.49 and (x<.225 or (spec['top_kind']=='tee' and x<.28 and z>1.22)))
        shorts=(.69<z<.99 and x<.225)
        return shirt or shorts
    bmesh.ops.delete(bm,geom=[f for f in bm.faces if hidden(f)],context='FACES')
    bmesh.ops.delete(bm,geom=[v for v in bm.verts if not v.link_faces],context='VERTS')
    bm.to_mesh(body.data);bm.free();body.data.update()

for name,spec in styles.items():
    bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
    bpy.ops.import_scene.gltf(filepath=SOURCE)
    arm=next(o for o in bpy.context.scene.objects if o.type=='ARMATURE')
    # Keep the armature object distinct from the Hips bone: glTFLoader otherwise
    # renames the bone to Hips_1, breaking the pose retargeter's root lookup.
    arm.name='SOMA_Rig'
    body=max((o for o in bpy.context.scene.objects if o.type=='MESH'),key=lambda o:len(o.data.vertices))
    skin=material('Skin warm',(.47,.29,.21,1),.7)
    body.data.materials.clear();body.data.materials.append(skin)
    for poly in body.data.polygons: poly.material_index=0
    shell(body,arm,'top',spec,material('Athletic top',spec['top']),material('Top trim',spec['trim']))
    shell(body,arm,'bottom',spec,material('Athletic bottoms',spec['bottom']),material('Bottom trim',spec['trim']))
    hide_body_under_clothes(body,spec)
    bpy.ops.export_scene.gltf(filepath=OUT+name+'.glb',export_format='GLB',export_apply=False)
    print('OUTFIT',name)
