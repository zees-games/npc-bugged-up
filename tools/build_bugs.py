"""Builds the insect models from primitives (our own work, CC0). Run via tools/build_bugs.sh.

Each model is a node hierarchy with the pivots a view animates: head, thorax, abdomen, mandibles/stinger,
antennae, wings and six two-segment legs named `leg<L|R><1-3>` (upper) with a child `..._lo` (knee).
Blender faces +Y, which exports to Godot's -Z (forward). Metres; a bug is about human-sized.
"""
import bpy, sys, math
from mathutils import Vector

SPEC = {
    "ant":  dict(body=(0.16, 0.16, 0.5, 0.12), thorax=(0.17, 0.13, 0.17), abd=(0.3, 0.26, 0.3), head=(0.17, 0.2, 0.16),
                 legs=0.62, thick=0.03, col=(0.28, 0.07, 0.04), col2=(0.12, 0.04, 0.03), wings=False, stinger=False, mand=True, scale=1.0),
    "wasp": dict(body=None, thorax=(0.15, 0.12, 0.14), abd=(0.2, 0.17, 0.36), head=(0.15, 0.14, 0.14),
                 legs=0.5, thick=0.022, col=(0.95, 0.75, 0.05), col2=(0.03, 0.03, 0.03), wings=True, stinger=True, mand=True, scale=1.0),
    "bee":  dict(body=None, thorax=(0.2, 0.17, 0.18), abd=(0.26, 0.22, 0.3), head=(0.16, 0.15, 0.14),
                 legs=0.42, thick=0.03, col=(0.9, 0.58, 0.05), col2=(0.1, 0.07, 0.03), wings=True, stinger=True, mand=False, scale=1.0),
}


def mat(name, rgb, rough=0.55):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    b.inputs["Base Color"].default_value = (*rgb, 1.0)
    b.inputs["Roughness"].default_value = rough
    return m


def empty(name, parent, loc):
    e = bpy.data.objects.new(name, None)
    bpy.context.collection.objects.link(e)
    e.parent = parent
    e.location = loc
    return e


def blob(name, parent, loc, size, m, shape="sphere"):
    if shape == "sphere":
        bpy.ops.mesh.primitive_uv_sphere_add(segments=16, ring_count=10, radius=1.0)
    else:
        bpy.ops.mesh.primitive_cylinder_add(vertices=8, radius=1.0, depth=1.0)
    o = bpy.context.active_object
    o.name = name
    o.data.name = name
    o.scale = size
    bpy.ops.object.transform_apply(scale=True)
    o.parent = parent
    o.location = loc
    o.data.materials.append(m)
    for p in o.data.polygons:
        p.use_smooth = True
    return o


def limb(name, parent, loc, vec, thick, m):
    """A segment from its pivot (parent origin) along vec, as a thin cylinder with the pivot at its start."""
    pivot = empty(name, parent, loc)
    ln = vec.length
    bpy.ops.mesh.primitive_cylinder_add(vertices=8, radius=thick, depth=ln)
    o = bpy.context.active_object
    o.name = name + "_mesh"
    o.data.name = name + "_mesh"
    o.parent = pivot
    o.location = vec * 0.5
    o.rotation_mode = "QUATERNION"
    o.rotation_quaternion = Vector((0, 0, 1)).rotation_difference(vec)
    o.data.materials.append(m)
    for p in o.data.polygons:
        p.use_smooth = True
    return pivot


def build(sp):
    s = SPEC[sp]
    bpy.ops.wm.read_factory_settings(use_empty=True)
    m1 = mat(sp + "_a", s["col"])
    m2 = mat(sp + "_b", s["col2"])
    mw = mat(sp + "_wing", (0.8, 0.9, 1.0), 0.2)
    root = empty(sp, None, (0, 0, 0))
    lift = s["legs"] * 0.78
    body = empty("body", root, (0, 0, lift))
    th = s["thorax"]
    blob("thorax_mesh", body, (0, 0, 0), th, m1)
    thorax = body
    ab = s["abd"]
    abdomen = empty("abdomen", body, (0, -th[1] * 0.8, 0.0))
    blob("abdomen_mesh", abdomen, (0, -ab[1] * 0.9, -0.02), ab, m1 if sp == "ant" else m2)
    if sp != "ant":
        for i, off in enumerate((-0.55, -0.1, 0.35)):
            blob("stripe%d" % i, abdomen, (0, -ab[1] * 0.9 + off * ab[1], -0.02), (ab[0] * 1.02, ab[1] * 0.2, ab[2] * 1.02), m1)
    hd = s["head"]
    head = empty("head", body, (0, th[1] * 0.85, th[2] * 0.2))
    blob("head_mesh", head, (0, hd[1] * 0.7, 0), hd, m2 if sp != "bee" else m1)
    for side, sx in (("L", -1), ("R", 1)):
        blob("eye" + side, head, (sx * hd[0] * 0.8, hd[1] * 1.0, hd[2] * 0.3), (0.05, 0.06, 0.06), mat("eye", (0.02, 0.02, 0.02), 0.1))
        ant = limb("antenna" + side, head, (sx * 0.05, hd[1] * 1.5, hd[2] * 0.4), Vector((sx * 0.12, 0.28, 0.32)), 0.012, m2)
        if s["mand"]:
            limb("mandible" + side, head, (sx * 0.05, hd[1] * 1.6, -hd[2] * 0.4), Vector((-sx * 0.1, 0.16, 0.0)), 0.025, m2)
        for k in range(3):
            y = th[1] * (0.55 - 0.55 * k)
            up = limb("leg%s%d" % (side, k + 1), body, (sx * th[0] * 0.7, y, -th[2] * 0.4), Vector((sx * s["legs"] * 0.45, (0.2 - 0.2 * k) * s["legs"] * 0.5, s["legs"] * 0.25)), s["thick"], m2)
            ln = s["legs"]
            limb("leg%s%d_lo" % (side, k + 1), up, Vector((sx * ln * 0.45, (0.2 - 0.2 * k) * ln * 0.5, ln * 0.25)), Vector((sx * ln * 0.2, (0.1 - 0.1 * k) * ln * 0.3, -ln * 1.05)), s["thick"] * 0.8, m2)
        if s["wings"]:
            w = empty("wing" + side, body, (sx * th[0] * 0.4, -0.02, th[2] * 0.8))
            blob("wing_mesh" + side, w, (sx * 0.28, -0.12, 0.02), (0.3, 0.12, 0.01), mw)
    if s["stinger"]:
        st = empty("stinger", abdomen, (0, -ab[1] * 1.85, -0.02))
        limb("stinger_mesh", st, (0, 0, 0), Vector((0, -0.22, -0.03)), 0.018, m2)
    for o in bpy.context.scene.objects:
        o.select_set(True)
    return root


def main():
    sp, out = sys.argv[sys.argv.index("--") + 1:][:2]
    build(sp)
    bpy.ops.export_scene.gltf(filepath=out, export_format="GLB", export_apply=True, export_yup=True)
    n = sum(1 for o in bpy.context.scene.objects if o.type == "MESH")
    print("BUILT", sp, out, n, "meshes")


main()
