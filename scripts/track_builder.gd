extends Node3D
class_name TrackBuilder

var road_width: float = 23.5
var jump_indices: Array[int] = []
var sample_points: Array[Vector3] = []
var sample_tangents: Array[Vector3] = []
var checkpoint_indices: Array[int] = []

func setup() -> void:
    _sample_track()
    _build_ground()
    _build_track()
    _build_scenery()
    _build_stunt_elements()
    _build_checkpoints()

func _sample_track() -> void:
    sample_points.clear()
    sample_tangents.clear()

    var controls: Array[Vector3] = [
        Vector3(0,0,-105),
        Vector3(48,0,-112),
        Vector3(105,0,-82),
        Vector3(132,0,-28),
        Vector3(102,0,18),
        Vector3(138,0,67),
        Vector3(82,0,112),
        Vector3(22,0,94),
        Vector3(-38,0,122),
        Vector3(-105,0,82),
        Vector3(-138,0,20),
        Vector3(-112,0,-42),
        Vector3(-72,0,-92),
        Vector3(-24,0,-78)
    ]

    var per_segment: int = 24
    var count: int = controls.size()
    for i in range(count):
        var p0: Vector3 = controls[(i - 1 + count) % count]
        var p1: Vector3 = controls[i]
        var p2: Vector3 = controls[(i + 1) % count]
        var p3: Vector3 = controls[(i + 2) % count]
        for s in range(per_segment):
            var t: float = float(s) / float(per_segment)
            sample_points.append(_catmull_rom(p0,p1,p2,p3,t))

    for i in range(sample_points.size()):
        var prev: Vector3 = sample_points[(i - 1 + sample_points.size()) % sample_points.size()]
        var next: Vector3 = sample_points[(i + 1) % sample_points.size()]
        sample_tangents.append((next - prev).normalized())

func _catmull_rom(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, t: float) -> Vector3:
    var t2: float = t * t
    var t3: float = t2 * t
    return 0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3)

func _mat(color: Color, metallic: float = 0.0, roughness: float = 0.9) -> StandardMaterial3D:
    var m: StandardMaterial3D = StandardMaterial3D.new()
    m.albedo_color = color
    m.metallic = metallic
    m.roughness = roughness
    return m

func _build_ground() -> void:
    var ground: MeshInstance3D = MeshInstance3D.new()
    var mesh: PlaneMesh = PlaneMesh.new()
    mesh.size = Vector2(410, 370)
    ground.mesh = mesh
    ground.material_override = _mat(Color(0.10,0.30,0.10))
    ground.position.y = -0.10
    add_child(ground)

func _build_track() -> void:
    _build_continuous_road_surface()

    var body: StaticBody3D = StaticBody3D.new()
    add_child(body)

    for i in range(sample_points.size()):
        var j: int = (i + 1) % sample_points.size()
        var a: Vector3 = sample_points[i]
        var b: Vector3 = sample_points[j]
        var mid: Vector3 = (a + b) * 0.5
        var tangent: Vector3 = (b - a).normalized()
        var length: float = a.distance_to(b)
        var yaw: float = atan2(tangent.x,tangent.z)

        var shape: BoxShape3D = BoxShape3D.new()
        shape.size = Vector3(road_width,0.24,length + 0.85)
        var col: CollisionShape3D = CollisionShape3D.new()
        col.shape = shape
        col.position = mid + Vector3.DOWN * 0.02
        col.rotation.y = yaw
        body.add_child(col)

        if i % 12 == 0:
            var line: MeshInstance3D = MeshInstance3D.new()
            var line_mesh: BoxMesh = BoxMesh.new()
            line_mesh.size = Vector3(0.16,0.025,min(length + 0.45,3.6))
            line.mesh = line_mesh
            line.position = mid + Vector3.UP * 0.055
            line.rotation.y = yaw
            line.material_override = _mat(Color(0.95,0.92,0.72),0.0,0.40)
            add_child(line)

        for side in [-1.0,1.0]:
            var side_value: float = float(side)
            var right: Vector3 = Vector3(-tangent.z,0.0,tangent.x)
            var rail_pos: Vector3 = mid + right * side_value * (road_width * 0.5 + 0.45) + Vector3.UP * 0.58

            var rail: MeshInstance3D = MeshInstance3D.new()
            var rail_mesh: BoxMesh = BoxMesh.new()
            rail_mesh.size = Vector3(0.40,1.05,length + 0.75)
            rail.mesh = rail_mesh
            rail.position = rail_pos
            rail.rotation.y = yaw
            rail.material_override = _mat(Color(0.82,0.84,0.88),0.65,0.28)
            add_child(rail)

            var rail_shape: BoxShape3D = BoxShape3D.new()
            rail_shape.size = Vector3(0.40,1.05,length + 0.75)
            var rail_col: CollisionShape3D = CollisionShape3D.new()
            rail_col.shape = rail_shape
            rail_col.position = rail_pos
            rail_col.rotation.y = yaw
            body.add_child(rail_col)

