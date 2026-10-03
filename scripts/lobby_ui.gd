extends CanvasLayer
class_name LobbyUI

signal start_requested(mode_value: String, kart_id: String, host_ip: String)

var kart_data: Dictionary = {}
var kart_order: Array[String] = []
var selected_kart: String = "rookie"
var selected_mode: String = "cpu"
var profile: Dictionary = {}

# Kept for Game.gd compatibility.
var mode_label: Label
var selected_label: Label
var network_status_label: Label
var result_label: Label
var ip_edit: LineEdit

var player_label: Label
var level_label: Label
var xp_bar: ProgressBar
var gold_label: Label
var displayed_gold: float = 0.0
var gold_tween: Tween

var content_root: VBoxContainer
var tab_title: Label
var preview_viewport: SubViewport
var preview_container: SubViewportContainer
var preview_kart: KartController
var preview_character: Node3D
var preview_dragging: bool = false
var preview_auto_rotate: bool = true
var selected_label_center: Label
var description_label: Label
var start_button: Button
var current_tab: String = "kart"

const RARITY_COLORS: Dictionary = {
    "일반":Color(0.78,0.84,0.90),
    "희귀":Color(0.20,0.70,1.0),
    "영웅":Color(0.68,0.28,1.0),
    "전설":Color(1.0,0.70,0.10)
}

func _ready() -> void:
    layer = 30
    profile = ProfileManager.load_profile()
    displayed_gold = float(profile.get("gold",0))
    selected_kart = str(profile.get("selected_kart","rookie"))
    _build_ui()
    set_process(true)

func configure(data: Dictionary, order: Array[String], lan_ip: String, lan_port: int) -> void:
    kart_data = data
    kart_order = order.duplicate()
    network_status_label.text = "LAN  %s : %d" % [lan_ip,lan_port]
    if not kart_data.has(selected_kart):
        selected_kart = "rookie"
    _select_mode("cpu")
    _select_kart(selected_kart)
    _open_tab("kart")
    _refresh_profile_bar()

func _panel(bg: Color = Color(0.012,0.035,0.060,0.94), border: Color = Color(0.14,0.53,0.72,0.72), radius: int = 8) -> StyleBoxFlat:
    var s: StyleBoxFlat = StyleBoxFlat.new()
    s.bg_color = bg
    s.border_color = border
    s.set_border_width_all(2)
    s.corner_radius_top_left = radius
    s.corner_radius_top_right = radius
    s.corner_radius_bottom_left = radius
    s.corner_radius_bottom_right = radius
    return s

func _style_button(b: Button, accent: bool = false) -> void:
    b.add_theme_font_size_override("font_size",15)
    if accent:
        b.add_theme_stylebox_override("normal",_panel(Color(0.06,0.56,0.86,0.98),Color(0.38,0.90,1.0,1.0),7))
        b.add_theme_stylebox_override("hover",_panel(Color(0.08,0.70,0.96,1.0),Color(0.62,0.96,1.0,1.0),7))
    else:
        b.add_theme_stylebox_override("normal",_panel(Color(0.015,0.050,0.078,0.94),Color(0.12,0.35,0.48,0.72),7))
        b.add_theme_stylebox_override("hover",_panel(Color(0.025,0.16,0.22,0.98),Color(0.22,0.80,1.0,1.0),7))

