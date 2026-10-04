extends Control
class_name PodiumCharacter

var body_color: Color = Color(0.3,0.7,1.0)
var anim_time: float = 0.0
var dragon_armor: bool = false
var koala_mode: bool = false

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    set_process(true)
    queue_redraw()

func set_body_color(value: Color) -> void:
    body_color = value
    queue_redraw()

func set_dragon_armor(value: bool) -> void:
    dragon_armor = value
    queue_redraw()

func set_koala_mode(value: bool) -> void:
    koala_mode = value
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
    var wave: float = sin(anim_time * 7.0) * 5.0

    if koala_mode:
        var fur: Color = Color(0.44,0.47,0.50)
        var fur_light: Color = Color(0.72,0.73,0.72)
        var nose: Color = Color(0.035,0.04,0.045)
        var red: Color = Color(0.90,0.055,0.065)

        # Koala ears/head.
        draw_circle(c + Vector2(-18,-54),14.0,fur_light)
        draw_circle(c + Vector2(18,-54),14.0,fur_light)
        draw_circle(c + Vector2(0,-45),22.0,fur)
        draw_circle(c + Vector2(-7,-49),2.1,nose)
        draw_circle(c + Vector2(7,-49),2.1,nose)
        draw_circle(c + Vector2(0,-41),5.0,nose)
        draw_arc(c + Vector2(0,-57),18.5,PI+0.15,TAU-0.15,22,red,4.0,true)

        # Compact koala torso.
        draw_circle(c + Vector2(0,-4),20.0,fur)
        draw_circle(c + Vector2(0,-2),12.0,fur_light)

        # Victory arms with a strong runner pose.
        draw_line(c + Vector2(-10,-14),c + Vector2(-35,-52-wave),fur,12.0,true)
        draw_line(c + Vector2(10,-14),c + Vector2(35,-52+wave),fur,12.0,true)
        draw_circle(c + Vector2(-36,-55-wave),6.5,fur_light)
        draw_circle(c + Vector2(36,-55+wave),6.5,fur_light)

        draw_line(c + Vector2(-7,10),c + Vector2(-18,48),fur,13.0,true)
        draw_line(c + Vector2(7,10),c + Vector2(18,48),fur,13.0,true)
        draw_circle(c + Vector2(-19,49),7.0,nose)
        draw_circle(c + Vector2(19,49),7.0,nose)
        return

    if dragon_armor:
        var armor_black: Color = Color(0.025,0.03,0.04)
        var armor_gold: Color = Color(1.0,0.72,0.10)
        var armor_gold_bright: Color = Color(1.0,0.90,0.38)

        # Dragon helmet: black crown with gold horns and a narrow face opening.
        draw_circle(c + Vector2(0,-47),20.0,armor_black)
        draw_colored_polygon(PackedVector2Array([
            c + Vector2(-18,-58), c + Vector2(-31,-79), c + Vector2(-10,-66)
        ]),armor_gold)
        draw_colored_polygon(PackedVector2Array([
            c + Vector2(18,-58), c + Vector2(31,-79), c + Vector2(10,-66)
        ]),armor_gold)
        draw_colored_polygon(PackedVector2Array([
            c + Vector2(-14,-52), c + Vector2(0,-63), c + Vector2(14,-52),
            c + Vector2(11,-37), c + Vector2(-11,-37)
        ]),armor_gold)
        draw_circle(c + Vector2(0,-46),12.5,skin)
        draw_circle(c + Vector2(-4,-48),1.6,dark)
        draw_circle(c + Vector2(4,-48),1.6,dark)
        draw_arc(c + Vector2(0,-43),5.0,0.20,PI-0.20,14,dark,1.6,true)

        # Layered dragon-scale chest armor.
        draw_line(c + Vector2(0,-27),c + Vector2(0,24),armor_black,19.0,true)
        draw_line(c + Vector2(-2,-25),c + Vector2(-2,20),armor_gold,3.0,true)
        for yy in [-18.0,-7.0,4.0,15.0]:
            draw_arc(c + Vector2(0,yy),11.0,0.18,PI-0.18,16,armor_gold_bright,2.3,true)

        # Oversized dragon shoulder plates.
        draw_colored_polygon(PackedVector2Array([
            c + Vector2(-7,-22), c + Vector2(-31,-30), c + Vector2(-39,-19), c + Vector2(-18,-12)
        ]),armor_black)
        draw_colored_polygon(PackedVector2Array([
            c + Vector2(7,-22), c + Vector2(31,-30), c + Vector2(39,-19), c + Vector2(18,-12)
        ]),armor_black)
        draw_line(c + Vector2(-30,-28),c + Vector2(-39,-19),armor_gold,4.0,true)
        draw_line(c + Vector2(30,-28),c + Vector2(39,-19),armor_gold,4.0,true)

        # Victory arms in black/gold gauntlets.
        draw_line(c + Vector2(-8,-17),c + Vector2(-35,-50-wave),armor_black,12.0,true)
        draw_line(c + Vector2(8,-17),c + Vector2(35,-50+wave),armor_black,12.0,true)
        draw_line(c + Vector2(-9,-18),c + Vector2(-34,-49-wave),armor_gold,3.0,true)
        draw_line(c + Vector2(9,-18),c + Vector2(34,-49+wave),armor_gold,3.0,true)
        draw_circle(c + Vector2(-36,-54-wave),6.0,armor_gold_bright)
        draw_circle(c + Vector2(36,-54+wave),6.0,armor_gold_bright)

        # Armored legs and a short dragon-tail silhouette.
        draw_line(c + Vector2(-4,19),c + Vector2(-18,48),armor_black,11.0,true)
        draw_line(c + Vector2(4,19),c + Vector2(18,48),armor_black,11.0,true)
        draw_line(c + Vector2(-16,47),c + Vector2(-22,48),armor_gold,3.0,true)
        draw_line(c + Vector2(16,47),c + Vector2(22,48),armor_gold,3.0,true)
        var tail_points: PackedVector2Array = PackedVector2Array([
            c + Vector2(7,14), c + Vector2(32,18), c + Vector2(42,31),
            c + Vector2(29,28), c + Vector2(12,24)
        ])
        draw_colored_polygon(tail_points,armor_black)
        draw_polyline(PackedVector2Array([
            c + Vector2(10,18), c + Vector2(29,21), c + Vector2(38,29)
        ]),armor_gold,3.0,true)
        return

    # Standard cheerful podium character.
    draw_circle(c + Vector2(0,-46),18.0,skin)
    draw_circle(c + Vector2(-6,-49),2.0,dark)
    draw_circle(c + Vector2(6,-49),2.0,dark)
    draw_arc(c + Vector2(0,-43),7.0,0.15,PI-0.15,18,dark,2.0,true)

    draw_line(c + Vector2(0,-27),c + Vector2(0,24),body_color,14.0,true)
    draw_line(c + Vector2(0,20),c + Vector2(-18,48),dark,9.0,true)
    draw_line(c + Vector2(0,20),c + Vector2(18,48),dark,9.0,true)

    draw_line(c + Vector2(-3,-17),c + Vector2(-34,-50-wave),glow,10.0,true)
    draw_line(c + Vector2(3,-17),c + Vector2(34,-50+wave),glow,10.0,true)
    draw_circle(c + Vector2(-35,-53-wave),6.0,skin)
    draw_circle(c + Vector2(35,-53+wave),6.0,skin)
