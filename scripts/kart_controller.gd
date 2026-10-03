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
var race_locked: bool = false
var jump_height: float = 0.0
var jump_velocity: float = 0.0
var jump_cooldown: float = 0.0
var boost_pad_cooldown: float = 0.0
var ride_height: float = 0.0
var active_shortcut_id: String = ""
var shortcut_entry_valid: bool = false
var shortcut_fail_cooldown: float = 0.0
var stuck_timer: float = 0.0
var stuck_cooldown: float = 0.0
var last_motion_position: Vector3 = Vector3.ZERO
var safe_track_index: int = 0
var safe_index_timer: float = 0.0

# Skill-based arcade handling state.
var drift_time: float = 0.0
var drift_direction: float = 0.0
var drift_slip_angle: float = 0.0
var corner_slip_angle: float = 0.0
var drift_chain_timer: float = 0.0
var collision_recovery_timer: float = 0.0
var landing_impact_timer: float = 0.0
var was_airborne_last_frame: bool = false

# Fast, readable arcade handling.
const ARCADE_GRIP_MULT: float = 1.74
const ARCADE_DRIFT_GRIP_MULT: float = 0.36
const STEER_RESPONSE_LOW: float = 13.0
const STEER_RESPONSE_HIGH: float = 8.6
const DRIFT_STEER_RESPONSE: float = 12.5
const DRIFT_RECOVERY_RESPONSE: float = 18.0
const THROTTLE_RESPONSE: float = 12.5
const COLLISION_SPEED_KEEP_WALL: float = 0.58
const COLLISION_SPEED_KEEP_KART: float = 0.84
const DRIFT_MIN_SPEED: float = 8.5
const DRIFT_LONG_TIME: float = 0.72
const DRIFT_MAX_SLIP_DEG: float = 24.0
const DRIFT_SHORT_SLIP_DEG: float = 11.0
const CORNER_SLIP_MAX_DEG: float = 7.5
const CORNER_SLIP_RESPONSE: float = 7.5
const CORNER_SLIP_RECOVERY: float = 12.0

var gold_boost_root: Node3D
var speed_fx_root: Node3D
var speed_streaks: Array[MeshInstance3D] = []
var gold_dragon_fx_root: Node3D
var gold_dragon_segments: Array[MeshInstance3D] = []
var gold_dragon_mane: Array[MeshInstance3D] = []
var gold_dragon_head_root: Node3D
var gold_dragon_scale_nodes: Array[MeshInstance3D] = []
var gold_dragon_spark_nodes: Array[MeshInstance3D] = []
var gold_dragon_claw_nodes: Array[MeshInstance3D] = []
var gold_trail_history: Array[Vector3] = []
var gold_trail_sample_timer: float = 0.0
var gold_boost_linger: float = 0.0
var gold_boost_activation: float = 0.0
var gold_boost_was_active: bool = false
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
    reset_physics_interpolation()
    ride_height = track.track_height_at(posmod(spawn_index,track.sample_points.size()))
    safe_track_index = posmod(spawn_index,track.sample_points.size())
    last_motion_position = global_position
    remote_position = global_position
    remote_yaw = rotation.y
    started_at = Time.get_ticks_msec()
func set_race_locked(value: bool) -> void:
    race_locked = value
    if value:
        forward_speed = 0.0
        velocity = Vector3.ZERO
        throttle_state = 0.0

func mark_race_started() -> void:
    started_at = Time.get_ticks_msec()

func apply_start_boost(power: float = 1.0) -> void:
    var p: float = clamp(power,0.5,1.4)
    var base_speed: float = float(stats.get("max_speed",36.0))
    forward_speed = max(forward_speed,base_speed * (0.48 + 0.08 * p))
    boost_timer = max(boost_timer,1.05 + 0.35 * p)


func apply_upgrade_level(level: int) -> void:
    var lv: int = clamp(level,0,10)
    stats["max_speed"] = float(stats.get("max_speed",36.0)) + lv*0.35
    stats["acceleration"] = float(stats.get("acceleration",19.0)) + lv*0.35
    stats["drift_charge_rate"] = float(stats.get("drift_charge_rate",50.0)) + lv*1.2
    stats["boost_speed"] = float(stats.get("boost_speed",44.0)) + lv*0.45
    stats["boost_duration"] = float(stats.get("boost_duration",1.4)) + lv*0.015
    stats["steer_rate"] = float(stats.get("steer_rate",1.6)) + lv*0.015

func apply_equipment(equipment_id: String) -> void:
    match equipment_id:
        "comfort_tire":
            stats["steer_rate"] = float(stats.get("steer_rate",1.6)) + 0.03
        "turbo_chip":
            stats["boost_speed"] = float(stats.get("boost_speed",44.0)) + 1.5
        "drift_ring":
            stats["drift_charge_rate"] = float(stats.get("drift_charge_rate",50.0)) + 4.0
        "engine_core":
            stats["acceleration"] = float(stats.get("acceleration",19.0)) + 1.5
        "gold_wing":
            stats["max_speed"] = float(stats.get("max_speed",36.0)) + 1.0
            stats["boost_speed"] = float(stats.get("boost_speed",44.0)) + 1.0

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
    if kart_id == "gold":
        shape.size = Vector3(1.82,0.68,3.08)
        collider.position.y = 0.34
    else:
        # Slightly smaller kart footprint to match the wider arcade track scale.
        shape.size = Vector3(1.58,0.72,2.38)
        collider.position.y = 0.36
    collider.shape = shape
    add_child(collider)

    var root: Node3D = Node3D.new()
    root.scale = Vector3(0.86,0.86,0.86)
    add_child(root)

    var c: Array = stats.get("color",[0.8,0.2,0.2])
    var body_mat: StandardMaterial3D = StandardMaterial3D.new()
    var dark: StandardMaterial3D = StandardMaterial3D.new()

    if kart_id == "gold":
        body_mat.albedo_color = Color(0.035,0.038,0.050)
        body_mat.metallic = 0.90
        body_mat.roughness = 0.12

        dark.albedo_color = Color(0.010,0.012,0.018)
        dark.metallic = 0.72
        dark.roughness = 0.16

        _build_gold_foundation(root,body_mat,dark)
        _build_gold_hypercar(root)
    else:
        body_mat.albedo_color = Color(float(c[0]),float(c[1]),float(c[2]))
        body_mat.metallic = 0.22
        body_mat.roughness = 0.34

        dark.albedo_color = Color(0.040,0.048,0.060)
        dark.metallic = 0.12
        dark.roughness = 0.42

        _build_cute_kart(root,body_mat,dark,c)

    _build_speed_fx()

    if kart_id == "gold":
        _build_gold_dragon(root)
        _build_gold_boost()
        _build_gold_dragon_flight()

