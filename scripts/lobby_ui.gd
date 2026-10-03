extends CanvasLayer
class_name LobbyUI

signal start_requested(mode_value: String, kart_id: String, host_ip: String)

var kart_data: Dictionary = {}
var kart_order: Array[String] = []
var selected_kart: String = "rookie"
var selected_mode: String = "cpu"

var mode_label: Label
var selected_label: Label
var network_status_label: Label
var result_label: Label
var ip_edit: LineEdit
var description_label: Label
var radar: KartRadarChart
var stat_labels: Array[Label] = []
var preview_viewport: SubViewport
var preview_kart: KartController
var preview_container: SubViewportContainer
var preview_dragging: bool = false
var preview_auto_rotate: bool = true

var kart_list: VBoxContainer

func _make_panel_style(bg: Color, border: Color) -> StyleBoxFlat:
    var s: StyleBoxFlat = StyleBoxFlat.new()
    s.bg_color = bg
    s.border_color = border
    s.set_border_width_all(2)
    s.corner_radius_top_left = 7
    s.corner_radius_top_right = 7
    s.corner_radius_bottom_left = 7
    s.corner_radius_bottom_right = 7
    return s

func _style_compact_button(b: Button) -> void:
    b.add_theme_font_size_override("font_size",15)
    b.add_theme_stylebox_override("normal",_make_panel_style(Color(0.015,0.050,0.078,0.94),Color(0.12,0.35,0.48,0.72)))
    b.add_theme_stylebox_override("hover",_make_panel_style(Color(0.025,0.16,0.22,0.98),Color(0.22,0.80,1.0,1.0)))
    b.add_theme_stylebox_override("pressed",_make_panel_style(Color(0.05,0.35,0.46,1.0),Color(0.45,0.92,1.0,1.0)))

func _ready() -> void:
    layer = 30
    _build_ui()
    set_process(true)

func configure(data: Dictionary, order: Array[String], lan_ip: String, lan_port: int) -> void:
    kart_data = data
    kart_order = order.duplicate()
    network_status_label.text = "내 LAN IP: %s   PORT %d" % [lan_ip,lan_port]
    _populate_karts()
    _select_mode("cpu")
    _select_kart("rookie")

