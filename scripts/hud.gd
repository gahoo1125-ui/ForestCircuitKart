extends CanvasLayer
class_name RaceHUD

signal lobby_requested

var speed_label: Label
var lap_label: Label
var n2o_label: Label
var drift_bar: ProgressBar
var status_label: Label
var minimap: RaceMiniMap
var ranking_panel: PanelContainer
var ranking_title: Label
var ranking_label: RichTextLabel

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

    ranking_panel = PanelContainer.new()
    ranking_panel.anchor_left = 0.5
    ranking_panel.anchor_right = 0.5
    ranking_panel.anchor_top = 0.0
    ranking_panel.anchor_bottom = 0.0
    ranking_panel.offset_left = -190.0
    ranking_panel.offset_right = 190.0
    ranking_panel.offset_top = 14.0
    ranking_panel.offset_bottom = 202.0
    ranking_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(ranking_panel)

    var rank_style: StyleBoxFlat = StyleBoxFlat.new()
    rank_style.bg_color = Color(0.015,0.020,0.030,0.88)
    rank_style.border_color = Color(0.92,0.68,0.16,0.82)
    rank_style.set_border_width_all(2)
    rank_style.corner_radius_top_left = 10
    rank_style.corner_radius_top_right = 10
    rank_style.corner_radius_bottom_left = 10
    rank_style.corner_radius_bottom_right = 10
    ranking_panel.add_theme_stylebox_override("panel",rank_style)

    var rank_margin: MarginContainer = MarginContainer.new()
    rank_margin.add_theme_constant_override("margin_left",12)
    rank_margin.add_theme_constant_override("margin_right",12)
    rank_margin.add_theme_constant_override("margin_top",8)
    rank_margin.add_theme_constant_override("margin_bottom",8)
    ranking_panel.add_child(rank_margin)

    var rank_v: VBoxContainer = VBoxContainer.new()
    rank_v.add_theme_constant_override("separation",4)
    rank_margin.add_child(rank_v)

    ranking_title = Label.new()
    ranking_title.text = "LIVE RANKING"
    ranking_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    ranking_title.add_theme_font_size_override("font_size",18)
    rank_v.add_child(ranking_title)

    ranking_label = RichTextLabel.new()
    ranking_label.bbcode_enabled = true
    ranking_label.fit_content = true
    ranking_label.scroll_active = false
    ranking_label.custom_minimum_size = Vector2(350,138)
    ranking_label.add_theme_font_size_override("normal_font_size",15)
    rank_v.add_child(ranking_label)

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

        # Cars spawned a few samples behind the start line should rank behind,
        # not first, until they actually cross the line.
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

    # Small field: simple insertion sort keeps this deterministic and avoids comparator edge cases.
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
        if name_value.length() > 26:
            name_value = name_value.substr(0,25) + "…"

        var place_text: String = "%d위" % (i + 1)
        var row: String = "%-4s  %s" % [place_text,name_value]

        if entry["kart"] == focus_kart:
            text_value += "[color=#FFD45A][b]▶ %s[/b][/color]\n" % row
        elif i == 0:
            text_value += "[color=#FFF0A0][b]%s[/b][/color]\n" % row
        else:
            text_value += "%s\n" % row

    ranking_label.text = text_value