func _build_cute_kart(root: Node3D, body_mat: StandardMaterial3D, dark: StandardMaterial3D, c: Array) -> void:
    var light_mat: StandardMaterial3D = StandardMaterial3D.new()
    light_mat.albedo_color = Color(0.92,0.98,1.0)
    light_mat.emission_enabled = true
    light_mat.emission = Color(0.45,0.84,1.0)
    light_mat.emission_energy_multiplier = 2.1
    light_mat.roughness = 0.16

    var cream_mat: StandardMaterial3D = StandardMaterial3D.new()
    cream_mat.albedo_color = Color(
        min(1.0,float(c[0])*0.55+0.45),
        min(1.0,float(c[1])*0.55+0.45),
        min(1.0,float(c[2])*0.55+0.45)
    )
    cream_mat.metallic = 0.08
    cream_mat.roughness = 0.42

    # Main body: short, wide and rounded like a toy kart.
    var body: MeshInstance3D = MeshInstance3D.new()
    var body_mesh: SphereMesh = SphereMesh.new()
    body_mesh.radius = 0.96
    body_mesh.height = 1.65
    body.mesh = body_mesh
    body.scale = Vector3(1.05,0.43,1.38)
    body.position = Vector3(0.0,0.46,0.06)
    body.material_override = body_mat
    root.add_child(body)

    # Puffy front bumper / nose.
    var nose: MeshInstance3D = MeshInstance3D.new()
    var nose_mesh: SphereMesh = SphereMesh.new()
    nose_mesh.radius = 0.69
    nose_mesh.height = 1.00
    nose.mesh = nose_mesh
    nose.scale = Vector3(1.08,0.34,0.78)
    nose.position = Vector3(0.0,0.46,-1.08)
    nose.material_override = cream_mat
    root.add_child(nose)

    # Bubble cockpit.
    var cockpit: MeshInstance3D = MeshInstance3D.new()
    var cockpit_mesh: SphereMesh = SphereMesh.new()
    cockpit_mesh.radius = 0.58
    cockpit_mesh.height = 0.92
    cockpit.mesh = cockpit_mesh
    cockpit.scale = Vector3(0.82,0.56,0.92)
    cockpit.position = Vector3(0.0,0.88,0.16)
    cockpit.material_override = dark
    root.add_child(cockpit)

    # Friendly round headlights.
    for side in [-1.0,1.0]:
        var lamp: MeshInstance3D = MeshInstance3D.new()
        var lamp_mesh: SphereMesh = SphereMesh.new()
        lamp_mesh.radius = 0.15
        lamp_mesh.height = 0.20
        lamp.mesh = lamp_mesh
        lamp.scale = Vector3(1.12,0.72,0.55)
        lamp.position = Vector3(float(side)*0.48,0.54,-1.55)
        lamp.material_override = light_mat
        root.add_child(lamp)

    # Rounded rear bumper instead of a rigid racing wing.
    var rear: MeshInstance3D = MeshInstance3D.new()
    var rear_mesh: SphereMesh = SphereMesh.new()
    rear_mesh.radius = 0.58
    rear_mesh.height = 0.58
    rear.mesh = rear_mesh
    rear.scale = Vector3(1.28,0.30,0.48)
    rear.position = Vector3(0.0,0.47,1.24)
    rear.material_override = cream_mat
    root.add_child(rear)

    # Chunky but slightly smaller wheels make the body feel cute and oversized.
    for x in [-0.91,0.91]:
        for z in [-0.78,0.86]:
            var wheel: MeshInstance3D = MeshInstance3D.new()
            var wheel_mesh: CylinderMesh = CylinderMesh.new()
            wheel_mesh.top_radius = 0.29
            wheel_mesh.bottom_radius = 0.29
            wheel_mesh.height = 0.26
            wheel.mesh = wheel_mesh
            wheel.rotation_degrees.z = 90
            wheel.position = Vector3(float(x),0.30,float(z))
            wheel.material_override = dark
            root.add_child(wheel)

            var hub: MeshInstance3D = MeshInstance3D.new()
            var hub_mesh: CylinderMesh = CylinderMesh.new()
            hub_mesh.top_radius = 0.12
            hub_mesh.bottom_radius = 0.12
            hub_mesh.height = 0.285
            hub.mesh = hub_mesh
            hub.rotation_degrees.z = 90
            hub.position = Vector3(float(x),0.30,float(z))
            hub.material_override = cream_mat
            root.add_child(hub)

    # Small characterful details keep each family from looking identical.
    if kart_id.contains("koala"):
        for side in [-1.0,1.0]:
            var ear: MeshInstance3D = MeshInstance3D.new()
            var ear_mesh: SphereMesh = SphereMesh.new()
            ear_mesh.radius = 0.21
            ear_mesh.height = 0.25
            ear.mesh = ear_mesh
            ear.scale = Vector3(1.0,0.82,0.58)
            ear.position = Vector3(float(side)*0.46,1.15,0.20)
            ear.material_override = cream_mat
            root.add_child(ear)

    elif kart_id.contains("yanghyunhoo"):
        for side in [-1.0,1.0]:
            var cheek: MeshInstance3D = MeshInstance3D.new()
            var cheek_mesh: SphereMesh = SphereMesh.new()
            cheek_mesh.radius = 0.18
            cheek_mesh.height = 0.24
            cheek.mesh = cheek_mesh
            cheek.scale = Vector3(1.0,0.58,0.72)
            cheek.position = Vector3(float(side)*0.68,0.48,-1.24)
            cheek.material_override = cream_mat
            root.add_child(cheek)

    elif kart_id == "phantom":
        var visor: MeshInstance3D = MeshInstance3D.new()
        var visor_mesh: BoxMesh = BoxMesh.new()
        visor_mesh.size = Vector3(0.92,0.08,0.18)
        visor.mesh = visor_mesh
        visor.position = Vector3(0.0,0.88,-0.48)
        visor.rotation_degrees.x = -8.0
        visor.material_override = light_mat
        root.add_child(visor)

func _gold_add_tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
    st.add_vertex(a)
    st.add_vertex(b)
    st.add_vertex(c)

func _gold_add_quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
    _gold_add_tri(st,a,b,c)
    _gold_add_tri(st,a,c,d)

func _gold_body_mesh() -> ArrayMesh:
    # Full-bodied GT/prototype shell: the wheelbase and cockpit are visually
    # enclosed by one continuous aerodynamic surface instead of an exposed kart frame.
    var stations: Array[Dictionary] = [
        {"z":-2.34,"w":0.12,"floor":0.16,"low":0.20,"shoulder":0.26,"deck":0.31},
        {"z":-2.08,"w":0.42,"floor":0.15,"low":0.23,"shoulder":0.34,"deck":0.40},
        {"z":-1.76,"w":0.90,"floor":0.15,"low":0.28,"shoulder":0.44,"deck":0.51},
        {"z":-1.38,"w":1.34,"floor":0.15,"low":0.32,"shoulder":0.52,"deck":0.59},
        {"z":-1.04,"w":1.46,"floor":0.15,"low":0.34,"shoulder":0.56,"deck":0.64},
        {"z":-0.58,"w":1.30,"floor":0.15,"low":0.35,"shoulder":0.59,"deck":0.69},
        {"z":-0.12,"w":1.24,"floor":0.15,"low":0.36,"shoulder":0.61,"deck":0.73},
        {"z":0.38,"w":1.29,"floor":0.15,"low":0.37,"shoulder":0.60,"deck":0.72},
        {"z":0.82,"w":1.42,"floor":0.15,"low":0.36,"shoulder":0.57,"deck":0.66},
        {"z":1.18,"w":1.48,"floor":0.16,"low":0.35,"shoulder":0.53,"deck":0.60},
        {"z":1.48,"w":1.30,"floor":0.17,"low":0.32,"shoulder":0.46,"deck":0.52},
        {"z":1.70,"w":1.05,"floor":0.18,"low":0.28,"shoulder":0.38,"deck":0.43}
    ]

    var rings: Array = []
    for d in stations:
        var z: float = float(d["z"])
        var w: float = float(d["w"])
        var floor_y: float = float(d["floor"])
        var low_y: float = float(d["low"])
        var shoulder_y: float = float(d["shoulder"])
        var deck_y: float = float(d["deck"])

        # 12-point section gives a much smoother, rounded full-body silhouette.
        var ring: Array[Vector3] = [
            Vector3(-w*0.78,floor_y,z),
            Vector3(-w*0.98,low_y,z),
            Vector3(-w,shoulder_y*0.82,z),
            Vector3(-w*0.86,shoulder_y,z),
            Vector3(-w*0.60,deck_y*0.98,z),
            Vector3(-w*0.28,deck_y*1.035,z),
            Vector3(0.0,deck_y*1.055,z),
            Vector3(w*0.28,deck_y*1.035,z),
            Vector3(w*0.60,deck_y*0.98,z),
            Vector3(w*0.86,shoulder_y,z),
            Vector3(w,shoulder_y*0.82,z),
            Vector3(w*0.98,low_y,z),
            Vector3(w*0.78,floor_y,z)
        ]
        rings.append(ring)

    var st: SurfaceTool = SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)

    for i in range(rings.size()-1):
        var a: Array = rings[i]
        var b: Array = rings[i+1]
        for j in range(a.size()-1):
            _gold_add_quad(st,a[j],b[j],b[j+1],a[j+1])

        # Close the flat underbody.
        _gold_add_quad(st,a[a.size()-1],b[b.size()-1],b[0],a[0])

    var first: Array = rings[0]
    for j in range(1,first.size()-2):
        _gold_add_tri(st,first[0],first[j+1],first[j])

    var last: Array = rings[rings.size()-1]
    for j in range(1,last.size()-2):
        _gold_add_tri(st,last[0],last[j],last[j+1])

    st.index()
    st.generate_normals()
    return st.commit()

func _gold_canopy_mesh() -> ArrayMesh:
    # Low cockpit canopy integrated into the body instead of an exposed seat.
    var stations: Array[Dictionary] = [
        {"z":-0.78,"w":0.30,"base":0.64,"top":0.70},
        {"z":-0.48,"w":0.52,"base":0.65,"top":0.83},
        {"z":-0.10,"w":0.62,"base":0.66,"top":0.95},
        {"z":0.28,"w":0.60,"base":0.65,"top":0.94},
        {"z":0.62,"w":0.48,"base":0.63,"top":0.83},
        {"z":0.84,"w":0.26,"base":0.60,"top":0.68}
    ]

    var rings: Array = []
    for d in stations:
        var z: float = float(d["z"])
        var w: float = float(d["w"])
        var base: float = float(d["base"])
        var top: float = float(d["top"])
        var ring: Array[Vector3] = [
            Vector3(-w,base,z),
            Vector3(-w*0.82,lerp(base,top,0.50),z),
            Vector3(-w*0.44,lerp(base,top,0.88),z),
            Vector3(0.0,top,z),
            Vector3(w*0.44,lerp(base,top,0.88),z),
            Vector3(w*0.82,lerp(base,top,0.50),z),
            Vector3(w,base,z)
        ]
        rings.append(ring)

    var st: SurfaceTool = SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    for i in range(rings.size()-1):
        var a: Array = rings[i]
        var b: Array = rings[i+1]
        for j in range(a.size()-1):
            _gold_add_quad(st,a[j],b[j],b[j+1],a[j+1])
        _gold_add_quad(st,a[a.size()-1],b[b.size()-1],b[0],a[0])

    st.index()
    st.generate_normals()
    return st.commit()

