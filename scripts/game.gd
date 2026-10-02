extends Node3D

const LAN_PORT: int = 24567

var track: TrackBuilder
var player: KartController
var player2: KartController
var hud: RaceHUD
var menu_layer: CanvasLayer
var result_label: Label
var selected_label: Label
var mode_label: Label
var network_status_label: Label
var ip_edit: LineEdit
var selected_kart: String = "rookie"
var selected_mode: String = "cpu"
var kart_data: Dictionary = {}
var race_camera: Camera3D

var race_karts: Array[KartController] = []
var cpu_karts: Array[KartController] = []

var split_layer: CanvasLayer
var split_cam1: Camera3D
var split_cam2: Camera3D

var lan_peer: ENetMultiplayerPeer
var network_specs: Dictionary = {}
var network_karts: Dictionary = {}
var net_send_accum: float = 0.0

var kart_order: Array[String] = ["rookie","koala_sprinter","bamboo_koala_gt","koala_drift_x","phantom","yanghyunhoo_turbo","yanghyunhoo_blaze","koala_hyunhoo_mix","gold"]

func _ready() -> void:
    _ensure_input()
    _connect_multiplayer_signals()
    _load_data()
    _build_world()
    _build_menu()

func _process(delta: float) -> void:
    if selected_mode == "split" and split_cam1 and split_cam2 and player and player2:
        _follow_camera(split_cam1,player,delta)
        _follow_camera(split_cam2,player2,delta)
    elif race_camera:
        if player and is_instance_valid(player) and not player.finished:
            _follow_camera(race_camera,player,delta)
        elif track and not track.sample_points.is_empty():
            var menu_pos: Vector3 = track.sample_points[0] + Vector3(22.0,20.0,26.0)
            race_camera.global_position = race_camera.global_position.lerp(menu_pos,clamp(delta*3.0,0.0,1.0))
            race_camera.look_at(track.sample_points[0] + Vector3.UP,Vector3.UP)

    if lan_peer and player and is_instance_valid(player) and multiplayer.multiplayer_peer:
        net_send_accum += delta
        if net_send_accum >= 0.05:
            net_send_accum = 0.0
            var pid: int = multiplayer.get_unique_id()
            if multiplayer.is_server():
                _broadcast_state.rpc(pid,player.global_position,player.rotation.y,player.forward_speed,player.lap)
            else:
                _submit_state.rpc_id(1,player.global_position,player.rotation.y,player.forward_speed,player.lap)

func _follow_camera(cam: Camera3D, kart: KartController, delta: float) -> void:
    if not kart or not is_instance_valid(kart):
        return
    var forward: Vector3 = -kart.global_transform.basis.z.normalized()
    var target: Vector3 = kart.global_position + forward * 3.6 + Vector3.UP * 1.0
    var desired: Vector3 = kart.global_position - forward * 8.2 + Vector3.UP * 4.0
    cam.global_position = cam.global_position.lerp(desired,clamp(delta*7.0,0.0,1.0))
    cam.look_at(target,Vector3.UP)

func _add_key(action: StringName, keycode: Key) -> void:
    if not InputMap.has_action(action):
        InputMap.add_action(action)
    var e: InputEventKey = InputEventKey.new()
    e.physical_keycode = keycode
    InputMap.action_add_event(action,e)

func _ensure_input() -> void:
    _add_key("accelerate",KEY_W)
    _add_key("brake",KEY_S)
    _add_key("steer_left",KEY_A)
    _add_key("steer_right",KEY_D)
    _add_key("drift",KEY_SHIFT)
    _add_key("boost",KEY_SPACE)
    _add_key("reset_kart",KEY_R)

    _add_key("p2_accelerate",KEY_UP)
    _add_key("p2_brake",KEY_DOWN)
    _add_key("p2_left",KEY_LEFT)
    _add_key("p2_right",KEY_RIGHT)
    _add_key("p2_drift",KEY_ENTER)
    _add_key("p2_boost",KEY_KP_0)
    _add_key("p2_reset",KEY_BACKSPACE)

