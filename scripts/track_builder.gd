extends Node3D
class_name TrackBuilder

var road_width: float = 23.5
var upper_sections: Array[Dictionary] = []
var boost_indices: Array[int] = []
var sample_points: Array[Vector3] = []
var sample_tangents: Array[Vector3] = []
var checkpoint_indices: Array[int] = []

func setup() -> void:
    _sample_track()
    _build_ground()
    _build_track()
    _build_scenery()
    _build_stunt_elements()
    _build_natural_landmarks()
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
    ground.material_override = _mat(Color(0.075,0.245,0.085),0.0,0.96)
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
            var rail_pos: Vector3 = mid + right * side_value * (road_width * 0.5 + 0.45) + Vector3.UP * 1.15

            var rail: MeshInstance3D = MeshInstance3D.new()
            var rail_mesh: BoxMesh = BoxMesh.new()
            rail_mesh.size = Vector3(0.46,2.30,length + 0.75)
            rail.mesh = rail_mesh
            rail.position = rail_pos
            rail.rotation.y = yaw
            rail.material_override = _mat(Color(0.82,0.84,0.88),0.65,0.28)
            add_child(rail)

            var rail_shape: BoxShape3D = BoxShape3D.new()
            rail_shape.size = Vector3(0.46,2.30,length + 0.75)
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
    var trunk_mat: StandardMaterial3D = _mat(Color(0.19,0.085,0.035),0.0,0.96)
    var leaf_mat: StandardMaterial3D = _mat(Color(0.025,0.22,0.065),0.0,0.92)
    var leaf_light: StandardMaterial3D = _mat(Color(0.08,0.34,0.10),0.0,0.90)
    var rock_mat: StandardMaterial3D = _mat(Color(0.20,0.23,0.20),0.02,0.98)
    var bush_mat: StandardMaterial3D = _mat(Color(0.055,0.30,0.075),0.0,0.95)

    for i in range(0,sample_points.size(),8):
        var p: Vector3 = sample_points[i]
        var tangent: Vector3 = sample_tangents[i]
        var right: Vector3 = Vector3(-tangent.z,0.0,tangent.x).normalized()

        for side in [-1.0,1.0]:
            var s: float = float(side)
            var depth: float = 7.8 + float((i/8)%3)*2.4
            var base: Vector3 = p + right*s*(road_width*0.5+depth)

            # Mixed-height trees make the forest less repetitive.
            var tree_scale: float = 0.82 + float((i+int(side))%4)*0.11
            var trunk: MeshInstance3D = MeshInstance3D.new()
            var cyl: CylinderMesh = CylinderMesh.new()
            cyl.top_radius = 0.25*tree_scale
            cyl.bottom_radius = 0.48*tree_scale
            cyl.height = 4.4*tree_scale
            trunk.mesh = cyl
            trunk.position = base + Vector3.UP*(2.2*tree_scale)
            trunk.material_override = trunk_mat
            add_child(trunk)

            for crown_i in range(2):
                var crown: MeshInstance3D = MeshInstance3D.new()
                var cone: CylinderMesh = CylinderMesh.new()
                cone.top_radius = 0.0
                cone.bottom_radius = (2.0-float(crown_i)*0.28)*tree_scale
                cone.height = (4.4-float(crown_i)*0.45)*tree_scale
                crown.mesh = cone
                crown.position = base + Vector3.UP*((5.2+float(crown_i)*1.3)*tree_scale)
                crown.material_override = leaf_mat if crown_i == 0 else leaf_light
                add_child(crown)

            # Low bushes close to the road edge.
            var bush: MeshInstance3D = MeshInstance3D.new()
            var bush_mesh: SphereMesh = SphereMesh.new()
            bush_mesh.radius = 0.75
            bush_mesh.height = 1.1
            bush.mesh = bush_mesh
            bush.scale = Vector3(1.35,0.58,0.92)
            bush.position = p + right*s*(road_width*0.5+3.3) + Vector3.UP*0.48
            bush.material_override = bush_mat
            add_child(bush)

            # Irregular boulders farther out.
            if i % 16 == 0:
                var rock: MeshInstance3D = MeshInstance3D.new()
                var rock_mesh: SphereMesh = SphereMesh.new()
                rock_mesh.radius = 1.18
                rock_mesh.height = 1.75
                rock.mesh = rock_mesh
                rock.scale = Vector3(1.15+0.15*s,0.72,0.95)
                rock.position = base + tangent*(2.0*s) + Vector3.UP*0.58
                rock.rotation_degrees = Vector3(0.0,float((i*13)%360),8.0*s)
                rock.material_override = rock_mat
                add_child(rock)

