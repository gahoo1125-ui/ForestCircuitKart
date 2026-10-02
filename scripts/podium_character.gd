extends Control
class_name PodiumCharacter

var body_color: Color = Color(0.3,0.7,1.0)
var anim_time: float = 0.0

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    set_process(true)
    queue_redraw()

func set_body_color(value: Color) -> void:
    body_color = value
    queue_redraw()

func _process(delta: float) -> void:
    anim_time += delta
    queue_redraw()

func _draw() -> void:
    var c: Vector2 = Vector2(size.x * 0.5,size.y * 0.60)
    var bounce: float = sin(anim_time * 5.0) * 3.0
    c.y += bounce

    var skin: Color = Color(1.0,0.78,0.62)
    var dark: Color = Color(0.04,0.045,0.055)
    var glow: Color = body_color.lightened(0.18)

    # Head / happy face.
    draw_circle(c + Vector2(0,-46),18.0,skin)
    draw_circle(c + Vector2(-6,-49),2.0,dark)
    draw_circle(c + Vector2(6,-49),2.0,dark)
    draw_arc(c + Vector2(0,-43),7.0,0.15,PI-0.15,18,dark,2.0,true)

    # Body and legs.
    draw_line(c + Vector2(0,-27),c + Vector2(0,24),body_color,14.0,true)
    draw_line(c + Vector2(0,20),c + Vector2(-18,48),dark,9.0,true)
    draw_line(c + Vector2(0,20),c + Vector2(18,48),dark,9.0,true)

    # Victory pose: both arms held high, with a tiny waving motion.
    var wave: float = sin(anim_time * 7.0) * 5.0
    draw_line(c + Vector2(-3,-17),c + Vector2(-34,-50-wave),glow,10.0,true)
    draw_line(c + Vector2(3,-17),c + Vector2(34,-50+wave),glow,10.0,true)
    draw_circle(c + Vector2(-35,-53-wave),6.0,skin)
    draw_circle(c + Vector2(35,-53+wave),6.0,skin)