func _build_ui() -> void:
    var root: Control = Control.new()
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(root)

    var bg: ColorRect = ColorRect.new()
    bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    bg.color = Color(0.84,0.92,0.96,1.0)
    root.add_child(bg)

    # Slim racing-game top bar: player on the left, hub categories in the middle,
    # currency on the right. The 3D showroom stays dominant.
    var top: PanelContainer = PanelContainer.new()
    top.anchor_left = 0.0
    top.anchor_right = 1.0
    top.offset_bottom = 58.0
    top.add_theme_stylebox_override("panel",_panel(Color(0.97,0.985,1.0,0.96),Color(0.72,0.82,0.90,0.92),0))
    root.add_child(top)

    var top_margin: MarginContainer = MarginContainer.new()
    top_margin.add_theme_constant_override("margin_left",16)
    top_margin.add_theme_constant_override("margin_right",16)
    top_margin.add_theme_constant_override("margin_top",7)
    top_margin.add_theme_constant_override("margin_bottom",7)
    top.add_child(top_margin)

    var top_row: HBoxContainer = HBoxContainer.new()
    top_row.add_theme_constant_override("separation",10)
    top_margin.add_child(top_row)

    player_label = Label.new()
    player_label.add_theme_font_size_override("font_size",18)
    player_label.modulate = Color(0.08,0.12,0.18)
    top_row.add_child(player_label)

    level_label = Label.new()
    level_label.add_theme_font_size_override("font_size",15)
    level_label.modulate = Color(0.10,0.42,0.72)
    top_row.add_child(level_label)

    xp_bar = ProgressBar.new()
    xp_bar.custom_minimum_size = Vector2(150,15)
    xp_bar.show_percentage = false
    xp_bar.min_value = 0
    xp_bar.max_value = 1
    top_row.add_child(xp_bar)

    var left_space: Control = Control.new()
    left_space.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    top_row.add_child(left_space)

    for item in [
        ["카트","kart"],["모드","mode"],["맵","map"],["뽑기","gacha"],["장비","equipment"]
    ]:
        var b: Button = Button.new()
        b.text = str(item[0])
        b.custom_minimum_size = Vector2(72,38)
        _style_button(b,str(item[1]) == "kart")
        b.pressed.connect(_open_tab.bind(str(item[1])))
        top_row.add_child(b)

    var right_space: Control = Control.new()
    right_space.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    top_row.add_child(right_space)

    var gold_icon: Label = Label.new()
    gold_icon.text = "●"
    gold_icon.modulate = Color(1.0,0.70,0.06)
    gold_icon.add_theme_font_size_override("font_size",23)
    top_row.add_child(gold_icon)

    gold_label = Label.new()
    gold_label.add_theme_font_size_override("font_size",21)
    gold_label.modulate = Color(0.38,0.28,0.04)
    top_row.add_child(gold_label)

    # Main area: huge 3D plaza showroom + compact management panel.
    var main: HBoxContainer = HBoxContainer.new()
    main.anchor_left = 0.0
    main.anchor_right = 1.0
    main.anchor_top = 0.0
    main.anchor_bottom = 1.0
    main.offset_left = 0.0
    main.offset_right = 0.0
    main.offset_top = 58.0
    main.offset_bottom = -54.0
    main.add_theme_constant_override("separation",0)
    root.add_child(main)

    var show_panel: PanelContainer = PanelContainer.new()
    show_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    show_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
    show_panel.add_theme_stylebox_override("panel",_panel(Color(0.70,0.86,0.94,1.0),Color(0.70,0.82,0.90,1.0),0))
    main.add_child(show_panel)

    var show_v: VBoxContainer = VBoxContainer.new()
    show_v.add_theme_constant_override("separation",0)
    show_panel.add_child(show_v)

    preview_container = SubViewportContainer.new()
    preview_container.stretch = true
    preview_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
    preview_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    preview_container.custom_minimum_size = Vector2(720,520)
    preview_container.gui_input.connect(_on_preview_input)
    show_v.add_child(preview_container)

    preview_viewport = SubViewport.new()
    preview_viewport.size = Vector2i(960,600)
    preview_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    preview_viewport.own_world_3d = true
    preview_container.add_child(preview_viewport)
    _build_preview_world()

    # Selected machine plate, kept small like a racing lobby nameplate.
    var name_plate: PanelContainer = PanelContainer.new()
    name_plate.anchor_left = 0.5
    name_plate.anchor_right = 0.5
    name_plate.anchor_top = 0.18
    name_plate.anchor_bottom = 0.18
    name_plate.offset_left = -165
    name_plate.offset_right = 165
    name_plate.offset_top = -20
    name_plate.offset_bottom = 26
    name_plate.add_theme_stylebox_override("panel",_panel(Color(0.08,0.12,0.17,0.68),Color(0.72,0.84,0.93,0.65),3))
    root.add_child(name_plate)

    selected_label_center = Label.new()
    selected_label_center.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    selected_label_center.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    selected_label_center.add_theme_font_size_override("font_size",17)
    selected_label_center.modulate = Color(0.98,0.99,1.0)
    name_plate.add_child(selected_label_center)
    selected_label = selected_label_center

    description_label = Label.new()
    description_label.anchor_left = 0.5
    description_label.anchor_right = 0.5
    description_label.anchor_top = 1.0
    description_label.anchor_bottom = 1.0
    description_label.offset_left = -280
    description_label.offset_right = 280
    description_label.offset_top = -92
    description_label.offset_bottom = -66
    description_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    description_label.modulate = Color(0.08,0.12,0.18,0.88)
    root.add_child(description_label)

    # Compact management panel on the right; the world remains visible behind it.
    var content_panel: PanelContainer = PanelContainer.new()
    content_panel.custom_minimum_size = Vector2(355,0)
    content_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
    content_panel.add_theme_stylebox_override("panel",_panel(Color(0.015,0.035,0.055,0.88),Color(0.18,0.56,0.78,0.72),0))
    main.add_child(content_panel)

    var content_margin: MarginContainer = MarginContainer.new()
    content_margin.add_theme_constant_override("margin_left",13)
    content_margin.add_theme_constant_override("margin_right",13)
    content_margin.add_theme_constant_override("margin_top",12)
    content_margin.add_theme_constant_override("margin_bottom",70)
    content_panel.add_child(content_margin)

    content_root = VBoxContainer.new()
    content_root.add_theme_constant_override("separation",8)
    content_margin.add_child(content_root)

    tab_title = Label.new()
    tab_title.add_theme_font_size_override("font_size",22)
    tab_title.modulate = Color(0.42,0.88,1.0)
    content_root.add_child(tab_title)

    # Bottom control strip.
    var bottom: PanelContainer = PanelContainer.new()
    bottom.anchor_left = 0.0
    bottom.anchor_right = 1.0
    bottom.anchor_top = 1.0
    bottom.anchor_bottom = 1.0
    bottom.offset_top = -54
    bottom.add_theme_stylebox_override("panel",_panel(Color(0.96,0.98,1.0,0.97),Color(0.72,0.82,0.90,0.92),0))
    root.add_child(bottom)

    result_label = Label.new()
    result_label.anchor_left = 0.0
    result_label.anchor_right = 1.0
    result_label.anchor_top = 1.0
    result_label.anchor_bottom = 1.0
    result_label.offset_left = 18
    result_label.offset_right = -290
    result_label.offset_top = -46
    result_label.offset_bottom = -12
    result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    result_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    result_label.add_theme_font_size_override("font_size",15)
    result_label.modulate = Color(0.12,0.18,0.24)
    root.add_child(result_label)

    mode_label = Label.new()
    mode_label.anchor_left = 0.0
    mode_label.anchor_top = 1.0
    mode_label.anchor_bottom = 1.0
    mode_label.offset_left = 16
    mode_label.offset_right = 230
    mode_label.offset_top = -47
    mode_label.offset_bottom = -12
    mode_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    mode_label.modulate = Color(0.14,0.30,0.44)
    root.add_child(mode_label)

    network_status_label = Label.new()
    network_status_label.visible = false
    root.add_child(network_status_label)

    ip_edit = LineEdit.new()
    ip_edit.text = "127.0.0.1"
    ip_edit.visible = false
    root.add_child(ip_edit)

    start_button = Button.new()
    start_button.text = "게임 선택  ▶"
    start_button.anchor_left = 1.0
    start_button.anchor_right = 1.0
    start_button.anchor_top = 1.0
    start_button.anchor_bottom = 1.0
    start_button.offset_left = -260
    start_button.offset_right = -20
    start_button.offset_top = -112
    start_button.offset_bottom = -62
    start_button.add_theme_font_size_override("font_size",20)
    var start_normal: StyleBoxFlat = _panel(Color(1.0,0.76,0.04,0.98),Color(1.0,0.90,0.32,1.0),2)
    var start_hover: StyleBoxFlat = _panel(Color(1.0,0.84,0.10,1.0),Color(1.0,0.96,0.54,1.0),2)
    start_button.add_theme_stylebox_override("normal",start_normal)
    start_button.add_theme_stylebox_override("hover",start_hover)
    start_button.add_theme_color_override("font_color",Color(0.08,0.10,0.13))
    start_button.pressed.connect(_on_start_pressed)
    root.add_child(start_button)

