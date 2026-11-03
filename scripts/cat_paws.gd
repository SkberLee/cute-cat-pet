# scripts/cat_paws.gd
## Procedural paw details for the Vuena rigged cat: toe bumps + grooves on the
## top-front of each foot, and pink toe beans + main pad on the sole.
## Built as one small merged mesh per foot, attached to the lower-leg bone via
## BoneAttachment3D so it follows walk / jump / sit / eat animations.
class_name CatPaws
extends RefCounted

const SOCK := Color(0.99, 0.94, 0.88)
const GROOVE := Color(0.86, 0.60, 0.52)
const PAD := Color(1.0, 0.62, 0.72)
const PAD_DEEP := Color(0.98, 0.48, 0.62)

## Foot centres in skeleton rest space (x mirrored for the right side).
const FEET := {
	"FrontLowerLeg_L": Vector3(0.058, 0.0, 0.086),
	"FrontLowerLeg_R": Vector3(-0.058, 0.0, 0.086),
	"BackLowerLeg_L": Vector3(0.064, 0.0, -0.094),
	"BackLowerLeg_R": Vector3(-0.064, 0.0, -0.094),
}

static func build(sk: Skeleton3D) -> Array:
	var made: Array = []
	if sk == null:
		return made
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.85
	mat.albedo_color = Color(0.80, 0.80, 0.80)  # scene is bright; keeps toes from blooming into the white rug
	mat.cull_mode = BaseMaterial3D.CULL_BACK
	for bone_name in FEET:
		var b := sk.find_bone(bone_name)
		if b < 0:
			continue
		var att := BoneAttachment3D.new()
		att.name = "Paw_" + bone_name
		att.bone_name = bone_name
		sk.add_child(att)
		var inst := MeshInstance3D.new()
		inst.name = "PawDetail"
		inst.mesh = _paw_mesh(FEET[bone_name], mat)
		inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# Mesh is authored in skeleton rest space; map it into the bone's local space.
		inst.transform = sk.get_bone_global_rest(b).affine_inverse()
		att.add_child(inst)
		made.append(inst)
	return made

static func _paw_mesh(c: Vector3, mat: Material) -> ArrayMesh:
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	var side := signf(c.x)
	# Toe bumps along the front rim (sock coloured): 4 toes, outer ones set back.
	var toe_x := [-0.033, -0.011, 0.011, 0.033]
	var toe_z := [0.030, 0.040, 0.040, 0.030]
	for i in 4:
		_ellipsoid(verts, norms, cols, idx, c + Vector3(toe_x[i], 0.020, toe_z[i]), Vector3(0.0145, 0.016, 0.017), SOCK)
	# Soft grooves between toes, running back over the top of the foot.
	for gx in [-0.022, 0.0, 0.022]:
		var gz: float = 0.026 if gx == 0.0 else 0.022
		_ellipsoid(verts, norms, cols, idx, c + Vector3(gx, 0.031, gz), Vector3(0.0034, 0.0036, 0.016), GROOVE)
	# Sole: main pad + 4 toe beans, slightly proud of the flat sole (y = 0).
	_ellipsoid(verts, norms, cols, idx, c + Vector3(0.0, 0.0015, -0.010), Vector3(0.026, 0.004, 0.021), PAD)
	var bean_x := [-0.034, -0.012, 0.012, 0.034]
	var bean_z := [0.016, 0.034, 0.034, 0.016]
	for i in 4:
		_ellipsoid(verts, norms, cols, idx, c + Vector3(bean_x[i], 0.0015, bean_z[i]), Vector3(0.0095, 0.0042, 0.0115), PAD_DEEP if (i == 1 or i == 2) else PAD)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_COLOR] = cols
	arrays[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	m.surface_set_material(0, mat)
	return m

static func _ellipsoid(verts: PackedVector3Array, norms: PackedVector3Array, cols: PackedColorArray, idx: PackedInt32Array, center: Vector3, r: Vector3, col: Color) -> void:
	var sm := SphereMesh.new()
	sm.radius = 1.0
	sm.height = 2.0
	sm.radial_segments = 12
	sm.rings = 6
	var a := sm.get_mesh_arrays()
	var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	var n: PackedVector3Array = a[Mesh.ARRAY_NORMAL]
	var ix: PackedInt32Array = a[Mesh.ARRAY_INDEX]
	var base := verts.size()
	for i in v.size():
		verts.append(center + v[i] * r)
		var nn := Vector3(n[i].x / r.x, n[i].y / r.y, n[i].z / r.z).normalized()
		norms.append(nn)
		# Fake soft occlusion: undersides / sides a touch darker so toes read against a white rug.
		cols.append(Color(col.r, col.g, col.b).darkened(0.20 * (1.0 - clampf(nn.y * 0.5 + 0.5, 0.0, 1.0))))
	for i in ix:
		idx.append(base + i)
