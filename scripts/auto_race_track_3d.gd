@tool
extends Path3D
class_name AutoRaceTrack3D

@export_group("Road")
@export_range(2.0,40.0,0.1) var road_width: float = 12.0
@export_range(0.25,5.0,0.05) var sample_distance: float = 0.70
@export_range(-0.5,0.5,0.01) var road_y_offset: float = 0.02
@export_range(0.5,20.0,0.1) var uv_repeat_meters: float = 4.0
@export var road_material: Material
@export var use_curve_tilt: bool = true

@export_group("Guardrail")
@export var generate_guardrails: bool = true
@export_range(0.1,3.0,0.05) var guardrail_height: float = 0.95
@export_range(0.05,1.0,0.01) var guardrail_thickness: float = 0.22
@export_range(0.0,3.0,0.05) var guardrail_edge_gap: float = 0.35
@export_range(0.0,1.0,0.01) var guardrail_bottom_offset: float = 0.08
@export var guardrail_material: Material

@export_group("Collision")
@export var generate_collision: bool = true
@export_flags_3d_physics var collision_layer: int = 1

@export_group("Editor")
@export var live_rebuild: bool = true
@export_range(0.03,0.5,0.01) var editor_refresh_seconds: float = 0.08

const GENERATED_ROOT_NAME: String = "__AUTO_TRACK_GENERATED"

var _editor_timer: float = 0.0
var _last_signature: int = 0
var _rebuild_queued: bool = false

func _ready() -> void:
    if Engine.is_editor_hint():
        set_process(true)
        _last_signature = _make_signature()
        _queue_rebuild()
    else:
        set_process(false)
        rebuild_track()

func _process(delta: float) -> void:
    if not Engine.is_editor_hint() or not live_rebuild:
        return

    _editor_timer += delta
    if _editor_timer < editor_refresh_seconds:
        return
    _editor_timer = 0.0

    var signature: int = _make_signature()
    if signature != _last_signature:
        _last_signature = signature
        _queue_rebuild()

func _queue_rebuild() -> void:
    if _rebuild_queued:
        return
    _rebuild_queued = true
    call_deferred("_deferred_rebuild")

func _deferred_rebuild() -> void:
    _rebuild_queued = false
    rebuild_track()

func rebuild_track() -> void:
    var generated: Node3D = _get_or_create_generated_root()
    _clear_generated(generated)

    if curve == null or curve.point_count < 2:
        return

    var length: float = curve.get_baked_length()
    if length <= 0.01:
        return

    var frames: Array[Dictionary] = _sample_curve_frames(length)
    if frames.size() < 2:
        return

    var road_mesh: ArrayMesh = _build_road_mesh(frames,length)
    if road_mesh:
        var road: MeshInstance3D = MeshInstance3D.new()
        road.name = "Road"
        road.mesh = road_mesh
        road.material_override = road_material if road_material != null else _default_road_material()
        generated.add_child(road)

        if generate_collision:
            _add_static_trimesh_collision(generated,road_mesh,"RoadCollision")

    if generate_guardrails:
        var left_mesh: ArrayMesh = _build_guardrail_mesh(frames,length,-1.0)
        var right_mesh: ArrayMesh = _build_guardrail_mesh(frames,length,1.0)
        _add_guardrail_instance(generated,left_mesh,"GuardrailLeft")
        _add_guardrail_instance(generated,right_mesh,"GuardrailRight")

        if generate_collision:
            _add_static_trimesh_collision(generated,left_mesh,"GuardrailLeftCollision")
            _add_static_trimesh_collision(generated,right_mesh,"GuardrailRightCollision")

func _sample_curve_frames(length: float) -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    var is_closed: bool = curve.closed

    if is_closed:
        var count: int = max(3,int(ceil(length/sample_distance)))
        for i in range(count):
            var d: float = length*float(i)/float(count)
            result.append(_frame_at_distance(d))
    else:
        var count: int = max(2,int(ceil(length/sample_distance))+1)
        for i in range(count):
            var d: float = min(length,float(i)*sample_distance)
            if i == count-1:
                d = length
            result.append(_frame_at_distance(d))

    return result

