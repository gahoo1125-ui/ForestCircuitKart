extends CharacterBody3D
class_name KartController

signal race_finished(total_time: float)
signal hud_update(speed_kmh: int, lap: int, n2o: int, drift_percent: float, offroad: bool)

var stats: Dictionary = {}
var track: TrackBuilder
var kart_id: String = "rookie"
var control_mode: String = "player1"

var forward_speed: float = 0.0
var steer_state: float = 0.0
var throttle_state: float = 0.0
var drift_charge: float = 0.0
var n2o_count: int = 0
var boost_timer: float = 0.0
var lap: int = 1
var next_checkpoint: int = 0
var started_at: int = 0
var finished: bool = false
var was_drifting: bool = false

var gold_boost_root: Node3D
var speed_fx_root: Node3D
var speed_streaks: Array[MeshInstance3D] = []
var gold_dragon_fx_root: Node3D
var gold_dragon_segments: Array[MeshInstance3D] = []
var gold_dragon_head_root: Node3D
var boost_fx_time: float = 0.0
var remote_position: Vector3 = Vector3.ZERO
var remote_yaw: float = 0.0
var remote_speed: float = 0.0
var has_remote_state: bool = false

func setup(id: String, track_ref: TrackBuilder, mode: String = "player1", spawn_index: int = 0, lane_offset: float = 0.0) -> void:
    kart_id = id
    track = track_ref
    control_mode = mode

    var f: FileAccess = FileAccess.open("res://assets/data/karts.json",FileAccess.READ)
    var data: Dictionary = JSON.parse_string(f.get_as_text()) if f else {}
    stats = data.get(id,data.get("rookie",{}))

    _build_kart()
    global_transform = track.spawn_transform_at(spawn_index,lane_offset)
    remote_position = global_position
    remote_yaw = rotation.y
    started_at = Time.get_ticks_msec()

func setup_preview(id: String) -> void:
    kart_id = id
    track = null
    control_mode = "preview"

    var f: FileAccess = FileAccess.open("res://assets/data/karts.json",FileAccess.READ)
    var data: Dictionary = JSON.parse_string(f.get_as_text()) if f else {}
    stats = data.get(id,data.get("rookie",{}))

    _build_kart()
    collision_layer = 0
    collision_mask = 0
    set_physics_process(false)


func _build_kart() -> void:
    var collider: CollisionShape3D = CollisionShape3D.new()
    var shape: BoxShape3D = BoxShape3D.new()
    shape.size = Vector3(1.8,0.8,2.7)
    collider.shape = shape
    collider.position.y = 0.4
    add_child(collider)

    var root: Node3D = Node3D.new()
    add_child(root)

    var c: Array = stats.get("color",[0.8,0.2,0.2])
    var body_mat: StandardMaterial3D = StandardMaterial3D.new()
    if kart_id == "gold":
        body_mat.albedo_color = Color(0.055,0.055,0.07)
        body_mat.metallic = 0.86
        body_mat.roughness = 0.17
    else:
        body_mat.albedo_color = Color(float(c[0]),float(c[1]),float(c[2]))
        body_mat.metallic = 0.72
        body_mat.roughness = 0.22

    var dark: StandardMaterial3D = StandardMaterial3D.new()
    dark.albedo_color = Color(0.035,0.04,0.05)
    dark.metallic = 0.25
    dark.roughness = 0.35

    var body: MeshInstance3D = MeshInstance3D.new()
    var body_mesh: BoxMesh = BoxMesh.new()
    body_mesh.size = Vector3(1.7,0.42,2.55)
    body.mesh = body_mesh
    body.position.y = 0.34
    body.material_override = body_mat
    root.add_child(body)

    var nose: MeshInstance3D = MeshInstance3D.new()
    var nose_mesh: BoxMesh = BoxMesh.new()
    nose_mesh.size = Vector3(1.25,0.22,0.95)
    nose.mesh = nose_mesh
    nose.position = Vector3(0,0.52,-1.45)
    nose.rotation_degrees.x = 10
    nose.material_override = body_mat
    root.add_child(nose)

    var cockpit: MeshInstance3D = MeshInstance3D.new()
    var cockpit_mesh: SphereMesh = SphereMesh.new()
    cockpit_mesh.radius = 0.55
    cockpit_mesh.height = 0.82
    cockpit.mesh = cockpit_mesh
    cockpit.scale = Vector3(0.8,0.48,1.05)
    cockpit.position = Vector3(0,0.72,0.15)
    cockpit.material_override = dark
    root.add_child(cockpit)

    var wing: MeshInstance3D = MeshInstance3D.new()
    var wing_mesh: BoxMesh = BoxMesh.new()
    wing_mesh.size = Vector3(1.75,0.10,0.45)
    wing.mesh = wing_mesh
    wing.position = Vector3(0,0.78,1.35)
    wing.material_override = body_mat
    root.add_child(wing)

    for x in [-0.95,0.95]:
        for z in [-0.9,0.9]:
            var wheel: MeshInstance3D = MeshInstance3D.new()
            var wheel_mesh: CylinderMesh = CylinderMesh.new()
            wheel_mesh.top_radius = 0.32
            wheel_mesh.bottom_radius = 0.32
            wheel_mesh.height = 0.28
            wheel.mesh = wheel_mesh
            wheel.rotation_degrees.z = 90
            wheel.position = Vector3(float(x),0.28,float(z))
            wheel.material_override = dark
            root.add_child(wheel)

    _build_speed_fx()

    if kart_id == "gold":
        _build_gold_hypercar(root)
        _build_gold_dragon(root)
        _build_gold_boost()
        _build_gold_dragon_flight()