func _connect_multiplayer_signals() -> void:
    if not multiplayer.peer_connected.is_connected(_on_peer_connected):
        multiplayer.peer_connected.connect(_on_peer_connected)
    if not multiplayer.peer_disconnected.is_connected(_on_peer_disconnected):
        multiplayer.peer_disconnected.connect(_on_peer_disconnected)
    if not multiplayer.connected_to_server.is_connected(_on_connected_to_server):
        multiplayer.connected_to_server.connect(_on_connected_to_server)
    if not multiplayer.connection_failed.is_connected(_on_connection_failed):
        multiplayer.connection_failed.connect(_on_connection_failed)
    if not multiplayer.server_disconnected.is_connected(_on_server_disconnected):
        multiplayer.server_disconnected.connect(_on_server_disconnected)

func _load_data() -> void:
    var f: FileAccess = FileAccess.open("res://assets/data/karts.json",FileAccess.READ)
    kart_data = JSON.parse_string(f.get_as_text()) if f else {}

func _build_world() -> void:
    var env_node: WorldEnvironment = WorldEnvironment.new()
    var env: Environment = Environment.new()
    env.background_mode = Environment.BG_COLOR
    env.background_color = Color(0.40,0.67,0.89)
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color(0.72,0.78,0.74)
    env.ambient_light_energy = 1.15
    env_node.environment = env
    add_child(env_node)

    var sun: DirectionalLight3D = DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-50,-30,0)
    sun.light_energy = 1.6
    sun.shadow_enabled = true
    add_child(sun)

    track = TrackBuilder.new()
    add_child(track)
    track.setup()

    race_camera = Camera3D.new()
    race_camera.name = "MainRaceCamera"
    race_camera.fov = 72.0
    race_camera.near = 0.05
    race_camera.far = 600.0
    add_child(race_camera)
    race_camera.global_position = track.sample_points[0] + Vector3(22.0,20.0,26.0)
    race_camera.look_at(track.sample_points[0] + Vector3.UP,Vector3.UP)
    race_camera.make_current()

func _build_menu() -> void:
    menu_layer = CanvasLayer.new()
    menu_layer.layer = 30
    add_child(menu_layer)

    var root: Control = Control.new()
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    menu_layer.add_child(root)

    var shade: ColorRect = ColorRect.new()
    shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    shade.color = Color(0.02,0.04,0.05,0.44)
    shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
    root.add_child(shade)

    var center: CenterContainer = CenterContainer.new()
    center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.add_child(center)

    var panel: PanelContainer = PanelContainer.new()
    panel.custom_minimum_size = Vector2(960,680)
    center.add_child(panel)

    var margin: MarginContainer = MarginContainer.new()
    margin.add_theme_constant_override("margin_left",24)
    margin.add_theme_constant_override("margin_right",24)
    margin.add_theme_constant_override("margin_top",18)
    margin.add_theme_constant_override("margin_bottom",18)
    panel.add_child(margin)

    var v: VBoxContainer = VBoxContainer.new()
    v.add_theme_constant_override("separation",7)
    margin.add_child(v)

    var title: Label = Label.new()
    title.text = "FOREST CIRCUIT KART 3D"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size",30)
    v.add_child(title)

    mode_label = Label.new()
    mode_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    mode_label.add_theme_font_size_override("font_size",18)
    v.add_child(mode_label)

    var modes: HBoxContainer = HBoxContainer.new()
    modes.alignment = BoxContainer.ALIGNMENT_CENTER
    modes.add_theme_constant_override("separation",8)
    v.add_child(modes)

    _add_mode_button(modes,"CPU 대전","cpu")
    _add_mode_button(modes,"화면분할 2P","split")
    _add_mode_button(modes,"LAN 호스트","lan_host")
    _add_mode_button(modes,"LAN 참가","lan_join")

    var lan_row: HBoxContainer = HBoxContainer.new()
    lan_row.alignment = BoxContainer.ALIGNMENT_CENTER
    v.add_child(lan_row)

    ip_edit = LineEdit.new()
    ip_edit.placeholder_text = "호스트 LAN IP 예: 192.168.0.10"
    ip_edit.text = "127.0.0.1"
    ip_edit.custom_minimum_size = Vector2(330,38)
    lan_row.add_child(ip_edit)

    network_status_label = Label.new()
    network_status_label.text = "내 LAN IP: %s  / 포트: %d" % [_get_lan_ip(),LAN_PORT]
    network_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    v.add_child(network_status_label)

    selected_label = Label.new()
    selected_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    selected_label.add_theme_font_size_override("font_size",17)
    v.add_child(selected_label)

    var scroll: ScrollContainer = ScrollContainer.new()
    scroll.custom_minimum_size = Vector2(0,390)
    scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    v.add_child(scroll)

    var grid: GridContainer = GridContainer.new()
    grid.columns = 2
    grid.add_theme_constant_override("h_separation",10)
    grid.add_theme_constant_override("v_separation",8)
    grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    scroll.add_child(grid)

    for id in kart_order:
        if kart_data.has(id):
            var entry: Dictionary = kart_data[id]
            var b: Button = Button.new()
            b.text = str(entry.get("display_name",id)) + "\n" + str(entry.get("menu_description",""))
            b.custom_minimum_size = Vector2(420,64)
            b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
            b.pressed.connect(_select_kart.bind(id))
            grid.add_child(b)

    var start: Button = Button.new()
    start.text = "선택한 모드 시작"
    start.custom_minimum_size.y = 48
    start.pressed.connect(_start_selected_mode)
    v.add_child(start)

    result_label = Label.new()
    result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    v.add_child(result_label)

    _set_mode("cpu")
    _select_kart("rookie")