func _build_ui() -> void:
    var root: Control = Control.new()
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(root)

    var bg: ColorRect = ColorRect.new()
    bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    bg.color = Color(0.008,0.022,0.040,0.985)
    root.add_child(bg)

    var outer: MarginContainer = MarginContainer.new()
    outer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    outer.add_theme_constant_override("margin_left",22)
    outer.add_theme_constant_override("margin_right",22)
    outer.add_theme_constant_override("margin_top",18)
    outer.add_theme_constant_override("margin_bottom",18)
    root.add_child(outer)

    var main_v: VBoxContainer = VBoxContainer.new()
    main_v.add_theme_constant_override("separation",10)
    outer.add_child(main_v)

    var title: Label = Label.new()
    title.text = "FOREST CIRCUIT"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size",34)
    title.modulate = Color(0.96,0.99,1.0)
    main_v.add_child(title)

    var sub: Label = Label.new()
    sub.text = "KART GARAGE  /  SELECT MACHINE"
    sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    sub.modulate = Color(0.30,0.82,1.0)
    main_v.add_child(sub)

    var columns: HBoxContainer = HBoxContainer.new()
    columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
    columns.add_theme_constant_override("separation",12)
    main_v.add_child(columns)

    var left_panel: PanelContainer = PanelContainer.new()
    left_panel.custom_minimum_size = Vector2(270,0)
    left_panel.add_theme_stylebox_override("panel",_make_panel_style(Color(0.012,0.035,0.060,0.92),Color(0.14,0.53,0.72,0.72)))
    columns.add_child(left_panel)
    var left_margin: MarginContainer = MarginContainer.new()
    for side in ["margin_left","margin_right","margin_top","margin_bottom"]:
        left_margin.add_theme_constant_override(side,12)
    left_panel.add_child(left_margin)
    var left_v: VBoxContainer = VBoxContainer.new()
    left_v.add_theme_constant_override("separation",8)
    left_margin.add_child(left_v)

    var mode_title: Label = Label.new()
    mode_title.text = "RACE MODE"
    mode_title.add_theme_font_size_override("font_size",18)
    left_v.add_child(mode_title)

    mode_label = Label.new()
    left_v.add_child(mode_label)

    _add_mode_button(left_v,"CPU 대전","cpu")
    _add_mode_button(left_v,"화면분할 2P","split")
    _add_mode_button(left_v,"LAN 호스트","lan_host")
    _add_mode_button(left_v,"LAN 참가","lan_join")

    ip_edit = LineEdit.new()
    ip_edit.placeholder_text = "호스트 LAN IP"
    ip_edit.text = "127.0.0.1"
    left_v.add_child(ip_edit)

    var sep: HSeparator = HSeparator.new()
    left_v.add_child(sep)

    var kart_title: Label = Label.new()
    kart_title.text = "KART SELECT"
    kart_title.add_theme_font_size_override("font_size",18)
    left_v.add_child(kart_title)

    var scroll: ScrollContainer = ScrollContainer.new()
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    left_v.add_child(scroll)
    kart_list = VBoxContainer.new()
    kart_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    kart_list.add_theme_constant_override("separation",5)
    scroll.add_child(kart_list)

    var center_panel: PanelContainer = PanelContainer.new()
    center_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    center_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
    center_panel.custom_minimum_size = Vector2(560,500)
    center_panel.add_theme_stylebox_override("panel",_make_panel_style(Color(0.008,0.026,0.048,0.82),Color(0.16,0.68,0.92,0.78)))
    columns.add_child(center_panel)

    var center_margin: MarginContainer = MarginContainer.new()
    for side in ["margin_left","margin_right","margin_top","margin_bottom"]:
        center_margin.add_theme_constant_override(side,10)
    center_panel.add_child(center_margin)

    var center_v: VBoxContainer = VBoxContainer.new()
    center_v.add_theme_constant_override("separation",8)
    center_margin.add_child(center_v)

    selected_label = Label.new()
    selected_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    selected_label.add_theme_font_size_override("font_size",22)
    center_v.add_child(selected_label)

    preview_container = SubViewportContainer.new()
    preview_container.stretch = true
    preview_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
    preview_container.custom_minimum_size = Vector2(520,410)
    preview_container.gui_input.connect(_on_preview_input)
    center_v.add_child(preview_container)

    preview_viewport = SubViewport.new()
    preview_viewport.size = Vector2i(720,480)
    preview_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    preview_viewport.own_world_3d = true
    preview_container.add_child(preview_viewport)
    _build_preview_world()

    var preview_help: Label = Label.new()
    preview_help.text = "자동 회전 · 마우스로 드래그해서 직접 둘러보기"
    preview_help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    preview_help.modulate = Color(0.74,0.76,0.80)
    center_v.add_child(preview_help)

    description_label = Label.new()
    description_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    description_label.custom_minimum_size.y = 42
    center_v.add_child(description_label)

    var start_button: Button = Button.new()
    start_button.text = "RACE START"
    start_button.custom_minimum_size = Vector2(0,64)
    start_button.add_theme_font_size_override("font_size",24)
    start_button.tooltip_text = "선택한 카트와 모드로 레이스 시작"
    var start_style: StyleBoxFlat = StyleBoxFlat.new()
    start_style.bg_color = Color(0.08,0.66,0.92,0.98)
    start_style.border_color = Color(0.42,0.90,1.0,1.0)
    start_style.set_border_width_all(2)
    start_style.corner_radius_top_left = 10
    start_style.corner_radius_top_right = 10
    start_style.corner_radius_bottom_left = 10
    start_style.corner_radius_bottom_right = 10
    start_button.add_theme_stylebox_override("normal",start_style)
    start_button.pressed.connect(_on_start_pressed)
    center_v.add_child(start_button)

    var right_panel: PanelContainer = PanelContainer.new()
    right_panel.custom_minimum_size = Vector2(315,0)
    right_panel.add_theme_stylebox_override("panel",_make_panel_style(Color(0.012,0.035,0.060,0.92),Color(0.14,0.53,0.72,0.72)))
    columns.add_child(right_panel)
    var right_margin: MarginContainer = MarginContainer.new()
    for side in ["margin_left","margin_right","margin_top","margin_bottom"]:
        right_margin.add_theme_constant_override(side,12)
    right_panel.add_child(right_margin)
    var right_v: VBoxContainer = VBoxContainer.new()
    right_v.add_theme_constant_override("separation",7)
    right_margin.add_child(right_v)

    var stat_title: Label = Label.new()
    stat_title.text = "PERFORMANCE"
    stat_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    stat_title.add_theme_font_size_override("font_size",20)
    right_v.add_child(stat_title)

    radar = KartRadarChart.new()
    radar.custom_minimum_size = Vector2(285,285)
    right_v.add_child(radar)

    var names: Array[String] = ["속도","가속","코너링","드리프트","부스터","그립"]
    for n in names:
        var label: Label = Label.new()
        label.text = n
        label.add_theme_font_size_override("font_size",15)
        right_v.add_child(label)
        stat_labels.append(label)

    var spacer: Control = Control.new()
    spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
    right_v.add_child(spacer)

    network_status_label = Label.new()
    network_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    network_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    main_v.add_child(network_status_label)

    result_label = Label.new()
    result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    result_label.add_theme_font_size_override("font_size",16)
    main_v.add_child(result_label)

