# scripts/cat_props.gd
## Procedural 3D props for the feed / play interactions (no external assets).
## Every builder returns a Node3D standing on y = 0 with a child named "Content"
## (food: the part that shrinks while the cat eats).
class_name CatProps
extends RefCounted

const FOODS := {
	"fish": {"name": "小鱼干", "hunger": 26.0, "mood": 6.0},
	"kibble": {"name": "猫粮", "hunger": 30.0, "mood": 3.0},
	"can": {"name": "罐头", "hunger": 22.0, "mood": 8.0},
	"milk": {"name": "牛奶", "hunger": 12.0, "mood": 7.0},
}
const FOOD_ORDER := ["fish", "kibble", "can", "milk"]

const TOYS := {
	"wand": {"name": "逗猫棒", "mood": 10.0, "bond": 5.0, "hunger": 5.0},
	"yarn": {"name": "毛线球", "mood": 8.0, "bond": 5.0, "hunger": 5.0},
	"laser": {"name": "激光点", "mood": 12.0, "bond": 4.0, "hunger": 7.0},
	"mouse": {"name": "小老鼠", "mood": 9.0, "bond": 6.0, "hunger": 6.0},
}
const TOY_ORDER := ["wand", "yarn", "laser", "mouse"]

static func _mat(c: Color, rough := 0.8, emit := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	# The room is strongly exposed / bloomed: dim albedo so props keep their colour.
	m.albedo_color = c if emit > 0.0 else Color(c.r * 0.62, c.g * 0.62, c.b * 0.62, c.a)
	m.roughness = rough
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = emit
	return m

static func _mi(parent: Node, mesh: Mesh, mat: Material, pos := Vector3.ZERO, scl := Vector3.ONE, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.scale = scl
	mi.rotation = rot
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi

static func _sphere(r: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 16
	s.rings = 8
	return s

static func _cyl(rt: float, rb: float, h: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = rt
	c.bottom_radius = rb
	c.height = h
	c.radial_segments = 20
	return c

# ---------------------------------------------------------------- foods

static func make_food(id: String) -> Node3D:
	var root := Node3D.new()
	root.name = "Food_" + id
	var content := Node3D.new()
	content.name = "Content"
	match id:
		"fish":
			_mi(root, _cyl(0.24, 0.2, 0.035), _mat(Color(0.98, 0.9, 0.82)), Vector3(0, 0.0175, 0))
			root.add_child(content)
			for i in 2:
				var f := Node3D.new()
				f.position = Vector3(0.02, 0.06 + 0.035 * i, -0.06 + 0.12 * i)
				f.rotation.y = 0.25 - 0.5 * i
				content.add_child(f)
				var fm := _mat(Color(0.5, 0.76, 1.0), 0.45)
				var belly := _mat(Color(0.95, 0.97, 1.0), 0.5)
				_mi(f, _sphere(0.1), fm, Vector3.ZERO, Vector3(1.25, 0.5, 0.55))
				_mi(f, _sphere(0.08), belly, Vector3(0.0, -0.025, 0.0), Vector3(1.1, 0.35, 0.5))
				_mi(f, _sphere(0.06), fm, Vector3(-0.15, 0.025, 0.0), Vector3(0.8, 0.2, 0.7), Vector3(0, 0, 0.7))
				_mi(f, _sphere(0.06), fm, Vector3(-0.15, -0.025, 0.0), Vector3(0.8, 0.2, 0.7), Vector3(0, 0, -0.7))
				_mi(f, _sphere(0.04), fm, Vector3(0.0, 0.05, 0.0), Vector3(0.9, 0.5, 0.2), Vector3(0, 0, 0.2))
				_mi(f, _sphere(0.016), _mat(Color(1, 1, 1)), Vector3(0.1, 0.022, 0.05))
				_mi(f, _sphere(0.016), _mat(Color(1, 1, 1)), Vector3(0.1, 0.022, -0.05))
				_mi(f, _sphere(0.009), _mat(Color(0.05, 0.05, 0.08)), Vector3(0.112, 0.022, 0.052))
				_mi(f, _sphere(0.009), _mat(Color(0.05, 0.05, 0.08)), Vector3(0.112, 0.022, -0.052))
		"kibble":
			_mi(root, _cyl(0.2, 0.14, 0.11), _mat(Color(0.95, 0.62, 0.7)), Vector3(0, 0.055, 0))
			root.add_child(content)
			var rng := RandomNumberGenerator.new()
			rng.seed = 7
			for i in 18:
				var a := rng.randf() * TAU
				var d := sqrt(rng.randf()) * 0.15
				_mi(content, _sphere(0.028), _mat(Color(0.6, 0.38, 0.2)), Vector3(cos(a) * d, 0.115 + rng.randf() * 0.025, sin(a) * d), Vector3(1.2, 0.8, 1.0), Vector3(0, a, 0))
		"can":
			_mi(root, _cyl(0.19, 0.16, 0.03), _mat(Color(0.98, 0.9, 0.82)), Vector3(0, 0.015, 0))
			root.add_child(content)
			_mi(content, _sphere(0.13), _mat(Color(0.72, 0.5, 0.36), 0.55), Vector3(0, 0.03, 0), Vector3(1.0, 0.5, 1.0))
			var can := Node3D.new()
			can.position = Vector3(0.0, 0.0, -0.22)
			can.rotation.z = 0.25
			root.add_child(can)
			_mi(can, _cyl(0.07, 0.07, 0.13), _mat(Color(0.82, 0.84, 0.88), 0.35), Vector3(0, 0.065, 0))
			_mi(can, _cyl(0.0715, 0.0715, 0.06), _mat(Color(0.95, 0.5, 0.58)), Vector3(0, 0.065, 0))
		"milk":
			_mi(root, _cyl(0.2, 0.15, 0.045), _mat(Color(0.88, 0.9, 0.98)), Vector3(0, 0.0225, 0))
			root.add_child(content)
			_mi(content, _cyl(0.16, 0.16, 0.03), _mat(Color(1.0, 0.99, 0.97), 0.3, 0.25), Vector3(0, 0.05, 0))
		_:
			root.add_child(content)
	return root

# ---------------------------------------------------------------- toys

static func make_toy(id: String) -> Node3D:
	var root := Node3D.new()
	root.name = "Toy_" + id
	match id:
		"wand":
			# Rod comes in from the camera side; "Tip" is the feather end (animated by the cat).
			var rod := Node3D.new()
			rod.name = "Rod"
			root.add_child(rod)
			_mi(rod, _cyl(0.012, 0.016, 1.6), _mat(Color(0.82, 0.62, 0.4)), Vector3(0, 0, 0.8), Vector3.ONE, Vector3(PI / 2.0, 0, 0))
			var tip := Node3D.new()
			tip.name = "Tip"
			root.add_child(tip)
			_mi(tip, _cyl(0.004, 0.004, 0.25), _mat(Color(0.95, 0.9, 0.85)), Vector3(0, -0.125, 0))
			var fp := _mat(Color(1.0, 0.62, 0.74), 0.9)
			var fw := _mat(Color(1.0, 0.97, 0.94), 0.9)
			_mi(tip, _sphere(0.06), fp, Vector3(0, -0.27, 0), Vector3(0.7, 1.9, 0.35))
			_mi(tip, _sphere(0.05), fw, Vector3(0.05, -0.3, 0.0), Vector3(0.55, 1.7, 0.3), Vector3(0, 0, 0.35))
			_mi(tip, _sphere(0.05), fw, Vector3(-0.05, -0.3, 0.0), Vector3(0.55, 1.7, 0.3), Vector3(0, 0, -0.35))
			_mi(tip, _sphere(0.02), _mat(Color(0.98, 0.84, 0.3), 0.4), Vector3(0, -0.24, 0.0))
		"yarn":
			var ball := Node3D.new()
			ball.name = "Spin"
			ball.position = Vector3(0, 0.15, 0)
			ball.scale = Vector3.ONE * 1.35
			root.add_child(ball)
			_mi(ball, _sphere(0.11), _mat(Color(0.74, 0.62, 0.96), 0.95))
			for i in 3:
				var t := TorusMesh.new()
				t.inner_radius = 0.1
				t.outer_radius = 0.118
				_mi(ball, t, _mat(Color(0.97, 0.62, 0.82), 0.95), Vector3.ZERO, Vector3.ONE, Vector3(i * 1.0, i * 0.7, i * 0.4))
		"mouse":
			var m := Node3D.new()
			m.name = "Spin"
			m.scale = Vector3.ONE * 1.4
			root.add_child(m)
			var gm := _mat(Color(0.7, 0.68, 0.74), 0.85)
			_mi(m, _sphere(0.1), gm, Vector3(0, 0.07, 0), Vector3(1.0, 0.75, 0.7))
			_mi(m, _sphere(0.04), gm, Vector3(0.11, 0.06, 0), Vector3(1.1, 0.8, 0.8))
			_mi(m, _sphere(0.035), _mat(Color(1.0, 0.6, 0.7)), Vector3(0.15, 0.065, 0))
			_mi(m, _sphere(0.035), _mat(Color(1.0, 0.7, 0.78)), Vector3(0.07, 0.13, 0.055), Vector3(0.5, 1.0, 1.0))
			_mi(m, _sphere(0.035), _mat(Color(1.0, 0.7, 0.78)), Vector3(0.07, 0.13, -0.055), Vector3(0.5, 1.0, 1.0))
			_mi(m, _sphere(0.012), _mat(Color(0.1, 0.08, 0.1)), Vector3(0.135, 0.09, 0.03))
			_mi(m, _sphere(0.012), _mat(Color(0.1, 0.08, 0.1)), Vector3(0.135, 0.09, -0.03))
			_mi(m, _cyl(0.008, 0.012, 0.2), _mat(Color(1.0, 0.7, 0.78)), Vector3(-0.2, 0.04, 0), Vector3.ONE, Vector3(0, 0, PI / 2.0 - 0.3))
		"laser":
			var dot := _mi(root, _sphere(0.075), _mat(Color(0.95, 0.04, 0.1), 0.4, 1.3), Vector3(0, 0.012, 0), Vector3(1.0, 0.35, 1.0))
			dot.name = "Dot"
			_mi(root, _cyl(0.12, 0.12, 0.004), _mat(Color(0.9, 0.1, 0.18), 0.6, 0.6), Vector3(0, 0.003, 0))
			var l := OmniLight3D.new()
			l.light_color = Color(1.0, 0.25, 0.3)
			l.light_energy = 0.7
			l.omni_range = 0.7
			l.position = Vector3(0, 0.1, 0)
			root.add_child(l)
	return root