func _build_stunt_elements() -> void:
    upper_sections.clear()
    boost_indices.clear()
    if sample_points.is_empty():
        return

    var n: int = sample_points.size()

    # Two real upper-deck sections. Entry/exit transitions act as the old "jump"
    # elements, but now they lift the kart onto another floor instead of launching it.
    upper_sections = [
        {"start":int(n*0.16),"end":int(n*0.31),"height":4.6,"transition":14},
        {"start":int(n*0.60),"end":int(n*0.75),"height":5.2,"transition":14}
    ]

    # Ground-floor speed pads replace the old free-flight ramps.
    boost_indices = [
        int(n*0.055),
        int(n*0.405),
        int(n*0.505),
        int(n*0.855)
    ]

    _build_upper_decks()
    _build_ground_boost_pads()

func _build_upper_decks() -> void:
    var deck_mat: StandardMaterial3D = _mat(Color(0.18,0.13,0.075),0.08,0.72)
    var edge_mat: StandardMaterial3D = _mat(Color(0.16,0.36,0.12),0.10,0.52)
    edge_mat.emission_enabled = true
    edge_mat.emission = Color(0.05,0.22,0.07)
    edge_mat.emission_energy_multiplier = 0.8

    var support_mat: StandardMaterial3D = _mat(Color(0.24,0.18,0.10),0.03,0.90)
    var rail_body: StaticBody3D = StaticBody3D.new()
    rail_body.name = "UpperDeckRails"
    add_child(rail_body)

    var n: int = sample_points.size()
    for section_index in range(upper_sections.size()):
        var section: Dictionary = upper_sections[section_index]
        var start_idx: int = int(section["start"])
        var end_idx: int = int(section["end"])
        var trans: int = int(section["transition"])

        for step in range(-trans,end_idx-start_idx+trans+1):
            var idx: int = posmod(start_idx+step,n)
            var next_idx: int = posmod(idx+1,n)
            var h0: float = track_height_at(idx)
            var h1: float = track_height_at(next_idx)

            if h0 <= 0.02 and h1 <= 0.02:
                continue

            var a: Vector3 = sample_points[idx] + Vector3.UP*h0
            var b: Vector3 = sample_points[next_idx] + Vector3.UP*h1
            var mid: Vector3 = (a+b)*0.5
            var dir: Vector3 = (b-a).normalized()
            var length: float = a.distance_to(b)

            var deck: MeshInstance3D = MeshInstance3D.new()
            var deck_mesh: BoxMesh = BoxMesh.new()
            deck_mesh.size = Vector3(road_width,0.28,length+0.45)
            deck.mesh = deck_mesh
            deck.global_position = mid
            deck.basis = Basis.looking_at(dir,Vector3.UP)
            deck.material_override = deck_mat
            add_child(deck)

            # Tall rails on the upper deck prevent skipping the course by hopping the wall.
            var right: Vector3 = Vector3(-dir.z,0.0,dir.x).normalized()
            for side in [-1.0,1.0]:
                var rail_pos: Vector3 = mid + right*float(side)*(road_width*0.5+0.42) + Vector3.UP*1.25

                var rail: MeshInstance3D = MeshInstance3D.new()
                var rail_mesh: BoxMesh = BoxMesh.new()
                rail_mesh.size = Vector3(0.46,2.5,length+0.52)
                rail.mesh = rail_mesh
                rail.global_position = rail_pos
                rail.basis = Basis.looking_at(dir,Vector3.UP)
                rail.material_override = edge_mat
                add_child(rail)

                var rail_shape: BoxShape3D = BoxShape3D.new()
                rail_shape.size = Vector3(0.46,2.5,length+0.52)
                var rail_col: CollisionShape3D = CollisionShape3D.new()
                rail_col.shape = rail_shape
                rail_col.global_position = rail_pos
                rail_col.basis = Basis.looking_at(dir,Vector3.UP)
                rail_body.add_child(rail_col)

            # Supports make the second floor read clearly as an elevated structure.
            if step % 8 == 0 and h0 > 1.0:
                for side in [-1.0,1.0]:
                    var pillar: MeshInstance3D = MeshInstance3D.new()
                    var pillar_mesh: BoxMesh = BoxMesh.new()
                    pillar_mesh.size = Vector3(0.75,h0,0.75)
                    pillar.mesh = pillar_mesh
                    pillar.position = sample_points[idx] + Vector3(-sample_tangents[idx].z,0.0,sample_tangents[idx].x).normalized()*float(side)*(road_width*0.38) + Vector3.UP*(h0*0.5)
                    pillar.material_override = support_mat
                    add_child(pillar)

