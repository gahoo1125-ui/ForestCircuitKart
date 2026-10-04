extends Node3D
class_name TrackBuilder

var road_width: float = 23.5
var upper_sections: Array[Dictionary] = []
var boost_indices: Array[int] = []
var sample_points: Array[Vector3] = []
var sample_tangents: Array[Vector3] = []
var checkpoint_indices: Array[int] = []
var shortcut_routes: Array[Dictionary] = []

func setup() -> void:
    _sample_track()
    _build_ground()
    _build_track()
    _build_scenery()

    # Keep the race course clean and flat:
    # no upper-deck stunt structures, shortcut roads, jump/ramp pieces,
    # tunnel arches or other protruding course geometry.
    upper_sections.clear()
    boost_indices.clear()
    shortcut_routes.clear()

    _build_natural_landmarks()
    _build_bamboo_temple_environment()
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
    ground.name = "HQForestGround"
    var mesh: PlaneMesh = PlaneMesh.new()
    mesh.size = Vector2(560,520)
    mesh.subdivide_width = 8
    mesh.subdivide_depth = 8
    ground.mesh = mesh
    var mat: StandardMaterial3D = _mat(Color(0.018,0.055,0.032),0.0,0.98)
    ground.material_override = mat
    ground.position.y = -0.10
    ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
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
            var lane_mat: StandardMaterial3D = _mat(Color(0.94,0.80,0.34),0.08,0.32)
            lane_mat.emission_enabled = true
            lane_mat.emission = Color(0.25,0.10,0.01)
            lane_mat.emission_energy_multiplier = 0.8
            line.material_override = lane_mat
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
            var rail_mat: StandardMaterial3D = _mat(Color(0.34,0.055,0.045),0.18,0.42)
            rail.material_override = rail_mat
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
    var road_mat: StandardMaterial3D = _mat(Color(0.070,0.075,0.086),0.10,0.56)
    road_mat.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
    road.material_override = road_mat
    add_child(road)

func _build_scenery() -> void:
    if sample_points.is_empty():
        return

    var root: Node3D = Node3D.new()
    root.name = "OptimizedForestScenery"
    add_child(root)

    var trunk_mat: StandardMaterial3D = _mat(Color(0.105,0.045,0.020),0.0,0.96)
    var pine_mat: StandardMaterial3D = _mat(Color(0.018,0.135,0.045),0.0,0.93)
    var pine_light_mat: StandardMaterial3D = _mat(Color(0.035,0.215,0.070),0.0,0.91)
    var rock_mat: StandardMaterial3D = _mat(Color(0.16,0.18,0.17),0.02,0.96)
    var bush_mat: StandardMaterial3D = _mat(Color(0.025,0.20,0.055),0.0,0.95)

    var trunk_mesh: CylinderMesh = CylinderMesh.new()
    trunk_mesh.top_radius = 0.22
    trunk_mesh.bottom_radius = 0.42
    trunk_mesh.height = 4.8
    trunk_mesh.radial_segments = 7

    var pine_mesh: CylinderMesh = CylinderMesh.new()
    pine_mesh.top_radius = 0.0
    pine_mesh.bottom_radius = 2.05
    pine_mesh.height = 5.6
    pine_mesh.radial_segments = 8

    var pine_top_mesh: CylinderMesh = CylinderMesh.new()
    pine_top_mesh.top_radius = 0.0
    pine_top_mesh.bottom_radius = 1.45
    pine_top_mesh.height = 4.0
    pine_top_mesh.radial_segments = 8

    var bush_mesh: SphereMesh = SphereMesh.new()
    bush_mesh.radius = 0.78
    bush_mesh.height = 1.05
    bush_mesh.radial_segments = 8
    bush_mesh.rings = 4

    var rock_mesh: SphereMesh = SphereMesh.new()
    rock_mesh.radius = 1.0
    rock_mesh.height = 1.55
    rock_mesh.radial_segments = 8
    rock_mesh.rings = 4

    var trunk_transforms: Array[Transform3D] = []
    var lower_transforms: Array[Transform3D] = []
    var upper_transforms: Array[Transform3D] = []
    var bush_transforms: Array[Transform3D] = []
    var rock_transforms: Array[Transform3D] = []

    var n: int = sample_points.size()
    for i in range(0,n,7):
        var p: Vector3 = sample_points[i]
        var tangent: Vector3 = sample_tangents[i].normalized()
        var right: Vector3 = Vector3(-tangent.z,0.0,tangent.x).normalized()

        for side in [-1.0,1.0]:
            var s: float = float(side)
            var variant: int = (i*17 + int((s+1.0)*7.0)) % 11
            var depth: float = 8.0 + float(variant%5)*2.1
            var base: Vector3 = p + right*s*(road_width*0.5+depth) + tangent*(float((variant%3)-1)*1.6)
            var sc: float = 0.86 + float(variant%6)*0.10
            var yaw: float = deg_to_rad(float((i*31+variant*47)%360))
            var basis: Basis = Basis(Vector3.UP,yaw).scaled(Vector3(sc,sc,sc))

            trunk_transforms.append(Transform3D(basis,base+Vector3.UP*(2.4*sc)))
            lower_transforms.append(Transform3D(basis,base+Vector3.UP*(5.1*sc)))
            upper_transforms.append(Transform3D(basis,base+Vector3.UP*(7.25*sc)))

            if i%14 == 0:
                var bush_base: Vector3 = p+right*s*(road_width*0.5+3.3+float(variant%3)*0.7)+tangent*(float(variant%4)-1.5)*0.9
                var bush_basis: Basis = Basis(Vector3.UP,yaw*0.73).scaled(Vector3(1.25+float(variant%3)*0.12,0.68,0.95))
                bush_transforms.append(Transform3D(bush_basis,bush_base+Vector3.UP*0.48))

            if i%28 == 0:
                var rock_base: Vector3 = p+right*s*(road_width*0.5+5.4+float(variant%4)*1.15)+tangent*(float(variant%3)-1.0)*1.7
                var rock_basis: Basis = Basis(Vector3.UP,yaw).scaled(Vector3(1.1+float(variant%3)*0.28,0.72+float(variant%2)*0.12,0.9))
                rock_transforms.append(Transform3D(rock_basis,rock_base+Vector3.UP*0.58))

    _add_multimesh(root,"TreeTrunks",trunk_mesh,trunk_mat,trunk_transforms)
    _add_multimesh(root,"PineCrownsLow",pine_mesh,pine_mat,lower_transforms)
    _add_multimesh(root,"PineCrownsHigh",pine_top_mesh,pine_light_mat,upper_transforms)
    _add_multimesh(root,"RoadsideBushes",bush_mesh,bush_mat,bush_transforms)
    _add_multimesh(root,"RoadsideRocks",rock_mesh,rock_mat,rock_transforms)