func _add_mode_button(parent: HBoxContainer, text_value: String, mode_value: String) -> void:
    var b: Button = Button.new()
    b.text = text_value
    b.custom_minimum_size = Vector2(150,40)
    b.pressed.connect(_set_mode.bind(mode_value))
    parent.add_child(b)

func _set_mode(mode_value: String) -> void:
    selected_mode = mode_value
    var names: Dictionary = {
        "cpu":"CPU 대전",
        "split":"화면분할 2P",
        "lan_host":"LAN 호스트",
        "lan_join":"LAN 참가"
    }
    if mode_label:
        mode_label.text = "모드: " + str(names.get(mode_value,mode_value))

func _select_kart(id: String) -> void:
    selected_kart = id
    selected_label.text = "선택: " + str(kart_data.get(id,{}).get("display_name",id))
    result_label.text = ""

func _start_selected_mode() -> void:
    _clear_race(false)

    match selected_mode:
        "cpu":
            _start_cpu_mode()
        "split":
            _start_split_mode()
        "lan_host":
            _start_lan_host()
        "lan_join":
            _start_lan_join()
        _:
            _start_cpu_mode()

func _spawn_kart(id: String, mode: String, spawn_index: int, lane_offset: float) -> KartController:
    var kart: KartController = KartController.new()
    add_child(kart)
    kart.setup(id,track,mode,spawn_index,lane_offset)
    race_karts.append(kart)
    return kart

func _create_hud(target: KartController) -> void:
    if hud and is_instance_valid(hud):
        hud.queue_free()
    hud = RaceHUD.new()
    add_child(hud)
    target.hud_update.connect(hud.update_values)
    hud.lobby_requested.connect(_return_to_lobby)

func _start_cpu_mode() -> void:
    menu_layer.visible = false
    player = _spawn_kart(selected_kart,"player1",0,-2.8)
    player.race_finished.connect(_finish)

    for i in range(5):
        var cpu_id: String = kart_order[(i + 1) % kart_order.size()]
        var lane: float = -4.5 + float(i % 3) * 4.5
        var cpu: KartController = _spawn_kart(cpu_id,"cpu",-5 - i*4,lane)
        cpu_karts.append(cpu)

    _create_hud(player)
    _snap_main_camera(player)

func _start_split_mode() -> void:
    menu_layer.visible = false
    player = _spawn_kart(selected_kart,"player1",0,-3.0)
    player2 = _spawn_kart("koala_hyunhoo_mix","player2",0,3.0)
    player.race_finished.connect(_finish)
    player2.race_finished.connect(_finish)
    _build_split_screen()
    _create_hud(player)