func _gold_fender_mesh(radius: float, length: float, side_sign: float) -> ArrayMesh:
    # Rounded upper wheel housing, not a box. The tire stays visible but the
    # mechanical frame is hidden under a proper full-body fender.
    var st: SurfaceTool = SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    var rings: Array = []
    var ring_count: int = 7
    var arch_count: int = 10

    for zi in range(ring_count):
        var tz: float = float(zi)/float(ring_count-1)
        var z: float = lerp(-length*0.5,length*0.5,tz)
        var taper: float = 1.0-abs(tz-0.5)*0.22
        var ring: Array[Vector3] = []
        for ai in range(arch_count):
            var ta: float = float(ai)/float(arch_count-1)
            var angle: float = lerp(-0.18,PI+0.18,ta)
            var x: float = cos(angle)*radius*taper
            var y: float = sin(angle)*radius*0.63 + 0.40
            ring.append(Vector3(x*side_sign,y,z))
        rings.append(ring)

    for i in range(rings.size()-1):
        var a: Array = rings[i]
        var b: Array = rings[i+1]
        for j in range(a.size()-1):
            _gold_add_quad(st,a[j],b[j],b[j+1],a[j+1])

    st.index()
    st.generate_normals()
    return st.commit()

func _gold_ribbon_mesh(points: Array[Vector3], half_width: float, normal_hint: Vector3) -> ArrayMesh:
    # Slightly raised metallic ribbon used for the large dragon relief.
    var st: SurfaceTool = SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    if points.size() < 2:
        return st.commit()

    var lefts: Array[Vector3] = []
    var rights: Array[Vector3] = []

    for i in range(points.size()):
        var prev: Vector3 = points[max(0,i-1)]
        var next: Vector3 = points[min(points.size()-1,i+1)]
        var tangent: Vector3 = (next-prev).normalized()
        var across: Vector3 = tangent.cross(normal_hint).normalized()
        if across.length_squared() < 0.001:
            across = Vector3.RIGHT
        var center: Vector3 = points[i] + normal_hint.normalized()*0.018
        lefts.append(center-across*half_width)
        rights.append(center+across*half_width)

    for i in range(points.size()-1):
        _gold_add_quad(st,lefts[i],lefts[i+1],rights[i+1],rights[i])

    st.index()
    st.generate_normals()
    return st.commit()

func _gold_wing_mesh(width: float, depth: float, thickness: float, sweep: float) -> ArrayMesh:
    # Swept aerodynamic wing panel built from vertices instead of BoxMesh.
    var hw: float = width*0.5
    var hd: float = depth*0.5
    var ht: float = thickness*0.5

    var front_left: Vector3 = Vector3(-hw,-ht,-hd)
    var front_right: Vector3 = Vector3(hw,-ht,-hd)
    var back_left: Vector3 = Vector3(-hw+sweep,-ht,hd)
    var back_right: Vector3 = Vector3(hw-sweep,-ht,hd)
    var front_left_top: Vector3 = front_left+Vector3.UP*thickness
    var front_right_top: Vector3 = front_right+Vector3.UP*thickness
    var back_left_top: Vector3 = back_left+Vector3.UP*thickness
    var back_right_top: Vector3 = back_right+Vector3.UP*thickness

    var st: SurfaceTool = SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    _gold_add_quad(st,front_left_top,front_right_top,back_right_top,back_left_top)
    _gold_add_quad(st,front_right,front_left,back_left,back_right)
    _gold_add_quad(st,front_left,front_right,front_right_top,front_left_top)
    _gold_add_quad(st,back_right,back_left,back_left_top,back_right_top)
    _gold_add_quad(st,front_left,front_left_top,back_left_top,back_left)
    _gold_add_quad(st,front_right_top,front_right,back_right,back_right_top)
    st.index()
    st.generate_normals()
    return st.commit()

func _gold_led_bar(root: Node3D, pos: Vector3, size: Vector3, rot: Vector3, mat: StandardMaterial3D) -> void:
    var led: MeshInstance3D = MeshInstance3D.new()
    var lm: BoxMesh = BoxMesh.new()
    lm.size = size
    led.mesh = lm
    led.position = pos
    led.rotation_degrees = rot
    led.material_override = mat
    root.add_child(led)

func _build_gold_foundation(root: Node3D, body_mat: StandardMaterial3D, dark: StandardMaterial3D) -> void:
    # Full-body black carbon shell. No exposed frame or oversized seat.
    body_mat.albedo_color = Color(0.007,0.010,0.016)
    body_mat.metallic = 0.94
    body_mat.roughness = 0.085

    dark.albedo_color = Color(0.002,0.004,0.008)
    dark.metallic = 0.78
    dark.roughness = 0.10

    var chassis: MeshInstance3D = MeshInstance3D.new()
    chassis.name = "GoldDragonFullBodyShell"
    chassis.mesh = _gold_body_mesh()
    chassis.material_override = body_mat
    root.add_child(chassis)

    var canopy: MeshInstance3D = MeshInstance3D.new()
    canopy.name = "IntegratedCockpitCanopy"
    canopy.mesh = _gold_canopy_mesh()
    canopy.material_override = dark
    root.add_child(canopy)

    var tire_mat: StandardMaterial3D = StandardMaterial3D.new()
    tire_mat.albedo_color = Color(0.006,0.007,0.009)
    tire_mat.metallic = 0.05
    tire_mat.roughness = 0.80

    var rim_gold: StandardMaterial3D = StandardMaterial3D.new()
    rim_gold.albedo_color = Color(0.93,0.63,0.08)
    rim_gold.metallic = 0.99
    rim_gold.roughness = 0.06
    rim_gold.emission_enabled = true
    rim_gold.emission = Color(0.62,0.20,0.008)
    rim_gold.emission_energy_multiplier = 2.1

    var rim_dark: StandardMaterial3D = StandardMaterial3D.new()
    rim_dark.albedo_color = Color(0.015,0.018,0.024)
    rim_dark.metallic = 0.92
    rim_dark.roughness = 0.11

    var wheel_data: Array[Dictionary] = [
        {"x":-1.22,"z":-1.34,"r":0.50,"w":0.38},
        {"x":1.22,"z":-1.34,"r":0.50,"w":0.38},
        {"x":-1.25,"z":1.05,"r":0.56,"w":0.44},
        {"x":1.25,"z":1.05,"r":0.56,"w":0.44}
    ]

    for wd in wheel_data:
        var x: float = float(wd["x"])
        var z: float = float(wd["z"])
        var r: float = float(wd["r"])
        var w: float = float(wd["w"])

        var tire: MeshInstance3D = MeshInstance3D.new()
        var tm: CylinderMesh = CylinderMesh.new()
        tm.top_radius = r
        tm.bottom_radius = r
        tm.height = w
        tm.radial_segments = 32
        tire.mesh = tm
        tire.rotation_degrees.z = 90.0
        tire.position = Vector3(x,0.48,z)
        tire.material_override = tire_mat
        root.add_child(tire)

        var rim: MeshInstance3D = MeshInstance3D.new()
        var rm: CylinderMesh = CylinderMesh.new()
        rm.top_radius = r*0.62
        rm.bottom_radius = r*0.62
        rm.height = w+0.022
        rm.radial_segments = 32
        rim.mesh = rm
        rim.rotation_degrees.z = 90.0
        rim.position = Vector3(x+(0.014 if x>0.0 else -0.014),0.48,z)
        rim.material_override = rim_gold
        root.add_child(rim)

        var hub: MeshInstance3D = MeshInstance3D.new()
        var hm: CylinderMesh = CylinderMesh.new()
        hm.top_radius = r*0.30
        hm.bottom_radius = r*0.30
        hm.height = w+0.032
        hm.radial_segments = 24
        hub.mesh = hm
        hub.rotation_degrees.z = 90.0
        hub.position = Vector3(x+(0.019 if x>0.0 else -0.019),0.48,z)
        hub.material_override = rim_dark
        root.add_child(hub)

        # Rounded fender shell visually integrates each wheel into the full body.
        var fender: MeshInstance3D = MeshInstance3D.new()
        fender.mesh = _gold_fender_mesh(r*1.07,w*2.05,1.0 if x>0.0 else -1.0)
        fender.position = Vector3(x*0.82,0.16,z)
        fender.material_override = body_mat
        root.add_child(fender)