func _build_continuous_road_surface() -> void:
    var vertices: PackedVector3Array = PackedVector3Array()
    var normals: PackedVector3Array = PackedVector3Array()
    var uvs: PackedVector2Array = PackedVector2Array()
    var indices: PackedInt32Array = PackedInt32Array()
    var n: int = sample_points.size()
    var cumulative: float = 0.0

    for i in range(n):
        if i > 0:
            cumulative += sample_points[i - 1].distance_to(sample_points[i])

        var p: Vector3 = sample_points[i]
        var tangent: Vector3 = sample_tangents[i]
        var right: Vector3 = Vector3(-tangent.z,0.0,tangent.x).normalized()
        var left_pos: Vector3 = p - right * road_width * 0.5 + Vector3.UP * 0.035
        var right_pos: Vector3 = p + right * road_width * 0.5 + Vector3.UP * 0.035

        vertices.append(left_pos)
        vertices.append(right_pos)
        normals.append(Vector3.UP)
        normals.append(Vector3.UP)
        uvs.append(Vector2(0.0,cumulative * 0.08))
        uvs.append(Vector2(1.0,cumulative * 0.08))

    for i in range(n):
        var next_i: int = (i + 1) % n
        var a: int = i * 2
        var b: int = a + 1
        var c: int = next_i * 2
        var d: int = c + 1

        indices.append(a)
        indices.append(c)
        indices.append(b)

        indices.append(b)
        indices.append(c)
        indices.append(d)

    var arrays: Array = []
    arrays.resize(Mesh.ARRAY_MAX)
    arrays[Mesh.ARRAY_VERTEX] = vertices
    arrays[Mesh.ARRAY_NORMAL] = normals
    arrays[Mesh.ARRAY_TEX_UV] = uvs
    arrays[Mesh.ARRAY_INDEX] = indices

    var road_mesh: ArrayMesh = ArrayMesh.new()
    road_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)

    var road: MeshInstance3D = MeshInstance3D.new()
    road.mesh = road_mesh
    road.material_override = _mat(Color(0.105,0.115,0.135),0.06,0.72)
    add_child(road)

func _build_scenery() -> void:
    var trunk_mat: StandardMaterial3D = _mat(Color(0.22,0.10,0.04))
    var leaf_mat: StandardMaterial3D = _mat(Color(0.035,0.24,0.07))
    for i in range(0,sample_points.size(),12):
        var p: Vector3 = sample_points[i]
        var tangent: Vector3 = sample_tangents[i]
        var right: Vector3 = Vector3(-tangent.z,0.0,tangent.x)
        for side in [-1.0,1.0]:
            var base: Vector3 = p + right * float(side) * (road_width * 0.5 + 8.5)

            var trunk: MeshInstance3D = MeshInstance3D.new()
            var cyl: CylinderMesh = CylinderMesh.new()
            cyl.top_radius = 0.30
            cyl.bottom_radius = 0.44
            cyl.height = 4.2
            trunk.mesh = cyl
            trunk.position = base + Vector3.UP * 2.1
            trunk.material_override = trunk_mat
            add_child(trunk)

            var crown: MeshInstance3D = MeshInstance3D.new()
            var cone: CylinderMesh = CylinderMesh.new()
            cone.top_radius = 0.0
            cone.bottom_radius = 2.0
            cone.height = 4.8
            crown.mesh = cone
            crown.position = base + Vector3.UP * 5.5
            crown.material_override = leaf_mat
            add_child(crown)