func _build_ground_boost_pads() -> void:
    var pad_mat: StandardMaterial3D = _mat(Color(0.02,0.35,0.62),0.50,0.16)
    pad_mat.emission_enabled = true
    pad_mat.emission = Color(0.03,0.66,1.0)
    pad_mat.emission_energy_multiplier = 4.2

    var arrow_mat: StandardMaterial3D = _mat(Color(0.68,0.95,1.0),0.25,0.10)
    arrow_mat.emission_enabled = true
    arrow_mat.emission = Color(0.22,0.85,1.0)
    arrow_mat.emission_energy_multiplier = 5.0

    for pad_i in range(boost_indices.size()):
        var idx: int = boost_indices[pad_i]
        var p: Vector3 = sample_points[idx]
        var t: Vector3 = sample_tangents[idx].normalized()

        var root: Node3D = Node3D.new()
        root.name = "GroundBoost_%d" % (pad_i+1)
        root.position = p + Vector3.UP*0.09
        root.basis = Basis.looking_at(t,Vector3.UP)
        add_child(root)

        var pad: MeshInstance3D = MeshInstance3D.new()
        var pad_mesh: BoxMesh = BoxMesh.new()
        pad_mesh.size = Vector3(road_width*0.56,0.08,5.6)
        pad.mesh = pad_mesh
        pad.material_override = pad_mat
        root.add_child(pad)

        # Three luminous forward stripes make it obvious that this is a speed pad.
        for z in [-1.45,0.0,1.45]:
            var stripe: MeshInstance3D = MeshInstance3D.new()
            var stripe_mesh: BoxMesh = BoxMesh.new()
            stripe_mesh.size = Vector3(road_width*0.42,0.04,0.34)
            stripe.mesh = stripe_mesh
            stripe.position = Vector3(0.0,0.07,float(z))
            stripe.material_override = arrow_mat
            root.add_child(stripe)