func _build_gold_hypercar(root: Node3D) -> void:
    var carbon: StandardMaterial3D = StandardMaterial3D.new()
    carbon.albedo_color = Color(0.007,0.009,0.014)
    carbon.metallic = 0.96
    carbon.roughness = 0.075

    var gold: StandardMaterial3D = StandardMaterial3D.new()
    gold.albedo_color = Color(0.98,0.69,0.09)
    gold.metallic = 0.99
    gold.roughness = 0.055
    gold.emission_enabled = true
    gold.emission = Color(0.31,0.10,0.005)
    gold.emission_energy_multiplier = 1.20

    var led: StandardMaterial3D = StandardMaterial3D.new()
    led.albedo_color = Color(1.0,0.78,0.18)
    led.metallic = 0.72
    led.roughness = 0.035
    led.emission_enabled = true
    led.emission = Color(1.0,0.38,0.008)
    led.emission_energy_multiplier = 4.2

    var red_led: StandardMaterial3D = StandardMaterial3D.new()
    red_led.albedo_color = Color(1.0,0.055,0.018)
    red_led.emission_enabled = true
    red_led.emission = Color(1.0,0.012,0.003)
    red_led.emission_energy_multiplier = 4.2

    # V-shaped nose fins hug the body instead of looking like a board stuck on front.
    for side in [-1.0,1.0]:
        var s: float = float(side)

        var nose_fin: MeshInstance3D = MeshInstance3D.new()
        nose_fin.mesh = _gold_wing_mesh(0.56,1.48,0.11,0.24)
        nose_fin.position = Vector3(s*0.27,0.30,-2.08)
        nose_fin.rotation_degrees = Vector3(7.0,s*8.0,s*4.0)
        nose_fin.material_override = carbon
        root.add_child(nose_fin)

        var front_wing: MeshInstance3D = MeshInstance3D.new()
        front_wing.mesh = _gold_wing_mesh(1.15,0.68,0.085,0.22)
        front_wing.position = Vector3(s*0.78,0.18,-2.38)
        front_wing.rotation_degrees = Vector3(0.0,s*12.0,s*-3.0)
        front_wing.material_override = carbon
        root.add_child(front_wing)

        var wing_edge: MeshInstance3D = MeshInstance3D.new()
        wing_edge.mesh = _gold_wing_mesh(0.96,0.10,0.038,0.16)
        wing_edge.position = Vector3(s*0.82,0.23,-2.62)
        wing_edge.rotation_degrees = Vector3(0.0,s*12.0,0.0)
        wing_edge.material_override = led
        root.add_child(wing_edge)

        # Gold side skirt is flush with the body shell.
        var side_skirt: MeshInstance3D = MeshInstance3D.new()
        side_skirt.mesh = _gold_wing_mesh(0.18,2.10,0.055,0.02)
        side_skirt.position = Vector3(s*1.15,0.20,-0.05)
        side_skirt.material_override = gold
        root.add_child(side_skirt)

        _gold_led_bar(root,Vector3(s*1.18,0.30,-0.06),Vector3(0.035,0.045,1.88),Vector3.ZERO,led)

    # Thin supercar-like headlights.
    for side in [-1.0,1.0]:
        var s: float = float(side)
        _gold_led_bar(
            root,
            Vector3(s*0.48,0.51,-1.72),
            Vector3(0.46,0.038,0.075),
            Vector3(0.0,s*-12.0,s*4.0),
            led
        )

    # Hood spine / nose outline.
    _gold_led_bar(root,Vector3(0.0,0.54,-1.88),Vector3(0.055,0.035,0.92),Vector3(9.0,0.0,0.0),gold)

    # Wide, low racing rear wing.
    var rear_wing: MeshInstance3D = MeshInstance3D.new()
    rear_wing.mesh = _gold_wing_mesh(2.62,0.62,0.095,0.16)
    rear_wing.position = Vector3(0.0,1.20,1.45)
    rear_wing.rotation_degrees.x = -5.0
    rear_wing.material_override = carbon
    root.add_child(rear_wing)

    var rear_edge: MeshInstance3D = MeshInstance3D.new()
    rear_edge.mesh = _gold_wing_mesh(2.46,0.09,0.040,0.11)
    rear_edge.position = Vector3(0.0,1.25,1.68)
    rear_edge.material_override = gold
    root.add_child(rear_edge)

    _gold_led_bar(root,Vector3(0.0,1.27,1.70),Vector3(2.20,0.035,0.045),Vector3.ZERO,led)

    for side in [-1.0,1.0]:
        var support: MeshInstance3D = MeshInstance3D.new()
        support.mesh = _gold_wing_mesh(0.13,0.70,0.085,0.015)
        support.position = Vector3(float(side)*0.70,0.88,1.34)
        support.material_override = gold
        root.add_child(support)

    # Proper rear diffuser and twin exhausts.
    for x in [-0.68,-0.34,0.0,0.34,0.68]:
        var fin: MeshInstance3D = MeshInstance3D.new()
        fin.mesh = _gold_wing_mesh(0.075,0.66,0.20,0.018)
        fin.position = Vector3(float(x),0.18,1.54)
        fin.rotation_degrees.x = -6.0
        fin.material_override = carbon
        root.add_child(fin)

    for x in [-0.40,0.40]:
        var exhaust: MeshInstance3D = MeshInstance3D.new()
        var em: CylinderMesh = CylinderMesh.new()
        em.top_radius = 0.17
        em.bottom_radius = 0.20
        em.height = 0.18
        em.radial_segments = 24
        exhaust.mesh = em
        exhaust.position = Vector3(float(x),0.45,1.70)
        exhaust.rotation_degrees.x = 90.0
        exhaust.material_override = gold
        root.add_child(exhaust)

    # Low angular taillights.
    for side in [-1.0,1.0]:
        _gold_led_bar(root,Vector3(float(side)*0.48,0.55,1.59),Vector3(0.46,0.040,0.060),Vector3(0.0,0.0,float(side)*-6.0),red_led)

