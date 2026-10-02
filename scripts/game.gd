extends Node3D

var track: TrackBuilder
var player: KartController
var hud: RaceHUD
var menu_layer: CanvasLayer
var result_label: Label
var selected_label: Label
var selected_kart := "rookie"
var kart_data: Dictionary = {}

var kart_order := ["rookie","koala_sprinter","bamboo_koala_gt","koala_drift_x","phantom","yanghyunhoo_turbo","yanghyunhoo_blaze","koala_hyunhoo_mix","gold"]

func _ready() -> void:
    _ensure_input()
    _load_data()
    _build_world()
    _build_menu()

func _add_key(action: StringName, keycode: Key) -> void:
    if not InputMap.has_action(action):
        InputMap.add_action(action)
    var e := InputEventKey.new()
    e.physical_keycode = keycode
    InputMap.action_add_event(action,e)

func _ensure_input() -> void:
    _add_key("accelerate",KEY_W); _add_key("accelerate",KEY_UP)
    _add_key("brake",KEY_S); _add_key("brake",KEY_DOWN)
    _add_key("steer_left",KEY_A); _add_key("steer_left",KEY_LEFT)
    _add_key("steer_right",KEY_D); _add_key("steer_right",KEY_RIGHT)
    _add_key("drift",KEY_SHIFT); _add_key("boost",KEY_SPACE)
    _add_key("boost",KEY_CTRL); _add_key("reset_kart",KEY_R)

func _load_data() -> void:
    var f := FileAccess.open("res://assets/data/karts.json",FileAccess.READ)
    kart_data = JSON.parse_string(f.get_as_text()) if f else {}

func _build_world() -> void:
    var env_node := WorldEnvironment.new()
    var env := Environment.new()
    env.background_mode = Environment.BG_COLOR
    env.background_color = Color(0.46,0.70,0.86)
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color(0.65,0.72,0.68)
    env.ambient_light_energy = 0.9
    env_node.environment = env
    add_child(env_node)

    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-50,-30,0)
    sun.light_energy = 1.4
    sun.shadow_enabled = true
    add_child(sun)

    track = TrackBuilder.new()
    add_child(track)
    track.setup()

func _build_menu() -> void:
    menu_layer = CanvasLayer.new()
    add_child(menu_layer)

    # Full-window root prevents the menu from being offset when the window is resized.
    var root := Control.new()
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.mouse_filter = Control.MOUSE_FILTER_PASS
    menu_layer.add_child(root)

    var shade := ColorRect.new()
    shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    shade.color = Color(0.02, 0.04, 0.05, 0.38)
    shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
    root.add_child(shade)

    # CenterContainer centers the panel using its actual minimum size.
    var center := CenterContainer.new()
    center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    center.size_flags_vertical = Control.SIZE_EXPAND_FILL
    root.add_child(center)

    var panel := PanelContainer.new()
    panel.custom_minimum_size = Vector2(900, 620)
    center.add_child(panel)

    var margin := MarginContainer.new()
    margin.add_theme_constant_override("margin_left",24)
    margin.add_theme_constant_override("margin_right",24)
    margin.add_theme_constant_override("margin_top",20)
    margin.add_theme_constant_override("margin_bottom",20)
    panel.add_child(margin)

    var v := VBoxContainer.new()
    v.add_theme_constant_override("separation",8)
    v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    v.size_flags_vertical = Control.SIZE_EXPAND_FILL
    margin.add_child(v)

    var title := Label.new()
    title.text = "FOREST CIRCUIT KART 3D"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size",30)
    v.add_child(title)

    var info := Label.new()
    info.text = "카트 9종 · 3D 숲 서킷\nWASD/방향키 · Shift 드리프트 · Space/Ctrl N2O · R 복귀"
    info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    v.add_child(info)

    selected_label = Label.new()
    selected_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    selected_label.add_theme_font_size_override("font_size",18)
    selected_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    v.add_child(selected_label)

    var scroll := ScrollContainer.new()
    scroll.custom_minimum_size = Vector2(0,400)
    scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    v.add_child(scroll)

    var grid := GridContainer.new()
    grid.columns = 2
    grid.add_theme_constant_override("h_separation",10)
    grid.add_theme_constant_override("v_separation",10)
    grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    scroll.add_child(grid)

    for id in kart_order:
        if kart_data.has(id):
            var e: Dictionary = kart_data[id]
            var b := Button.new()
            b.text = str(e.get("display_name",id)) + "\n" + str(e.get("menu_description",""))
            b.custom_minimum_size = Vector2(410,70)
            b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
            b.pressed.connect(_select_kart.bind(id))
            grid.add_child(b)

    var start := Button.new()
    start.text = "선택한 카트로 레이스 시작"
    start.custom_minimum_size.y = 50
    start.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    start.pressed.connect(_start_race)
    v.add_child(start)

    result_label = Label.new()
    result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    v.add_child(result_label)
    _select_kart("rookie")

func _select_kart(id: String) -> void:
    selected_kart = id
    selected_label.text = "선택: " + str(kart_data.get(id,{}).get("display_name",id))
    result_label.text = ""

func _start_race() -> void:
    if player and is_instance_valid(player):
        player.queue_free()
    if hud and is_instance_valid(hud):
        hud.queue_free()

    player = KartController.new()
    add_child(player)
    player.setup(selected_kart,track)

    hud = RaceHUD.new()
    add_child(hud)
    player.hud_update.connect(hud.update_values)
    player.race_finished.connect(_finish)
    menu_layer.visible = false

func _finish(total_time: float) -> void:
    menu_layer.visible = true
    result_label.text = "FINISH! %.2f초" % total_time