func _build_gold_hypercar(root: Node3D) -> void:
    var black_mat: StandardMaterial3D = StandardMaterial3D.new()
    black_mat.albedo_color = Color(0.025,0.025,0.035)
    black_mat.metallic = 0.88
    black_mat.roughness = 0.14

    var graphite_mat: StandardMaterial3D = StandardMaterial3D.new()
    graphite_mat.albedo_color = Color(0.13,0.13,0.16)
    graphite_mat.metallic = 0.78
    graphite_mat.roughness = 0.18

    var gold_mat: StandardMaterial3D = StandardMaterial3D.new()
    gold_mat.albedo_color = Color(1.0,0.73,0.08)
    gold_mat.metallic = 0.94
    gold_mat.roughness = 0.10
    gold_mat.emission_enabled = true
    gold_mat.emission = Color(0.52,0.25,0.01)
    gold_mat.emission_energy_multiplier = 1.55

    var blue_light: StandardMaterial3D = StandardMaterial3D.new()
    blue_light.albedo_color = Color(0.70,0.91,1.0)
    blue_light.emission_enabled = true
    blue_light.emission = Color(0.18,0.62,1.0)
    blue_light.emission_energy_multiplier = 4.2
    blue_light.roughness = 0.06

    # Long wedge nose and split blades.
    var center_wedge: MeshInstance3D = MeshInstance3D.new()
    var center_wedge_mesh: BoxMesh = BoxMesh.new()
    center_wedge_mesh.size = Vector3(0.78,0.16,1.62)
    center_wedge.mesh = center_wedge_mesh
    center_wedge.position = Vector3(0.0,0.43,-1.46)
    center_wedge.rotation_degrees.x = 16.0
    center_wedge.material_override = graphite_mat
    root.add_child(center_wedge)

    var gold_spine: MeshInstance3D = MeshInstance3D.new()
    var gold_spine_mesh: BoxMesh = BoxMesh.new()
    gold_spine_mesh.size = Vector3(0.11,0.035,1.58)
    gold_spine.mesh = gold_spine_mesh
    gold_spine.position = Vector3(0.0,0.54,-1.43)
    gold_spine.rotation_degrees.x = 16.0
    gold_spine.material_override = gold_mat
    root.add_child(gold_spine)

    for side in [-1.0,1.0]:
        var s: float = float(side)

        var nose_blade: MeshInstance3D = MeshInstance3D.new()
        var nose_blade_mesh: BoxMesh = BoxMesh.new()
        nose_blade_mesh.size = Vector3(0.44,0.12,1.36)
        nose_blade.mesh = nose_blade_mesh
        nose_blade.position = Vector3(s*0.64,0.33,-1.44)
        nose_blade.rotation_degrees = Vector3(8.0,s*-22.0,s*8.0)
        nose_blade.material_override = black_mat
        root.add_child(nose_blade)

        var splitter: MeshInstance3D = MeshInstance3D.new()
        var splitter_mesh: BoxMesh = BoxMesh.new()
        splitter_mesh.size = Vector3(0.52,0.055,0.86)
        splitter.mesh = splitter_mesh
        splitter.position = Vector3(s*0.86,0.20,-1.72)
        splitter.rotation_degrees = Vector3(0.0,s*-24.0,s*8.0)
        splitter.material_override = graphite_mat
        root.add_child(splitter)

        var front_gold_edge: MeshInstance3D = MeshInstance3D.new()
        var front_gold_mesh: BoxMesh = BoxMesh.new()
        front_gold_mesh.size = Vector3(0.055,0.045,1.05)
        front_gold_edge.mesh = front_gold_mesh
        front_gold_edge.position = Vector3(s*0.73,0.43,-1.44)
        front_gold_edge.rotation_degrees = Vector3(8.0,s*-20.0,s*7.0)
        front_gold_edge.material_override = gold_mat
        root.add_child(front_gold_edge)

        var shoulder: MeshInstance3D = MeshInstance3D.new()
        var shoulder_mesh: BoxMesh = BoxMesh.new()
        shoulder_mesh.size = Vector3(0.42,0.24,1.18)
        shoulder.mesh = shoulder_mesh
        shoulder.position = Vector3(s*0.79,0.50,-0.50)
        shoulder.rotation_degrees = Vector3(0.0,s*-14.0,s*8.0)
        shoulder.material_override = black_mat
        root.add_child(shoulder)

        var side_plate: MeshInstance3D = MeshInstance3D.new()
        var side_plate_mesh: BoxMesh = BoxMesh.new()
        side_plate_mesh.size = Vector3(0.16,0.28,1.70)
        side_plate.mesh = side_plate_mesh
        side_plate.position = Vector3(s*0.98,0.38,0.18)
        side_plate.rotation_degrees.z = s*8.0
        side_plate.material_override = graphite_mat
        root.add_child(side_plate)

        var side_gold: MeshInstance3D = MeshInstance3D.new()
        var side_gold_mesh: BoxMesh = BoxMesh.new()
        side_gold_mesh.size = Vector3(0.055,0.06,1.55)
        side_gold.mesh = side_gold_mesh
        side_gold.position = Vector3(s*0.99,0.51,0.12)
        side_gold.rotation_degrees.z = s*8.0
        side_gold.material_override = gold_mat
        root.add_child(side_gold)

        var headlight: MeshInstance3D = MeshInstance3D.new()
        var headlight_mesh: BoxMesh = BoxMesh.new()
        headlight_mesh.size = Vector3(0.34,0.045,0.12)
        headlight.mesh = headlight_mesh
        headlight.position = Vector3(s*0.37,0.60,-1.42)
        headlight.rotation_degrees = Vector3(0.0,s*-12.0,s*5.0)
        headlight.material_override = blue_light
        root.add_child(headlight)

        # Tall rear blades inspired by an extreme track hypercar.
        var rear_tower: MeshInstance3D = MeshInstance3D.new()
        var rear_tower_mesh: BoxMesh = BoxMesh.new()
        rear_tower_mesh.size = Vector3(0.25,0.92,0.50)
        rear_tower.mesh = rear_tower_mesh
        rear_tower.position = Vector3(s*0.57,1.00,1.18)
        rear_tower.rotation_degrees = Vector3(-8.0,s*7.0,s*12.0)
        rear_tower.material_override = black_mat
        root.add_child(rear_tower)

        var rear_fin: MeshInstance3D = MeshInstance3D.new()
        var rear_fin_mesh: BoxMesh = BoxMesh.new()
        rear_fin_mesh.size = Vector3(0.33,0.12,0.78)
        rear_fin.mesh = rear_fin_mesh
        rear_fin.position = Vector3(s*0.69,1.36,1.33)
        rear_fin.rotation_degrees = Vector3(-10.0,s*12.0,s*22.0)
        rear_fin.material_override = graphite_mat
        root.add_child(rear_fin)

        var rear_gold_edge: MeshInstance3D = MeshInstance3D.new()
        var rear_gold_mesh: BoxMesh = BoxMesh.new()
        rear_gold_mesh.size = Vector3(0.055,0.66,0.08)
        rear_gold_edge.mesh = rear_gold_mesh
        rear_gold_edge.position = Vector3(s*0.61,1.05,1.08)
        rear_gold_edge.rotation_degrees.z = s*12.0
        rear_gold_edge.material_override = gold_mat
        root.add_child(rear_gold_edge)

        # Gold wheel halo makes the wheels read like the reference without copying it.
        for z in [-0.9,0.9]:
            var halo: MeshInstance3D = MeshInstance3D.new()
            var halo_mesh: CylinderMesh = CylinderMesh.new()
            halo_mesh.top_radius = 0.40
            halo_mesh.bottom_radius = 0.40
            halo_mesh.height = 0.035
            halo.mesh = halo_mesh
            halo.position = Vector3(s*1.09,0.30,float(z))
            halo.rotation_degrees.z = 90.0
            halo.material_override = gold_mat
            root.add_child(halo)

    var rear_cross: MeshInstance3D = MeshInstance3D.new()
    var rear_cross_mesh: BoxMesh = BoxMesh.new()
    rear_cross_mesh.size = Vector3(1.72,0.12,0.34)
    rear_cross.mesh = rear_cross_mesh
    rear_cross.position = Vector3(0.0,1.02,1.48)
    rear_cross.material_override = black_mat
    root.add_child(rear_cross)

    var rear_cross_gold: MeshInstance3D = MeshInstance3D.new()
    var rear_cross_gold_mesh: BoxMesh = BoxMesh.new()
    rear_cross_gold_mesh.size = Vector3(1.48,0.055,0.09)
    rear_cross_gold.mesh = rear_cross_gold_mesh
    rear_cross_gold.position = Vector3(0.0,1.10,1.46)
    rear_cross_gold.material_override = gold_mat
    root.add_child(rear_cross_gold)