func _build_preview_world() -> void:
    var env_node: WorldEnvironment = WorldEnvironment.new()
    var env: Environment = Environment.new()
    env.background_mode = Environment.BG_COLOR
    env.background_color = Color(0.006,0.020,0.038)
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color(0.62,0.67,0.78)
    env.ambient_light_energy = 1.15
    env_node.environment = env
    preview_viewport.add_child(env_node)

    var key: DirectionalLight3D = DirectionalLight3D.new()
    key.rotation_degrees = Vector3(-48,-32,0)
    key.light_energy = 2.0
    key.shadow_enabled = true
    preview_viewport.add_child(key)

    var fill: OmniLight3D = OmniLight3D.new()
    fill.position = Vector3(-3.5,2.6,-2.5)
    fill.light_energy = 4.0
    fill.omni_range = 10.0
    preview_viewport.add_child(fill)

    var rim: OmniLight3D = OmniLight3D.new()
    rim.position = Vector3(3.0,2.0,2.8)
    rim.light_energy = 3.0
    rim.omni_range = 9.0
    rim.light_color = Color(0.18,0.78,1.0)
    preview_viewport.add_child(rim)

    var floor: MeshInstance3D = MeshInstance3D.new()
    var floor_mesh: CylinderMesh = CylinderMesh.new()
    floor_mesh.top_radius = 3.4
    floor_mesh.bottom_radius = 3.5
    floor_mesh.height = 0.12
    floor.mesh = floor_mesh
    floor.position.y = -0.08
    var floor_mat: StandardMaterial3D = StandardMaterial3D.new()
    floor_mat.albedo_color = Color(0.025,0.070,0.095)
    floor_mat.metallic = 0.75
    floor_mat.roughness = 0.28
    floor.material_override = floor_mat
    preview_viewport.add_child(floor)

    var camera: Camera3D = Camera3D.new()
    camera.fov = 42.0
    camera.position = Vector3(4.6,2.35,-6.3)
    preview_viewport.add_child(camera)
    camera.look_at(Vector3(0,0.52,0),Vector3.UP)
    camera.make_current()

func _populate_karts() -> void:
    for child in kart_list.get_children():
        child.queue_free()
    for id in kart_order:
        if not kart_data.has(id):
            continue
        var entry: Dictionary = kart_data[id]
        var b: Button = Button.new()
        b.text = str(entry.get("display_name",id))
        b.custom_minimum_size.y = 46
        b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        _style_compact_button(b)
        b.pressed.connect(_select_kart.bind(id))
        kart_list.add_child(b)

func _add_mode_button(parent: VBoxContainer, text_value: String, mode_value: String) -> void:
    var b: Button = Button.new()
    b.text = text_value
    b.custom_minimum_size.y = 38
    _style_compact_button(b)
    b.pressed.connect(_select_mode.bind(mode_value))
    parent.add_child(b)

func _select_mode(mode_value: String) -> void:
    selected_mode = mode_value
    var names: Dictionary = {
        "cpu":"CPU 대전",
        "split":"화면분할 2P",
        "lan_host":"LAN 호스트",
        "lan_join":"LAN 참가"
    }
    mode_label.text = "선택 모드: " + str(names.get(mode_value,mode_value))

func _select_kart(id: String) -> void:
    if not kart_data.has(id):
        return
    selected_kart = id
    var entry: Dictionary = kart_data[id]
    selected_label.text = str(entry.get("display_name",id))
    description_label.text = str(entry.get("menu_description",""))
    result_label.text = ""
    _update_stats(entry)
    _spawn_preview(id)

func _update_stats(entry: Dictionary) -> void:
    var speed: float = clamp((float(entry.get("max_speed",36.0))-34.0)/14.0,0.0,1.0)
    var accel: float = clamp((float(entry.get("acceleration",19.0))-17.0)/9.0,0.0,1.0)
    var corner: float = clamp((float(entry.get("steer_rate",1.6))-1.45)/0.60,0.0,1.0)
    var drift: float = clamp((float(entry.get("drift_charge_rate",50.0))-40.0)/42.0,0.0,1.0)
    var boost: float = clamp((float(entry.get("boost_speed",44.0))-42.0)/18.0,0.0,1.0)
    var grip: float = clamp((float(entry.get("grip",6.0))-5.0)/3.2,0.0,1.0)
    var vals := PackedFloat32Array([speed,accel,corner,drift,boost,grip])
    radar.set_values(vals)

    var names: Array[String] = ["속도","가속","코너링","드리프트","부스터","그립"]
    for i in range(min(6,stat_labels.size())):
        stat_labels[i].text = "%s   %d" % [names[i],int(round(vals[i]*100.0))]

func _spawn_preview(id: String) -> void:
    if preview_kart and is_instance_valid(preview_kart):
        preview_kart.queue_free()
    preview_kart = KartController.new()
    preview_viewport.add_child(preview_kart)
    preview_kart.setup_preview(id)
    preview_kart.position = Vector3(0,0.18,0)
    preview_kart.rotation.y = deg_to_rad(22.0)
    preview_auto_rotate = true

func _process(delta: float) -> void:
    if preview_kart and is_instance_valid(preview_kart) and preview_auto_rotate and not preview_dragging:
        preview_kart.rotate_y(delta*0.42)

func _on_preview_input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
        preview_dragging = event.pressed
        if event.pressed:
            preview_auto_rotate = false
    elif event is InputEventMouseMotion and preview_dragging:
        if preview_kart and is_instance_valid(preview_kart):
            preview_kart.rotate_y(-event.relative.x*0.012)

func _on_start_pressed() -> void:
    start_requested.emit(selected_mode,selected_kart,ip_edit.text.strip_edges())
