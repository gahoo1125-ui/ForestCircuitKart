extends Control
class_name KartRadarChart

var values: PackedFloat32Array = PackedFloat32Array([0.5,0.5,0.5,0.5,0.5,0.5])

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    queue_redraw()

func set_values(new_values: PackedFloat32Array) -> void:
    values = new_values
    queue_redraw()

func _point(index: int, radius: float, center: Vector2) -> Vector2:
    var angle: float = -PI * 0.5 + TAU * float(index) / 6.0
    return center + Vector2(cos(angle),sin(angle)) * radius

func _draw() -> void:
    var center: Vector2 = size * 0.5
    var radius: float = min(size.x,size.y) * 0.36

    for ring in range(1,6):
        var ring_points: PackedVector2Array = PackedVector2Array()
        var ring_radius: float = radius * float(ring) / 5.0
        for i in range(6):
            ring_points.append(_point(i,ring_radius,center))
        ring_points.append(ring_points[0])
        draw_polyline(ring_points,Color(0.35,0.38,0.42,0.72),1.0,true)

    for i in range(6):
        draw_line(center,_point(i,radius,center),Color(0.35,0.38,0.42,0.72),1.0,true)

    var filled: PackedVector2Array = PackedVector2Array()
    for i in range(6):
        var value: float = 0.0
        if i < values.size():
            value = clamp(values[i],0.0,1.0)
        filled.append(_point(i,radius*value,center))

    if filled.size() == 6:
        draw_colored_polygon(filled,Color(1.0,0.65,0.08,0.30))
        var outline: PackedVector2Array = filled.duplicate()
        outline.append(filled[0])
        draw_polyline(outline,Color(1.0,0.76,0.18,1.0),3.0,true)
        for p in filled:
            draw_circle(p,4.0,Color(1.0,0.88,0.36,1.0))