func _build_natural_landmarks() -> void:
    if sample_points.is_empty():
        return

    var rock_dark: StandardMaterial3D = _mat(Color(0.13,0.16,0.14),0.02,0.98)
    var rock_moss: StandardMaterial3D = _mat(Color(0.12,0.24,0.10),0.0,0.96)
    var water_mat: StandardMaterial3D = _mat(Color(0.055,0.34,0.52),0.08,0.22)
    water_mat.emission_enabled = true
    water_mat.emission = Color(0.02,0.13,0.19)
    water_mat.emission_energy_multiplier = 0.7
    var flower_mat: StandardMaterial3D = _mat(Color(0.92,0.72,0.24),0.0,0.82)

    var n: int = sample_points.size()

    # A small forest pond next to the first half of the circuit.
    var pond_idx: int = int(n*0.43)
    var pp: Vector3 = sample_points[pond_idx]
    var pt: Vector3 = sample_tangents[pond_idx]
    var pr: Vector3 = Vector3(-pt.z,0.0,pt.x).normalized()
    var pond_center: Vector3 = pp + pr*(road_width*0.5+16.0)

    var pond: MeshInstance3D = MeshInstance3D.new()
    var pond_mesh: CylinderMesh = CylinderMesh.new()
    pond_mesh.top_radius = 7.5
    pond_mesh.bottom_radius = 7.9
    pond_mesh.height = 0.16
    pond.mesh = pond_mesh
    pond.position = pond_center + Vector3.UP*0.02
    pond.material_override = water_mat
    add_child(pond)

    for i in range(10):
        var angle: float = TAU*float(i)/10.0
        var rock: MeshInstance3D = MeshInstance3D.new()
        var rock_mesh: SphereMesh = SphereMesh.new()
        rock_mesh.radius = 0.85+float(i%3)*0.17
        rock_mesh.height = 1.15
        rock.mesh = rock_mesh
        rock.scale = Vector3(1.15,0.62,0.90)
        rock.position = pond_center + Vector3(cos(angle)*7.2,0.42,sin(angle)*7.2)
        rock.material_override = rock_moss if i%2==0 else rock_dark
        add_child(rock)

    # Waterfall / cliff landmark on the opposite side of the map.
    var fall_idx: int = int(n*0.70)
    var fp: Vector3 = sample_points[fall_idx]
    var ft: Vector3 = sample_tangents[fall_idx]
    var fr: Vector3 = Vector3(-ft.z,0.0,ft.x).normalized()
    var cliff_center: Vector3 = fp - fr*(road_width*0.5+18.0)

    for level in range(5):
        for side in [-1,0,1]:
            var cliff: MeshInstance3D = MeshInstance3D.new()
            var cliff_mesh: SphereMesh = SphereMesh.new()
            cliff_mesh.radius = 2.2
            cliff_mesh.height = 3.0
            cliff.mesh = cliff_mesh
            cliff.scale = Vector3(1.4,0.95,1.0)
            cliff.position = cliff_center + Vector3(float(side)*3.0,float(level)*1.65+1.3,float((level+side)%2)*1.2)
            cliff.material_override = rock_dark if (level+side)%2==0 else rock_moss
            add_child(cliff)

    var waterfall: MeshInstance3D = MeshInstance3D.new()
    var waterfall_mesh: BoxMesh = BoxMesh.new()
    waterfall_mesh.size = Vector3(3.0,7.8,0.18)
    waterfall.mesh = waterfall_mesh
    waterfall.position = cliff_center + Vector3(0.0,4.9,-2.1)
    waterfall.material_override = water_mat
    add_child(waterfall)

    var pool: MeshInstance3D = MeshInstance3D.new()
    var pool_mesh: CylinderMesh = CylinderMesh.new()
    pool_mesh.top_radius = 5.0
    pool_mesh.bottom_radius = 5.3
    pool_mesh.height = 0.14
    pool.mesh = pool_mesh
    pool.position = cliff_center + Vector3(0.0,0.05,-2.1)
    pool.material_override = water_mat
    add_child(pool)

    # Rock arches around the upper-deck entrances.
    for section in upper_sections:
        var entrance_idx: int = max(0,int(section["start"])-5)
        var ep: Vector3 = sample_points[entrance_idx]
        var et: Vector3 = sample_tangents[entrance_idx].normalized()
        var er: Vector3 = Vector3(-et.z,0.0,et.x).normalized()

        for side in [-1.0,1.0]:
            var tower: MeshInstance3D = MeshInstance3D.new()
            var tower_mesh: SphereMesh = SphereMesh.new()
            tower_mesh.radius = 1.6
            tower_mesh.height = 4.8
            tower.mesh = tower_mesh
            tower.scale = Vector3(0.90,1.45,0.92)
            tower.position = ep + er*float(side)*(road_width*0.5+1.8) + Vector3.UP*2.5
            tower.material_override = rock_moss
            add_child(tower)

        var cap: MeshInstance3D = MeshInstance3D.new()
        var cap_mesh: BoxMesh = BoxMesh.new()
        cap_mesh.size = Vector3(road_width+4.8,1.15,1.6)
        cap.mesh = cap_mesh
        cap.position = ep + Vector3.UP*5.0
        cap.basis = Basis.looking_at(et,Vector3.UP)
        cap.material_override = rock_moss
        add_child(cap)

    # Small golden wildflowers around selected curves.
    for i in range(0,n,18):
        var p: Vector3 = sample_points[i]
        var t: Vector3 = sample_tangents[i]
        var r: Vector3 = Vector3(-t.z,0.0,t.x).normalized()
        for side in [-1.0,1.0]:
            for j in range(3):
                var flower: MeshInstance3D = MeshInstance3D.new()
                var flower_mesh: SphereMesh = SphereMesh.new()
                flower_mesh.radius = 0.11
                flower_mesh.height = 0.16
                flower.mesh = flower_mesh
                flower.position = p + r*float(side)*(road_width*0.5+2.2+float(j)*0.45) + t*(float(j)-1.0)*0.7 + Vector3.UP*0.14
                flower.material_override = flower_mat
                add_child(flower)

