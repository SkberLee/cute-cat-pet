# scripts/head_lean.gd
## Skeleton modifier that adds a small extra head pitch on top of the animation
## (used so the cat leans into the petting hand). `amount` 0..1, `pitch` radians at 1.
class_name HeadLean
extends SkeletonModifier3D

var bone_name := "Head"
var amount := 0.0
var pitch := 0.10
var roll := 0.0
var _bone := -2

func _process_modification_with_delta(_delta: float) -> void:
	var sk := get_skeleton()
	if sk == null or absf(amount) < 0.001:
		return
	if _bone == -2:
		_bone = sk.find_bone(bone_name)
	if _bone < 0:
		return
	var gp := sk.get_bone_global_pose(_bone)
	var rot := Basis(Vector3.RIGHT, pitch * amount) * Basis(Vector3.FORWARD, roll * amount)
	gp.basis = rot * gp.basis
	sk.set_bone_global_pose(_bone, gp)
