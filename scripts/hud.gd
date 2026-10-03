extends CanvasLayer
class_name RaceHUD

signal lobby_requested

var speed_label: Label
var speed_unit_label: Label
var lap_label: Label
var n2o_label: Label
var drift_bar: ProgressBar
var status_label: Label
var minimap: RaceMiniMap
var ranking_panel: PanelContainer
var ranking_title: Label
var ranking_label: RichTextLabel

func _panel_style(bg: Color, border: Color, width: int = 2, radius: int = 8) -> StyleBoxFlat:
    var s: StyleBoxFlat = StyleBoxFlat.new()
    s.bg_color = bg
    s.border_color = border
    s.set_border_width_all(width)
    s.corner_radius_top_left = radius
    s.corner_radius_top_right = radius
    s.corner_radius_bottom_left = radius
    s.corner_radius_bottom_right = radius
    return s

func _ready() -> void:
    layer = 20

    # KartRider-like compact lap chip at the upper-left.
    var lap_panel: PanelContainer = PanelContainer.new()
    lap_panel.anchor_left = 0.0
    lap_panel.anchor_right = 0.0
    lap_panel.anchor_top = 0.0
    lap_panel.anchor_bottom = 0.0
    lap_panel.offset_left = 22.0
    lap_panel.offset_right = 226.0
    lap_panel.offset_top = 18.0
    lap_panel.offset_bottom = 88.0
    lap_panel.add_theme_stylebox_override("panel",_panel_style(Color(0.015,0.035,0.060,0.90),Color(0.17,0.78,1.0,0.92),2,6))
    add_child(lap_panel)

    var lap_margin: MarginContainer = MarginContainer.new()
    lap_margin.add_theme_constant_override("margin_left",14)
    lap_margin.add_theme_constant_override("margin_right",14)
    lap_margin.add_theme_constant_override("margin_top",8)
    lap_margin.add_theme_constant_override("margin_bottom",8)
    lap_panel.add_child(lap_margin)

    var lap_v: VBoxContainer = VBoxContainer.new()
    lap_v.add_theme_constant_override("separation",0)
    lap_margin.add_child(lap_v)

    var lap_caption: Label = Label.new()
    lap_caption.text = "RACE"
    lap_caption.modulate = Color(0.35,0.84,1.0)
    lap_caption.add_theme_font_size_override("font_size",13)
    lap_v.add_child(lap_caption)

    lap_label = Label.new()
    lap_label.add_theme_font_size_override("font_size",28)
    lap_v.add_child(lap_label)

    # Live ranking: narrow, left-aligned list rather than a large centered box.
    ranking_panel = PanelContainer.new()
    ranking_panel.anchor_left = 0.0
    ranking_panel.anchor_right = 0.0
    ranking_panel.anchor_top = 0.0
    ranking_panel.anchor_bottom = 0.0
    ranking_panel.offset_left = 22.0
    ranking_panel.offset_right = 330.0
    ranking_panel.offset_top = 100.0
    ranking_panel.offset_bottom = 292.0
    ranking_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
    ranking_panel.add_theme_stylebox_override("panel",_panel_style(Color(0.012,0.026,0.045,0.84),Color(0.20,0.52,0.68,0.62),1,6))
    add_child(ranking_panel)

    var rank_margin: MarginContainer = MarginContainer.new()
    rank_margin.add_theme_constant_override("margin_left",12)
    rank_margin.add_theme_constant_override("margin_right",12)
    rank_margin.add_theme_constant_override("margin_top",9)
    rank_margin.add_theme_constant_override("margin_bottom",9)
    ranking_panel.add_child(rank_margin)

    var rank_v: VBoxContainer = VBoxContainer.new()
    rank_v.add_theme_constant_override("separation",4)
    rank_margin.add_child(rank_v)

    ranking_title = Label.new()
    ranking_title.text = "POSITION"
    ranking_title.modulate = Color(0.35,0.84,1.0)
    ranking_title.add_theme_font_size_override("font_size",15)
    rank_v.add_child(ranking_title)

    ranking_label = RichTextLabel.new()
    ranking_label.bbcode_enabled = true
    ranking_label.fit_content = true
    ranking_label.scroll_active = false
    ranking_label.custom_minimum_size = Vector2(280,142)
    ranking_label.add_theme_font_size_override("normal_font_size",15)
    rank_v.add_child(ranking_label)

    # Top-right map.
    minimap = RaceMiniMap.new()
    minimap.anchor_left = 1.0
    minimap.anchor_right = 1.0
    minimap.anchor_top = 0.0
    minimap.anchor_bottom = 0.0
    minimap.offset_left = -286.0
    minimap.offset_right = -22.0
    minimap.offset_top = 18.0
    minimap.offset_bottom = 204.0
    minimap.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(minimap)

    var lobby_button: Button = Button.new()
    lobby_button.text = "GARAGE"
    lobby_button.anchor_left = 1.0
    lobby_button.anchor_right = 1.0
    lobby_button.anchor_top = 0.0
    lobby_button.anchor_bottom = 0.0
    lobby_button.offset_left = -142.0
    lobby_button.offset_right = -22.0
    lobby_button.offset_top = 214.0
    lobby_button.offset_bottom = 254.0
    lobby_button.add_theme_font_size_override("font_size",14)
    lobby_button.add_theme_stylebox_override("normal",_panel_style(Color(0.02,0.06,0.09,0.88),Color(0.20,0.72,0.92,0.72),1,5))
    lobby_button.add_theme_stylebox_override("hover",_panel_style(Color(0.04,0.18,0.25,0.95),Color(0.30,0.88,1.0,1.0),2,5))
    lobby_button.pressed.connect(_on_lobby_pressed)
    add_child(lobby_button)

    # Driver HUD at bottom-right: large speed, compact boost status.
    var drive_panel: PanelContainer = PanelContainer.new()
    drive_panel.anchor_left = 1.0
    drive_panel.anchor_right = 1.0
    drive_panel.anchor_top = 1.0
    drive_panel.anchor_bottom = 1.0
    drive_panel.offset_left = -352.0
    drive_panel.offset_right = -22.0
    drive_panel.offset_top = -184.0
    drive_panel.offset_bottom = -22.0
    drive_panel.add_theme_stylebox_override("panel",_panel_style(Color(0.01,0.025,0.045,0.84),Color(0.16,0.69,0.92,0.78),2,8))
    add_child(drive_panel)

    var drive_margin: MarginContainer = MarginContainer.new()
    drive_margin.add_theme_constant_override("margin_left",16)
    drive_margin.add_theme_constant_override("margin_right",16)
    drive_margin.add_theme_constant_override("margin_top",10)
    drive_margin.add_theme_constant_override("margin_bottom",10)
    drive_panel.add_child(drive_margin)

    var drive_v: VBoxContainer = VBoxContainer.new()
    drive_v.add_theme_constant_override("separation",3)
    drive_margin.add_child(drive_v)

    var speed_row: HBoxContainer = HBoxContainer.new()
    speed_row.alignment = BoxContainer.ALIGNMENT_END
    drive_v.add_child(speed_row)

    speed_label = Label.new()
    speed_label.add_theme_font_size_override("font_size",56)
    speed_label.modulate = Color(0.94,0.98,1.0)
    speed_row.add_child(speed_label)

    speed_unit_label = Label.new()
    speed_unit_label.text = " KM/H"
    speed_unit_label.add_theme_font_size_override("font_size",16)
    speed_unit_label.modulate = Color(0.35,0.84,1.0)
    speed_row.add_child(speed_unit_label)

    var info_row: HBoxContainer = HBoxContainer.new()
    info_row.add_theme_constant_override("separation",18)
    drive_v.add_child(info_row)

    n2o_label = Label.new()
    n2o_label.add_theme_font_size_override("font_size",17)
    n2o_label.modulate = Color(0.35,0.84,1.0)
    info_row.add_child(n2o_label)

    status_label = Label.new()
    status_label.add_theme_font_size_override("font_size",14)
    info_row.add_child(status_label)

    var drift_caption: Label = Label.new()
    drift_caption.text = "BOOST CHARGE"
    drift_caption.modulate = Color(0.58,0.72,0.82)
    drift_caption.add_theme_font_size_override("font_size",12)
    drive_v.add_child(drift_caption)

    drift_bar = ProgressBar.new()
    drift_bar.min_value = 0
    drift_bar.max_value = 100
    drift_bar.show_percentage = false
    drift_bar.custom_minimum_size = Vector2(290,14)
    var bar_bg: StyleBoxFlat = StyleBoxFlat.new()
    bar_bg.bg_color = Color(0.06,0.10,0.14,0.92)
    bar_bg.corner_radius_top_left = 3
    bar_bg.corner_radius_top_right = 3
    bar_bg.corner_radius_bottom_left = 3
    bar_bg.corner_radius_bottom_right = 3
    drift_bar.add_theme_stylebox_override("background",bar_bg)
    var bar_fill: StyleBoxFlat = StyleBoxFlat.new()
    bar_fill.bg_color = Color(0.10,0.78,1.0,1.0)
    bar_fill.corner_radius_top_left = 3
    bar_fill.corner_radius_top_right = 3
    bar_fill.corner_radius_bottom_left = 3
    bar_fill.corner_radius_bottom_right = 3
    drift_bar.add_theme_stylebox_override("fill",bar_fill)
    drive_v.add_child(drift_bar)

    update_values(0,1,0,0.0,false)