func _preview_mat(color: Color, metallic: float = 0.0, roughness: float = 0.75) -> StandardMaterial3D:
    var m: StandardMaterial3D = StandardMaterial3D.new()
    m.albedo_color = color
    m.metallic = metallic
    m.roughness = roughness
    return m

func _preview_box(pos: Vector3, size: Vector3, mat: StandardMaterial3D) -> MeshInstance3D:
    var mi: MeshInstance3D = MeshInstance3D.new()
    var mesh: BoxMesh = BoxMesh.new()
    mesh.size = size
    mi.mesh = mesh
    mi.position = pos
    mi.material_override = mat
    preview_viewport.add_child(mi)
    return mi

func _preview_tree(pos: Vector3, crown_color: Color) -> void:
    var trunk: MeshInstance3D = MeshInstance3D.new()
    var trunk_mesh: CylinderMesh = CylinderMesh.new()
    trunk_mesh.top_radius = 0.13
    trunk_mesh.bottom_radius = 0.18
    trunk_mesh.height = 2.0
    trunk.mesh = trunk_mesh
    trunk.position = pos + Vector3.UP
    trunk.material_override = _preview_mat(Color(0.30,0.16,0.08),0.0,0.92)
    preview_viewport.add_child(trunk)

    var crown: MeshInstance3D = MeshInstance3D.new()
    var crown_mesh: SphereMesh = SphereMesh.new()
    crown_mesh.radius = 1.05
    crown_mesh.height = 1.65
    crown.mesh = crown_mesh
    crown.scale = Vector3(1.15,0.86,1.05)
    crown.position = pos + Vector3.UP*2.45
    crown.material_override = _preview_mat(crown_color,0.0,0.86)
    preview_viewport.add_child(crown)

func _preview_lamp(pos: Vector3) -> void:
    var pole: MeshInstance3D = MeshInstance3D.new()
    var pm: CylinderMesh = CylinderMesh.new()
    pm.top_radius = 0.055
    pm.bottom_radius = 0.075
    pm.height = 3.6
    pole.mesh = pm
    pole.position = pos + Vector3.UP*1.8
    pole.material_override = _preview_mat(Color(0.11,0.15,0.18),0.55,0.30)
    preview_viewport.add_child(pole)

    var lamp: MeshInstance3D = MeshInstance3D.new()
    var lm: SphereMesh = SphereMesh.new()
    lm.radius = 0.18
    lm.height = 0.28
    lamp.mesh = lm
    lamp.position = pos + Vector3(0.0,3.55,0.0)
    var glow: StandardMaterial3D = _preview_mat(Color(0.95,0.98,1.0),0.05,0.18)
    glow.emission_enabled = true
    glow.emission = Color(0.50,0.75,1.0)
    glow.emission_energy_multiplier = 1.8
    lamp.material_override = glow
    preview_viewport.add_child(lamp)