func _add_multimesh(parent: Node3D, node_name: String, mesh: Mesh, material: Material, transforms: Array[Transform3D]) -> void:
    if transforms.is_empty():
        return
    var mm: MultiMesh = MultiMesh.new()
    mm.transform_format = MultiMesh.TRANSFORM_3D
    mm.mesh = mesh
    mm.instance_count = transforms.size()
    for i in range(transforms.size()):
        mm.set_instance_transform(i,transforms[i])

    var instance: MultiMeshInstance3D = MultiMeshInstance3D.new()
    instance.name = node_name
    instance.multimesh = mm
    instance.material_override = material
    instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
    parent.add_child(instance)


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

func _build_arcade_race_environment() -> void:
    if sample_points.is_empty():
        return

    var n: int = sample_points.size()

    var cyan: StandardMaterial3D = _mat(Color(0.04,0.70,0.96),0.32,0.22)
    cyan.emission_enabled = true
    cyan.emission = Color(0.02,0.34,0.62)
    cyan.emission_energy_multiplier = 2.0

    var yellow: StandardMaterial3D = _mat(Color(1.0,0.72,0.08),0.24,0.28)
    yellow.emission_enabled = true
    yellow.emission = Color(0.55,0.24,0.01)
    yellow.emission_energy_multiplier = 1.6

    var pink: StandardMaterial3D = _mat(Color(0.96,0.20,0.46),0.18,0.30)
    var white: StandardMaterial3D = _mat(Color(0.94,0.98,1.0),0.08,0.36)
    var navy: StandardMaterial3D = _mat(Color(0.045,0.085,0.14),0.28,0.30)
    var seat_mat: StandardMaterial3D = _mat(Color(0.10,0.18,0.28),0.05,0.58)
    var building_mats: Array[StandardMaterial3D] = [
        _mat(Color(0.18,0.62,0.92),0.02,0.66),
        _mat(Color(0.96,0.48,0.18),0.02,0.66),
        _mat(Color(0.36,0.76,0.34),0.02,0.66),
        _mat(Color(0.72,0.40,0.90),0.02,0.66)
    ]

    # --- Start / finish festival zone.
    var start_idx: int = 0
    var p: Vector3 = sample_points[start_idx]
    var t: Vector3 = sample_tangents[start_idx].normalized()
    var r: Vector3 = Vector3(-t.z,0.0,t.x).normalized()

    # Checkered start line.
    for lane in range(12):
        var tile: MeshInstance3D = MeshInstance3D.new()
        var tile_mesh: BoxMesh = BoxMesh.new()
        tile_mesh.size = Vector3(road_width/12.0,0.045,0.72)
        tile.mesh = tile_mesh
        tile.position = p + r*(-road_width*0.5 + (float(lane)+0.5)*(road_width/12.0)) + Vector3.UP*0.08
        tile.basis = Basis.looking_at(t,Vector3.UP)
        tile.material_override = white if lane%2==0 else navy
        add_child(tile)

    # Start gate pillars and overhead beam.
    for side in [-1.0,1.0]:
        var pillar: MeshInstance3D = MeshInstance3D.new()
        var pillar_mesh: BoxMesh = BoxMesh.new()
        pillar_mesh.size = Vector3(1.4,7.2,1.4)
        pillar.mesh = pillar_mesh
        pillar.position = p + r*float(side)*(road_width*0.5+2.0) + Vector3.UP*3.6
        pillar.material_override = cyan if side < 0.0 else yellow
        add_child(pillar)

        # Decorative flag/banner beside the gate.
        var flag: MeshInstance3D = MeshInstance3D.new()
        var flag_mesh: BoxMesh = BoxMesh.new()
        flag_mesh.size = Vector3(2.6,3.8,0.16)
        flag.mesh = flag_mesh
        flag.position = p + r*float(side)*(road_width*0.5+4.1) - t*1.5 + Vector3.UP*3.1
        flag.basis = Basis.looking_at(t,Vector3.UP)
        flag.material_override = pink if side < 0.0 else cyan
        add_child(flag)

    var beam: MeshInstance3D = MeshInstance3D.new()
    var beam_mesh: BoxMesh = BoxMesh.new()
    beam_mesh.size = Vector3(road_width+5.5,1.3,1.25)
    beam.mesh = beam_mesh
    beam.position = p + Vector3.UP*6.5
    beam.basis = Basis.looking_at(t,Vector3.UP)
    beam.material_override = navy
    add_child(beam)

    var start_sign: Label3D = Label3D.new()
    start_sign.text = "FOREST CIRCUIT  •  START"
    start_sign.font_size = 52
    start_sign.outline_size = 8
    start_sign.modulate = Color(0.95,0.99,1.0)
    start_sign.position = p - t*0.68 + Vector3.UP*6.52
    start_sign.basis = Basis.looking_at(t,Vector3.UP)
    add_child(start_sign)

    # World-space countdown lights on the start gate.
    for li in range(3):
        var light: MeshInstance3D = MeshInstance3D.new()
        var light_mesh: SphereMesh = SphereMesh.new()
        light_mesh.radius = 0.34
        light_mesh.height = 0.55
        light.mesh = light_mesh
        light.position = p + r*(float(li)-1.0)*1.05 - t*0.78 + Vector3.UP*5.55
        var lm: StandardMaterial3D = StandardMaterial3D.new()
        if li == 0:
            lm.albedo_color = Color(1.0,0.08,0.06)
            lm.emission = Color(1.0,0.03,0.02)
        elif li == 1:
            lm.albedo_color = Color(1.0,0.76,0.05)
            lm.emission = Color(1.0,0.42,0.01)
        else:
            lm.albedo_color = Color(0.08,1.0,0.28)
            lm.emission = Color(0.02,0.75,0.14)
        lm.emission_enabled = true
        lm.emission_energy_multiplier = 3.0
        light.material_override = lm
        add_child(light)

    # Staggered starting grid boxes for several karts.
    for row in range(4):
        var grid_idx: int = posmod(-6-row*4,n)
        var gp: Vector3 = sample_points[grid_idx]
        var gt: Vector3 = sample_tangents[grid_idx].normalized()
        var gr: Vector3 = Vector3(-gt.z,0.0,gt.x).normalized()
        for lane in [-1.0,1.0]:
            var box: MeshInstance3D = MeshInstance3D.new()
            var box_mesh: BoxMesh = BoxMesh.new()
            box_mesh.size = Vector3(3.7,0.025,5.0)
            box.mesh = box_mesh
            box.position = gp + gr*lane*4.1 + Vector3.UP*0.075
            box.basis = Basis.looking_at(gt,Vector3.UP)
            box.material_override = _mat(Color(0.94,0.96,1.0,1.0),0.0,0.50)
            add_child(box)

    # Grandstands on both sides of the starting straight.
    for side in [-1.0,1.0]:
        for section in range(3):
            var base_pos: Vector3 = p + r*float(side)*(road_width*0.5+9.5) + t*(float(section)-1.0)*10.0
            for tier in range(4):
                var stand: MeshInstance3D = MeshInstance3D.new()
                var stand_mesh: BoxMesh = BoxMesh.new()
                stand_mesh.size = Vector3(6.5,0.85,7.0)
                stand.mesh = stand_mesh
                stand.position = base_pos + r*float(side)*float(tier)*0.75 + Vector3.UP*(0.45+float(tier)*0.75)
                stand.basis = Basis.looking_at(t,Vector3.UP)
                stand.material_override = seat_mat if tier%2==0 else navy
                add_child(stand)

    # --- Arcade buildings, street lamps, billboards and flags around the whole course.
    for i in range(0,n,24):
        var bp: Vector3 = sample_points[i]
        var bt: Vector3 = sample_tangents[i].normalized()
        var br: Vector3 = Vector3(-bt.z,0.0,bt.x).normalized()

        for side in [-1.0,1.0]:
            var s: float = float(side)
            var outer: Vector3 = bp + br*s*(road_width*0.5+22.0+float((i/24)%3)*4.5)

            var building: MeshInstance3D = MeshInstance3D.new()
            var bm: BoxMesh = BoxMesh.new()
            var bh: float = 7.0 + float((i/24)%4)*2.2
            bm.size = Vector3(7.0, bh, 7.0)
            building.mesh = bm
            building.position = outer + Vector3.UP*(bh*0.5)
            building.rotation.y = atan2(bt.x,bt.z) + s*0.12
            building.material_override = building_mats[(i/24 + (0 if side < 0.0 else 1)) % building_mats.size()]
            add_child(building)

            var roof: MeshInstance3D = MeshInstance3D.new()
            var roof_mesh: CylinderMesh = CylinderMesh.new()
            roof_mesh.top_radius = 0.0
            roof_mesh.bottom_radius = 5.2
            roof_mesh.height = 3.0
            roof.mesh = roof_mesh
            roof.position = outer + Vector3.UP*(bh+1.5)
            roof.material_override = yellow if i%48==0 else pink
            add_child(roof)

            # Oversized arcade billboard.
            var billboard: MeshInstance3D = MeshInstance3D.new()
            var bb_mesh: BoxMesh = BoxMesh.new()
            bb_mesh.size = Vector3(5.8,3.0,0.22)
            billboard.mesh = bb_mesh
            billboard.position = bp + br*s*(road_width*0.5+5.1) + Vector3.UP*3.3
            billboard.basis = Basis.looking_at(bt,Vector3.UP)
            billboard.material_override = cyan if i%48==0 else yellow
            add_child(billboard)

        # Cartoonish streetlight.
        if i % 48 == 0:
            for side in [-1.0,1.0]:
                var pole: MeshInstance3D = MeshInstance3D.new()
                var pole_mesh: CylinderMesh = CylinderMesh.new()
                pole_mesh.top_radius = 0.10
                pole_mesh.bottom_radius = 0.16
                pole_mesh.height = 5.4
                pole.mesh = pole_mesh
                pole.position = bp + br*float(side)*(road_width*0.5+3.0) + Vector3.UP*2.7
                pole.material_override = navy
                add_child(pole)

                var lamp: MeshInstance3D = MeshInstance3D.new()
                var lamp_mesh: SphereMesh = SphereMesh.new()
                lamp_mesh.radius = 0.35
                lamp_mesh.height = 0.5
                lamp.mesh = lamp_mesh
                lamp.position = bp + br*float(side)*(road_width*0.5+3.0) + Vector3.UP*5.55
                lamp.material_override = yellow
                add_child(lamp)

    # --- Bright tunnel section.
    var tunnel_center: int = int(n*0.47)
    for step in range(-6,7,2):
        var idx: int = posmod(tunnel_center+step,n)
        var tp: Vector3 = sample_points[idx] + Vector3.UP*track_height_at(idx)
        var tt: Vector3 = sample_tangents[idx].normalized()
        var tr: Vector3 = Vector3(-tt.z,0.0,tt.x).normalized()

        for side in [-1.0,1.0]:
            var wall: MeshInstance3D = MeshInstance3D.new()
            var wall_mesh: BoxMesh = BoxMesh.new()
            wall_mesh.size = Vector3(1.1,6.0,4.8)
            wall.mesh = wall_mesh
            wall.position = tp + tr*float(side)*(road_width*0.5+0.7) + Vector3.UP*3.0
            wall.basis = Basis.looking_at(tt,Vector3.UP)
            wall.material_override = navy
            add_child(wall)

        var roof: MeshInstance3D = MeshInstance3D.new()
        var roof_mesh: BoxMesh = BoxMesh.new()
        roof_mesh.size = Vector3(road_width+2.2,0.8,4.8)
        roof.mesh = roof_mesh
        roof.position = tp + Vector3.UP*6.0
        roof.basis = Basis.looking_at(tt,Vector3.UP)
        roof.material_override = cyan if step%4==0 else pink
        add_child(roof)

    # --- Oversized directional arches on technical corners/S-sections.
    for frac in [0.11,0.34,0.57,0.79,0.91]:
        var idx: int = int(float(n)*float(frac))
        var ap: Vector3 = sample_points[idx] + Vector3.UP*track_height_at(idx)
        var at: Vector3 = sample_tangents[idx].normalized()
        var ar: Vector3 = Vector3(-at.z,0.0,at.x).normalized()

        for side in [-1.0,1.0]:
            var post: MeshInstance3D = MeshInstance3D.new()
            var post_mesh: BoxMesh = BoxMesh.new()
            post_mesh.size = Vector3(0.65,4.6,0.65)
            post.mesh = post_mesh
            post.position = ap + ar*float(side)*(road_width*0.5+1.1) + Vector3.UP*2.3
            post.material_override = yellow
            add_child(post)

        var arch: MeshInstance3D = MeshInstance3D.new()
        var arch_mesh: BoxMesh = BoxMesh.new()
        arch_mesh.size = Vector3(road_width+2.5,0.65,0.65)
        arch.mesh = arch_mesh
        arch.position = ap + Vector3.UP*4.45
        arch.basis = Basis.looking_at(at,Vector3.UP)
        arch.material_override = pink if idx%2==0 else cyan
        add_child(arch)

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