func _build_split_screen() -> void:
    split_layer = CanvasLayer.new()
    split_layer.layer = 5
    add_child(split_layer)

    var root: Control = Control.new()
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.mouse_filter = Control.MOUSE_FILTER_IGNORE
    split_layer.add_child(root)

    var left: SubViewportContainer = SubViewportContainer.new()
    left.anchor_left = 0.0
    left.anchor_right = 0.5
    left.anchor_top = 0.0
    left.anchor_bottom = 1.0
    left.offset_right = -2.0
    left.stretch = true
    root.add_child(left)

    var right: SubViewportContainer = SubViewportContainer.new()
    right.anchor_left = 0.5
    right.anchor_right = 1.0
    right.anchor_top = 0.0
    right.anchor_bottom = 1.0
    right.offset_left = 2.0
    right.stretch = true
    root.add_child(right)

    var vp1: SubViewport = SubViewport.new()
    vp1.size = Vector2i(640,720)
    vp1.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    vp1.world_3d = get_viewport().world_3d
    left.add_child(vp1)

    var vp2: SubViewport = SubViewport.new()
    vp2.size = Vector2i(640,720)
    vp2.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    vp2.world_3d = get_viewport().world_3d
    right.add_child(vp2)

    split_cam1 = Camera3D.new()
    split_cam1.fov = 74.0
    vp1.add_child(split_cam1)
    split_cam1.make_current()

    split_cam2 = Camera3D.new()
    split_cam2.fov = 74.0
    vp2.add_child(split_cam2)
    split_cam2.make_current()

    split_cam1.global_position = player.global_position + Vector3(0,4,8)
    split_cam2.global_position = player2.global_position + Vector3(0,4,8)

func _snap_main_camera(kart: KartController) -> void:
    if not race_camera:
        return
    var forward: Vector3 = -kart.global_transform.basis.z.normalized()
    race_camera.global_position = kart.global_position - forward*8.2 + Vector3.UP*4.0
    race_camera.look_at(kart.global_position + forward*3.5 + Vector3.UP,Vector3.UP)
    race_camera.make_current()

func _start_lan_host() -> void:
    lan_peer = ENetMultiplayerPeer.new()
    var err: Error = lan_peer.create_server(LAN_PORT,8)
    if err != OK:
        network_status_label.text = "호스트 생성 실패: " + error_string(err)
        lan_peer = null
        return

    multiplayer.multiplayer_peer = lan_peer
    network_specs.clear()
    network_karts.clear()
    network_specs[1] = selected_kart

    menu_layer.visible = false
    _spawn_network_kart_local(1,selected_kart)
    network_status_label.text = "호스트 실행 중 · 다른 PC에서 %s 입력" % _get_lan_ip()

func _start_lan_join() -> void:
    var host_ip: String = ip_edit.text.strip_edges()
    if host_ip.is_empty():
        network_status_label.text = "호스트 LAN IP를 입력해줘."
        return

    lan_peer = ENetMultiplayerPeer.new()
    var err: Error = lan_peer.create_client(host_ip,LAN_PORT)
    if err != OK:
        network_status_label.text = "접속 시작 실패: " + error_string(err)
        lan_peer = null
        return

    multiplayer.multiplayer_peer = lan_peer
    network_specs.clear()
    network_karts.clear()
    menu_layer.visible = false
    network_status_label.text = "호스트에 연결 중..."

func _spawn_network_kart_local(peer_id: int, id: String) -> void:
    if network_karts.has(peer_id):
        return

    var local_id: int = multiplayer.get_unique_id()
    var mode: String = "player1" if peer_id == local_id else "remote"
    var lane: float = -3.0 if peer_id % 2 == 0 else 3.0
    var kart: KartController = _spawn_kart(id,mode,-(peer_id % 5)*4,lane)
    network_karts[peer_id] = kart

    if peer_id == local_id:
        player = kart
        player.race_finished.connect(_finish)
        _create_hud(player)
        _snap_main_camera(player)