func _build_gold_dragon(root: Node3D) -> void:
    var dragon_root: Node3D = Node3D.new()
    dragon_root.name = "GoldenDragonBodyWrap"
    root.add_child(dragon_root)

    var red_mat: StandardMaterial3D = StandardMaterial3D.new()
    red_mat.albedo_color = Color(0.38,0.018,0.028)
    red_mat.metallic = 0.78
    red_mat.roughness = 0.18
    red_mat.emission_enabled = true
    red_mat.emission = Color(0.18,0.01,0.015)
    red_mat.emission_energy_multiplier = 1.4

    var gold_mat: StandardMaterial3D = StandardMaterial3D.new()
    gold_mat.albedo_color = Color(1.0,0.72,0.10)
    gold_mat.metallic = 0.92
    gold_mat.roughness = 0.13
    gold_mat.emission_enabled = true
    gold_mat.emission = Color(0.40,0.17,0.01)
    gold_mat.emission_energy_multiplier = 1.5

    var top_path: Array[Vector3] = [
        Vector3(0.00,0.585,-1.78),
        Vector3(-0.40,0.60,-1.55),
        Vector3(0.42,0.61,-1.28),
        Vector3(-0.46,0.62,-0.98),
        Vector3(0.44,0.63,-0.68),
        Vector3(-0.38,0.64,-0.36),
        Vector3(0.34,0.64,-0.05),
        Vector3(-0.32,0.62,0.30),
        Vector3(0.36,0.58,0.68),
        Vector3(-0.28,0.54,1.05),
        Vector3(0.00,0.52,1.38)
    ]
    _add_dragon_wrap_path(dragon_root,top_path,red_mat,0.13,0.040)

    for side in [-1.0,1.0]:
        var s: float = float(side)
        var side_path: Array[Vector3] = [
            Vector3(s*0.62,0.50,-1.55),
            Vector3(s*0.82,0.48,-1.15),
            Vector3(s*0.72,0.44,-0.72),
            Vector3(s*0.88,0.42,-0.28),
            Vector3(s*0.74,0.40,0.18),
            Vector3(s*0.86,0.39,0.62),
            Vector3(s*0.68,0.40,1.03)
        ]
        _add_dragon_wrap_path(dragon_root,side_path,gold_mat,0.11,0.035)

        for z in [-1.20,-0.78,-0.34,0.12,0.56,0.98]:
            var scale_mark: MeshInstance3D = MeshInstance3D.new()
            var scale_mesh: SphereMesh = SphereMesh.new()
            scale_mesh.radius = 0.085
            scale_mesh.height = 0.09
            scale_mark.mesh = scale_mesh
            scale_mark.scale = Vector3(1.3,0.28,0.8)
            scale_mark.position = Vector3(s*0.77,0.51,float(z))
            scale_mark.material_override = red_mat
            dragon_root.add_child(scale_mark)

    var head: MeshInstance3D = MeshInstance3D.new()
    var head_mesh: SphereMesh = SphereMesh.new()
    head_mesh.radius = 0.19
    head_mesh.height = 0.28
    head.mesh = head_mesh
    head.scale = Vector3(1.35,0.40,1.05)
    head.position = Vector3(0.0,0.63,-1.88)
    head.material_override = red_mat
    dragon_root.add_child(head)

    for horn_x in [-0.16,0.16]:
        var horn: MeshInstance3D = MeshInstance3D.new()
        var horn_mesh: CylinderMesh = CylinderMesh.new()
        horn_mesh.top_radius = 0.0
        horn_mesh.bottom_radius = 0.055
        horn_mesh.height = 0.31
        horn.mesh = horn_mesh
        horn.position = Vector3(float(horn_x),0.75,-1.87)
        horn.rotation_degrees = Vector3(72,0,0)
        horn.material_override = gold_mat
        dragon_root.add_child(horn)

    for side in [-1.0,1.0]:
        var wing: MeshInstance3D = MeshInstance3D.new()
        var wing_mesh: BoxMesh = BoxMesh.new()
        wing_mesh.size = Vector3(0.72,0.030,0.14)
        wing.mesh = wing_mesh
        wing.position = Vector3(float(side)*0.48,0.64,-1.12)
        wing.rotation_degrees.y = float(side)*28.0
        wing.material_override = gold_mat
        dragon_root.add_child(wing)