func setup_minimap(track_points: Array[Vector3], kart_refs: Array[KartController], focus_kart: KartController) -> void:
    if minimap:
        minimap.setup(track_points,kart_refs,focus_kart)

func _on_lobby_pressed() -> void:
    lobby_requested.emit()

func update_values(speed: int, lap: int, n2o: int, drift: float, offroad: bool) -> void:
    speed_label.text = "%03d" % speed
    lap_label.text = "LAP %d / 3" % min(lap,3)
    n2o_label.text = "N2O  × %d" % n2o
    drift_bar.value = drift
    if offroad:
        status_label.text = "OFF ROAD"
        status_label.modulate = Color(1.0,0.40,0.30)
    else:
        status_label.text = "ON TRACK"
        status_label.modulate = Color(0.72,0.92,1.0)

func update_rankings(kart_refs: Array[KartController], track_ref: TrackBuilder, data: Dictionary, focus_kart: KartController) -> void:
    if ranking_label == null or track_ref == null or track_ref.sample_points.is_empty():
        return

    var entries: Array[Dictionary] = []
    var n: int = track_ref.sample_points.size()

    for kart in kart_refs:
        if kart == null or not is_instance_valid(kart):
            continue

        var info: Dictionary = track_ref.nearest_track_info(kart.global_position)
        var idx: int = int(info.get("index",0))
        var adjusted_idx: int = idx

        if kart.lap <= 1 and kart.next_checkpoint == 0 and idx > int(float(n) * 0.75):
            adjusted_idx = idx - n

        var progress: int = (max(kart.lap,1) - 1) * n + adjusted_idx
        if kart.finished:
            progress += n * 4

        var display_name: String = kart.kart_id
        if data.has(kart.kart_id):
            display_name = str((data[kart.kart_id] as Dictionary).get("display_name",kart.kart_id))

        entries.append({
            "kart":kart,
            "name":display_name,
            "progress":progress
        })

    for i in range(1,entries.size()):
        var key: Dictionary = entries[i]
        var j: int = i - 1
        while j >= 0 and int(entries[j]["progress"]) < int(key["progress"]):
            entries[j + 1] = entries[j]
            j -= 1
        entries[j + 1] = key

    var text_value: String = ""
    var max_rows: int = min(entries.size(),6)
    for i in range(max_rows):
        var entry: Dictionary = entries[i]
        var name_value: String = str(entry["name"])
        if name_value.length() > 22:
            name_value = name_value.substr(0,21) + "…"

        var row: String = "%d   %s" % [i + 1,name_value]
        if entry["kart"] == focus_kart:
            text_value += "[color=#55DAFF][b]▶ %s[/b][/color]\n" % row
        elif i == 0:
            text_value += "[color=#FFE36B][b]%s[/b][/color]\n" % row
        else:
            text_value += "[color=#EAF6FF]%s[/color]\n" % row

    ranking_label.text = text_value