func _remove_network_kart_local(peer_id: int) -> void:
    if not network_karts.has(peer_id):
        return
    var kart: KartController = network_karts[peer_id] as KartController
    if kart and is_instance_valid(kart):
        race_karts.erase(kart)
        kart.queue_free()
    network_karts.erase(peer_id)

func _on_peer_connected(peer_id: int) -> void:
    if not multiplayer.is_server():
        return
    for existing_id in network_specs.keys():
        _net_spawn_kart.rpc_id(peer_id,int(existing_id),str(network_specs[existing_id]))

func _on_peer_disconnected(peer_id: int) -> void:
    if multiplayer.is_server():
        network_specs.erase(peer_id)
        _remove_network_kart_local(peer_id)
        _net_remove_kart.rpc(peer_id)

func _on_connected_to_server() -> void:
    network_status_label.text = "LAN 연결 성공"
    _request_spawn.rpc_id(1,selected_kart)

func _on_connection_failed() -> void:
    network_status_label.text = "LAN 연결 실패 · IP/방화벽 확인"
    _return_to_lobby()

func _on_server_disconnected() -> void:
    network_status_label.text = "호스트 연결이 종료됨"
    _return_to_lobby()

@rpc("any_peer","call_remote","reliable")
func _request_spawn(id: String) -> void:
    if not multiplayer.is_server():
        return
    var peer_id: int = multiplayer.get_remote_sender_id()
    network_specs[peer_id] = id
    _spawn_network_kart_local(peer_id,id)
    _net_spawn_kart.rpc(peer_id,id)

@rpc("authority","call_remote","reliable")
func _net_spawn_kart(peer_id: int, id: String) -> void:
    network_specs[peer_id] = id
    _spawn_network_kart_local(peer_id,id)

@rpc("authority","call_remote","reliable")
func _net_remove_kart(peer_id: int) -> void:
    _remove_network_kart_local(peer_id)

@rpc("any_peer","call_remote","unreliable")
func _submit_state(pos: Vector3, yaw: float, speed_value: float, lap_value: int) -> void:
    if not multiplayer.is_server():
        return
    var peer_id: int = multiplayer.get_remote_sender_id()
    _apply_remote_state(peer_id,pos,yaw,speed_value,lap_value)
    _broadcast_state.rpc(peer_id,pos,yaw,speed_value,lap_value)

@rpc("authority","call_remote","unreliable")
func _broadcast_state(peer_id: int, pos: Vector3, yaw: float, speed_value: float, lap_value: int) -> void:
    if peer_id == multiplayer.get_unique_id():
        return
    _apply_remote_state(peer_id,pos,yaw,speed_value,lap_value)

func _apply_remote_state(peer_id: int, pos: Vector3, yaw: float, speed_value: float, lap_value: int) -> void:
    if not network_karts.has(peer_id):
        return
    var kart: KartController = network_karts[peer_id] as KartController
    if kart:
        kart.set_remote_state(pos,yaw,speed_value,lap_value)

func _finish(total_time: float) -> void:
    if result_label:
        result_label.text = "FINISH! %.2f초" % total_time
    _return_to_lobby()

func _return_to_lobby() -> void:
    _clear_race(true)
    menu_layer.visible = true
    if result_label and result_label.text.is_empty():
        result_label.text = "로비로 돌아왔습니다."

func _clear_race(disconnect_network: bool) -> void:
    if hud and is_instance_valid(hud):
        hud.queue_free()
    hud = null

    if split_layer and is_instance_valid(split_layer):
        split_layer.queue_free()
    split_layer = null
    split_cam1 = null
    split_cam2 = null

    for kart in race_karts:
        if kart and is_instance_valid(kart):
            kart.queue_free()
    race_karts.clear()
    cpu_karts.clear()
    network_karts.clear()
    network_specs.clear()
    player = null
    player2 = null

    if disconnect_network and lan_peer:
        lan_peer.close()
        lan_peer = null
        multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()

func _get_lan_ip() -> String:
    var addresses: PackedStringArray = IP.get_local_addresses()
    for address in addresses:
        var a: String = str(address)
        if a.contains(":"):
            continue
        if a.begins_with("192.168.") or a.begins_with("10.") or a.begins_with("172."):
            return a
    return "확인 불가"
