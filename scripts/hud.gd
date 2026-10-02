extends CanvasLayer
class_name RaceHUD

signal lobby_requested

var speed_label: Label
var lap_label: Label
var n2o_label: Label
var drift_bar: ProgressBar
var status_label: Label
var minimap: RaceMiniMap

func _ready() -> void:
    layer = 20

    var root: MarginContainer = MarginContainer.new()
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.add_theme_constant_override("margin_left",24)
    root.add_theme_constant_override("margin_top",20)
    add_child(root)

    var v: VBoxContainer = VBoxContainer.new()
    root.add_child(v)

    var title: Label = Label.new()
    title.text = "FOREST CIRCUIT KART 3D"
    title.add_theme_font_size_override("font_size",22)
    v.add_child(title)

    speed_label = Label.new()
    lap_label = Label.new()
    n2o_label = Label.new()
    status_label = Label.new()
    drift_bar = ProgressBar.new()
    drift_bar.min_value = 0
    drift_bar.max_value = 100
    drift_bar.custom_minimum_size = Vector2(260,20)

    v.add_child(speed_label)
    v.add_child(lap_label)
    v.add_child(n2o_label)
    v.add_child(status_label)
    v.add_child(drift_bar)

    minimap = RaceMiniMap.new()
    minimap.anchor_left = 1.0
    minimap.anchor_right = 1.0
    minimap.anchor_top = 0.0
    minimap.anchor_bottom = 0.0
    minimap.offset_left = -270.0
    minimap.offset_right = -24.0
    minimap.offset_top = 18.0
    minimap.offset_bottom = 208.0
    minimap.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(minimap)

    var lobby_button: Button = Button.new()
    lobby_button.text = "로비로"
    lobby_button.anchor_left = 1.0
    lobby_button.anchor_right = 1.0
    lobby_button.anchor_top = 0.0
    lobby_button.anchor_bottom = 0.0
    lobby_button.offset_left = -150.0
    lobby_button.offset_right = -24.0
    lobby_button.offset_top = 220.0
    lobby_button.offset_bottom = 264.0
    lobby_button.pressed.connect(_on_lobby_pressed)
    add_child(lobby_button)

    update_values(0,1,0,0.0,false)

func setup_minimap(track_points: Array[Vector3], kart_refs: Array[KartController], focus_kart: KartController) -> void:
    if minimap:
        minimap.setup(track_points,kart_refs,focus_kart)

func _on_lobby_pressed() -> void:
    lobby_requested.emit()

func update_values(speed: int, lap: int, n2o: int, drift: float, offroad: bool) -> void:
    speed_label.text = "SPEED  %d km/h" % speed
    lap_label.text = "LAP    %d / 3" % min(lap,3)
    n2o_label.text = "N2O    %d" % n2o
    drift_bar.value = drift
    status_label.text = "OFF ROAD - 감속" if offroad else "TRACK"