func _build_shortcuts() -> void:
    shortcut_routes.clear()
    if sample_points.is_empty():
        return

    var n: int = sample_points.size()
    var defs: Array[Dictionary] = [
        {
            "id":"woodland_drift",
            "name":"숨은 숲 샛길",
            "start":int(n*0.07),
            "end":int(n*0.13),
            "width":7.0,
            "offset":-8.5,
            "peak_height":0.0,
            "requirement":"drift",
            "theme":"dirt"
        },
        {
            "id":"boost_tunnel",
            "name":"부스터 터널",
            "start":int(n*0.33),
            "end":int(n*0.40),
            "width":6.2,
            "offset":10.0,
            "peak_height":0.0,
            "requirement":"boost",
            "theme":"tunnel"
        },
        {
            "id":"ridge_jump",
            "name":"언덕 위 비밀 루트",
            "start":int(n*0.79),
            "end":int(n*0.87),
            "width":6.6,
            "offset":-9.0,
            "peak_height":2.2,
            "requirement":"skill",
            "theme":"ridge"
        }
    ]

    for def in defs:
        var route: Dictionary = def.duplicate(true)
        route["points"] = _make_shortcut_points(route)
        shortcut_routes.append(route)
        _build_shortcut_route(route)

func _make_shortcut_points(route: Dictionary) -> Array[Vector3]:
    var points: Array[Vector3] = []
    var start_idx: int = int(route["start"])
    var end_idx: int = int(route["end"])
    var a: Vector3 = sample_points[start_idx]
    var b: Vector3 = sample_points[end_idx]
    var tangent: Vector3 = sample_tangents[start_idx]
    tangent.y = 0.0
    tangent = tangent.normalized()
    var right: Vector3 = Vector3(-tangent.z,0.0,tangent.x)
    var control: Vector3 = (a+b)*0.5 + right*float(route["offset"])
    var peak_height: float = float(route.get("peak_height",0.0))

    for i in range(13):
        var t: float = float(i)/12.0
        var omt: float = 1.0-t
        var p: Vector3 = omt*omt*a + 2.0*omt*t*control + t*t*b
        p.y = sin(PI*t)*peak_height
        points.append(p)
    return points