func _build_preview_world() -> void:
    var env_node: WorldEnvironment = WorldEnvironment.new()
    var env: Environment = Environment.new()
    env.background_mode = Environment.BG_COLOR
    env.background_color = Color(0.60,0.84,0.95)
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color(0.92,0.96,1.0)
    env.ambient_light_energy = 1.15
    env_node.environment = env
    preview_viewport.add_child(env_node)

    var sun: DirectionalLight3D = DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-52,-25,0)
    sun.light_energy = 1.75
    sun.shadow_enabled = true
    preview_viewport.add_child(sun)

    var fill: OmniLight3D = OmniLight3D.new()
    fill.position = Vector3(-3.5,3.0,-3.0)
    fill.light_energy = 2.2
    fill.omni_range = 13.0
    fill.light_color = Color(0.70,0.86,1.0)
    preview_viewport.add_child(fill)

    # Wide asphalt plaza similar in composition to a kart-racing lobby.
    var plaza: MeshInstance3D = MeshInstance3D.new()
    var plaza_mesh: PlaneMesh = PlaneMesh.new()
    plaza_mesh.size = Vector2(38,26)
    plaza.mesh = plaza_mesh
    plaza.position.y = -0.03
    plaza.material_override = _preview_mat(Color(0.17,0.20,0.22),0.02,0.86)
    preview_viewport.add_child(plaza)

    _preview_box(Vector3(0,0.08,5.25),Vector3(38,0.18,2.0),_preview_mat(Color(0.88,0.90,0.90),0.0,0.82))
    _preview_box(Vector3(0,0.20,6.0),Vector3(38,0.22,0.28),_preview_mat(Color(0.76,0.80,0.82),0.0,0.72))

    # Small colorful town background.
    var house_x: Array[float] = [-8.0,-4.2,0.0,4.4,8.2]
    for i in range(house_x.size()):
        var x: float = house_x[i]
        var h: float = 3.2 + float(i%3)*0.55
        var body_color: Color = [
            Color(0.88,0.86,0.78),
            Color(0.82,0.90,0.92),
            Color(0.95,0.88,0.82),
            Color(0.86,0.92,0.84),
            Color(0.90,0.84,0.88)
        ][i]
        _preview_box(Vector3(x,h*0.5,8.4),Vector3(3.1,h,2.5),_preview_mat(body_color,0.0,0.90))
        var roof: MeshInstance3D = _preview_box(Vector3(x,h+0.45,8.4),Vector3(3.6,0.85,2.9),_preview_mat(Color(0.56,0.18+0.04*float(i%2),0.12),0.0,0.84))
        roof.rotation_degrees.z = 4.0 if i%2==0 else -4.0

    for p in [Vector3(-6.6,0,4.9),Vector3(-2.8,0,5.1),Vector3(3.0,0,5.0),Vector3(6.8,0,5.1)]:
        _preview_tree(p,Color(0.95,0.54,0.68))

    for p in [Vector3(-8.6,0,3.9),Vector3(-4.7,0,4.0),Vector3(4.7,0,4.0),Vector3(8.6,0,3.9)]:
        _preview_lamp(p)

    # Planters / benches make the scene feel inhabited without stealing focus.
    for x in [-5.2,5.2]:
        _preview_box(Vector3(float(x),0.32,4.35),Vector3(2.2,0.55,0.75),_preview_mat(Color(0.64,0.48,0.32),0.0,0.88))
        _preview_box(Vector3(float(x),0.72,4.35),Vector3(1.85,0.32,0.65),_preview_mat(Color(0.12,0.46,0.18),0.0,0.92))

    var camera: Camera3D = Camera3D.new()
    camera.fov = 39.0
    camera.position = Vector3(0.0,2.65,-10.6)
    preview_viewport.add_child(camera)
    camera.look_at(Vector3(0.0,0.95,0.45),Vector3.UP)
    camera.make_current()

func _clear_content() -> void:
    for child in content_root.get_children():
        if child != tab_title:
            child.queue_free()

func _open_tab(tab: String) -> void:
    current_tab = tab
    if content_root == null:
        return
    _clear_content()
    match tab:
        "kart":
            _build_kart_tab()
        "mode":
            _build_mode_tab()
        "map":
            _build_map_tab()
        "gacha":
            _build_gacha_tab()
        "equipment":
            _build_equipment_tab()
        _:
            _build_kart_tab()

func _build_kart_tab() -> void:
    tab_title.text = "카트 / 강화"

    var scroll: ScrollContainer = ScrollContainer.new()
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    scroll.custom_minimum_size.y = 260
    content_root.add_child(scroll)

    var list: VBoxContainer = VBoxContainer.new()
    list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    list.add_theme_constant_override("separation",5)
    scroll.add_child(list)

    for id in kart_order:
        if not kart_data.has(id):
            continue
        var level: int = get_upgrade_level(id)
        var owned: bool = _owned_karts().has(id)
        var b: Button = Button.new()
        b.text = "%s   +%d%s" % [str((kart_data[id] as Dictionary).get("display_name",id)),level,("" if owned else "  [LOCK]")]
        b.custom_minimum_size.y = 42
        b.disabled = not owned
        _style_button(b)
        b.pressed.connect(_select_kart.bind(id))
        list.add_child(b)

    var locked: Label = Label.new()
    locked.text = "잠긴 카트: 오로라 캣 X / 타이거 제트 (추후 해금)"
    locked.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    locked.modulate = Color(0.52,0.62,0.72)
    content_root.add_child(locked)

    _add_upgrade_panel()

func _add_upgrade_panel() -> void:
    if not kart_data.has(selected_kart):
        return

    var lvl: int = get_upgrade_level(selected_kart)
    var title: Label = Label.new()
    title.text = "강화 레벨  +%d / +10" % lvl
    title.add_theme_font_size_override("font_size",18)
    content_root.add_child(title)

    var base: Dictionary = kart_data[selected_kart] as Dictionary
    var now: Dictionary = _effective_stats(base,lvl)
    var next: Dictionary = _effective_stats(base,min(10,lvl+1))

    var rows: Array = [
        ["최고 속도","max_speed"],["가속력","acceleration"],["드리프트","drift_charge_rate"],
        ["부스터","boost_speed"],["핸들링","steer_rate"]
    ]
    for row in rows:
        var l: Label = Label.new()
        var key: String = str(row[1])
        if key == "steer_rate":
            l.text = "%s  %.2f  →  %.2f" % [str(row[0]),float(now[key]),float(next[key])]
        else:
            l.text = "%s  %.1f  →  %.1f" % [str(row[0]),float(now[key]),float(next[key])]
        l.modulate = Color(0.82,0.90,0.96)
        content_root.add_child(l)

    var cost: int = upgrade_cost(lvl)
    var upgrade: Button = Button.new()
    upgrade.text = "강화하기   %d GOLD" % cost if lvl < 10 else "MAX +10"
    upgrade.disabled = lvl >= 10 or int(profile.get("gold",0)) < cost
    _style_button(upgrade,true)
    upgrade.pressed.connect(_upgrade_selected_kart)
    content_root.add_child(upgrade)