func _add_dragon_wrap_path(parent: Node3D, path: Array[Vector3], mat: StandardMaterial3D, width: float, height: float) -> void:
    for i in range(path.size()-1):
        var a: Vector3 = path[i]
        var b: Vector3 = path[i+1]
        var dir: Vector3 = (b-a).normalized()
        var seg: MeshInstance3D = MeshInstance3D.new()
        var mesh: BoxMesh = BoxMesh.new()
        mesh.size = Vector3(width,height,a.distance_to(b)+0.04)
        seg.mesh = mesh
        seg.position = (a+b)*0.5
        seg.basis = Basis.looking_at(dir,Vector3.UP)
        seg.material_override = mat
        parent.add_child(seg)

func _build_gold_boost() -> void:
    gold_boost_root = Node3D.new()
    gold_boost_root.visible = false
    add_child(gold_boost_root)

    var gold_mat: StandardMaterial3D = StandardMaterial3D.new()
    gold_mat.albedo_color = Color(1.0,0.64,0.05)
    gold_mat.emission_enabled = true
    gold_mat.emission = Color(1.0,0.48,0.02)

    var bright_mat: StandardMaterial3D = StandardMaterial3D.new()
    bright_mat.albedo_color = Color(1.0,0.95,0.45)
    bright_mat.emission_enabled = true
    bright_mat.emission = Color(1.0,0.88,0.28)

    for x in [-0.52,0.52]:
        var flame: MeshInstance3D = MeshInstance3D.new()
        var flame_mesh: CylinderMesh = CylinderMesh.new()
        flame_mesh.top_radius = 0.05
        flame_mesh.bottom_radius = 0.28
        flame_mesh.height = 1.55
        flame.mesh = flame_mesh
        flame.position = Vector3(float(x),0.38,1.85)
        flame.rotation_degrees.x = 90
        flame.material_override = gold_mat
        gold_boost_root.add_child(flame)

        var core: MeshInstance3D = MeshInstance3D.new()
        var core_mesh: CylinderMesh = CylinderMesh.new()
        core_mesh.top_radius = 0.03
        core_mesh.bottom_radius = 0.14
        core_mesh.height = 1.15
        core.mesh = core_mesh
        core.position = Vector3(float(x),0.38,1.62)
        core.rotation_degrees.x = 90
        core.material_override = bright_mat
        gold_boost_root.add_child(core)