func _build_shortcut_route(route: Dictionary) -> void:
    var points: Array = route.get("points",[])
    if points.size() < 2:
        return

    var width: float = float(route.get("width",6.5))
    var theme: String = str(route.get("theme","dirt"))
    var road_mat: StandardMaterial3D
    if theme == "tunnel":
        road_mat = _mat(Color(0.08,0.11,0.14),0.18,0.58)
    elif theme == "ridge":
        road_mat = _mat(Color(0.31,0.22,0.11),0.02,0.88)
    else:
        road_mat = _mat(Color(0.30,0.19,0.085),0.0,0.96)

    var edge_mat: StandardMaterial3D = _mat(Color(0.16,0.38,0.10),0.0,0.88)
    var hint_mat: StandardMaterial3D = _mat(Color(0.92,0.72,0.12),0.08,0.32)
    hint_mat.emission_enabled = true
    hint_mat.emission = Color(0.25,0.12,0.01)
    hint_mat.emission_energy_multiplier = 1.3

    var body: StaticBody3D = StaticBody3D.new()
    body.name = "ShortcutCollision_" + str(route["id"])
    add_child(body)

    for i in range(points.size()-1):
        var a: Vector3 = points[i]
        var b: Vector3 = points[i+1]
        var mid: Vector3 = (a+b)*0.5
        var dir: Vector3 = (b-a).normalized()
        var length: float = a.distance_to(b)

        var road: MeshInstance3D = MeshInstance3D.new()
        var road_mesh: BoxMesh = BoxMesh.new()
        road_mesh.size = Vector3(width,0.22,length+0.30)
        road.mesh = road_mesh
        road.position = mid + Vector3.DOWN*0.02
        road.basis = Basis.looking_at(dir,Vector3.UP)
        road.material_override = road_mat
        add_child(road)

        var shape: BoxShape3D = BoxShape3D.new()
        shape.size = Vector3(width,0.24,length+0.34)
        var col: CollisionShape3D = CollisionShape3D.new()
        col.shape = shape
        col.position = mid + Vector3.DOWN*0.02
        col.basis = Basis.looking_at(dir,Vector3.UP)
        body.add_child(col)

        if i > 0 and i < points.size()-2 and i%3 == 0:
            var flat_dir: Vector3 = dir
            flat_dir.y = 0.0
            flat_dir = flat_dir.normalized()
            var side_vec: Vector3 = Vector3(-flat_dir.z,0.0,flat_dir.x)
            for side in [-1.0,1.0]:
                var marker: MeshInstance3D = MeshInstance3D.new()
                var mm: SphereMesh = SphereMesh.new()
                mm.radius = 0.38
                mm.height = 0.54
                marker.mesh = mm
                marker.scale = Vector3(1.2,0.7,0.9)
                marker.position = mid + side_vec*float(side)*(width*0.5+0.5) + Vector3.UP*0.27
                marker.material_override = edge_mat
                add_child(marker)

    var entry: Vector3 = points[1]
    var entry_dir: Vector3 = (points[2]-points[1]).normalized()
    var clue: MeshInstance3D = MeshInstance3D.new()
    var clue_mesh: BoxMesh = BoxMesh.new()
    clue_mesh.size = Vector3(1.65,0.10,0.42)
    clue.mesh = clue_mesh
    clue.position = entry + Vector3.UP*0.15
    clue.basis = Basis.looking_at(entry_dir,Vector3.UP)
    clue.material_override = hint_mat
    add_child(clue)

    if theme == "tunnel":
        _decorate_shortcut_tunnel(points,width)
    elif theme == "ridge":
        _decorate_shortcut_ridge(points,width)
    else:
        _decorate_shortcut_forest(points)

func _decorate_shortcut_forest(points: Array) -> void:
    var bush_mat: StandardMaterial3D = _mat(Color(0.035,0.27,0.065),0.0,0.94)
    for idx in [1,2,9,10]:
        if idx >= points.size():
            continue
        var bush: MeshInstance3D = MeshInstance3D.new()
        var bm: SphereMesh = SphereMesh.new()
        bm.radius = 0.72
        bm.height = 1.0
        bush.mesh = bm
        bush.scale = Vector3(1.4,0.65,0.95)
        bush.position = points[idx] + Vector3.UP*0.45
        bush.material_override = bush_mat
        add_child(bush)