func _build_gold_dragon(root: Node3D) -> void:
    # Large dimensional Eastern-dragon relief following the hood and both body sides.
    var dragon_root: Node3D = Node3D.new()
    dragon_root.name = "GoldenDragonBodyRelief"
    root.add_child(dragon_root)

    var gold: StandardMaterial3D = StandardMaterial3D.new()
    gold.albedo_color = Color(0.99,0.73,0.12)
    gold.metallic = 0.99
    gold.roughness = 0.055
    gold.emission_enabled = true
    gold.emission = Color(0.38,0.12,0.006)
    gold.emission_energy_multiplier = 1.35

    var bright: StandardMaterial3D = StandardMaterial3D.new()
    bright.albedo_color = Color(1.0,0.90,0.38)
    bright.metallic = 0.92
    bright.roughness = 0.045
    bright.emission_enabled = true
    bright.emission = Color(1.0,0.45,0.012)
    bright.emission_energy_multiplier = 2.25

    # Hood dragon relief: broad ribbon, not a tiny sticker.
    var hood_path: Array[Vector3] = [
        Vector3(0.00,0.37,-2.20),
        Vector3(-0.16,0.44,-1.99),
        Vector3(0.22,0.51,-1.76),
        Vector3(-0.25,0.57,-1.51),
        Vector3(0.27,0.62,-1.26),
        Vector3(-0.24,0.66,-1.01),
        Vector3(0.20,0.69,-0.76),
        Vector3(-0.14,0.71,-0.50),
        Vector3(0.08,0.72,-0.28)
    ]
    var hood_ribbon: MeshInstance3D = MeshInstance3D.new()
    hood_ribbon.mesh = _gold_ribbon_mesh(hood_path,0.075,Vector3.UP)
    hood_ribbon.material_override = gold
    dragon_root.add_child(hood_ribbon)

    var head: MeshInstance3D = MeshInstance3D.new()
    var hm: SphereMesh = SphereMesh.new()
    hm.radius = 0.18
    hm.height = 0.22
    head.mesh = hm
    head.scale = Vector3(1.50,0.34,1.08)
    head.position = Vector3(0.0,0.40,-2.26)
    head.material_override = bright
    dragon_root.add_child(head)

    # Hood scales.
    for row in range(5):
        for col in range(3):
            var scale: MeshInstance3D = MeshInstance3D.new()
            var sm: SphereMesh = SphereMesh.new()
            sm.radius = 0.070
            sm.height = 0.050
            scale.mesh = sm
            scale.scale = Vector3(1.25,0.18,0.72)
            scale.position = Vector3((float(col)-1.0)*0.17,0.59+float(row)*0.022,-1.46+float(row)*0.18)
            scale.material_override = bright
            dragon_root.add_child(scale)

    for side in [-1.0,1.0]:
        var s: float = float(side)

        var side_path: Array[Vector3] = [
            Vector3(s*0.82,0.49,-1.48),
            Vector3(s*1.01,0.49,-1.16),
            Vector3(s*0.92,0.50,-0.82),
            Vector3(s*1.08,0.50,-0.47),
            Vector3(s*0.96,0.51,-0.10),
            Vector3(s*1.09,0.50,0.27),
            Vector3(s*0.96,0.50,0.63),
            Vector3(s*1.05,0.49,0.96),
            Vector3(s*0.90,0.48,1.24)
        ]

        var ribbon: MeshInstance3D = MeshInstance3D.new()
        ribbon.mesh = _gold_ribbon_mesh(side_path,0.070,Vector3(s,0.0,0.0))
        ribbon.material_override = gold
        dragon_root.add_child(ribbon)

        # Raised scale plates along the side make the motif visible from gameplay camera.
        for z in [-1.20,-0.88,-0.56,-0.24,0.08,0.40,0.72,1.02]:
            var scale_mark: MeshInstance3D = MeshInstance3D.new()
            var ssm: SphereMesh = SphereMesh.new()
            ssm.radius = 0.075
            ssm.height = 0.060
            scale_mark.mesh = ssm
            scale_mark.scale = Vector3(1.42,0.20,0.70)
            scale_mark.position = Vector3(s*1.02,0.58,float(z))
            scale_mark.material_override = bright
            dragon_root.add_child(scale_mark)

        # Head horns / whiskers.
        var horn: MeshInstance3D = MeshInstance3D.new()
        var horn_mesh: CylinderMesh = CylinderMesh.new()
        horn_mesh.top_radius = 0.0
        horn_mesh.bottom_radius = 0.045
        horn_mesh.height = 0.31
        horn.mesh = horn_mesh
        horn.position = Vector3(s*0.14,0.52,-2.26)
        horn.rotation_degrees = Vector3(70.0,0.0,s*-20.0)
        horn.material_override = bright
        dragon_root.add_child(horn)

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
    # Lightweight visual-only exhaust package. No boost stats are changed.
    gold_boost_root = Node3D.new()
    gold_boost_root.name = "GoldenDragonExhaustVFX"
    gold_boost_root.visible = false
    add_child(gold_boost_root)

    var gold_mat: StandardMaterial3D = StandardMaterial3D.new()
    gold_mat.albedo_color = Color(1.0,0.70,0.08)
    gold_mat.emission_enabled = true
    gold_mat.emission = Color(1.0,0.42,0.012)
    gold_mat.emission_energy_multiplier = 5.2
    gold_mat.roughness = 0.06

    var core_mat: StandardMaterial3D = StandardMaterial3D.new()
    core_mat.albedo_color = Color(1.0,0.96,0.52)
    core_mat.emission_enabled = true
    core_mat.emission = Color(1.0,0.82,0.22)
    core_mat.emission_energy_multiplier = 6.2
    core_mat.roughness = 0.04

    for x in [-0.52,0.52]:
        var sx: float = float(x)

        var flame: MeshInstance3D = MeshInstance3D.new()
        var fm: CylinderMesh = CylinderMesh.new()
        fm.top_radius = 0.035
        fm.bottom_radius = 0.30
        fm.height = 1.70
        fm.radial_segments = 12
        flame.mesh = fm
        flame.position = Vector3(sx,0.39,1.92)
        flame.rotation_degrees.x = 90.0
        flame.material_override = gold_mat
        gold_boost_root.add_child(flame)

        var core: MeshInstance3D = MeshInstance3D.new()
        var cm: CylinderMesh = CylinderMesh.new()
        cm.top_radius = 0.020
        cm.bottom_radius = 0.13
        cm.height = 1.10
        cm.radial_segments = 10
        core.mesh = cm
        core.position = Vector3(sx,0.39,1.65)
        core.rotation_degrees.x = 90.0
        core.material_override = core_mat
        gold_boost_root.add_child(core)

        var ring: MeshInstance3D = MeshInstance3D.new()
        var rm: TorusMesh = TorusMesh.new()
        rm.inner_radius = 0.16
        rm.outer_radius = 0.23
        rm.rings = 12
        rm.ring_segments = 8
        ring.mesh = rm
        ring.position = Vector3(sx,0.39,1.34)
        ring.rotation_degrees.x = 90.0
        ring.material_override = core_mat
        gold_boost_root.add_child(ring)

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
    gold_dragon_fx_root.name = "GoldenDragonBoostVFX"
    gold_dragon_fx_root.visible = false
    add_child(gold_dragon_fx_root)

    gold_dragon_segments.clear()
    gold_dragon_mane.clear()
    gold_dragon_scale_nodes.clear()
    gold_dragon_spark_nodes.clear()
    gold_dragon_claw_nodes.clear()
    gold_trail_history.clear()

    var body_mat: StandardMaterial3D = StandardMaterial3D.new()
    body_mat.albedo_color = Color(1.0,0.65,0.04)
    body_mat.metallic = 0.75
    body_mat.roughness = 0.10
    body_mat.emission_enabled = true
    body_mat.emission = Color(1.0,0.34,0.008)
    body_mat.emission_energy_multiplier = 4.8

    var detail_mat: StandardMaterial3D = StandardMaterial3D.new()
    detail_mat.albedo_color = Color(1.0,0.86,0.22)
    detail_mat.metallic = 0.82
    detail_mat.roughness = 0.07
    detail_mat.emission_enabled = true
    detail_mat.emission = Color(1.0,0.56,0.03)
    detail_mat.emission_energy_multiplier = 5.6

    var line_mat: StandardMaterial3D = StandardMaterial3D.new()
    line_mat.albedo_color = Color(1.0,0.96,0.54)
    line_mat.emission_enabled = true
    line_mat.emission = Color(1.0,0.74,0.16)
    line_mat.emission_energy_multiplier = 6.4

    # Fewer body sections for performance. The dragon remains clearly readable.
    for i in range(16):
        var t: float = float(i)/15.0

        var seg: MeshInstance3D = MeshInstance3D.new()
        var mesh: SphereMesh = SphereMesh.new()
        var r: float = lerp(0.32,0.075,pow(t,0.82))
        mesh.radius = r
        mesh.height = r*1.85
        mesh.radial_segments = 10
        mesh.rings = 6
        seg.mesh = mesh
        seg.scale = Vector3(1.05,0.62,1.52)
        seg.material_override = body_mat
        gold_dragon_fx_root.add_child(seg)
        gold_dragon_segments.append(seg)

        if i < 12 and i % 3 == 0:
            var mane: MeshInstance3D = MeshInstance3D.new()
            var mm: CylinderMesh = CylinderMesh.new()
            mm.top_radius = 0.0
            mm.bottom_radius = 0.055+(1.0-t)*0.025
            mm.height = 0.34+(1.0-t)*0.18
            mm.radial_segments = 7
            mane.mesh = mm
            mane.material_override = line_mat
            gold_dragon_fx_root.add_child(mane)
            gold_dragon_mane.append(mane)

        if i < 12 and i % 3 == 0:
            for side in [-1.0,1.0]:
                var sc: MeshInstance3D = MeshInstance3D.new()
                var sm: SphereMesh = SphereMesh.new()
                sm.radius = lerp(0.10,0.05,t)
                sm.height = lerp(0.055,0.028,t)
                sm.radial_segments = 8
                sc.mesh = sm
                sc.scale = Vector3(1.20,0.20,0.70)
                sc.material_override = detail_mat
                gold_dragon_fx_root.add_child(sc)
                gold_dragon_scale_nodes.append(sc)

    gold_dragon_head_root = Node3D.new()
    gold_dragon_head_root.name = "GoldenDragonHead"
    gold_dragon_fx_root.add_child(gold_dragon_head_root)

    var head: MeshInstance3D = MeshInstance3D.new()
    var hm: SphereMesh = SphereMesh.new()
    hm.radius = 0.42
    hm.height = 0.60
    hm.radial_segments = 14
    head.mesh = hm
    head.scale = Vector3(1.40,0.68,1.52)
    head.material_override = body_mat
    gold_dragon_head_root.add_child(head)

    var muzzle: MeshInstance3D = MeshInstance3D.new()
    var muzzle_mesh: SphereMesh = SphereMesh.new()
    muzzle_mesh.radius = 0.22
    muzzle_mesh.height = 0.40
    muzzle_mesh.radial_segments = 10
    muzzle.mesh = muzzle_mesh
    muzzle.scale = Vector3(1.28,0.52,1.68)
    muzzle.position = Vector3(0.0,-0.06,-0.45)
    muzzle.material_override = detail_mat
    gold_dragon_head_root.add_child(muzzle)

    var jaw: MeshInstance3D = MeshInstance3D.new()
    var jaw_mesh: BoxMesh = BoxMesh.new()
    jaw_mesh.size = Vector3(0.40,0.09,0.44)
    jaw.mesh = jaw_mesh
    jaw.position = Vector3(0.0,-0.24,-0.43)
    jaw.rotation_degrees.x = -9.0
    jaw.material_override = body_mat
    gold_dragon_head_root.add_child(jaw)

    for side in [-1.0,1.0]:
        var ss: float = float(side)

        var horn: MeshInstance3D = MeshInstance3D.new()
        var horn_mesh: CylinderMesh = CylinderMesh.new()
        horn_mesh.top_radius = 0.0
        horn_mesh.bottom_radius = 0.065
        horn_mesh.height = 0.58
        horn_mesh.radial_segments = 8
        horn.mesh = horn_mesh
        horn.position = Vector3(ss*0.20,0.34,0.02)
        horn.rotation_degrees = Vector3(-60.0,ss*16.0,ss*40.0)
        horn.material_override = line_mat
        gold_dragon_head_root.add_child(horn)

        var whisker: MeshInstance3D = MeshInstance3D.new()
        var wm: BoxMesh = BoxMesh.new()
        wm.size = Vector3(0.022,0.022,1.38)
        whisker.mesh = wm
        whisker.position = Vector3(ss*0.34,-0.04,-0.62)
        whisker.rotation_degrees = Vector3(0.0,ss*22.0,ss*-12.0)
        whisker.material_override = line_mat
        gold_dragon_head_root.add_child(whisker)

        var eye: MeshInstance3D = MeshInstance3D.new()
        var em: SphereMesh = SphereMesh.new()
        em.radius = 0.055
        em.height = 0.10
        em.radial_segments = 8
        eye.mesh = em
        eye.position = Vector3(ss*0.18,0.08,-0.35)
        eye.material_override = line_mat
        gold_dragon_head_root.add_child(eye)

    # Only two claws and ten sparks: enough to sell the effect without flooding the scene.
    for i in range(2):
        var claw: MeshInstance3D = MeshInstance3D.new()
        var cm: CylinderMesh = CylinderMesh.new()
        cm.top_radius = 0.0
        cm.bottom_radius = 0.045
        cm.height = 0.32
        cm.radial_segments = 7
        claw.mesh = cm
        claw.material_override = line_mat
        gold_dragon_fx_root.add_child(claw)
        gold_dragon_claw_nodes.append(claw)

    for i in range(10):
        var spark: MeshInstance3D = MeshInstance3D.new()
        var spm: SphereMesh = SphereMesh.new()
        spm.radius = 0.024+float(i%2)*0.010
        spm.height = 0.042+float(i%2)*0.014
        spm.radial_segments = 6
        spark.mesh = spm
        spark.material_override = line_mat if i%3==0 else detail_mat
        gold_dragon_fx_root.add_child(spark)
        gold_dragon_spark_nodes.append(spark)