func _build_speed_fx() -> void:
    speed_fx_root = Node3D.new()
    speed_fx_root.name = "BoostSpeedLines"
    speed_fx_root.visible = false
    add_child(speed_fx_root)

    var streak_mat: StandardMaterial3D = StandardMaterial3D.new()
    streak_mat.albedo_color = Color(0.82,0.93,1.0)
    streak_mat.emission_enabled = true
    streak_mat.emission = Color(0.48,0.78,1.0)
    streak_mat.emission_energy_multiplier = 2.2
    streak_mat.roughness = 0.18

    if kart_id == "gold":
        streak_mat.albedo_color = Color(1.0,0.80,0.20)
        streak_mat.emission = Color(1.0,0.52,0.05)
        streak_mat.emission_energy_multiplier = 3.0

    for i in range(10):
        var streak: MeshInstance3D = MeshInstance3D.new()
        var streak_mesh: BoxMesh = BoxMesh.new()
        streak_mesh.size = Vector3(0.045,0.045,1.0 + float(i % 4) * 0.32)
        streak.mesh = streak_mesh
        streak.material_override = streak_mat
        streak.position = Vector3(
            -1.15 + float(i % 5) * 0.58,
            0.22 + float(i / 5) * 0.72,
            1.5 + float(i) * 0.36
        )
        speed_fx_root.add_child(streak)
        speed_streaks.append(streak)