func _decorate_shortcut_tunnel(points: Array, width: float) -> void:
    var shell_mat: StandardMaterial3D = _mat(Color(0.045,0.07,0.11),0.34,0.34)
    var glow_mat: StandardMaterial3D = _mat(Color(0.06,0.64,1.0),0.25,0.18)
    glow_mat.emission_enabled = true
    glow_mat.emission = Color(0.02,0.52,1.0)
    glow_mat.emission_energy_multiplier = 3.5

    for i in range(2,points.size()-2,2):
        var p: Vector3 = points[i]
        var dir: Vector3 = (points[min(i+1,points.size()-1)]-points[max(i-1,0)]).normalized()
        var right: Vector3 = Vector3(-dir.z,0.0,dir.x).normalized()

        for side in [-1.0,1.0]:
            var wall: MeshInstance3D = MeshInstance3D.new()
            var wm: BoxMesh = BoxMesh.new()
            wm.size = Vector3(0.65,4.0,2.5)
            wall.mesh = wm
            wall.position = p + right*float(side)*(width*0.5+0.25) + Vector3.UP*2.0
            wall.basis = Basis.looking_at(dir,Vector3.UP)
            wall.material_override = shell_mat
            add_child(wall)

        var roof: MeshInstance3D = MeshInstance3D.new()
        var rm: BoxMesh = BoxMesh.new()
        rm.size = Vector3(width+1.2,0.45,2.5)
        roof.mesh = rm
        roof.position = p + Vector3.UP*4.0
        roof.basis = Basis.looking_at(dir,Vector3.UP)
        roof.material_override = shell_mat
        add_child(roof)

        var strip: MeshInstance3D = MeshInstance3D.new()
        var sm: BoxMesh = BoxMesh.new()
        sm.size = Vector3(width*0.72,0.06,0.26)
        strip.mesh = sm
        strip.position = p + Vector3.UP*0.15
        strip.basis = Basis.looking_at(dir,Vector3.UP)
        strip.material_override = glow_mat
        add_child(strip)

func _decorate_shortcut_ridge(points: Array, width: float) -> void:
    var wood_mat: StandardMaterial3D = _mat(Color(0.26,0.15,0.07),0.0,0.92)
    for idx in [2,9]:
        if idx >= points.size():
            continue
        var p: Vector3 = points[idx]
        var dir: Vector3 = (points[min(idx+1,points.size()-1)]-points[max(idx-1,0)]).normalized()
        var ramp: MeshInstance3D = MeshInstance3D.new()
        var rm: BoxMesh = BoxMesh.new()
        rm.size = Vector3(width*0.92,0.24,3.2)
        ramp.mesh = rm
        ramp.position = p + Vector3.UP*0.10
        ramp.basis = Basis.looking_at(dir,Vector3.UP)
        ramp.material_override = wood_mat
        add_child(ramp)

func shortcut_info(world_pos: Vector3) -> Dictionary:
    var best: Dictionary = {"active":false}
    var best_distance: float = INF

    for route in shortcut_routes:
        var points: Array = route.get("points",[])
        if points.size() < 2:
            continue

        for i in range(points.size()-1):
            var a: Vector3 = points[i]
            var b: Vector3 = points[i+1]
            var ab: Vector3 = b-a
            ab.y = 0.0
            var len_sq: float = max(0.0001,ab.length_squared())
            var ap: Vector3 = world_pos-a
            ap.y = 0.0
            var local_t: float = clamp(ap.dot(ab)/len_sq,0.0,1.0)
            var closest: Vector3 = a + (b-a)*local_t
            var dx: float = world_pos.x-closest.x
            var dz: float = world_pos.z-closest.z
            var dist: float = sqrt(dx*dx+dz*dz)

            if dist < best_distance and dist <= float(route.get("width",6.5))*0.62:
                best_distance = dist
                var route_t: float = (float(i)+local_t)/float(points.size()-1)
                var start_idx: int = int(route["start"])
                var end_idx: int = int(route["end"])
                best = {
                    "active":true,
                    "id":str(route["id"]),
                    "name":str(route["name"]),
                    "requirement":str(route["requirement"]),
                    "distance":dist,
                    "point":closest,
                    "segment_start":a,
                    "segment_end":b,
                    "width":float(route["width"]),
                    "height":closest.y,
                    "route_t":route_t,
                    "track_index":int(round(lerp(float(start_idx),float(end_idx),route_t)))
                }

    return best

func shortcut_entry_allowed(requirement: String, drifting: bool, boosting: bool, speed_value: float) -> bool:
    match requirement:
        "drift":
            return drifting and speed_value > 10.0
        "boost":
            return boosting
        "skill":
            return (drifting or boosting) and speed_value > 16.0
        _:
            return true

func confine_to_shortcut(world_pos: Vector3, info: Dictionary) -> Vector3:
    if not bool(info.get("active",false)):
        return world_pos

    var a: Vector3 = info["segment_start"]
    var b: Vector3 = info["segment_end"]
    var dir: Vector3 = b-a
    dir.y = 0.0
    dir = dir.normalized()
    var right: Vector3 = Vector3(-dir.z,0.0,dir.x)
    var center: Vector3 = info["point"]
    var lateral: float = (world_pos-center).dot(right)
    var limit: float = float(info.get("width",6.5))*0.5-0.55
    if abs(lateral) > limit:
        world_pos -= right*(lateral-clamp(lateral,-limit,limit))
    return world_pos

func reject_shortcut_position(info: Dictionary) -> Vector3:
    if not bool(info.get("active",false)):
        return Vector3.ZERO
    var idx: int = int(info.get("track_index",0))
    return sample_points[posmod(idx,sample_points.size())] + Vector3.UP*0.55

func confine_to_road(world_pos: Vector3, track_index: int) -> Vector3:
    if sample_points.is_empty():
        return world_pos

    # Normal-road confinement is intentionally independent from shortcuts.
    # Shortcut confinement is handled explicitly by KartController only after
    # its entry requirement has been validated. This prevents entrance trapping.
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

func _temple_box(parent: Node3D, pos: Vector3, size: Vector3, mat: StandardMaterial3D, basis: Basis = Basis.IDENTITY) -> MeshInstance3D:
    var mi: MeshInstance3D = MeshInstance3D.new()
    var mesh: BoxMesh = BoxMesh.new()
    mesh.size = size
    mi.mesh = mesh
    mi.position = pos
    mi.basis = basis
    mi.material_override = mat
    parent.add_child(mi)
    return mi

