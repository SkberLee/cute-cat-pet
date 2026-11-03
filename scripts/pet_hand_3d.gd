# scripts/pet_hand_3d.gd
## A refined cartoon hand (procedural 3D mesh) that strokes the cat's head.
## Hand-local frame: fingers point -Z, back of the hand is +Y, thumb on -X.
## The rig lives in the cat's local frame (+Z = the way the cat faces), so the
## hand always reaches in from the cat's front/above, palm down, fingers along
## the cat's back, and strokes forehead -> neck.
class_name PetHand3D
extends Node3D

const SKIN := Color(1.0, 0.80, 0.69)
const SKIN_SHADE := Color(0.98, 0.66, 0.58)
const SLEEVE := Color(0.99, 0.58, 0.72)
const CUFF := Color(1.0, 0.96, 0.94)

var _cat: Node3D
var _rig: Node3D
var _hand: Node3D
var _lean: HeadLean
var _t := -1.0
var _dur := 2.4
var _lean_v := 0.0
# Tunables (cat-local metres, relative to Cat.get_head_point()).
var z_forehead := 0.02     # palm-centre offsets from the Head bone (cat-local Z)
var z_neck := -0.02
var hand_scale := 1.3
var _fwd := 1.0      # +1: fingers point to the cat's front (arm comes from behind), -1: mirrored

func setup(cat: Node3D) -> void:
	_cat = cat
	name = "PetHand3D"
	visible = false
	cat.add_child(self)
	_build()
	var sk: Skeleton3D = null
	if cat.get("_jaw_skel") != null:
		sk = cat.get("_jaw_skel")
	if sk:
		_lean = HeadLean.new()
		_lean.name = "HeadLean"
		sk.add_child(_lean)

func play(duration: float) -> void:
	_dur = maxf(duration, 2.2)
	_t = 0.0
	visible = true
	# Reach in from the side away from the camera so the back of the hand and the
	# fingers are always readable (the sleeve then rises up and out of frame).
	_fwd = 1.0
	var cam := get_viewport().get_camera_3d()
	if cam and _cat:
		_fwd = 1.0 if _cat.to_local(cam.global_position).z >= 0.0 else -1.0

func is_playing() -> bool:
	return _t >= 0.0

func stop() -> void:
	_t = -1.0
	visible = false
	if _lean:
		_lean.amount = 0.0