func _build_gold_dragon_flight() -> void:
    gold_dragon_fx_root = Node3D.new()
    gold_dragon_fx_root.name = "FlyingGoldenDragon"
    gold_dragon_fx_root.visible = false
    add_child(gold_dragon_fx_root)

    var dragon_mat: StandardMaterial3D = StandardMaterial3D.new()
    dragon_mat.albedo_color = Color(1.0,0.68,0.10)
    dragon_mat.metallic = 0.55
    dragon_mat.roughness = 0.20
    dragon_mat.emission_enabled = true
    dragon_mat.emission = Color(1.0,0.42,0.03)
    dragon_mat.emission_energy_multiplier = 3.2

    var bright_mat: StandardMaterial3D = StandardMaterial3D.new()
    bright_mat.albedo_color = Color(1.0,0.96,0.55)
    bright_mat.metallic = 0.40
    bright_mat.roughness = 0.16
    bright_mat.emission_enabled = true
    bright_mat.emission = Color(1.0,0.86,0.28)
    bright_mat.emission_energy_multiplier = 3.4

    for i in range(9):
        var seg: MeshInstance3D = MeshInstance3D.new()
        var seg_mesh: SphereMesh = SphereMesh.new()
        var r: float = 0.28 - float(i) * 0.014
        seg_mesh.radius = r
        seg_mesh.height = r * 2.0
        seg.mesh = seg_mesh
        seg.scale = Vector3(1.0,0.72,1.28)
        seg.material_override = dragon_mat
        gold_dragon_fx_root.add_child(seg)
        gold_dragon_segments.append(seg)

    gold_dragon_head_root = Node3D.new()
    gold_dragon_fx_root.add_child(gold_dragon_head_root)

    var head: MeshInstance3D = MeshInstance3D.new()
    var head_mesh: SphereMesh = SphereMesh.new()
    head_mesh.radius = 0.38
    head_mesh.height = 0.64
    head.mesh = head_mesh
    head.scale = Vector3(1.28,0.78,1.38)
    head.material_override = dragon_mat
    gold_dragon_head_root.add_child(head)

    var snout: MeshInstance3D = MeshInstance3D.new()
    var snout_mesh: BoxMesh = BoxMesh.new()
    snout_mesh.size = Vector3(0.34,0.20,0.48)
    snout.mesh = snout_mesh
    snout.position = Vector3(0.0,-0.03,-0.36)
    snout.material_override = bright_mat
    gold_dragon_head_root.add_child(snout)

    for side in [-1.0,1.0]:
        var horn: MeshInstance3D = MeshInstance3D.new()
        var horn_mesh: CylinderMesh = CylinderMesh.new()
        horn_mesh.top_radius = 0.0
        horn_mesh.bottom_radius = 0.07
        horn_mesh.height = 0.42
        horn.mesh = horn_mesh
        horn.position = Vector3(float(side) * 0.20,0.28,0.02)
        horn.rotation_degrees = Vector3(-55.0,0.0,float(side) * 28.0)
        horn.material_override = bright_mat
        gold_dragon_head_root.add_child(horn)

        var wing: MeshInstance3D = MeshInstance3D.new()
        var wing_mesh: BoxMesh = BoxMesh.new()
        wing_mesh.size = Vector3(0.72,0.06,0.28)
        wing.mesh = wing_mesh
        wing.position = Vector3(float(side) * 0.52,0.04,0.35)
        wing.rotation_degrees = Vector3(0.0,float(side) * 22.0,float(side) * 18.0)
        wing.material_override = bright_mat
        gold_dragon_head_root.add_child(wing)

