extends CharacterBody3D
class_name KartController

signal race_finished(total_time: float)
signal hud_update(speed_kmh: int, lap: int, n2o: int, drift_percent: float, offroad: bool)

var stats: Dictionary = {}
var track: TrackBuilder
var forward_speed := 0.0
var steer_state := 0.0
var drift_charge := 0.0
var n2o_count := 0
var boost_timer := 0.0
var lap := 1
var last_index := 0
var started_at := 0
var finished := false
var was_drifting := false

func setup(id: String, track_ref: TrackBuilder) -> void:
    track = track_ref
    var f := FileAccess.open("res://assets/data/karts.json", FileAccess.READ)
    var data: Dictionary = JSON.parse_string(f.get_as_text()) if f else {}
    stats = data.get(id, data.get("rookie", {}))
    _build_kart()
    global_transform = track.spawn_transform()
    started_at = Time.get_ticks_msec()

func _build_kart() -> void:
    var collider := CollisionShape3D.new()
    var shape := BoxShape3D.new()
    shape.size = Vector3(1.8,0.8,2.7)
    collider.shape = shape
    collider.position.y = 0.4
    add_child(collider)

    var root := Node3D.new()
    add_child(root)
    var c: Array = stats.get("color",[0.8,0.2,0.2])
    var body_mat := StandardMaterial3D.new()
    body_mat.albedo_color = Color(float(c[0]),float(c[1]),float(c[2]))
    body_mat.metallic = 0.72
    body_mat.roughness = 0.22
    var dark := StandardMaterial3D.new()
    dark.albedo_color = Color(0.035,0.04,0.05)
    dark.metallic = 0.25
    dark.roughness = 0.35

    var body := MeshInstance3D.new()
    var body_mesh := BoxMesh.new()
    body_mesh.size = Vector3(1.7,0.42,2.55)
    body.mesh = body_mesh
    body.position.y = 0.34
    body.material_override = body_mat
    root.add_child(body)

    var nose := MeshInstance3D.new()
    var nose_mesh := BoxMesh.new()
    nose_mesh.size = Vector3(1.25,0.22,0.95)
    nose.mesh = nose_mesh
    nose.position = Vector3(0,0.52,-1.45)
    nose.rotation_degrees.x = 10
    nose.material_override = body_mat
    root.add_child(nose)

    var cockpit := MeshInstance3D.new()
    var cockpit_mesh := SphereMesh.new()
    cockpit_mesh.radius = 0.55
    cockpit_mesh.height = 0.82
    cockpit.mesh = cockpit_mesh
    cockpit.scale = Vector3(0.8,0.48,1.05)
    cockpit.position = Vector3(0,0.72,0.15)
    cockpit.material_override = dark
    root.add_child(cockpit)

    var wing := MeshInstance3D.new()
    var wing_mesh := BoxMesh.new()
    wing_mesh.size = Vector3(1.75,0.10,0.45)
    wing.mesh = wing_mesh
    wing.position = Vector3(0,0.78,1.35)
    wing.material_override = body_mat
    root.add_child(wing)

    for x in [-0.95,0.95]:
        for z in [-0.9,0.9]:
            var wheel := MeshInstance3D.new()
            var wheel_mesh := CylinderMesh.new()
            wheel_mesh.top_radius = 0.32
            wheel_mesh.bottom_radius = 0.32
            wheel_mesh.height = 0.28
            wheel.mesh = wheel_mesh
            wheel.rotation_degrees.z = 90
            wheel.position = Vector3(x,0.28,z)
            wheel.material_override = dark
            root.add_child(wheel)

    var cam := Camera3D.new()
    cam.position = Vector3(0,3.0,6.4)
    cam.rotation_degrees.x = -12
    cam.current = true
    add_child(cam)

func _physics_process(delta: float) -> void:
    if finished or track == null:
        return
    var throttle := Input.get_axis("brake","accelerate")
    var steer_input := Input.get_axis("steer_left","steer_right")
    var drifting := Input.is_action_pressed("drift") and abs(steer_input) > 0.05 and abs(forward_speed) > 8.0
    var max_speed := float(stats.get("max_speed",36.0))
    var accel := float(stats.get("acceleration",19.0))

    if boost_timer > 0.0:
        boost_timer -= delta
        max_speed = float(stats.get("boost_speed",44.0))
        accel += 8.0
    elif Input.is_action_just_pressed("boost") and n2o_count > 0:
        n2o_count -= 1
        boost_timer = float(stats.get("boost_duration",1.4))

    if throttle > 0:
        forward_speed = move_toward(forward_speed,max_speed,accel*delta)
    elif throttle < 0:
        forward_speed = move_toward(forward_speed,-max_speed*0.25,24.0*delta)
    else:
        forward_speed = move_toward(forward_speed,0.0,7.0*delta)

    if drifting:
        drift_charge += abs(steer_input) * float(stats.get("drift_charge_rate",50.0)) * delta
    elif was_drifting:
        while drift_charge >= 100.0 and n2o_count < int(stats.get("max_n2o",2)):
            drift_charge -= 100.0
            n2o_count += 1
    was_drifting = drifting

    var steer_target := steer_input * float(stats.get("steer_rate",1.6)) * (1.45 if drifting else 1.0)
    steer_state = move_toward(steer_state,steer_target,5.0*delta)
    rotate_y(-steer_state * delta * (1.0 if forward_speed >= 0.0 else -0.65))

    var forward := -global_transform.basis.z.normalized()
    var desired := forward * forward_speed
    velocity = velocity.lerp(desired,clamp(float(stats.get("grip",6.0))*delta,0.0,1.0))
    velocity.y = 0.0
    move_and_slide()
    global_position.y = 0.55

    var info := track.nearest_track_info(global_position)
    var offroad := float(info["distance"]) > track.road_width * 0.62
    if offroad:
        forward_speed = min(forward_speed,16.0)

    var idx := int(info["index"])
    if last_index > track.sample_points.size() * 0.8 and idx < track.sample_points.size() * 0.2 and forward_speed > 3.0:
        lap += 1
        if lap > 3:
            finished = true
            race_finished.emit(float(Time.get_ticks_msec()-started_at)/1000.0)
    last_index = idx

    if Input.is_action_just_pressed("reset_kart"):
        global_transform = track.spawn_transform()
        forward_speed = 0.0

    hud_update.emit(int(abs(forward_speed)*3.6),lap,n2o_count,clamp(drift_charge,0.0,100.0),offroad)