# --- materials / mesh helpers ------------------------------------------------
static func _mat(c: Color, rough := 0.65, rim := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(c.r * 0.62, c.g * 0.62, c.b * 0.62, c.a)
	m.roughness = rough
	if rim > 0.0:
		m.rim_enabled = true
		m.rim = rim
		m.rim_tint = 0.6
	return m

static func _mi(parent: Node, mesh: Mesh, mat: Material, pos := Vector3.ZERO, scl := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.scale = scl
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi

static func _sph(r: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 20
	s.rings = 10
	return s

## Tapered limb between a and b (cylinder + end spheres => smooth soft joints).
static func _limb(parent: Node, a: Vector3, b: Vector3, r0: float, r1: float, mat: Material) -> void:
	var d := b - a
	var len := d.length()
	if len < 0.0001:
		return
	var cyl := CylinderMesh.new()
	cyl.bottom_radius = r0
	cyl.top_radius = r1
	cyl.height = len
	cyl.radial_segments = 20
	cyl.rings = 1
	var mi := _mi(parent, cyl, mat, (a + b) * 0.5)
	mi.basis = Basis(Quaternion(Vector3.UP, d.normalized()))
	_mi(parent, _sph(r0), mat, a)
	_mi(parent, _sph(r1), mat, b)

func _build() -> void:
	_rig = Node3D.new()
	_rig.name = "Rig"
	add_child(_rig)
	_hand = Node3D.new()
	_hand.name = "Hand"
	_rig.add_child(_hand)
	var skin := _mat(SKIN, 0.62, 0.35)
	var shade := _mat(SKIN_SHADE, 0.7)
	var nail := _mat(Color(1.0, 0.86, 0.88), 0.35)
	# --- palm (soft pillow) + back-of-hand highlight
	_mi(_hand, _sph(0.09), skin, Vector3(0, 0, 0), Vector3(0.98, 0.42, 0.94))
	_mi(_hand, _sph(0.06), shade, Vector3(0, -0.012, 0.0), Vector3(1.2, 0.3, 1.1))   # underside shade
	# --- four fingers: 3 phalanges each, slight fan + curl, knuckle spheres
	var fx := [-0.058, -0.019, 0.019, 0.056]
	var flen := [0.118, 0.135, 0.124, 0.098]
	var splay := [0.16, 0.05, -0.05, -0.17]
	for i in 4:
		var base := Vector3(fx[i], 0.004, -0.058)
		var dir := Vector3(sin(splay[i]), 0.0, -cos(splay[i]))
		var seg := [0.44, 0.31, 0.25]
		var curl := [-0.10, -0.32, -0.45]
		var p := base
		var r := 0.0215 if i < 3 else 0.0195
		var rr := r
		for s in 3:
			var dd := (Basis(Vector3.RIGHT, curl[s]) * dir).normalized()
			var q: Vector3 = p + dd * float(flen[i]) * float(seg[s])
			var r2 := rr * (0.90 if s < 2 else 0.84)
			_limb(_hand, p, q, rr, r2, skin)
			p = q
			rr = r2
		# nail on the back of the tip
		var tipdir := (Basis(Vector3.RIGHT, -0.45) * dir).normalized()
		var nl := _mi(_hand, _sph(0.0125), nail, p - tipdir * 0.006 + Vector3(0, rr * 0.86, 0), Vector3(0.95, 0.34, 1.35))
		nl.rotation.x = -0.45
		# knuckle bump on the back
		_mi(_hand, _sph(0.016), skin, base + Vector3(0, 0.014, -0.004), Vector3(1.0, 0.7, 1.0))
	# --- thumb (two phalanges, angled out and down)
	var tb := Vector3(-0.072, -0.004, 0.012)
	var t1 := tb + Vector3(-0.045, -0.006, -0.035)
	var t2 := t1 + Vector3(-0.030, -0.018, -0.040)
	_limb(_hand, tb, t1, 0.027, 0.0235, skin)
	_limb(_hand, t1, t2, 0.0235, 0.0205, skin)
	var tn := _mi(_hand, _sph(0.0105), nail, t2 + Vector3(0.002, 0.014, 0.004), Vector3(0.95, 0.32, 1.25))
	tn.rotation = Vector3(-0.5, 0.6, 0.0)
	# --- wrist + sleeve cuff rising up/toward the viewer (+Z)
	var arm_dir := Vector3(-0.5, 1.0, 0.55).normalized()
	var wrist := Vector3(0.0, 0.004, 0.085)
	wrist.x = 0.01
	var cuff_a := wrist + arm_dir * 0.035
	var cuff_b := cuff_a + arm_dir * 0.06
	_limb(_hand, wrist - arm_dir * 0.02, cuff_a, 0.046, 0.048, skin)
	_limb(_hand, cuff_a, cuff_b, 0.062, 0.062, _mat(CUFF, 0.9))
	var ring := TorusMesh.new()
	ring.inner_radius = 0.058
	ring.outer_radius = 0.07
	var rm := _mi(_hand, ring, _mat(Color(0.93, 0.45, 0.62), 0.9), cuff_b)
	rm.basis = Basis(Quaternion(Vector3.UP, arm_dir))
	var sleeve_end := cuff_b + arm_dir * 0.5
	_limb(_hand, cuff_b, sleeve_end, 0.074, 0.098, _mat(SLEEVE, 0.95))
	# polka dots on the sleeve
	var ux := arm_dir.cross(Vector3.UP).normalized()
	var uy := arm_dir.cross(ux).normalized()
	for k in 9:
		var along := 0.05 + k * 0.05
		var ang := k * 2.4
		var center := cuff_b + arm_dir * along
		var radial := (ux * cos(ang) + uy * sin(ang)).normalized()
		var rad := lerpf(0.074, 0.098, along / 0.5) * 0.985
		var p0 := center + radial * rad
		var dot := _mi(_hand, _sph(0.0125), _mat(Color(1, 0.95, 0.96), 0.9), p0)
		dot.basis = Basis.looking_at(radial, arm_dir) * Basis.from_scale(Vector3(1, 1, 0.35))

func _process(delta: float) -> void:
	if _t < 0.0 or _cat == null:
		return
	_t += delta
	if _t >= _dur:
		stop()
		return
	# head anchor in cat-local space
	var head: Vector3 = _cat.to_local(_cat.get_head_point()) - Vector3(0.0, 0.34, 0.0)   # Head bone
	var enter := clampf(_t / 0.45, 0.0, 1.0)
	var leave := clampf((_dur - _t) / 0.4, 0.0, 1.0)
	var vis := minf(enter, leave)
	var ev := vis * vis * (3.0 - 2.0 * vis)
	var stroke_t := clampf((_t - 0.35) / maxf(_dur - 0.75, 0.1), 0.0, 1.0)
	var passes := maxi(2, roundi((_dur - 0.75) / 0.85))
	var u := fposmod(stroke_t * float(passes), 1.0)
	var z := 0.0
	var lift := 0.0
	var press := 0.0
	if u < 0.74:
		var s := u / 0.74
		var e := s * s * (3.0 - 2.0 * s)
		z = lerpf(z_forehead, z_neck, e)
		press = smoothstep(0.0, 0.12, s) * smoothstep(1.0, 0.86, s)
	else:
		var r := (u - 0.74) / 0.26
		var e2 := r * r * (3.0 - 2.0 * r)
		z = lerpf(z_neck, z_forehead, e2)
		lift = sin(r * PI) * 0.045
	if stroke_t <= 0.0 or stroke_t >= 1.0:
		press *= 0.4
	var away := (1.0 - ev)
	var dz := z - 0.03
	var top := 0.47 - 1.6 * dz * dz     # dome height above the Head bone at this Z
	z *= _fwd
	# Follow the head: anchor on the midpoint between the ear bones (they ride the Head bone,
	# so the hand tracks the head's nod/tilt while the dome height stays right).
	var anchor := Vector3(0.0, head.y + 0.47, head.z)
	if _lean and _lean.get_skeleton():
		var sk := _lean.get_skeleton()
		var el := sk.find_bone("Ear_L")
		var er := sk.find_bone("Ear_R")
		if el >= 0 and er >= 0:
			var m := (sk.get_bone_global_pose(el).origin + sk.get_bone_global_pose(er).origin) * 0.5
			anchor = _cat.global_transform.affine_inverse() * (sk.global_transform * m)
	var local := Vector3(sway_x(press), (top - 0.47) + 0.045 + lift - 0.016 * press, z)
	var pos := Vector3(anchor.x, anchor.y, head.z) + local + Vector3(0.0, 0.42, -0.34 * _fwd) * away
	var eul := Basis.from_euler(Vector3(-0.05 - 0.10 * press + 0.12 * away, PI if _fwd > 0.0 else 0.0, 0.05 * sin(_t * 5.0) * press))
	_rig.transform = Transform3D(eul * Basis.from_scale(Vector3.ONE * hand_scale), pos)
	_hand.scale = Vector3(1.0 + 0.03 * press, 1.0 - 0.10 * press, 1.0)
	_lean_v = lerpf(_lean_v, press * ev, clampf(delta * 10.0, 0.0, 1.0))
	if _lean:
		_lean.amount = _lean_v

func sway_x(press: float) -> float:
	return 0.035 * sin(_t * 7.0) * press    # little rubbing wiggle so the stroke reads from the front