func _update_boost_fx(delta: float, boosting: bool) -> void:
    boost_fx_time += delta

    if speed_fx_root:
        speed_fx_root.visible = boosting
        if boosting:
            var stretch: float = 1.0 + sin(boost_fx_time * 22.0) * 0.16
            speed_fx_root.scale = Vector3(1.0,1.0,stretch)
            for i in range(speed_streaks.size()):
                var streak: MeshInstance3D = speed_streaks[i]
                streak.position.z = 1.2 + fmod(boost_fx_time * (11.0 + float(i) * 0.55) + float(i) * 0.42,4.6)
                streak.scale.z = 1.0 + sin(boost_fx_time * 25.0 + float(i)) * 0.28
        else:
            speed_fx_root.scale = Vector3.ONE

    if gold_dragon_fx_root:
        gold_dragon_fx_root.visible = boosting
        if boosting:
            var head_z: float = 2.0 + sin(boost_fx_time * 4.0) * 0.14
            var head_x: float = sin(boost_fx_time * 6.0) * 0.24
            var head_y: float = 0.82 + sin(boost_fx_time * 7.0) * 0.10
            gold_dragon_head_root.position = Vector3(head_x,head_y,head_z)
            gold_dragon_head_root.rotation.y = sin(boost_fx_time * 3.2) * 0.22

            for i in range(gold_dragon_segments.size()):
                var t: float = float(i + 1) / float(gold_dragon_segments.size())
                var seg: MeshInstance3D = gold_dragon_segments[i]
                var wave_x: float = sin(boost_fx_time * 7.0 + t * 5.0) * (0.30 + t * 0.34)
                var wave_y: float = 0.72 + sin(boost_fx_time * 5.5 + t * 3.5) * 0.14
                var z: float = head_z + 0.55 + t * 4.1
                seg.position = Vector3(wave_x,wave_y,z)

func _read_controls() -> Dictionary:
    if control_mode == "cpu":
        return _cpu_controls()

    if control_mode == "player2":
        return {
            "throttle": Input.get_axis("p2_brake","p2_accelerate"),
            "steer": Input.get_axis("p2_left","p2_right"),
            "drift": Input.is_action_pressed("p2_drift"),
            "boost": Input.is_action_just_pressed("p2_boost"),
            "reset": Input.is_action_just_pressed("p2_reset")
        }

    return {
        "throttle": Input.get_axis("brake","accelerate"),
        "steer": Input.get_axis("steer_left","steer_right"),
        "drift": Input.is_action_pressed("drift"),
        "boost": Input.is_action_just_pressed("boost"),
        "reset": Input.is_action_just_pressed("reset_kart")
    }

func _cpu_controls() -> Dictionary:
    var info: Dictionary = track.nearest_track_info(global_position)
    var idx: int = int(info["index"])
    var lookahead: int = 9 + int(clamp(abs(forward_speed) * 0.18,0.0,10.0))
    var target_idx: int = (idx + lookahead) % track.sample_points.size()
    var target: Vector3 = track.sample_points[target_idx]
    var to_target: Vector3 = target - global_position
    to_target.y = 0.0
    if to_target.length() > 0.01:
        to_target = to_target.normalized()

    var forward: Vector3 = -global_transform.basis.z.normalized()
    var cross_y: float = forward.cross(to_target).y
    var steer: float = clamp(-cross_y * 4.2,-1.0,1.0)
    var drift_on: bool = abs(steer) > 0.62 and abs(forward_speed) > 13.0
    var boost_now: bool = abs(steer) < 0.18 and n2o_count > 0 and boost_timer <= 0.0

    return {"throttle":1.0,"steer":steer,"drift":drift_on,"boost":boost_now,"reset":false}