func _build_mode_tab() -> void:
    tab_title.text = "레이스 모드"

    _mode_option("일반 레이스","cpu","5명의 AI와 기본 레이스")
    _mode_option("AI 대전","cpu","현재 구현된 AI 대전")
    _mode_option("화면분할 2P","split","한 PC에서 2인 플레이")

    var item_btn: Button = Button.new()
    item_btn.text = "아이템전   · 준비 중"
    item_btn.disabled = true
    _style_button(item_btn)
    content_root.add_child(item_btn)

    var time_btn: Button = Button.new()
    time_btn.text = "타임어택   · 준비 중"
    time_btn.disabled = true
    _style_button(time_btn)
    content_root.add_child(time_btn)

    var multiplayer: Label = Label.new()
    multiplayer.text = "멀티플레이"
    multiplayer.add_theme_font_size_override("font_size",18)
    content_root.add_child(multiplayer)

    var host: Button = Button.new()
    host.text = "LAN 방 만들기"
    _style_button(host)
    host.pressed.connect(_select_mode.bind("lan_host"))
    content_root.add_child(host)

    var join: Button = Button.new()
    join.text = "LAN 방 참가"
    _style_button(join)
    join.pressed.connect(_select_mode.bind("lan_join"))
    content_root.add_child(join)

func _mode_option(text_value: String, mode_value: String, desc: String) -> void:
    var b: Button = Button.new()
    b.text = text_value
    b.tooltip_text = desc
    b.custom_minimum_size.y = 44
    _style_button(b)
    b.pressed.connect(_select_mode.bind(mode_value))
    content_root.add_child(b)

func _build_map_tab() -> void:
    tab_title.text = "맵 선택"

    _map_card("FOREST CIRCUIT","★★★★☆","숲 · 폭포 · 상층 트랙 · 터널 · 숙련자용 지름길 3개",true)
    _map_card("CRYSTAL CANYON","★★★★☆","수정 협곡 / 추후 업데이트",false)
    _map_card("SKY GARDEN","★★★★★","공중 정원 / 추후 업데이트",false)

func _map_card(name_value: String, difficulty: String, desc: String, unlocked: bool) -> void:
    var p: PanelContainer = PanelContainer.new()
    p.custom_minimum_size = Vector2(0,112)
    p.add_theme_stylebox_override("panel",_panel(Color(0.018,0.052,0.078,0.94),Color(0.16,0.52,0.70,0.70),7))
    content_root.add_child(p)

    var m: MarginContainer = MarginContainer.new()
    m.add_theme_constant_override("margin_left",12)
    m.add_theme_constant_override("margin_right",12)
    m.add_theme_constant_override("margin_top",9)
    m.add_theme_constant_override("margin_bottom",9)
    p.add_child(m)

    var v: VBoxContainer = VBoxContainer.new()
    m.add_child(v)
    var n: Label = Label.new()
    n.text = name_value + ("" if unlocked else "  🔒")
    n.add_theme_font_size_override("font_size",18)
    v.add_child(n)
    var d: Label = Label.new()
    d.text = "난이도 " + difficulty
    d.modulate = Color(1.0,0.78,0.26)
    v.add_child(d)
    var info: Label = Label.new()
    info.text = desc
    info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    v.add_child(info)

func _build_gacha_tab() -> void:
    tab_title.text = "골드 뽑기"

    var info: Label = Label.new()
    info.text = "카트 · 장비 · 캐릭터 꾸미기\n일반 60%  /  희귀 25%  /  영웅 11%  /  전설 4%"
    info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    info.modulate = Color(0.80,0.90,0.98)
    content_root.add_child(info)

    var one: Button = Button.new()
    one.text = "1회 뽑기   800 GOLD"
    one.disabled = int(profile.get("gold",0)) < 800
    _style_button(one,true)
    one.pressed.connect(_perform_gacha.bind(1))
    content_root.add_child(one)

    var ten: Button = Button.new()
    ten.text = "10회 뽑기   7,200 GOLD"
    ten.disabled = int(profile.get("gold",0)) < 7200
    _style_button(ten,true)
    ten.pressed.connect(_perform_gacha.bind(10))
    content_root.add_child(ten)

    var list: Label = Label.new()
    list.text = "주요 획득품\n전설: 종결 카트 / 골드 윙\n영웅: 엔진 코어 / 하이브리드 카트\n희귀: 터보 칩 / 드리프트 링\n일반: 타이어 / 꾸미기 아이템"
    list.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    list.modulate = Color(0.64,0.76,0.86)
    content_root.add_child(list)

func _build_equipment_tab() -> void:
    tab_title.text = "장비"
    var equipped: String = str(profile.get("equipped_equipment",""))

    for item in _equipment_defs():
        var id: String = str(item["id"])
        var owned: bool = _owned_equipment().has(id)
        var b: Button = Button.new()
        b.text = "%s%s%s" % [
            str(item["name"]),
            ("   [장착 중]" if equipped == id else ""),
            ("" if owned else "   [미보유]")
        ]
        b.tooltip_text = str(item["effect"])
        b.disabled = not owned
        b.custom_minimum_size.y = 45
        _style_button(b)
        b.pressed.connect(_equip_item.bind(id))
        content_root.add_child(b)

    var note: Label = Label.new()
    note.text = "장비는 레이스 시작 시 실제 카트 능력치에 적용됩니다."
    note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    note.modulate = Color(0.55,0.72,0.82)
    content_root.add_child(note)