func _update_boost_fx(delta: float, boosting: bool) -> void:
    boost_fx_time += delta

    # No lingering afterimage. VFX exists only while boost is actually active.
    if speed_fx_root:
        speed_fx_root.visible = boosting
        if boosting:
            var stretch: float = 1.0+sin(boost_fx_time*20.0)*0.12
            speed_fx_root.scale = Vector3(1.0,1.0,stretch)
            for i in range(speed_streaks.size()):
                var streak: MeshInstance3D = speed_streaks[i]
                streak.visible = i < 6
                streak.position.z = 1.3+fmod(boost_fx_time*(9.0+float(i)*0.42)+float(i)*0.46,4.0)
                streak.scale.z = 0.88+sin(boost_fx_time*20.0+float(i))*0.18
        else:
            speed_fx_root.scale = Vector3.ONE

    if gold_boost_root:
        gold_boost_root.visible = boosting
        if boosting:
            var pulse: float = 1.0+sin(boost_fx_time*22.0)*0.10
            gold_boost_root.scale = Vector3(1.0,1.0,pulse)
        else:
            gold_boost_root.scale = Vector3.ONE

    if gold_dragon_fx_root:
        gold_dragon_fx_root.visible = boosting
        if boosting:
            # Dragon stays attached to the kart while the boost is active.
            # It does not leave a world-space trail after the kart passes.
            var head_z: float = 2.00+sin(boost_fx_time*3.0)*0.10
            var head_x: float = sin(boost_fx_time*2.8)*0.34
            var head_y: float = 1.28+sin(boost_fx_time*4.8)*0.10
            gold_dragon_head_root.position = Vector3(head_x,head_y,head_z)
            gold_dragon_head_root.rotation.y = sin(boost_fx_time*2.4)*0.20
            gold_dragon_head_root.rotation.z = sin(boost_fx_time*3.5)*0.08

            for i in range(gold_dragon_segments.size()):
                var t: float = float(i+1)/float(gold_dragon_segments.size())
                var phase: float = boost_fx_time*4.2+t*8.8
                var width: float = 0.26+t*0.68
                var seg: MeshInstance3D = gold_dragon_segments[i]
                seg.position = Vector3(
                    sin(phase)*width,
                    1.00+cos(phase*0.64)*(0.10+t*0.17),
                    head_z+0.38+t*6.1
                )
                seg.rotation.y = sin(phase*0.52)*0.20
                seg.rotation.z = sin(phase+0.6)*0.30
                var pulse: float = 1.0+sin(boost_fx_time*8.0+t*5.0)*0.08
                seg.scale = Vector3(1.05,0.62,1.52)*pulse*lerp(1.05,0.76,t)

            for i in range(gold_dragon_mane.size()):
                var body_index: int = min(i*3,gold_dragon_segments.size()-1)
                var body_seg: MeshInstance3D = gold_dragon_segments[body_index]
                var mane: MeshInstance3D = gold_dragon_mane[i]
                mane.position = body_seg.position+Vector3(0.0,0.22,0.0)
                mane.rotation_degrees = Vector3(78.0,0.0,sin(boost_fx_time*4.0+float(i))*34.0)

            for i in range(gold_dragon_scale_nodes.size()):
                var pair_index: int = i/2
                var body_index: int = min(pair_index*3,gold_dragon_segments.size()-1)
                var side: float = -1.0 if i%2==0 else 1.0
                var body_seg: MeshInstance3D = gold_dragon_segments[body_index]
                var scale_node: MeshInstance3D = gold_dragon_scale_nodes[i]
                scale_node.position = body_seg.position+Vector3(side*0.19,0.05,0.0)
                scale_node.rotation_degrees = Vector3(0.0,side*18.0,side*14.0)

            for i in range(gold_dragon_claw_nodes.size()):
                var body_index: int = min(3+i*5,gold_dragon_segments.size()-1)
                var side: float = -1.0 if i%2==0 else 1.0
                var claw: MeshInstance3D = gold_dragon_claw_nodes[i]
                var body_seg: MeshInstance3D = gold_dragon_segments[body_index]
                claw.position = body_seg.position+Vector3(side*0.34,-0.16,0.0)
                claw.rotation_degrees = Vector3(62.0,side*22.0,side*38.0)

            for i in range(gold_dragon_spark_nodes.size()):
                var spark: MeshInstance3D = gold_dragon_spark_nodes[i]
                var lane: float = float(i%5)-2.0
                var cycle: float = fmod(boost_fx_time*(4.4+float(i%3)*0.55)+float(i)*0.46,5.0)
                spark.position = Vector3(
                    lane*0.24+sin(boost_fx_time*2.8+float(i))*0.16,
                    0.45+float(i%3)*0.23,
                    1.4+cycle
                )
                spark.scale = Vector3.ONE*(0.65+sin(boost_fx_time*7.0+float(i))*0.20)
        else:
            gold_dragon_head_root.rotation = Vector3.ZERO
            gold_trail_history.clear()

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

    rotation.x = 0.0
    rotation.z = 0.0

    if race_locked:
        forward_speed = 0.0
        velocity = Vector3.ZERO
        hud_update.emit(0,lap,n2o_count,clamp(drift_charge,0.0,100.0),false)
        return

    if control_mode == "remote":
        if has_remote_state:
            global_position = global_position.lerp(remote_position,clamp(delta*12.0,0.0,1.0))
            rotation.y = lerp_angle(rotation.y,remote_yaw,clamp(delta*14.0,0.0,1.0))
            forward_speed = lerp(forward_speed,remote_speed,clamp(delta*10.0,0.0,1.0))
        return

    var input_data: Dictionary = _read_controls()
    var raw_throttle: float = float(input_data["throttle"])
    var steer_input: float = float(input_data["steer"])
    var drift_pressed: bool = bool(input_data["drift"])
    var boost_pressed: bool = bool(input_data["boost"])
    var reset_pressed: bool = bool(input_data["reset"])

    if jump_cooldown > 0.0:
        jump_cooldown = max(0.0,jump_cooldown-delta)
    if boost_pad_cooldown > 0.0:
        boost_pad_cooldown = max(0.0,boost_pad_cooldown-delta)
    if shortcut_fail_cooldown > 0.0:
        shortcut_fail_cooldown = max(0.0,shortcut_fail_cooldown-delta)
    if stuck_cooldown > 0.0:
        stuck_cooldown = max(0.0,stuck_cooldown-delta)
    if safe_index_timer > 0.0:
        safe_index_timer = max(0.0,safe_index_timer-delta)
    if drift_chain_timer > 0.0:
        drift_chain_timer = max(0.0,drift_chain_timer-delta)
    if collision_recovery_timer > 0.0:
        collision_recovery_timer = max(0.0,collision_recovery_timer-delta)
    if landing_impact_timer > 0.0:
        landing_impact_timer = max(0.0,landing_impact_timer-delta)

    # Lightweight jump / landing support for future ramps.
    var airborne: bool = jump_height > 0.01 or jump_velocity > 0.01
    if airborne:
        jump_velocity -= 24.0*delta
        jump_height += jump_velocity*delta
        if jump_height <= 0.0:
            jump_height = 0.0
            jump_velocity = 0.0
            airborne = false
            landing_impact_timer = 0.18
    if was_airborne_last_frame and not airborne:
        landing_impact_timer = max(landing_impact_timer,0.18)
    was_airborne_last_frame = airborne

    var throttle_smooth: float = 1.0-exp(-THROTTLE_RESPONSE*delta)
    throttle_state = lerp(throttle_state,raw_throttle,throttle_smooth)

    var base_max_speed: float = float(stats.get("max_speed",36.0))
    var max_speed: float = base_max_speed
    var accel: float = float(stats.get("acceleration",19.0))
    var speed_ratio: float = clamp(abs(forward_speed)/max(1.0,base_max_speed),0.0,1.25)

    var boosting: bool = boost_timer > 0.0
    if boosting:
        boost_timer = max(0.0,boost_timer-delta)
        max_speed = float(stats.get("boost_speed",44.0))
        accel += 13.0
    elif boost_pressed and n2o_count > 0:
        n2o_count -= 1
        boost_timer = float(stats.get("boost_duration",1.4))
        boosting = true
        max_speed = float(stats.get("boost_speed",44.0))
        accel += 13.0

    if collision_recovery_timer > 0.0:
        accel += 11.0
    if landing_impact_timer > 0.0:
        accel *= 0.86

    if gold_boost_root:
        gold_boost_root.visible = boosting
        if gold_boost_root.visible:
            var pulse: float = 1.0+sin(float(Time.get_ticks_msec())*0.018)*0.12
            gold_boost_root.scale = Vector3(1.0,1.0,pulse)

    _update_boost_fx(delta,boosting)

    if throttle_state > 0.03:
        forward_speed = move_toward(forward_speed,max_speed,accel*1.22*throttle_state*delta)
    elif throttle_state < -0.03:
        forward_speed = move_toward(forward_speed,-base_max_speed*0.25,32.0*abs(throttle_state)*delta)
    else:
        forward_speed = move_toward(forward_speed,0.0,6.2*delta)

    var drifting: bool = drift_pressed and abs(steer_input) > 0.08 and abs(forward_speed) > DRIFT_MIN_SPEED

    if drifting and not was_drifting:
        drift_time = 0.0
        drift_direction = sign(steer_input)
        if drift_direction == 0.0:
            drift_direction = 1.0
        if drift_chain_timer > 0.0:
            drift_charge += 6.0

    if drifting:
        drift_time += delta
        var drift_growth: float = clamp(drift_time/DRIFT_LONG_TIME,0.0,1.0)
        var same_direction: float = max(0.0,steer_input*drift_direction)
        var countersteer: float = max(0.0,-steer_input*drift_direction)

        var desired_slip_deg: float = lerp(DRIFT_SHORT_SLIP_DEG,DRIFT_MAX_SLIP_DEG,drift_growth)
        desired_slip_deg += same_direction*4.0
        desired_slip_deg -= countersteer*10.0
        desired_slip_deg = clamp(desired_slip_deg,5.0,DRIFT_MAX_SLIP_DEG+4.0)

        var desired_slip: float = deg_to_rad(desired_slip_deg)*drift_direction
        drift_slip_angle = lerp(drift_slip_angle,desired_slip,clamp(delta*(7.8+same_direction*2.0),0.0,1.0))

        var charge_mult: float = lerp(0.72,1.28,drift_growth)
        if drift_chain_timer > 0.0:
            charge_mult *= 1.10
        drift_charge += abs(steer_input)*float(stats.get("drift_charge_rate",50.0))*charge_mult*delta

        var drift_speed_cap: float = lerp(base_max_speed*0.96,base_max_speed*0.86,drift_growth)
        if abs(forward_speed) > drift_speed_cap:
            forward_speed = move_toward(forward_speed,drift_speed_cap,4.8*delta)
    elif was_drifting:
        drift_chain_timer = 0.90
        if drift_time >= DRIFT_LONG_TIME:
            forward_speed += min(1.6,base_max_speed*0.04)
        elif drift_time >= 0.22:
            forward_speed += min(0.7,base_max_speed*0.02)

        while drift_charge >= 100.0 and n2o_count < int(stats.get("max_n2o",2)):
            drift_charge -= 100.0
            n2o_count += 1

        drift_time = 0.0
        drift_direction = 0.0

    if not drifting:
        drift_slip_angle = lerp(drift_slip_angle,0.0,clamp(delta*DRIFT_RECOVERY_RESPONSE,0.0,1.0))

        # Natural arcade corner slide:
        # at low speed the kart tracks almost exactly with the nose;
        # at medium/high speed the movement direction lags slightly behind
        # the body heading, creating a smooth powerslide-like arc.
        var corner_speed_factor: float = clamp((speed_ratio-0.28)/0.72,0.0,1.0)
        var corner_input_factor: float = pow(abs(steer_input),1.15)
        var target_corner_slip: float = deg_to_rad(CORNER_SLIP_MAX_DEG)*sign(steer_input)*corner_speed_factor*corner_input_factor
        if boosting:
            target_corner_slip *= 0.72

        var corner_response: float = CORNER_SLIP_RESPONSE if abs(steer_input) > 0.04 else CORNER_SLIP_RECOVERY
        corner_slip_angle = lerp(corner_slip_angle,target_corner_slip,clamp(delta*corner_response,0.0,1.0))
    else:
        # Dedicated drift remains the larger, skill-based slide.
        corner_slip_angle = lerp(corner_slip_angle,0.0,clamp(delta*14.0,0.0,1.0))

    was_drifting = drifting

    speed_ratio = clamp(abs(forward_speed)/max(1.0,base_max_speed),0.0,1.15)
    var high_speed_soften: float = lerp(1.04,0.72,clamp(speed_ratio,0.0,1.0))
    var steer_mult: float = high_speed_soften
    if drifting:
        steer_mult *= 1.34
    elif boosting:
        steer_mult *= 0.88

    var steer_target: float = steer_input*float(stats.get("steer_rate",1.6))*1.16*steer_mult
    if airborne:
        steer_target *= 0.42

    var steer_response: float = lerp(STEER_RESPONSE_LOW,STEER_RESPONSE_HIGH,clamp(speed_ratio,0.0,1.0))
    if drifting:
        steer_response = DRIFT_STEER_RESPONSE
    elif abs(drift_slip_angle) > 0.01:
        steer_response = DRIFT_RECOVERY_RESPONSE

    var steer_smooth: float = 1.0-exp(-steer_response*delta)
    steer_state = lerp(steer_state,steer_target,steer_smooth)

    var yaw_mult: float = 1.0
    if drifting:
        var drift_growth_yaw: float = clamp(drift_time/DRIFT_LONG_TIME,0.0,1.0)
        yaw_mult = lerp(1.18,1.38,drift_growth_yaw)
    elif boosting:
        yaw_mult = 0.92

    rotate_y(-steer_state*delta*yaw_mult*(1.0 if forward_speed >= 0.0 else -0.72))

    var forward: Vector3 = -global_transform.basis.z.normalized()
    var travel_dir: Vector3 = forward
    var total_slip_angle: float = drift_slip_angle
    if not drifting:
        total_slip_angle += corner_slip_angle
    if drifting or abs(total_slip_angle) > 0.003:
        travel_dir = forward.rotated(Vector3.UP,total_slip_angle).normalized()

    var desired: Vector3 = travel_dir*forward_speed

    var base_grip: float = float(stats.get("grip",6.0))
    var grip_value: float = base_grip*(ARCADE_DRIFT_GRIP_MULT if drifting else ARCADE_GRIP_MULT)
    if boosting and not drifting:
        grip_value *= 1.08
    if airborne:
        grip_value *= 0.22
    if landing_impact_timer > 0.0:
        grip_value *= 1.12

    velocity = velocity.lerp(desired,clamp(grip_value*delta,0.0,1.0))
    velocity.y = 0.0

    var speed_before_collision: float = forward_speed
    move_and_slide()

    if get_slide_collision_count() > 0:
        var keep_ratio: float = 1.0
        var best_normal: Vector3 = Vector3.ZERO
        var wall_hit_during_drift: bool = false
        var hit_wall: bool = false

        for i in range(get_slide_collision_count()):
            var collision: KinematicCollision3D = get_slide_collision(i)
            if collision == null:
                continue

            var raw_normal: Vector3 = collision.get_normal()
            var horizontal_normal: Vector3 = raw_normal
            horizontal_normal.y = 0.0
            if horizontal_normal.length_squared() < 0.0001:
                continue
            horizontal_normal = horizontal_normal.normalized()

            var collider: Object = collision.get_collider()
            var ratio: float = COLLISION_SPEED_KEEP_WALL
            if collider is KartController:
                ratio = COLLISION_SPEED_KEEP_KART
            else:
                hit_wall = true
                if drifting and abs(raw_normal.y) < 0.55:
                    wall_hit_during_drift = true

            keep_ratio = min(keep_ratio,ratio)
            if abs(forward.dot(horizontal_normal)) > abs(forward.dot(best_normal)):
                best_normal = horizontal_normal

        if best_normal != Vector3.ZERO:
            global_position += best_normal*0.12
            var slide_dir: Vector3 = desired.slide(best_normal)
            if slide_dir.length_squared() > 0.001:
                var slide_normalized: Vector3 = slide_dir.normalized()
                velocity = slide_normalized*abs(speed_before_collision)*keep_ratio
                if abs(forward.dot(best_normal)) > 0.52:
                    var target_yaw: float = atan2(-slide_normalized.x,-slide_normalized.z)
                    rotation.y = lerp_angle(rotation.y,target_yaw,0.22)

        if abs(speed_before_collision) > 2.0:
            forward_speed = sign(speed_before_collision)*max(3.5,abs(speed_before_collision)*keep_ratio)

        if hit_wall:
            collision_recovery_timer = 0.72

        if wall_hit_during_drift:
            drift_charge = 0.0
            drift_time = 0.0
            drift_slip_angle *= 0.28
            was_drifting = false

    var info: Dictionary = track.nearest_track_info(global_position)
    var track_idx: int = int(info["index"])
    var shortcut: Dictionary = track.shortcut_info(global_position)
    var shortcut_active: bool = bool(shortcut.get("active",false))

    if not shortcut_active and float(info.get("distance",0.0)) < track.road_width*0.42 and safe_index_timer <= 0.0:
        safe_track_index = track_idx
        safe_index_timer = 0.35

    if shortcut_active:
        var sid: String = str(shortcut.get("id",""))
        if sid != active_shortcut_id:
            active_shortcut_id = sid
            shortcut_entry_valid = track.shortcut_entry_allowed(
                str(shortcut.get("requirement","")),
                drifting,
                boosting,
                abs(forward_speed)
            )

            if not shortcut_entry_valid and shortcut_fail_cooldown <= 0.0:
                shortcut_fail_cooldown = 0.8
                forward_speed *= 0.42
                var rejected: Vector3 = track.reject_shortcut_position(shortcut)
                if rejected != Vector3.ZERO:
                    global_position = rejected
                active_shortcut_id = ""
                shortcut_active = false
        elif not shortcut_entry_valid:
            shortcut_active = false
    else:
        active_shortcut_id = ""
        shortcut_entry_valid = false

    if shortcut_active and shortcut_entry_valid:
        track_idx = int(shortcut.get("track_index",track_idx))
        global_position = track.confine_to_shortcut(global_position,shortcut)
    else:
        global_position = track.confine_to_road(global_position,track_idx)

    var target_height: float = track.track_height_at(track_idx)
    if shortcut_active and shortcut_entry_valid:
        target_height = float(shortcut.get("height",target_height))

    var height_response: float = 6.3 if landing_impact_timer > 0.0 else 8.2
    ride_height = move_toward(ride_height,target_height,height_response*delta)
    global_position.y = 0.55+ride_height+jump_height

    if not shortcut_active and target_height < 0.25 and track.boost_pad_at(track_idx) and boost_pad_cooldown <= 0.0:
        boost_pad_cooldown = 1.15
        boost_timer = max(boost_timer,0.90)
        forward_speed = max(forward_speed,base_max_speed*0.72)

    var offroad: bool = float(info["distance"]) > track.road_width*0.58 and not shortcut_active
    if offroad:
        forward_speed = min(forward_speed,20.0)

    var moved_distance: float = global_position.distance_to(last_motion_position)
    var trying_to_move: bool = abs(raw_throttle) > 0.55
    var nearly_stationary: bool = abs(forward_speed) < 3.2 or moved_distance < 0.055
    var touching_geometry: bool = get_slide_collision_count() > 0 or offroad

    if trying_to_move and nearly_stationary and touching_geometry and stuck_cooldown <= 0.0:
        stuck_timer += delta
    else:
        stuck_timer = max(0.0,stuck_timer-delta*2.4)

    if stuck_timer >= 1.15:
        _recover_from_stuck(track_idx)
        stuck_timer = 0.0
        stuck_cooldown = 1.5
        info = track.nearest_track_info(global_position)
        track_idx = int(info["index"])

    last_motion_position = global_position
    _update_lap(track_idx)

    if reset_pressed:
        global_transform = track.spawn_transform_at(int(info["index"]),0.0)
        reset_physics_interpolation()
        forward_speed = 0.0
        velocity = Vector3.ZERO
        jump_height = 0.0
        jump_velocity = 0.0
        jump_cooldown = 0.6
        boost_pad_cooldown = 0.5
        active_shortcut_id = ""
        shortcut_entry_valid = false
        shortcut_fail_cooldown = 0.5
        stuck_timer = 0.0
        stuck_cooldown = 0.8
        safe_track_index = int(info["index"])
        last_motion_position = global_position
        ride_height = track.track_height_at(int(info["index"]))
        drift_time = 0.0
        drift_direction = 0.0
        drift_slip_angle = 0.0
        corner_slip_angle = 0.0
        drift_chain_timer = 0.0
        collision_recovery_timer = 0.0
        landing_impact_timer = 0.0

    hud_update.emit(int(abs(forward_speed)*3.6),lap,n2o_count,clamp(drift_charge,0.0,100.0),offroad)