func _physics_process(delta: float) -> void:
    if finished or track == null:
        return

    if control_mode == "remote":
        if has_remote_state:
            global_position = global_position.lerp(remote_position,clamp(delta*10.0,0.0,1.0))
            rotation.y = lerp_angle(rotation.y,remote_yaw,clamp(delta*10.0,0.0,1.0))
            forward_speed = lerp(forward_speed,remote_speed,clamp(delta*8.0,0.0,1.0))
        return

    var input_data: Dictionary = _read_controls()
    var raw_throttle: float = float(input_data["throttle"])
    var steer_input: float = float(input_data["steer"])
    var drift_pressed: bool = bool(input_data["drift"])
    var boost_pressed: bool = bool(input_data["boost"])
    var reset_pressed: bool = bool(input_data["reset"])

    var smooth_t: float = 1.0 - exp(-7.5 * delta)
    throttle_state = lerp(throttle_state,raw_throttle,smooth_t)

    var drifting: bool = drift_pressed and abs(steer_input) > 0.05 and abs(forward_speed) > 8.0
    var max_speed: float = float(stats.get("max_speed",36.0))
    var accel: float = float(stats.get("acceleration",19.0))

    if boost_timer > 0.0:
        boost_timer -= delta
        max_speed = float(stats.get("boost_speed",44.0))
        accel += 8.0
    elif boost_pressed and n2o_count > 0:
        n2o_count -= 1
        boost_timer = float(stats.get("boost_duration",1.4))

    if gold_boost_root:
        gold_boost_root.visible = boost_timer > 0.0
        if gold_boost_root.visible:
            var pulse: float = 1.0 + sin(float(Time.get_ticks_msec()) * 0.018) * 0.12
            gold_boost_root.scale = Vector3(1.0,1.0,pulse)

    _update_boost_fx(delta,boost_timer > 0.0)

    if throttle_state > 0.03:
        forward_speed = move_toward(forward_speed,max_speed,accel*throttle_state*delta)
    elif throttle_state < -0.03:
        forward_speed = move_toward(forward_speed,-max_speed*0.25,24.0*abs(throttle_state)*delta)
    else:
        forward_speed = move_toward(forward_speed,0.0,6.5*delta)

    if drifting:
        drift_charge += abs(steer_input) * float(stats.get("drift_charge_rate",50.0)) * delta
    elif was_drifting:
        while drift_charge >= 100.0 and n2o_count < int(stats.get("max_n2o",2)):
            drift_charge -= 100.0
            n2o_count += 1
    was_drifting = drifting

    var speed_ratio: float = clamp(abs(forward_speed) / max(1.0,max_speed),0.0,1.0)
    var steer_softener: float = lerp(1.0,0.68,speed_ratio)
    var steer_target: float = steer_input * float(stats.get("steer_rate",1.6)) * steer_softener * (1.35 if drifting else 1.0)
    var steer_smooth: float = 1.0 - exp(-9.0 * delta)
    steer_state = lerp(steer_state,steer_target,steer_smooth)

    rotate_y(-steer_state * delta * (1.0 if forward_speed >= 0.0 else -0.65))

    var forward: Vector3 = -global_transform.basis.z.normalized()
    var desired: Vector3 = forward * forward_speed
    var grip_value: float = float(stats.get("grip",6.0)) * (0.72 if drifting else 1.0)
    velocity = velocity.lerp(desired,clamp(grip_value*delta,0.0,1.0))
    velocity.y = 0.0
    move_and_slide()
    global_position.y = 0.55

    var info: Dictionary = track.nearest_track_info(global_position)
    var offroad: bool = float(info["distance"]) > track.road_width * 0.58
    if offroad:
        forward_speed = min(forward_speed,18.0)

    _update_lap(int(info["index"]))

    if reset_pressed:
        global_transform = track.spawn_transform_at(int(info["index"]),0.0)
        forward_speed = 0.0
        velocity = Vector3.ZERO

    hud_update.emit(int(abs(forward_speed)*3.6),lap,n2o_count,clamp(drift_charge,0.0,100.0),offroad)

func _update_lap(idx: int) -> void:
    if track.checkpoint_indices.is_empty():
        return

    var target_idx: int = track.checkpoint_indices[next_checkpoint]
    if track.circular_index_distance(idx,target_idx) <= 3:
        next_checkpoint += 1
        if next_checkpoint >= track.checkpoint_indices.size():
            next_checkpoint = 0
            lap += 1
            if lap > 3:
                finished = true
                race_finished.emit(float(Time.get_ticks_msec()-started_at)/1000.0)

func set_remote_state(pos: Vector3, yaw: float, speed_value: float, lap_value: int) -> void:
    remote_position = pos
    remote_yaw = yaw
    remote_speed = speed_value
    lap = lap_value
    has_remote_state = true