func _select_mode(mode_value: String) -> void:
    selected_mode = mode_value
    var names: Dictionary = {
        "cpu":"일반 / AI 레이스",
        "split":"화면분할 2P",
        "lan_host":"LAN 호스트",
        "lan_join":"LAN 참가"
    }
    mode_label.text = "MODE\n" + str(names.get(mode_value,mode_value))
    result_label.text = "모드 선택: " + str(names.get(mode_value,mode_value))

func _select_kart(id: String) -> void:
    if not kart_data.has(id) or not _owned_karts().has(id):
        return
    selected_kart = id
    profile["selected_kart"] = id
    ProfileManager.save_profile(profile)

    var entry: Dictionary = kart_data[id] as Dictionary
    selected_label_center.text = "%s   +%d" % [str(entry.get("display_name",id)),get_upgrade_level(id)]
    description_label.text = str(entry.get("menu_description",""))
    _spawn_preview(id)
    if current_tab == "kart":
        _open_tab("kart")

func _spawn_preview(id: String) -> void:
    if preview_kart and is_instance_valid(preview_kart):
        preview_kart.queue_free()
    if preview_character and is_instance_valid(preview_character):
        preview_character.queue_free()

    preview_kart = KartController.new()
    preview_viewport.add_child(preview_kart)
    preview_kart.setup_preview(id)
    preview_kart.apply_upgrade_level(get_upgrade_level(id))
    preview_kart.apply_equipment(get_equipped_equipment())
    preview_kart.position = Vector3(1.25,0.15,0.15)
    preview_kart.rotation.y = deg_to_rad(-10.0)
    preview_kart.scale = Vector3(1.12,1.12,1.12)

    preview_character = _create_preview_character(id)
    preview_viewport.add_child(preview_character)
    preview_character.position = Vector3(-1.35,0.0,0.55)
    preview_character.rotation.y = deg_to_rad(7.0)
    preview_character.scale = Vector3(1.18,1.18,1.18)
    preview_auto_rotate = true

func _create_preview_character(id: String) -> Node3D:
    var root: Node3D = Node3D.new()
    var is_gold: bool = id == "gold"

    var body_mat: StandardMaterial3D = StandardMaterial3D.new()
    body_mat.albedo_color = Color(0.025,0.03,0.04) if is_gold else Color(0.16,0.62,0.92)
    body_mat.metallic = 0.65 if is_gold else 0.12
    body_mat.roughness = 0.22 if is_gold else 0.50

    var accent: StandardMaterial3D = StandardMaterial3D.new()
    accent.albedo_color = Color(1.0,0.72,0.10) if is_gold else Color(0.90,0.96,1.0)
    accent.metallic = 0.85 if is_gold else 0.05

    var body: MeshInstance3D = MeshInstance3D.new()
    var bm: CylinderMesh = CylinderMesh.new()
    bm.top_radius = 0.34
    bm.bottom_radius = 0.44
    bm.height = 1.05
    body.mesh = bm
    body.position.y = 0.88
    body.material_override = body_mat
    root.add_child(body)

    var head: MeshInstance3D = MeshInstance3D.new()
    var hm: SphereMesh = SphereMesh.new()
    hm.radius = 0.34
    hm.height = 0.62
    head.mesh = hm
    head.position.y = 1.72
    head.material_override = accent
    root.add_child(head)

    for side in [-1.0,1.0]:
        var arm: MeshInstance3D = MeshInstance3D.new()
        var am: CylinderMesh = CylinderMesh.new()
        am.top_radius = 0.10
        am.bottom_radius = 0.12
        am.height = 0.82
        arm.mesh = am
        arm.position = Vector3(float(side)*0.48,1.05,0.0)
        arm.rotation_degrees.z = float(side)*-16.0
        arm.material_override = body_mat
        root.add_child(arm)

        if is_gold:
            var horn: MeshInstance3D = MeshInstance3D.new()
            var hornm: CylinderMesh = CylinderMesh.new()
            hornm.top_radius = 0.0
            hornm.bottom_radius = 0.075
            hornm.height = 0.48
            horn.mesh = hornm
            horn.position = Vector3(float(side)*0.18,2.05,0.0)
            horn.rotation_degrees.z = float(side)*-32.0
            horn.material_override = accent
            root.add_child(horn)

    return root

func _process(delta: float) -> void:
    if preview_auto_rotate and not preview_dragging:
        if preview_kart and is_instance_valid(preview_kart):
            preview_kart.rotate_y(delta*0.20)
        if preview_character and is_instance_valid(preview_character):
            preview_character.position.y = sin(float(Time.get_ticks_msec())*0.0022)*0.025

func _on_preview_input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
        preview_dragging = event.pressed
        if event.pressed:
            preview_auto_rotate = false
    elif event is InputEventMouseMotion and preview_dragging:
        if preview_kart and is_instance_valid(preview_kart):
            preview_kart.rotate_y(-event.relative.x*0.012)
        if preview_character and is_instance_valid(preview_character):
            preview_character.rotate_y(-event.relative.x*0.012)

func _on_start_pressed() -> void:
    if not _owned_karts().has(selected_kart):
        result_label.text = "잠긴 카트는 사용할 수 없습니다."
        return
    start_requested.emit(selected_mode,selected_kart,ip_edit.text.strip_edges())