func _frame_at_distance(distance: float) -> Dictionary:
    var tr: Transform3D = curve.sample_baked_with_rotation(distance,true,use_curve_tilt)
    var right: Vector3 = tr.basis.x.normalized()
    var up: Vector3 = tr.basis.y.normalized()

    if right.length_squared() < 0.001:
        right = Vector3.RIGHT
    if up.length_squared() < 0.001:
        up = Vector3.UP

    return {
        "p":tr.origin,
        "right":right,
        "up":up,
        "d":distance
    }

func _build_road_mesh(frames: Array[Dictionary], length: float) -> ArrayMesh:
    var st: SurfaceTool = SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)

    var half_width: float = road_width*0.5
    var is_closed: bool = curve.closed
    var segment_count: int = frames.size() if is_closed else frames.size()-1

    for i in range(segment_count):
        var j: int = (i+1)%frames.size()
        var f0: Dictionary = frames[i]
        var f1: Dictionary = frames[j]

        var p0: Vector3 = f0["p"]
        var p1: Vector3 = f1["p"]
        var r0: Vector3 = f0["right"]
        var r1: Vector3 = f1["right"]
        var u0: Vector3 = f0["up"]
        var u1: Vector3 = f1["up"]

        var left0: Vector3 = p0-r0*half_width+u0*road_y_offset
        var right0: Vector3 = p0+r0*half_width+u0*road_y_offset
        var left1: Vector3 = p1-r1*half_width+u1*road_y_offset
        var right1: Vector3 = p1+r1*half_width+u1*road_y_offset

        var d0: float = float(f0["d"])
        var d1: float = length if (is_closed and j == 0) else float(f1["d"])
        var v0: float = d0/max(0.01,uv_repeat_meters)
        var v1: float = d1/max(0.01,uv_repeat_meters)

        _add_vertex(st,left0,u0,Vector2(0.0,v0))
        _add_vertex(st,left1,u1,Vector2(0.0,v1))
        _add_vertex(st,right1,u1,Vector2(1.0,v1))

        _add_vertex(st,left0,u0,Vector2(0.0,v0))
        _add_vertex(st,right1,u1,Vector2(1.0,v1))
        _add_vertex(st,right0,u0,Vector2(1.0,v0))

    st.generate_tangents()
    return st.commit()

func _build_guardrail_mesh(frames: Array[Dictionary], length: float, side_sign: float) -> ArrayMesh:
    var st: SurfaceTool = SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)

    var is_closed: bool = curve.closed
    var segment_count: int = frames.size() if is_closed else frames.size()-1
    var center_offset: float = road_width*0.5+guardrail_edge_gap

    for i in range(segment_count):
        var j: int = (i+1)%frames.size()
        var f0: Dictionary = frames[i]
        var f1: Dictionary = frames[j]

        var p0: Vector3 = f0["p"]
        var p1: Vector3 = f1["p"]
        var r0: Vector3 = (f0["right"] as Vector3)*side_sign
        var r1: Vector3 = (f1["right"] as Vector3)*side_sign
        var u0: Vector3 = f0["up"]
        var u1: Vector3 = f1["up"]

        var center0: Vector3 = p0+r0*center_offset+u0*guardrail_bottom_offset
        var center1: Vector3 = p1+r1*center_offset+u1*guardrail_bottom_offset

        var inner0: Vector3 = center0-r0*(guardrail_thickness*0.5)
        var outer0: Vector3 = center0+r0*(guardrail_thickness*0.5)
        var inner1: Vector3 = center1-r1*(guardrail_thickness*0.5)
        var outer1: Vector3 = center1+r1*(guardrail_thickness*0.5)

        var inner0_top: Vector3 = inner0+u0*guardrail_height
        var outer0_top: Vector3 = outer0+u0*guardrail_height
        var inner1_top: Vector3 = inner1+u1*guardrail_height
        var outer1_top: Vector3 = outer1+u1*guardrail_height

        var d0: float = float(f0["d"])
        var d1: float = length if (is_closed and j == 0) else float(f1["d"])
        var v0: float = d0/2.0
        var v1: float = d1/2.0

        _add_quad(st,inner0,inner1,inner1_top,inner0_top,Vector2(0,v0),Vector2(0,v1),Vector2(1,v1),Vector2(1,v0))
        _add_quad(st,outer1,outer0,outer0_top,outer1_top,Vector2(0,v1),Vector2(0,v0),Vector2(1,v0),Vector2(1,v1))
        _add_quad(st,inner0_top,inner1_top,outer1_top,outer0_top,Vector2(0,v0),Vector2(0,v1),Vector2(1,v1),Vector2(1,v0))
        _add_quad(st,outer0,outer1,inner1,inner0,Vector2(0,v0),Vector2(0,v1),Vector2(1,v1),Vector2(1,v0))

    st.generate_normals()
    st.generate_tangents()
    return st.commit()