func _temple_cylinder(parent: Node3D, pos: Vector3, radius: float, height: float, mat: StandardMaterial3D) -> MeshInstance3D:
    var mi: MeshInstance3D = MeshInstance3D.new()
    var mesh: CylinderMesh = CylinderMesh.new()
    mesh.top_radius = radius*0.78
    mesh.bottom_radius = radius
    mesh.height = height
    mi.mesh = mesh
    mi.position = pos
    mi.material_override = mat
    parent.add_child(mi)
    return mi

func _build_lantern(root: Node3D, pos: Vector3, scale_value: float, warm: StandardMaterial3D, dark: StandardMaterial3D) -> void:
    _temple_cylinder(root,pos+Vector3.UP*(1.55*scale_value),0.075*scale_value,3.1*scale_value,dark)
    var lamp: MeshInstance3D = MeshInstance3D.new()
    var lamp_mesh: CylinderMesh = CylinderMesh.new()
    lamp_mesh.top_radius = 0.24*scale_value
    lamp_mesh.bottom_radius = 0.24*scale_value
    lamp_mesh.height = 0.50*scale_value
    lamp.mesh = lamp_mesh
    lamp.position = pos+Vector3.UP*(3.15*scale_value)
    lamp.material_override = warm
    root.add_child(lamp)

    var cap_top: MeshInstance3D = MeshInstance3D.new()
    var cap_mesh: CylinderMesh = CylinderMesh.new()
    cap_mesh.top_radius = 0.04*scale_value
    cap_mesh.bottom_radius = 0.34*scale_value
    cap_mesh.height = 0.22*scale_value
    cap_top.mesh = cap_mesh
    cap_top.position = pos+Vector3.UP*(3.48*scale_value)
    cap_top.material_override = dark
    root.add_child(cap_top)

func _build_bamboo_cluster(root: Node3D, center: Vector3, mat: StandardMaterial3D, leaf_mat: StandardMaterial3D, seed: int) -> void:
    for j in range(7):
        var angle: float = TAU*float(j)/7.0 + float(seed%7)*0.13
        var radius: float = 0.65 + float((j+seed)%3)*0.34
        var p: Vector3 = center + Vector3(cos(angle)*radius,0.0,sin(angle)*radius)
        var h: float = 5.6 + float((j*3+seed)%5)*0.72
        _temple_cylinder(root,p+Vector3.UP*(h*0.5),0.10+0.018*float(j%2),h,mat)

        for leaf_i in range(2):
            var leaf: MeshInstance3D = MeshInstance3D.new()
            var lm: SphereMesh = SphereMesh.new()
            lm.radius = 0.55+0.10*float((j+leaf_i)%2)
            lm.height = 0.50
            leaf.mesh = lm
            leaf.scale = Vector3(1.8,0.26,0.72)
            leaf.position = p + Vector3(
                cos(angle+float(leaf_i)*1.9)*0.45,
                h-0.9+float(leaf_i)*0.45,
                sin(angle+float(leaf_i)*1.9)*0.45
            )
            leaf.rotation_degrees.y = rad_to_deg(angle)+float(leaf_i)*38.0
            leaf.material_override = leaf_mat
            root.add_child(leaf)

func _build_cherry_tree(root: Node3D, center: Vector3, trunk_mat: StandardMaterial3D, blossom_mat: StandardMaterial3D, seed: int) -> void:
    var h: float = 3.6+float(seed%3)*0.45
    _temple_cylinder(root,center+Vector3.UP*(h*0.48),0.22,h,trunk_mat)
    for j in range(6):
        var a: float = TAU*float(j)/6.0 + float(seed%4)*0.21
        var crown: MeshInstance3D = MeshInstance3D.new()
        var cm: SphereMesh = SphereMesh.new()
        cm.radius = 0.95+0.12*float(j%2)
        cm.height = 1.10
        crown.mesh = cm
        crown.scale = Vector3(1.15,0.78,1.0)
        crown.position = center + Vector3(cos(a)*1.05,h+sin(float(j)*1.4)*0.26,sin(a)*0.78)
        crown.material_override = blossom_mat
        root.add_child(crown)

func _build_pagoda(root: Node3D, center: Vector3, facing: Vector3, scale_value: float, wall_mat: StandardMaterial3D, trim_mat: StandardMaterial3D, roof_mat: StandardMaterial3D, glow_mat: StandardMaterial3D) -> void:
    var right: Vector3 = Vector3(-facing.z,0.0,facing.x).normalized()
    var base_basis: Basis = Basis.looking_at(facing,Vector3.UP)

    _temple_box(root,center+Vector3.UP*(0.45*scale_value),Vector3(6.8,0.9,5.2)*scale_value,trim_mat,base_basis)

    for level in range(3):
        var y: float = (1.25+float(level)*2.25)*scale_value
        var shrink: float = 1.0-float(level)*0.15
        _temple_box(root,center+Vector3.UP*y,Vector3(5.1,1.55,3.8)*scale_value*shrink,wall_mat,base_basis)

        # Wide layered roof slab + gold underside.
        var roof_y: float = y+1.05*scale_value*shrink
        _temple_box(root,center+Vector3.UP*roof_y,Vector3(6.6,0.28,5.15)*scale_value*shrink,roof_mat,base_basis)
        _temple_box(root,center+Vector3.UP*(roof_y+0.18*scale_value),Vector3(5.9,0.12,4.55)*scale_value*shrink,trim_mat,base_basis)

        # Warm windows on both sides.
        for side in [-1.0,1.0]:
            var wp: Vector3 = center + right*float(side)*(1.50*scale_value*shrink) - facing*(1.93*scale_value*shrink) + Vector3.UP*y
            _temple_box(root,wp,Vector3(0.9,0.72,0.08)*scale_value*shrink,glow_mat,base_basis)

    var spire: MeshInstance3D = MeshInstance3D.new()
    var sm: CylinderMesh = CylinderMesh.new()
    sm.top_radius = 0.0
    sm.bottom_radius = 0.48*scale_value
    sm.height = 2.8*scale_value
    spire.mesh = sm
    spire.position = center+Vector3.UP*(7.9*scale_value)
    spire.material_override = trim_mat
    root.add_child(spire)