func launch_kart(impulse: float = 5.8) -> void:
    if jump_cooldown > 0.0:
        return
    jump_velocity = max(jump_velocity,impulse)
    jump_height = max(jump_height,0.02)
    jump_cooldown = 0.32

func _recover_from_stuck(current_track_idx: int) -> void:
    if track == null or track.sample_points.is_empty():
        return

    var n: int = track.sample_points.size()
    var rescue_idx: int = posmod(safe_track_index,n)

    # If the saved point is implausibly far from the current progress,
    # fall back to a few samples behind the nearest track point.
    if track.circular_index_distance(rescue_idx,current_track_idx) > 28:
        rescue_idx = posmod(current_track_idx-4,n)

    global_transform = track.spawn_transform_at(rescue_idx,0.0)
    ride_height = track.track_height_at(rescue_idx)
    global_position.y = 0.55 + ride_height
    reset_physics_interpolation()

    # Keep a little momentum so recovery feels like a racing-game rescue,
    # not a full stop / teleport penalty.
    forward_speed = min(max(abs(forward_speed),5.5),10.0)
    velocity = -global_transform.basis.z.normalized() * forward_speed
    steer_state = 0.0
    throttle_state = 0.0
    drift_charge = 0.0
    was_drifting = false
    active_shortcut_id = ""
    shortcut_entry_valid = false
    shortcut_fail_cooldown = 0.6
    boost_pad_cooldown = 0.45
    drift_time = 0.0
    drift_direction = 0.0
    drift_slip_angle = 0.0
    corner_slip_angle = 0.0
    drift_chain_timer = 0.0
    collision_recovery_timer = 0.5
    last_motion_position = global_position

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