func _build_stunt_elements() -> void:
    jump_indices.clear()
    if sample_points.is_empty():
        return

    var n: int = sample_points.size()
    jump_indices = [
        int(n * 0.14),
        int(n * 0.36),
        int(n * 0.61),
        int(n * 0.83)
    ]

    var ramp_mat: StandardMaterial3D = _mat(Color(0.12,0.14,0.18),0.62,0.30)
    ramp_mat.emission_enabled = true
    ramp_mat.emission = Color(0.035,0.045,0.07)
    ramp_mat.emission_energy_multiplier = 1.4

    var edge_mat: StandardMaterial3D = _mat(Color(1.0,0.68,0.08),0.78,0.16)
    edge_mat.emission_enabled = true
    edge_mat.emission = Color(1.0,0.38,0.025)
    edge_mat.emission_energy_multiplier = 2.6

    for ramp_i in range(jump_indices.size()):
        var idx: int = jump_indices[ramp_i]
        var p: Vector3 = sample_points[idx]
        var t: Vector3 = sample_tangents[idx].normalized()
        var right: Vector3 = Vector3(-t.z,0.0,t.x).normalized()

        var root: Node3D = Node3D.new()
        root.name = "JumpRamp_%d" % (ramp_i + 1)
        root.position = p + Vector3.UP * 0.28
        root.basis = Basis.looking_at(t,Vector3.UP)
        add_child(root)

        var ramp: MeshInstance3D = MeshInstance3D.new()
        var ramp_mesh: BoxMesh = BoxMesh.new()
        ramp_mesh.size = Vector3(road_width * 0.60,0.34,6.8)
        ramp.mesh = ramp_mesh
        ramp.position = Vector3(0.0,0.34,0.0)
        ramp.rotation_degrees.x = -8.0
        ramp.material_override = ramp_mat
        root.add_child(ramp)

        for side in [-1.0,1.0]:
            var edge: MeshInstance3D = MeshInstance3D.new()
            var edge_mesh: BoxMesh = BoxMesh.new()
            edge_mesh.size = Vector3(0.16,0.12,6.9)
            edge.mesh = edge_mesh
            edge.position = Vector3(float(side) * road_width * 0.29,0.58,0.0)
            edge.rotation_degrees.x = -8.0
            edge.material_override = edge_mat
            root.add_child(edge)

        # Floating landing gate makes the airborne section easy to read.
        var landing_idx: int = posmod(idx + 16,n)
        var lp: Vector3 = sample_points[landing_idx]
        var lt: Vector3 = sample_tangents[landing_idx].normalized()
        var lr: Vector3 = Vector3(-lt.z,0.0,lt.x).normalized()

        for side in [-1.0,1.0]:
            var pillar: MeshInstance3D = MeshInstance3D.new()
            var pillar_mesh: BoxMesh = BoxMesh.new()
            pillar_mesh.size = Vector3(0.28,5.2,0.28)
            pillar.mesh = pillar_mesh
            pillar.position = lp + lr * float(side) * 5.6 + Vector3.UP * 2.6
            pillar.material_override = edge_mat
            add_child(pillar)

        var top_gate: MeshInstance3D = MeshInstance3D.new()
        var top_mesh: BoxMesh = BoxMesh.new()
        top_mesh.size = Vector3(11.5,0.30,0.30)
        top_gate.mesh = top_mesh
        top_gate.position = lp + Vector3.UP * 5.05
        top_gate.basis = Basis.looking_at(lt,Vector3.UP)
        top_gate.material_override = edge_mat
        add_child(top_gate)

    # Two elevated-looking side structures to give the course more vertical character.
    for frac in [0.25,0.72]:
        var idx: int = int(float(n) * float(frac))
        var p: Vector3 = sample_points[idx]
        var t: Vector3 = sample_tangents[idx].normalized()
        var right: Vector3 = Vector3(-t.z,0.0,t.x).normalized()

        for side in [-1.0,1.0]:
            var tower: MeshInstance3D = MeshInstance3D.new()
            var tower_mesh: BoxMesh = BoxMesh.new()
            tower_mesh.size = Vector3(3.4,7.0,5.0)
            tower.mesh = tower_mesh
            tower.position = p + right * float(side) * (road_width * 0.5 + 6.2) + Vector3.UP * 3.5
            tower.basis = Basis.looking_at(t,Vector3.UP)
            tower.material_override = _mat(Color(0.16,0.18,0.22),0.35,0.48)
            add_child(tower)

func jump_strength_at(track_index: int) -> float:
    if sample_points.is_empty():
        return 0.0
    for i in range(jump_indices.size()):
        if circular_index_distance(track_index,jump_indices[i]) <= 2:
            return 9.2 + float(i % 2) * 1.3
    return 0.0

func _build_checkpoints() -> void:
    checkpoint_indices.clear()
    var n: int = sample_points.size()
    checkpoint_indices.append(int(n / 4))
    checkpoint_indices.append(int(n / 2))
    checkpoint_indices.append(int(n * 3 / 4))
    checkpoint_indices.append(0)

func spawn_transform_at(sample_index: int = 0, lane_offset: float = 0.0) -> Transform3D:
    if sample_points.is_empty():
        return Transform3D.IDENTITY
    var idx: int = posmod(sample_index,sample_points.size())
    var p: Vector3 = sample_points[idx] + Vector3.UP * 0.55
    var t: Vector3 = sample_tangents[idx]
    var right: Vector3 = Vector3(-t.z,0.0,t.x)
    p += right * lane_offset
    return Transform3D(Basis.looking_at(t,Vector3.UP),p)

func spawn_transform() -> Transform3D:
    return spawn_transform_at(0,0.0)

func nearest_track_info(world_pos: Vector3) -> Dictionary:
    var best_i: int = 0
    var best_d: float = INF
    for i in range(sample_points.size()):
        var d: float = world_pos.distance_squared_to(sample_points[i])
        if d < best_d:
            best_d = d
            best_i = i
    var tangent: Vector3 = sample_tangents[best_i]
    var right: Vector3 = Vector3(-tangent.z,0.0,tangent.x)
    return {"index":best_i,"point":sample_points[best_i],"tangent":tangent,"right":right,"distance":sqrt(best_d)}

func circular_index_distance(a: int, b: int) -> int:
    var n: int = sample_points.size()
    var d: int = int(abs(a-b))
    return min(d,n-d)
