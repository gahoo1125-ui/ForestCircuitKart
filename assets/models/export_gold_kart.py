import bpy
import os

GLB_OUT = os.path.abspath("build/gold_dragon_kart.glb")
BLEND_OUT = os.path.abspath("build/blender.gold_redblack.blend")
PREVIEW_OUT = os.path.abspath("build/red_black_kart_preview.png")
os.makedirs(os.path.dirname(GLB_OUT), exist_ok=True)

roots = [o for o in bpy.data.objects if o.name.startswith("GOLD_DRAGON_HYPERKART")]
if not roots:
    raise RuntimeError("Gold kart root not found in uploaded .blend")
root = roots[0]

def descendants(obj):
    out=[]
    stack=list(obj.children)
    while stack:
        child=stack.pop()
        out.append(child)
        stack.extend(list(child.children))
    return out

def make_principled(name, base, metallic, rough, emission=None, emission_strength=0.0):
    m=bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.use_nodes=True
    bsdf=m.node_tree.nodes.get("Principled BSDF")
    if bsdf is None:
        return m
    if "Base Color" in bsdf.inputs:
        bsdf.inputs["Base Color"].default_value=(*base,1.0)
    if "Metallic" in bsdf.inputs:
        bsdf.inputs["Metallic"].default_value=metallic
    if "Roughness" in bsdf.inputs:
        bsdf.inputs["Roughness"].default_value=rough
    if "Coat Weight" in bsdf.inputs:
        bsdf.inputs["Coat Weight"].default_value=0.35
    if "Coat Roughness" in bsdf.inputs:
        bsdf.inputs["Coat Roughness"].default_value=0.08
    if emission is not None:
        if "Emission Color" in bsdf.inputs:
            bsdf.inputs["Emission Color"].default_value=(*emission,1.0)
        elif "Emission" in bsdf.inputs:
            bsdf.inputs["Emission"].default_value=(*emission,1.0)
        if "Emission Strength" in bsdf.inputs:
            bsdf.inputs["Emission Strength"].default_value=emission_strength
    return m

carbon_black = make_principled("RB_CarbonBlack",(0.004,0.005,0.008),0.72,0.14)
carbon_soft  = make_principled("RB_CarbonSoft",(0.015,0.017,0.022),0.60,0.20)
metal_red    = make_principled("RB_MetallicRed",(0.42,0.006,0.010),0.98,0.10)
deep_red     = make_principled("RB_DeepRed",(0.16,0.002,0.004),0.94,0.14)
red_glow     = make_principled("RB_RedGlow",(0.60,0.008,0.006),0.45,0.06,(1.0,0.015,0.006),6.0)
headlight    = make_principled("RB_Headlight",(1.0,0.68,0.58),0.25,0.05,(1.0,0.18,0.08),4.0)
tire_mat     = make_principled("RB_Tire",(0.003,0.0035,0.004),0.0,0.82)
wheel_dark   = make_principled("RB_WheelDark",(0.008,0.009,0.012),0.88,0.15)
brake_mat    = make_principled("RB_Brake",(0.12,0.13,0.15),0.90,0.28)
glass_mat    = make_principled("RB_Glass",(0.008,0.010,0.016),0.25,0.08)
seat_mat     = make_principled("RB_Seat",(0.010,0.010,0.013),0.08,0.34)

def replace_all_materials(obj, material):
    if not hasattr(obj.data,"materials"):
        return
    obj.data.materials.clear()
    obj.data.materials.append(material)

targets=[root]+descendants(root)
targets=[o for o in targets if not o.name.startswith("STUDIO_") and o.type not in {"LIGHT","CAMERA"}]

for obj in targets:
    n=obj.name.upper()
    if not hasattr(obj,"data") or obj.data is None:
        continue
    if "TIRE" in n:
        replace_all_materials(obj,tire_mat); continue
    if "BARREL" in n or "WHEEL_DARK" in n:
        replace_all_materials(obj,wheel_dark); continue
    if "DISC" in n:
        replace_all_materials(obj,brake_mat); continue
    if "GLASS" in n or "WINDSCREEN" in n or "VISOR" in n:
        replace_all_materials(obj,glass_mat); continue
    if "SEAT" in n:
        replace_all_materials(obj,seat_mat); continue
    if "HEADLIGHT" in n or "LIGHT_LED" in n or "DISPLAY" in n:
        replace_all_materials(obj,headlight); continue
    if "TAIL_LED" in n or "TAILLIGHT" in n:
        replace_all_materials(obj,red_glow); continue

    red_keys=("DRAGON","TRIM_","SCALE_","GOLD","RIMOUTER","SPOKE","CALIPER","HOOD_CENTERSPINE","WING_GOLDFLAP","REAR_VENT")
    if any(k in n for k in red_keys):
        replace_all_materials(obj,metal_red); continue

    if "EXHAUST" in n or "HUB" in n:
        replace_all_materials(obj,deep_red); continue

    soft_keys=("INTAKE","DIFFUSER","UNDERBODY","DASHBOARD")
    replace_all_materials(obj,carbon_soft if any(k in n for k in soft_keys) else carbon_black)

for obj in targets:
    n=obj.name.upper()
    if any(k in n for k in ("FRONT_GOLDFANG","FRONT_GOLDLIP","FRONT_CENTERGOLDCHIN","SIDE_GOLDSILL","WING_GOLDFLAP")):
        replace_all_materials(obj,metal_red)

bpy.ops.wm.save_as_mainfile(filepath=BLEND_OUT)
print("Saved recolored blend:",BLEND_OUT,os.path.getsize(BLEND_OUT))

try:
    scene=bpy.context.scene
    if scene.camera is not None:
        scene.render.engine='BLENDER_EEVEE_NEXT'
        scene.render.resolution_x=960
        scene.render.resolution_y=540
        scene.render.resolution_percentage=100
        scene.render.image_settings.file_format='PNG'
        scene.render.filepath=PREVIEW_OUT
        scene.render.film_transparent=False
        bpy.ops.render.render(write_still=True)
        print("Preview rendered:",PREVIEW_OUT)
except Exception as e:
    print("Preview render skipped:",e)

root=[o for o in bpy.data.objects if o.name.startswith("GOLD_DRAGON_HYPERKART")][0]
targets=[root]+descendants(root)
targets=[o for o in targets if not o.name.startswith("STUDIO_") and o.type not in {"LIGHT","CAMERA"}]

for obj in list(targets):
    if obj.type in {"CURVE","SURFACE","FONT","META"}:
        bpy.ops.object.select_all(action='DESELECT')
        obj.hide_set(False)
        obj.select_set(True)
        bpy.context.view_layer.objects.active=obj
        bpy.ops.object.convert(target='MESH')

root=[o for o in bpy.data.objects if o.name.startswith("GOLD_DRAGON_HYPERKART")][0]
targets=[root]+descendants(root)
targets=[o for o in targets if not o.name.startswith("STUDIO_") and o.type not in {"LIGHT","CAMERA"}]
bpy.ops.object.select_all(action='DESELECT')
for obj in targets:
    obj.hide_set(False)
    obj.hide_render=False
    obj.select_set(True)
bpy.context.view_layer.objects.active=root

bpy.ops.export_scene.gltf(filepath=GLB_OUT,export_format='GLB',use_selection=True,export_apply=True)

if not os.path.isfile(GLB_OUT) or os.path.getsize(GLB_OUT)<1024:
    raise RuntimeError("GLB export failed")
print("Red/black GLB export complete:",GLB_OUT,os.path.getsize(GLB_OUT))