func _refresh_profile_bar() -> void:
    if player_label == null:
        return
    var level: int = int(profile.get("level",1))
    var xp: int = int(profile.get("xp",0))
    var need: int = _xp_needed(level)
    player_label.text = str(profile.get("player_name","Racer"))
    level_label.text = "LV.%d" % level
    xp_bar.max_value = need
    xp_bar.value = xp
    gold_label.text = "%d GOLD" % int(round(displayed_gold))

func _animate_gold_to(target: int) -> void:
    if gold_tween and gold_tween.is_valid():
        gold_tween.kill()
    gold_tween = create_tween()
    gold_tween.set_trans(Tween.TRANS_QUAD)
    gold_tween.set_ease(Tween.EASE_OUT)
    gold_tween.tween_method(_set_gold_display,displayed_gold,float(target),0.42)

func _set_gold_display(value: float) -> void:
    displayed_gold = value
    if gold_label:
        gold_label.text = "%d GOLD" % int(round(value))

func _xp_needed(level: int) -> int:
    return 350 + level*150

func _add_xp(amount: int) -> void:
    var level: int = int(profile.get("level",1))
    var xp: int = int(profile.get("xp",0)) + amount
    while xp >= _xp_needed(level):
        xp -= _xp_needed(level)
        level += 1
    profile["level"] = level
    profile["xp"] = xp

func award_race_result(place: int, completed: bool) -> Dictionary:
    var rewards: Array[int] = [650,450,320,220,150,100]
    var base_gold: int = 25
    if completed and place >= 1 and place <= rewards.size():
        base_gold = rewards[place-1]

    var streak: int = int(profile.get("win_streak",0))
    var streak_bonus: int = 0
    if completed and place == 1:
        streak += 1
        streak_bonus = min(max(0,streak-1)*75,375)
        profile["wins"] = int(profile.get("wins",0))+1
    else:
        streak = 0

    profile["win_streak"] = streak
    profile["total_races"] = int(profile.get("total_races",0))+1

    var earned: int = base_gold + streak_bonus
    var old_gold: int = int(profile.get("gold",0))
    profile["gold"] = old_gold + earned

    var xp_gain: int = 25 if not completed else max(35,125-(place-1)*15)
    _add_xp(xp_gain)
    ProfileManager.save_profile(profile)
    _animate_gold_to(int(profile["gold"]))
    _refresh_profile_bar()

    return {
        "place":place,
        "completed":completed,
        "base_gold":base_gold,
        "streak_bonus":streak_bonus,
        "gold":earned,
        "streak":streak,
        "xp":xp_gain
    }

func show_last_reward(reward: Dictionary) -> void:
    if reward.is_empty():
        return
    var place: int = int(reward.get("place",0))
    var place_text: String = ("%d위" % place) if bool(reward.get("completed",false)) else "DNF"
    result_label.text = "%s · +%d GOLD · +%d XP" % [place_text,int(reward.get("gold",0)),int(reward.get("xp",0))]
    _refresh_profile_bar()

func refresh_hub() -> void:
    profile = ProfileManager.load_profile()
    displayed_gold = float(profile.get("gold",0))
    _refresh_profile_bar()
    _select_kart(str(profile.get("selected_kart",selected_kart)))
    _open_tab(current_tab)

func _owned_karts() -> Array:
    return profile.get("owned_karts",[]) as Array

func _owned_equipment() -> Array:
    return profile.get("owned_equipment",[]) as Array

func get_upgrade_level(id: String) -> int:
    var levels: Dictionary = profile.get("kart_levels",{}) as Dictionary
    return int(levels.get(id,0))

func get_equipped_equipment() -> String:
    return str(profile.get("equipped_equipment","comfort_tire"))

func upgrade_cost(level: int) -> int:
    return 600 + level*450

func _effective_stats(base: Dictionary, level: int) -> Dictionary:
    var out: Dictionary = base.duplicate(true)
    out["max_speed"] = float(out.get("max_speed",36.0)) + level*0.35
    out["acceleration"] = float(out.get("acceleration",19.0)) + level*0.35
    out["drift_charge_rate"] = float(out.get("drift_charge_rate",50.0)) + level*1.2
    out["boost_speed"] = float(out.get("boost_speed",44.0)) + level*0.45
    out["steer_rate"] = float(out.get("steer_rate",1.6)) + level*0.015
    return out

func _upgrade_selected_kart() -> void:
    var lvl: int = get_upgrade_level(selected_kart)
    if lvl >= 10:
        return
    var cost: int = upgrade_cost(lvl)
    var gold: int = int(profile.get("gold",0))
    if gold < cost:
        result_label.text = "골드가 부족합니다."
        return

    profile["gold"] = gold-cost
    var levels: Dictionary = profile.get("kart_levels",{}) as Dictionary
    levels[selected_kart] = lvl+1
    profile["kart_levels"] = levels
    ProfileManager.save_profile(profile)
    _animate_gold_to(int(profile["gold"]))
    result_label.text = "%s  +%d 강화 성공!" % [str((kart_data[selected_kart] as Dictionary).get("display_name",selected_kart)),lvl+1]
    _select_kart(selected_kart)
    _refresh_profile_bar()

func _equipment_defs() -> Array[Dictionary]:
    return [
        {"id":"comfort_tire","name":"컴포트 타이어","rarity":"일반","effect":"핸들링 +0.03"},
        {"id":"turbo_chip","name":"터보 칩","rarity":"희귀","effect":"부스터 속도 +1.5"},
        {"id":"drift_ring","name":"드리프트 링","rarity":"희귀","effect":"드리프트 충전 +4"},
        {"id":"engine_core","name":"엔진 코어","rarity":"영웅","effect":"가속력 +1.5"},
        {"id":"gold_wing","name":"골드 윙","rarity":"전설","effect":"최고 속도 +1.0 / 부스터 +1.0"}
    ]