func _build_temple_gate(root: Node3D, p: Vector3, tangent: Vector3, scale_value: float, red_mat: StandardMaterial3D, roof_mat: StandardMaterial3D, gold_mat: StandardMaterial3D) -> void:
    var right: Vector3 = Vector3(-tangent.z,0.0,tangent.x).normalized()
    var basis: Basis = Basis.looking_at(tangent,Vector3.UP)
    var offset: float = road_width*0.5+2.8

    for side in [-1.0,1.0]:
        _temple_box(root,p+right*float(side)*offset+Vector3.UP*(3.2*scale_value),Vector3(0.75,6.4,0.75)*scale_value,red_mat,basis)
        _temple_box(root,p+right*float(side)*(offset+0.95*scale_value)+Vector3.UP*(1.05*scale_value),Vector3(1.1,2.1,1.1)*scale_value,roof_mat,basis)

    _temple_box(root,p+Vector3.UP*(5.95*scale_value),Vector3(road_width+7.5,0.72,1.05)*scale_value,red_mat,basis)
    _temple_box(root,p+Vector3.UP*(6.55*scale_value),Vector3(road_width+10.0,0.26,1.65)*scale_value,roof_mat,basis)
    _temple_box(root,p-tangent*(0.58*scale_value)+Vector3.UP*(5.90*scale_value),Vector3(4.3,1.45,0.18)*scale_value,gold_mat,basis)

func _build_dragon_statue(root: Node3D, center: Vector3, scale_value: float, gold_mat: StandardMaterial3D, rock_mat: StandardMaterial3D) -> void:
    _temple_cylinder(root,center+Vector3.UP*(0.75*scale_value),2.25*scale_value,1.50*scale_value,rock_mat)

    var prev: Vector3 = center+Vector3(-2.0*scale_value,2.0*scale_value,0.0)
    for i in range(12):
        var t: float = float(i)/11.0
        var a: float = t*TAU*1.20
        var p: Vector3 = center + Vector3(
            cos(a)*(2.4-0.7*t)*scale_value,
            (2.3+4.2*t)*scale_value,
            sin(a)*(1.5-0.3*t)*scale_value
        )
        var segment: MeshInstance3D = MeshInstance3D.new()
        var seg_mesh: SphereMesh = SphereMesh.new()
        seg_mesh.radius = (0.50-0.16*t)*scale_value
        seg_mesh.height = (0.72-0.18*t)*scale_value
        segment.mesh = seg_mesh
        segment.position = p
        segment.material_override = gold_mat
        root.add_child(segment)

        if i > 0:
            var dir: Vector3 = p-prev
            var link: MeshInstance3D = MeshInstance3D.new()
            var link_mesh: CylinderMesh = CylinderMesh.new()
            link_mesh.top_radius = (0.34-0.08*t)*scale_value
            link_mesh.bottom_radius = (0.39-0.08*t)*scale_value
            link_mesh.height = dir.length()
            link.mesh = link_mesh
            link.position = (prev+p)*0.5
            link.basis = Basis.looking_at(dir.normalized(),Vector3.UP).rotated(Vector3.RIGHT,PI*0.5)
            link.material_override = gold_mat
            root.add_child(link)
        prev = p

    var head: MeshInstance3D = MeshInstance3D.new()
    var hm: SphereMesh = SphereMesh.new()
    hm.radius = 0.72*scale_value
    hm.height = 0.85*scale_value
    head.mesh = hm
    head.scale = Vector3(1.5,0.80,1.0)
    head.position = prev+Vector3(0.0,0.20*scale_value,-0.25*scale_value)
    head.material_override = gold_mat
    root.add_child(head)

    for side in [-1.0,1.0]:
        var horn: MeshInstance3D = MeshInstance3D.new()
        var horn_mesh: CylinderMesh = CylinderMesh.new()
        horn_mesh.top_radius = 0.0
        horn_mesh.bottom_radius = 0.16*scale_value
        horn_mesh.height = 1.20*scale_value
        horn.mesh = horn_mesh
        horn.position = head.position+Vector3(float(side)*0.48*scale_value,0.62*scale_value,0.0)
        horn.rotation_degrees.z = float(side)*-24.0
        horn.material_override = gold_mat
        root.add_child(horn)