func _add_guardrail_instance(parent: Node3D, mesh: ArrayMesh, node_name: String) -> void:
    if mesh == null:
        return
    var rail: MeshInstance3D = MeshInstance3D.new()
    rail.name = node_name
    rail.mesh = mesh
    rail.material_override = guardrail_material if guardrail_material != null else _default_guardrail_material()
    parent.add_child(rail)

func _add_static_trimesh_collision(parent: Node3D, mesh: Mesh, node_name: String) -> void:
    if mesh == null:
        return
    var shape: ConcavePolygonShape3D = mesh.create_trimesh_shape()
    if shape == null:
        return

    var body: StaticBody3D = StaticBody3D.new()
    body.name = node_name
    body.collision_layer = collision_layer
    body.collision_mask = 0
    parent.add_child(body)

    var collision: CollisionShape3D = CollisionShape3D.new()
    collision.shape = shape
    body.add_child(collision)

func _add_vertex(st: SurfaceTool, position: Vector3, normal: Vector3, uv: Vector2) -> void:
    st.set_normal(normal)
    st.set_uv(uv)
    st.add_vertex(position)

func _add_quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, uv_a: Vector2, uv_b: Vector2, uv_c: Vector2, uv_d: Vector2) -> void:
    st.set_uv(uv_a)
    st.add_vertex(a)
    st.set_uv(uv_b)
    st.add_vertex(b)
    st.set_uv(uv_c)
    st.add_vertex(c)

    st.set_uv(uv_a)
    st.add_vertex(a)
    st.set_uv(uv_c)
    st.add_vertex(c)
    st.set_uv(uv_d)
    st.add_vertex(d)

func _get_or_create_generated_root() -> Node3D:
    var existing: Node3D = get_node_or_null(GENERATED_ROOT_NAME) as Node3D
    if existing != null:
        return existing

    var generated: Node3D = Node3D.new()
    generated.name = GENERATED_ROOT_NAME
    add_child(generated)
    return generated

func _clear_generated(generated: Node3D) -> void:
    for child in generated.get_children():
        generated.remove_child(child)
        child.queue_free()

func _default_road_material() -> StandardMaterial3D:
    var mat: StandardMaterial3D = StandardMaterial3D.new()
    mat.albedo_color = Color(0.055,0.060,0.070)
    mat.roughness = 0.72
    mat.metallic = 0.05
    return mat

func _default_guardrail_material() -> StandardMaterial3D:
    var mat: StandardMaterial3D = StandardMaterial3D.new()
    mat.albedo_color = Color(0.52,0.56,0.62)
    mat.roughness = 0.42
    mat.metallic = 0.68
    return mat

func _make_signature() -> int:
    if curve == null:
        return 0

    var values: Array = [
        curve.point_count,
        curve.get_baked_length(),
        curve.closed,
        curve.bake_interval,
        road_width,
        sample_distance,
        road_y_offset,
        uv_repeat_meters,
        use_curve_tilt,
        generate_guardrails,
        guardrail_height,
        guardrail_thickness,
        guardrail_edge_gap,
        guardrail_bottom_offset,
        generate_collision
    ]

    for i in range(curve.point_count):
        values.append(curve.get_point_position(i))
        values.append(curve.get_point_in(i))
        values.append(curve.get_point_out(i))
        values.append(curve.get_point_tilt(i))

    return hash(values)
