import bpy
import os

OUT = os.path.abspath("build/gold_dragon_kart.glb")
os.makedirs(os.path.dirname(OUT), exist_ok=True)

roots = [o for o in bpy.data.objects if o.name.startswith("GOLD_DRAGON_HYPERKART")]
if not roots:
    raise RuntimeError("Gold kart root not found in uploaded .blend")

root = roots[0]

def descendants(obj):
    result = []
    stack = list(obj.children)
    while stack:
        child = stack.pop()
        result.append(child)
        stack.extend(list(child.children))
    return result

targets = [root] + descendants(root)
targets = [o for o in targets if not o.name.startswith("STUDIO_") and o.type not in {"LIGHT", "CAMERA"}]

# Curves are used for gold trim/dragon ornaments; convert them to meshes
# so the glTF contains the authored appearance reliably.
for obj in list(targets):
    if obj.type in {"CURVE", "SURFACE", "FONT", "META"}:
        bpy.ops.object.select_all(action="DESELECT")
        obj.hide_set(False)
        obj.select_set(True)
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.convert(target="MESH")

# Re-resolve after conversion.
root = [o for o in bpy.data.objects if o.name.startswith("GOLD_DRAGON_HYPERKART")][0]
targets = [root] + descendants(root)
targets = [o for o in targets if not o.name.startswith("STUDIO_") and o.type not in {"LIGHT", "CAMERA"}]

bpy.ops.object.select_all(action="DESELECT")
for obj in targets:
    obj.hide_set(False)
    obj.hide_render = False
    obj.select_set(True)

bpy.context.view_layer.objects.active = root

bpy.ops.export_scene.gltf(
    filepath=OUT,
    export_format="GLB",
    use_selection=True,
    export_apply=True
)

if not os.path.isfile(OUT):
    raise RuntimeError("GLB was not created")
if os.path.getsize(OUT) < 1024:
    raise RuntimeError("GLB output is unexpectedly small")

print("GLB export complete:", OUT, os.path.getsize(OUT))
