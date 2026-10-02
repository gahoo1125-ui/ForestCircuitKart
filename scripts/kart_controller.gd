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

    if kart_id == "gold":
        _build_gold_boost()

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
