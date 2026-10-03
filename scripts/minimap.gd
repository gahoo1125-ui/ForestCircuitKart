extends Control
class_name RaceMiniMap

var track_points: Array[Vector3] = []
var karts: Array[KartController] = []
var focus_kart: KartController
var min_x: float = -1.0
var max_x: float = 1.0
var min_z: float = -1.0
var max_z: float = 1.0

func setup(points: Array[Vector3], kart_refs: Array[KartController], focus: KartController) -> void:
    track_points = points
    karts = kart_refs
    focus_kart = focus
    _recalculate_bounds()
    queue_redraw()

func _process(_delta: float) -> void:
    queue_redraw()

func _recalculate_bounds() -> void:
    if track_points.is_empty():
        return
    min_x = track_points[0].x
    max_x = track_points[0].x
    min_z = track_points[0].z
    max_z = track_points[0].z
    for p in track_points:
        min_x = min(min_x,p.x)
        max_x = max(max_x,p.x)
        min_z = min(min_z,p.z)
        max_z = max(max_z,p.z)

func _map_point(world_pos: Vector3) -> Vector2:
    var pad: float = 14.0
    var usable_w: float = max(1.0,size.x - pad * 2.0)
    var usable_h: float = max(1.0,size.y - pad * 2.0)
    var nx: float = inverse_lerp(min_x,max_x,world_pos.x)
    var nz: float = inverse_lerp(min_z,max_z,world_pos.z)
    return Vector2(pad + nx * usable_w,pad + nz * usable_h)

func _draw() -> void:
    draw_rect(Rect2(Vector2.ZERO,size),Color(0.008,0.026,0.046,0.86),true)
    draw_rect(Rect2(Vector2(3,3),size-Vector2(6,6)),Color(0.18,0.72,0.94,0.72),false,2.0)

    if track_points.size() > 1:
        var line: PackedVector2Array = PackedVector2Array()
        for p in track_points:
            line.append(_map_point(p))
        line.append(_map_point(track_points[0]))
        draw_polyline(line,Color(0.62,0.88,0.98,0.92),4.0,true)
        draw_polyline(line,Color(0.18,0.20,0.23,1.0),2.0,true)

    for kart in karts:
        if kart == null or not is_instance_valid(kart):
            continue
        var pos: Vector2 = _map_point(kart.global_position)
        if kart == focus_kart:
            draw_circle(pos,6.0,Color(0.20,0.86,1.0))
            var forward: Vector3 = -kart.global_transform.basis.z.normalized()
            var dir := Vector2(forward.x,forward.z).normalized()
            draw_line(pos,pos + dir * 11.0,Color.WHITE,2.0,true)
        else:
            draw_circle(pos,4.0,Color(0.93,0.22,0.22))