func _build_bamboo_temple_environment() -> void:
    if sample_points.is_empty():
        return

    var root: Node3D = Node3D.new()
    root.name = "CinematicForestVisualUpgrade"
    add_child(root)

    var n: int = sample_points.size()

    # --- Curbs: visual only, inside existing road/collision limits.
    var curb_mesh: BoxMesh = BoxMesh.new()
    curb_mesh.size = Vector3(0.72,0.055,1.85)
    var curb_red: StandardMaterial3D = _mat(Color(0.56,0.025,0.025),0.10,0.48)
    var curb_white: StandardMaterial3D = _mat(Color(0.76,0.78,0.80),0.08,0.42)
    var red_transforms: Array[Transform3D] = []
    var white_transforms: Array[Transform3D] = []

    # --- Drainage strip beside curb.
    var drain_mesh: BoxMesh = BoxMesh.new()
    drain_mesh.size = Vector3(0.30,0.035,1.85)
    var drain_mat: StandardMaterial3D = _mat(Color(0.045,0.050,0.055),0.30,0.55)
    var drain_transforms: Array[Transform3D] = []

    for i in range(0,n,3):
        var p: Vector3 = sample_points[i]
        var t: Vector3 = sample_tangents[i].normalized()
        var right: Vector3 = Vector3(-t.z,0.0,t.x).normalized()
        var yaw: float = atan2(t.x,t.z)
        var segment_basis: Basis = Basis(Vector3.UP,yaw)

        for side in [-1.0,1.0]:
            var s: float = float(side)
            var curb_pos: Vector3 = p+right*s*(road_width*0.5-0.38)+Vector3.UP*0.072
            var tr: Transform3D = Transform3D(segment_basis,curb_pos)
            if ((i/3)+int((s+1.0)*0.5))%2 == 0:
                red_transforms.append(tr)
            else:
                white_transforms.append(tr)

            var drain_pos: Vector3 = p+right*s*(road_width*0.5-0.95)+Vector3.UP*0.048
            drain_transforms.append(Transform3D(segment_basis,drain_pos))

    _add_multimesh(root,"CurbsRed",curb_mesh,curb_red,red_transforms)
    _add_multimesh(root,"CurbsWhite",curb_mesh,curb_white,white_transforms)
    _add_multimesh(root,"DrainageStrips",drain_mesh,drain_mat,drain_transforms)

    # --- Sparse asphalt wear patches/skid marks, all non-collision.
    var skid_mesh: BoxMesh = BoxMesh.new()
    skid_mesh.size = Vector3(0.12,0.012,3.8)
    var skid_mat: StandardMaterial3D = _mat(Color(0.025,0.026,0.030),0.05,0.62)
    skid_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    skid_mat.albedo_color.a = 0.54
    var skid_transforms: Array[Transform3D] = []
    for i in range(9,n,22):
        var p: Vector3 = sample_points[i]
        var t: Vector3 = sample_tangents[i].normalized()
        var r: Vector3 = Vector3(-t.z,0.0,t.x).normalized()
        var yaw: float = atan2(t.x,t.z)
        for lane in [-0.95,0.95]:
            skid_transforms.append(Transform3D(Basis(Vector3.UP,yaw),p+r*float(lane)+Vector3.UP*0.064))
    _add_multimesh(root,"PermanentSkidWear",skid_mesh,skid_mat,skid_transforms)

    # --- Distant forest wall: large low-detail conifers hide the map boundary.
    var distant_mesh: CylinderMesh = CylinderMesh.new()
    distant_mesh.top_radius = 0.0
    distant_mesh.bottom_radius = 5.2
    distant_mesh.height = 13.5
    distant_mesh.radial_segments = 6
    var distant_mat: StandardMaterial3D = _mat(Color(0.012,0.085,0.035),0.0,0.98)
    var distant_transforms: Array[Transform3D] = []
    for i in range(72):
        var a: float = TAU*float(i)/72.0
        var radial: float = 186.0+float(i%5)*8.0
        var pos: Vector3 = Vector3(cos(a)*radial,6.0+float(i%3)*1.2,sin(a)*radial)
        var scale_v: Vector3 = Vector3(1.0+float(i%4)*0.16,1.0+float((i+2)%3)*0.20,1.0)
        distant_transforms.append(Transform3D(Basis(Vector3.UP,a).scaled(scale_v),pos))
    _add_multimesh(root,"DistantForestLOD",distant_mesh,distant_mat,distant_transforms)

    # --- Mountain/cliff silhouettes, low count.
    var mountain_mat: StandardMaterial3D = _mat(Color(0.055,0.070,0.072),0.0,0.99)
    for i in range(12):
        var a: float = TAU*float(i)/12.0+0.11
        var block: MeshInstance3D = MeshInstance3D.new()
        var bm: BoxMesh = BoxMesh.new()
        bm.size = Vector3(34.0+float(i%3)*8.0,22.0+float(i%4)*5.5,28.0+float((i+1)%3)*9.0)
        block.mesh = bm
        block.position = Vector3(cos(a)*(214.0+float(i%2)*18.0),10.0+float(i%3)*4.0,sin(a)*(214.0+float(i%2)*18.0))
        block.rotation_degrees = Vector3(0,rad_to_deg(a)+float(i%3)*14.0,0)
        block.material_override = mountain_mat
        block.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        root.add_child(block)

    # --- Start/finish landmark arch: visual only, high clearance.
    var sp: Vector3 = sample_points[0]
    var st: Vector3 = sample_tangents[0].normalized()
    var sr: Vector3 = Vector3(-st.z,0.0,st.x).normalized()
    var arch_basis: Basis = Basis.looking_at(st,Vector3.UP)
    var arch_dark: StandardMaterial3D = _mat(Color(0.035,0.040,0.050),0.68,0.24)
    var arch_red: StandardMaterial3D = _mat(Color(0.72,0.018,0.018),0.72,0.18)
    arch_red.emission_enabled = true
    arch_red.emission = Color(0.28,0.006,0.006)
    arch_red.emission_energy_multiplier = 1.3

    for side in [-1.0,1.0]:
        var post: MeshInstance3D = MeshInstance3D.new()
        var pm: BoxMesh = BoxMesh.new()
        pm.size = Vector3(0.85,7.6,0.85)
        post.mesh = pm
        post.position = sp+sr*float(side)*(road_width*0.5+2.0)+Vector3.UP*3.8
        post.basis = arch_basis
        post.material_override = arch_dark
        root.add_child(post)

    var beam: MeshInstance3D = MeshInstance3D.new()
    var beam_mesh: BoxMesh = BoxMesh.new()
    beam_mesh.size = Vector3(road_width+5.0,0.86,0.92)
    beam.mesh = beam_mesh
    beam.position = sp+Vector3.UP*7.1
    beam.basis = arch_basis
    beam.material_override = arch_dark
    root.add_child(beam)

    var board: MeshInstance3D = MeshInstance3D.new()
    var board_mesh: BoxMesh = BoxMesh.new()
    board_mesh.size = Vector3(road_width*0.62,1.35,0.20)
    board.mesh = board_mesh
    board.position = sp+Vector3.UP*6.25-st*0.50
    board.basis = arch_basis
    board.material_override = arch_red
    root.add_child(board)

    # --- Corner chevrons / speed cues. Sparse and emissive.
    var chevron_mat: StandardMaterial3D = _mat(Color(0.95,0.30,0.055),0.30,0.22)
    chevron_mat.emission_enabled = true
    chevron_mat.emission = Color(0.36,0.055,0.008)
    chevron_mat.emission_energy_multiplier = 1.25
    for frac in [0.10,0.27,0.48,0.67,0.86]:
        var idx: int = int(float(n)*float(frac))
        var p: Vector3 = sample_points[idx]
        var tangent: Vector3 = sample_tangents[idx].normalized()
        var right: Vector3 = Vector3(-tangent.z,0.0,tangent.x).normalized()
        for j in range(3):
            var sign: MeshInstance3D = MeshInstance3D.new()
            var sm: BoxMesh = BoxMesh.new()
            sm.size = Vector3(1.25,0.72,0.10)
            sign.mesh = sm
            sign.position = p+right*(road_width*0.5+2.2)+tangent*(float(j)-1.0)*2.4+Vector3.UP*1.05
            sign.basis = Basis.looking_at(-right,Vector3.UP)
            sign.material_override = chevron_mat
            root.add_child(sign)

    # --- Only four real lights across the whole map to protect FPS.
    var warm: Color = Color(1.0,0.46,0.18)
    for frac in [0.02,0.31,0.58,0.81]:
        var idx: int = int(float(n)*float(frac))
        var p: Vector3 = sample_points[idx]
        var tangent: Vector3 = sample_tangents[idx].normalized()
        var right: Vector3 = Vector3(-tangent.z,0.0,tangent.x).normalized()
        var light: OmniLight3D = OmniLight3D.new()
        light.position = p+right*(road_width*0.5+5.0)+Vector3.UP*4.2
        light.light_color = warm
        light.light_energy = 1.45
        light.omni_range = 15.0
        light.shadow_enabled = false
        root.add_child(light)

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