func track_height_at(track_index: int) -> float:
    if sample_points.is_empty():
        return 0.0

    var n: int = sample_points.size()
    var idx: int = posmod(track_index,n)

    for section in upper_sections:
        var start_idx: int = int(section["start"])
        var end_idx: int = int(section["end"])
        var height: float = float(section["height"])
        var transition: int = int(section["transition"])

        var rise_start: int = posmod(start_idx-transition,n)
        var fall_end: int = posmod(end_idx+transition,n)

        # Sections used here do not wrap around index zero, so ordinary ranges are stable.
        if idx >= start_idx and idx <= end_idx:
            return height
        if idx >= start_idx-transition and idx < start_idx:
            var t: float = float(idx-(start_idx-transition))/float(max(1,transition))
            return smoothstep(0.0,1.0,t)*height
        if idx > end_idx and idx <= end_idx+transition:
            var t: float = float(idx-end_idx)/float(max(1,transition))
            return (1.0-smoothstep(0.0,1.0,t))*height

    return 0.0

func boost_pad_at(track_index: int) -> bool:
    for idx in boost_indices:
        if circular_index_distance(track_index,idx) <= 2:
            return true
    return false

func confine_to_road(world_pos: Vector3, track_index: int) -> Vector3:
    if sample_points.is_empty():
        return world_pos

    var idx: int = posmod(track_index,sample_points.size())
    var center: Vector3 = sample_points[idx]
    var tangent: Vector3 = sample_tangents[idx]
    tangent.y = 0.0
    tangent = tangent.normalized()
    var right: Vector3 = Vector3(-tangent.z,0.0,tangent.x)
    var offset: Vector3 = world_pos-center
    var lateral: float = offset.dot(right)
    var limit: float = road_width*0.5-1.55

    if abs(lateral) > limit:
        world_pos -= right*(lateral-clamp(lateral,-limit,limit))

    return world_pos

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
    var p: Vector3 = sample_points[idx] + Vector3.UP * (0.55 + track_height_at(idx))
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
        var dx: float = world_pos.x-sample_points[i].x
        var dz: float = world_pos.z-sample_points[i].z
        var d: float = dx*dx+dz*dz
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
