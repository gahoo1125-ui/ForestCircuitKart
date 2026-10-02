extends Node3D
class_name TrackBuilder

var road_width: float = 11.0
var radius_x: float = 72.0
var radius_z: float = 48.0
var sample_points: Array[Vector3] = []
var sample_tangents: Array[Vector3] = []

func setup() -> void:
    _sample_track()
    _build_ground()
    _build_track()
    _build_scenery()

func _sample_track() -> void:
    sample_points.clear()
    sample_tangents.clear()
    var count: int = 160
    for i in range(count):
        var a: float = TAU * float(i) / float(count)
        sample_points.append(Vector3(cos(a) * radius_x, 0.0, sin(a) * radius_z))
    for i in range(count):
        var prev: Vector3 = sample_points[(i - 1 + count) % count]
        var next: Vector3 = sample_points[(i + 1) % count]
        sample_tangents.append((next - prev).normalized())

func _mat(color: Color, metallic: float = 0.0, roughness: float = 0.9) -> StandardMaterial3D:
    var m: StandardMaterial3D = StandardMaterial3D.new()
    m.albedo_color = color
    m.metallic = metallic
    m.roughness = roughness
    return m

func _build_ground() -> void:
    var ground: MeshInstance3D = MeshInstance3D.new()
    var mesh: PlaneMesh = PlaneMesh.new()
    mesh.size = Vector2(220, 180)
    ground.mesh = mesh
    ground.material_override = _mat(Color(0.12, 0.32, 0.12))
    ground.position.y = -0.08
    add_child(ground)

func _build_track() -> void:
    var body: StaticBody3D = StaticBody3D.new()
    add_child(body)
    for i in range(0, sample_points.size(), 2):
        var j: int = (i + 2) % sample_points.size()
        var a: Vector3 = sample_points[i]
        var b: Vector3 = sample_points[j]
        var mid: Vector3 = (a + b) * 0.5
        var tangent: Vector3 = (b - a).normalized()
        var length: float = a.distance_to(b)
        var yaw: float = atan2(tangent.x, tangent.z)

        var road: MeshInstance3D = MeshInstance3D.new()
        var road_mesh: BoxMesh = BoxMesh.new()
        road_mesh.size = Vector3(road_width, 0.18, length + 0.4)
        road.mesh = road_mesh
        road.position = mid
        road.rotation.y = yaw
        road.material_override = _mat(Color(0.12,0.13,0.15), 0.05, 0.72)
        add_child(road)

        var shape: BoxShape3D = BoxShape3D.new()
        shape.size = Vector3(road_width, 0.18, length + 0.4)
        var col: CollisionShape3D = CollisionShape3D.new()
        col.shape = shape
        col.position = mid
        col.rotation.y = yaw
        body.add_child(col)

        for side in [-1.0, 1.0]:
            var side_value: float = float(side)
            var right: Vector3 = Vector3(-tangent.z, 0.0, tangent.x)
            var rail_pos: Vector3 = mid + right * side_value * (road_width * 0.5 + 0.35) + Vector3.UP * 0.55
            var rail: MeshInstance3D = MeshInstance3D.new()
            var rail_mesh: BoxMesh = BoxMesh.new()
            rail_mesh.size = Vector3(0.35, 1.0, length + 0.3)
            rail.mesh = rail_mesh
            rail.position = rail_pos
            rail.rotation.y = yaw
            rail.material_override = _mat(Color(0.82,0.84,0.88),0.7,0.25)
            add_child(rail)

            var rail_shape: BoxShape3D = BoxShape3D.new()
            rail_shape.size = Vector3(0.35, 1.0, length + 0.3)
            var rail_col: CollisionShape3D = CollisionShape3D.new()
            rail_col.shape = rail_shape
            rail_col.position = rail_pos
            rail_col.rotation.y = yaw
            body.add_child(rail_col)

func _build_scenery() -> void:
    var trunk_mat: StandardMaterial3D = _mat(Color(0.22,0.10,0.04))
    var leaf_mat: StandardMaterial3D = _mat(Color(0.04,0.26,0.08))
    for i in range(0, sample_points.size(), 8):
        var p: Vector3 = sample_points[i]
        var tangent: Vector3 = sample_tangents[i]
        var right: Vector3 = Vector3(-tangent.z,0,tangent.x)
        for side in [-1.0,1.0]:
            var side_value: float = float(side)
            var base: Vector3 = p + right * side_value * (road_width * 0.5 + 7.0)
            var trunk: MeshInstance3D = MeshInstance3D.new()
            var cyl: CylinderMesh = CylinderMesh.new()
            cyl.top_radius = 0.28
            cyl.bottom_radius = 0.42
            cyl.height = 3.8
            trunk.mesh = cyl
            trunk.position = base + Vector3.UP * 1.9
            trunk.material_override = trunk_mat
            add_child(trunk)

            var crown: MeshInstance3D = MeshInstance3D.new()
            var cone: CylinderMesh = CylinderMesh.new()
            cone.top_radius = 0.0
            cone.bottom_radius = 1.8
            cone.height = 4.2
            crown.mesh = cone
            crown.position = base + Vector3.UP * 5.0
            crown.material_override = leaf_mat
            add_child(crown)

func spawn_transform() -> Transform3D:
    var p: Vector3 = sample_points[0] + Vector3.UP * 0.55
    var t: Vector3 = sample_tangents[0]
    return Transform3D(Basis.looking_at(-t, Vector3.UP), p)

func nearest_track_info(world_pos: Vector3) -> Dictionary:
    var best_i: int = 0
    var best_d: float = INF
    for i in range(sample_points.size()):
        var d: float = world_pos.distance_squared_to(sample_points[i])
        if d < best_d:
            best_d = d
            best_i = i
    var tangent: Vector3 = sample_tangents[best_i]
    var right: Vector3 = Vector3(-tangent.z,0,tangent.x)
    return {"index":best_i,"point":sample_points[best_i],"tangent":tangent,"right":right,"distance":sqrt(best_d)}
