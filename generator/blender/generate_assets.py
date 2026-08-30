import bpy
import math
from pathlib import Path

OUT = Path("generated")
MODELS = OUT / "models"
MAPS = OUT / "maps"
MODELS.mkdir(parents=True, exist_ok=True)
MAPS.mkdir(parents=True, exist_ok=True)

bpy.ops.wm.read_factory_settings(use_empty=True)


def mat(name, color, metallic=0.0, roughness=0.55):
    m = bpy.data.materials.new(name)
    m.diffuse_color = (*color, 1.0)
    m.metallic = metallic
    m.roughness = roughness
    return m

black = mat("polymer", (0.035, 0.04, 0.045), 0.1, 0.42)
metal = mat("steel", (0.18, 0.19, 0.2), 0.75, 0.3)
concrete = mat("concrete", (0.32, 0.34, 0.35), 0.0, 0.9)


def cube(name, loc, scale, material=black):
    bpy.ops.mesh.primitive_cube_add(location=loc)
    o = bpy.context.object
    o.name = name
    o.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    o.data.materials.append(material)
    return o


def cylinder(name, loc, radius, depth, rotation=(0, 0, 0), material=metal):
    bpy.ops.mesh.primitive_cylinder_add(vertices=16, radius=radius, depth=depth, location=loc, rotation=rotation)
    o = bpy.context.object
    o.name = name
    o.data.materials.append(material)
    return o


def weapon(name, kind):
    bpy.ops.object.select_all(action="DESELECT")
    parts = []
    if kind == "pistol":
        parts += [cube("slide", (0, 0, 0), (0.34, 0.06, 0.07), metal)]
        parts += [cube("frame", (0, -0.02, -0.09), (0.28, 0.055, 0.05), black)]
        parts += [cube("grip", (-0.04, -0.02, -0.23), (0.055, 0.055, 0.13), black)]
        parts += [cylinder("barrel", (0.37, 0, 0), 0.035, 0.22, (0, math.pi / 2, 0), metal)]
    elif kind == "shotgun":
        parts += [cube("receiver", (0, 0, 0), (0.28, 0.08, 0.08), metal)]
        parts += [cube("stock", (-0.48, 0, -0.01), (0.25, 0.065, 0.065), black)]
        parts += [cylinder("barrel", (0.55, 0, 0.04), 0.055, 1.0, (0, math.pi / 2, 0), metal)]
        parts += [cube("pump", (0.35, 0, -0.09), (0.18, 0.07, 0.055), black)]
    else:
        parts += [cube("receiver", (0, 0, 0), (0.3, 0.09, 0.09), metal)]
        parts += [cube("handguard", (0.5, 0, 0), (0.35, 0.075, 0.075), black)]
        parts += [cube("stock", (-0.42, 0, 0), (0.22, 0.065, 0.07), black)]
        parts += [cylinder("barrel", (0.88, 0, 0), 0.035, 0.75, (0, math.pi / 2, 0), metal)]
        parts += [cube("grip", (-0.05, 0, -0.18), (0.06, 0.06, 0.14), black)]
    bpy.ops.object.select_all(action="SELECT")
    bpy.context.view_layer.objects.active = parts[0]
    bpy.ops.object.join()
    obj = bpy.context.object
    obj.name = name
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.wm.save_as_mainfile(filepath=str(MODELS / f"{name}.blend"))
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.gltf(filepath=str(MODELS / f"{name}.glb"), export_format="GLB", use_selection=True)
    bpy.ops.object.select_all(action="DESELECT")
    bpy.data.objects.remove(obj, do_unlink=True)


def room():
    pieces = []
    pieces += [cube("floor", (0, 0, 0), (10, 10, 0.15), concrete)]
    pieces += [cube("north", (0, 2.5, -10), (10, 2.5, 0.15), concrete)]
    pieces[-1].rotation_euler.x = math.pi / 2
    pieces += [cube("south", (0, 2.5, 10), (10, 2.5, 0.15), concrete)]
    pieces[-1].rotation_euler.x = math.pi / 2
    pieces += [cube("west", (-10, 2.5, 0), (0.15, 2.5, 10), concrete)]
    pieces += [cube("east", (10, 2.5, 0), (0.15, 2.5, 10), concrete)]
    pieces += [cube("cover_a", (-3, 0.8, -2), (1.6, 0.8, 0.6), concrete)]
    pieces += [cube("cover_b", (4, 0.8, 3), (1.2, 0.8, 0.6), concrete)]
    bpy.ops.object.select_all(action="DESELECT")
    for p in pieces:
        p.select_set(True)
    bpy.context.view_layer.objects.active = pieces[0]
    bpy.ops.object.join()
    bpy.context.object.name = "training_room"
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.gltf(filepath=str(MAPS / "training_room.glb"), export_format="GLB", use_selection=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(MAPS / "training_room.blend"))

weapon("pistol_9mm", "pistol")
weapon("carbine_556", "rifle")
weapon("pump_shotgun", "shotgun")
room()
print("generated 3d assets")