func _equip_item(id: String) -> void:
    if not _owned_equipment().has(id):
        return
    profile["equipped_equipment"] = id
    ProfileManager.save_profile(profile)
    result_label.text = "장비 장착: " + id
    _spawn_preview(selected_kart)
    _open_tab("equipment")

func _gacha_pool() -> Array[Dictionary]:
    return [
        {"type":"equipment","id":"comfort_tire","name":"컴포트 타이어","rarity":"일반"},
        {"type":"cosmetic","id":"leaf_badge","name":"나뭇잎 배지","rarity":"일반"},
        {"type":"cosmetic","id":"blue_helmet","name":"블루 헬멧","rarity":"일반"},
        {"type":"equipment","id":"turbo_chip","name":"터보 칩","rarity":"희귀"},
        {"type":"equipment","id":"drift_ring","name":"드리프트 링","rarity":"희귀"},
        {"type":"kart","id":"phantom","name":"블루 팬텀","rarity":"희귀"},
        {"type":"equipment","id":"engine_core","name":"엔진 코어","rarity":"영웅"},
        {"type":"kart","id":"koala_hyunhoo_mix","name":"코알라 × 양현후 하이브리드","rarity":"영웅"},
        {"type":"cosmetic","id":"dragon_cape","name":"드래곤 케이프","rarity":"영웅"},
        {"type":"equipment","id":"gold_wing","name":"골드 윙","rarity":"전설"},
        {"type":"kart","id":"gold","name":"골드 익스피어리언스","rarity":"전설"}
    ]

func _roll_rarity() -> String:
    var roll: float = randf()*100.0
    if roll < 60.0:
        return "일반"
    if roll < 85.0:
        return "희귀"
    if roll < 96.0:
        return "영웅"
    return "전설"

func _draw_one() -> Dictionary:
    var rarity: String = _roll_rarity()
    var choices: Array[Dictionary] = []
    for item in _gacha_pool():
        if str(item["rarity"]) == rarity:
            choices.append(item)
    if choices.is_empty():
        return {}
    return choices[randi()%choices.size()].duplicate(true)

func _perform_gacha(count: int) -> void:
    var cost: int = 800 if count == 1 else 7200
    var gold: int = int(profile.get("gold",0))
    if gold < cost:
        result_label.text = "골드가 부족합니다."
        return

    profile["gold"] = gold-cost
    var results: Array[Dictionary] = []
    var total_refund: int = 0

    for i in range(count):
        var item: Dictionary = _draw_one()
        if item.is_empty():
            continue
        var duplicate: bool = false
        var type: String = str(item["type"])
        var id: String = str(item["id"])

        if type == "kart":
            var owned_k: Array = _owned_karts()
            duplicate = owned_k.has(id)
            if not duplicate:
                owned_k.append(id)
                profile["owned_karts"] = owned_k
        elif type == "equipment":
            var owned_e: Array = _owned_equipment()
            duplicate = owned_e.has(id)
            if not duplicate:
                owned_e.append(id)
                profile["owned_equipment"] = owned_e
        else:
            var cosmetics: Array = profile.get("owned_cosmetics",[]) as Array
            duplicate = cosmetics.has(id)
            if not duplicate:
                cosmetics.append(id)
                profile["owned_cosmetics"] = cosmetics

        var refund_map: Dictionary = {"일반":120,"희귀":260,"영웅":520,"전설":1200}
        var refund: int = int(refund_map.get(str(item["rarity"]),100)) if duplicate else 0
        total_refund += refund
        item["duplicate"] = duplicate
        item["refund"] = refund
        results.append(item)

    profile["gold"] = int(profile["gold"])+total_refund
    ProfileManager.save_profile(profile)
    _animate_gold_to(int(profile["gold"]))
    _show_gacha_results(results,total_refund)

func _show_gacha_results(results: Array[Dictionary], refund: int) -> void:
    _clear_content()
    tab_title.text = "뽑기 결과"

    var headline: Label = Label.new()
    var best: String = "일반"
    var order: Dictionary = {"일반":0,"희귀":1,"영웅":2,"전설":3}
    for item in results:
        if int(order[str(item["rarity"])]) > int(order[best]):
            best = str(item["rarity"])
    headline.text = "%s 등급 획득!" % best
    headline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    headline.add_theme_font_size_override("font_size",25)
    headline.modulate = RARITY_COLORS.get(best,Color.WHITE)
    content_root.add_child(headline)

    var scroll: ScrollContainer = ScrollContainer.new()
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    content_root.add_child(scroll)
    var list: VBoxContainer = VBoxContainer.new()
    list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    scroll.add_child(list)

    for item in results:
        var row: Label = Label.new()
        row.text = "[%s] %s%s" % [
            str(item["rarity"]),
            str(item["name"]),
            ("  중복 → +%d GOLD" % int(item["refund"]) if bool(item["duplicate"]) else "")
        ]
        row.modulate = RARITY_COLORS.get(str(item["rarity"]),Color.WHITE)
        list.add_child(row)

    if refund > 0:
        var ref: Label = Label.new()
        ref.text = "중복 변환 총 +%d GOLD" % refund
        ref.modulate = Color(1.0,0.82,0.25)
        content_root.add_child(ref)

    var back: Button = Button.new()
    back.text = "뽑기로 돌아가기"
    _style_button(back,true)
    back.pressed.connect(_open_tab.bind("gacha"))
    content_root.add_child(back)
    _refresh_profile_bar()
