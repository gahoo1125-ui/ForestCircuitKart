extends Node3D

const LAN_PORT: int = 24567
const LOBBY_SCENE: PackedScene = preload("res://scenes/Lobby.tscn")

var track: TrackBuilder
var player: KartController
var player2: KartController
var hud: RaceHUD
var menu_layer: CanvasLayer
var lobby_ui: LobbyUI
var last_race_reward: Dictionary = {}
var result_label: Label
var selected_label: Label
var mode_label: Label
var network_status_label: Label
var ip_edit: LineEdit
var selected_kart: String = "rookie"
var selected_mode: String = "cpu"
var kart_data: Dictionary = {}
var race_camera: Camera3D
var podium_layer: CanvasLayer
var finish_countdown_layer: CanvasLayer
var finish_countdown_label: Label
var race_result_open: bool = false
var finish_countdown_active: bool = false
var finish_countdown_left: float = 0.0
var finished_order: Array[KartController] = []
var finished_times: Dictionary = {}

var start_light_layer: CanvasLayer
var start_light_label: Label
var start_red: ColorRect
var start_yellow: ColorRect
var start_green: ColorRect
var start_countdown_active: bool = false
var start_countdown_left: float = 0.0
var start_green_display_left: float = 0.0
var start_boost_p1: bool = false
var start_boost_p2: bool = false
var start_early_p1: bool = false
var start_early_p2: bool = false

var race_karts: Array[KartController] = []
var cpu_karts: Array[KartController] = []

var split_layer: CanvasLayer
var split_cam1: Camera3D
var split_cam2: Camera3D

var lan_peer: ENetMultiplayerPeer
var network_specs: Dictionary = {}
var network_names: Dictionary = {}
var network_karts: Dictionary = {}

const CPU_DRIVER_NAMES: Array[String] = ["NOVA","RIN","BLAZE","MIRA","ZERO"]
var net_send_accum: float = 0.0
var ranking_update_accum: float = 0.0

var kart_order: Array[String] = ["rookie","koala_sprinter","bamboo_koala_gt","koala_drift_x","phantom","yanghyunhoo_turbo","yanghyunhoo_blaze","koala_hyunhoo_mix","running_seala","gold"]

func _ready() -> void:
    _ensure_input()
    _connect_multiplayer_signals()
    _load_data()
    _build_world()
    _build_menu()

func _process(delta: float) -> void:
    if start_countdown_active:
        _update_start_sequence(delta)
    elif start_green_display_left > 0.0:
        start_green_display_left = max(0.0,start_green_display_left-delta)
        if start_green_display_left <= 0.0:
            _hide_start_lights()

    if finish_countdown_active:
        finish_countdown_left = max(0.0,finish_countdown_left - delta)
        if finish_countdown_label:
            finish_countdown_label.text = "FINISH WINDOW  %.1f" % finish_countdown_left
        if finish_countdown_left <= 0.0:
            _finalize_race_after_countdown()

    if hud and is_instance_valid(hud) and track:
        ranking_update_accum += delta
        if ranking_update_accum >= 0.12:
            ranking_update_accum = 0.0
            hud.update_rankings(race_karts,track,kart_data,player)

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

    var kart_transform: Transform3D = kart.get_global_transform_interpolated()
    var raw_forward: Vector3 = -kart_transform.basis.z.normalized()
    var kart_position: Vector3 = kart_transform.origin

    if not bool(cam.get_meta("smooth_camera_ready",false)):
        cam.set_physics_interpolation_mode(Node.PHYSICS_INTERPOLATION_MODE_OFF)
        cam.set_meta("smooth_camera_ready",true)
        cam.set_meta("smooth_forward",raw_forward)
        cam.set_meta("smooth_target",kart_position + raw_forward*4.0 + Vector3.UP*0.72)

    var smooth_forward: Vector3 = cam.get_meta("smooth_forward",raw_forward)
    var forward_alpha: float = 1.0-exp(-10.5*delta)
    smooth_forward = smooth_forward.lerp(raw_forward,clamp(forward_alpha,0.0,1.0)).normalized()
    cam.set_meta("smooth_forward",smooth_forward)

    var boosting: bool = kart.boost_timer > 0.0
    var target_goal: Vector3 = kart_position + smooth_forward*(4.8 if boosting else 4.0) + Vector3.UP*0.72
    var smooth_target: Vector3 = cam.get_meta("smooth_target",target_goal)
    var target_alpha: float = 1.0-exp(-11.5*delta)
    smooth_target = smooth_target.lerp(target_goal,clamp(target_alpha,0.0,1.0))
    cam.set_meta("smooth_target",smooth_target)

    var follow_distance: float = 10.1 if boosting else 8.75
    var follow_height: float = 2.85 if boosting else 2.95
    var desired: Vector3 = kart_position - smooth_forward*follow_distance + Vector3.UP*follow_height

    # Stable exponential smoothing: consistent feel across 60/120/144+ FPS.
    var position_response: float = 8.3 if boosting else 6.8
    var position_alpha: float = 1.0-exp(-position_response*delta)
    cam.global_position = cam.global_position.lerp(desired,clamp(position_alpha,0.0,1.0))

    # Smooth FOV transition without the old boost camera shake.
    var fov_alpha: float = 1.0-exp(-4.4*delta)
    cam.fov = lerp(cam.fov,93.0 if boosting else 74.0,clamp(fov_alpha,0.0,1.0))
    cam.look_at(smooth_target,Vector3.UP)

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
    env.background_color = Color(0.010,0.020,0.042)
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color(0.18,0.24,0.34)
    env.ambient_light_energy = 0.78
    env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
    env.fog_enabled = true
    env.fog_light_color = Color(0.18,0.24,0.30)
    env.fog_light_energy = 0.55
    env.fog_density = 0.0065
    env.fog_sky_affect = 0.62
    env_node.environment = env
    add_child(env_node)

    # Cool moonlight over the course.
    var moon_light: DirectionalLight3D = DirectionalLight3D.new()
    moon_light.rotation_degrees = Vector3(-48,-28,0)
    moon_light.light_energy = 1.25
    moon_light.light_color = Color(0.55,0.66,0.95)
    moon_light.shadow_enabled = true
    add_child(moon_light)

    # Visible stylized moon kept far outside the race geometry.
    var moon: MeshInstance3D = MeshInstance3D.new()
    var moon_mesh: SphereMesh = SphereMesh.new()
    moon_mesh.radius = 8.0
    moon_mesh.height = 14.0
    moon.mesh = moon_mesh
    moon.position = Vector3(118.0,92.0,95.0)
    var moon_mat: StandardMaterial3D = StandardMaterial3D.new()
    moon_mat.albedo_color = Color(0.92,0.95,1.0)
    moon_mat.emission_enabled = true
    moon_mat.emission = Color(0.65,0.76,1.0)
    moon_mat.emission_energy_multiplier = 1.6
    moon.material_override = moon_mat
    add_child(moon)

    track = TrackBuilder.new()
    add_child(track)
    track.setup()

    race_camera = Camera3D.new()
    race_camera.name = "MainRaceCamera"
    race_camera.fov = 72.0
    race_camera.near = 0.05
    race_camera.far = 700.0
    add_child(race_camera)
    race_camera.global_position = track.sample_points[0] + Vector3(22.0,20.0,26.0)
    race_camera.look_at(track.sample_points[0] + Vector3.UP,Vector3.UP)
    race_camera.make_current()

func _build_menu() -> void:
    var lobby: LobbyUI = LOBBY_SCENE.instantiate() as LobbyUI
    lobby_ui = lobby
    menu_layer = lobby
    add_child(menu_layer)
    lobby.configure(kart_data,kart_order,_get_lan_ip(),LAN_PORT)
    lobby.start_requested.connect(_on_lobby_start_requested)

    result_label = lobby.result_label
    selected_label = lobby.selected_label
    mode_label = lobby.mode_label
    network_status_label = lobby.network_status_label
    ip_edit = lobby.ip_edit
    selected_kart = lobby.selected_kart
    selected_mode = lobby.selected_mode

func _on_lobby_start_requested(mode_value: String, kart_id: String, host_ip: String) -> void:
    selected_mode = mode_value
    selected_kart = kart_id
    if ip_edit:
        ip_edit.text = host_ip
    _start_selected_mode()

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
    if mode == "player1" and lobby_ui:
        kart.driver_name = lobby_ui.get_player_name()
    elif mode == "player2":
        kart.driver_name = "PLAYER 2"
    elif mode == "cpu":
        kart.driver_name = "CPU"
    if lobby_ui and mode == "player1":
        kart.apply_upgrade_level(lobby_ui.get_upgrade_level(id))
        kart.apply_equipment(lobby_ui.get_equipped_equipment())
    kart.set_race_locked(true)
    race_karts.append(kart)
    kart.race_finished.connect(_on_kart_finished.bind(kart))
    return kart

func _create_hud(target: KartController) -> void:
    if hud and is_instance_valid(hud):
        hud.queue_free()
    hud = RaceHUD.new()
    add_child(hud)
    target.hud_update.connect(hud.update_values)
    hud.lobby_requested.connect(_return_to_lobby)
    hud.setup_minimap(track.sample_points,race_karts,target)

func _start_cpu_mode() -> void:
    menu_layer.visible = false
    player = _spawn_kart(selected_kart,"player1",0,-2.8)
    for i in range(5):
        var cpu_id: String = kart_order[(i + 1) % kart_order.size()]
        var lane: float = -4.5 + float(i % 3) * 4.5
        var cpu: KartController = _spawn_kart(cpu_id,"cpu",-5 - i*4,lane)
        cpu.driver_name = CPU_DRIVER_NAMES[i % CPU_DRIVER_NAMES.size()]
        cpu_karts.append(cpu)

    _create_hud(player)
    _snap_main_camera(player)
    _begin_start_sequence()

func _start_split_mode() -> void:
    menu_layer.visible = false
    player = _spawn_kart(selected_kart,"player1",0,-3.0)
    player2 = _spawn_kart("koala_hyunhoo_mix","player2",0,3.0)
    _build_split_screen()
    _create_hud(player)
    _begin_start_sequence()

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

func _begin_start_sequence() -> void:
    if race_karts.is_empty():
        return

    start_countdown_active = true
    start_countdown_left = 3.0
    start_green_display_left = 0.0
    start_boost_p1 = false
    start_boost_p2 = false
    start_early_p1 = false
    start_early_p2 = false

    for kart in race_karts:
        if kart and is_instance_valid(kart):
            kart.set_race_locked(true)

    _show_start_lights()
    _set_start_light_phase("red","READY")

func _show_start_lights() -> void:
    if start_light_layer and is_instance_valid(start_light_layer):
        start_light_layer.queue_free()

    start_light_layer = CanvasLayer.new()
    start_light_layer.layer = 58
    add_child(start_light_layer)

    var panel: PanelContainer = PanelContainer.new()
    panel.anchor_left = 0.5
    panel.anchor_right = 0.5
    panel.anchor_top = 0.0
    panel.anchor_bottom = 0.0
    panel.offset_left = -190.0
    panel.offset_right = 190.0
    panel.offset_top = 38.0
    panel.offset_bottom = 162.0
    start_light_layer.add_child(panel)

    var style: StyleBoxFlat = StyleBoxFlat.new()
    style.bg_color = Color(0.015,0.018,0.025,0.95)
    style.border_color = Color(0.38,0.40,0.45,1.0)
    style.set_border_width_all(2)
    style.corner_radius_top_left = 12
    style.corner_radius_top_right = 12
    style.corner_radius_bottom_left = 12
    style.corner_radius_bottom_right = 12
    panel.add_theme_stylebox_override("panel",style)

    var v: VBoxContainer = VBoxContainer.new()
    v.alignment = BoxContainer.ALIGNMENT_CENTER
    v.add_theme_constant_override("separation",6)
    panel.add_child(v)

    var row: HBoxContainer = HBoxContainer.new()
    row.alignment = BoxContainer.ALIGNMENT_CENTER
    row.add_theme_constant_override("separation",18)
    v.add_child(row)

    start_red = ColorRect.new()
    start_red.custom_minimum_size = Vector2(72,50)
    row.add_child(start_red)

    start_yellow = ColorRect.new()
    start_yellow.custom_minimum_size = Vector2(72,50)
    row.add_child(start_yellow)

    start_green = ColorRect.new()
    start_green.custom_minimum_size = Vector2(72,50)
    row.add_child(start_green)

    start_light_label = Label.new()
    start_light_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    start_light_label.add_theme_font_size_override("font_size",22)
    v.add_child(start_light_label)

func _set_start_light_phase(phase: String, message: String) -> void:
    if start_red == null or start_yellow == null or start_green == null:
        return
    start_red.color = Color(0.22,0.04,0.04)
    start_yellow.color = Color(0.23,0.19,0.04)
    start_green.color = Color(0.04,0.20,0.07)

    if phase == "red":
        start_red.color = Color(1.0,0.09,0.07)
    elif phase == "yellow":
        start_yellow.color = Color(1.0,0.78,0.05)
    elif phase == "green":
        start_green.color = Color(0.08,1.0,0.28)

    if start_light_label:
        start_light_label.text = message

func _update_start_sequence(delta: float) -> void:
    # Sweet spot: press accelerate during the final 0.45 sec of yellow.
    if player and is_instance_valid(player) and Input.is_action_just_pressed("accelerate"):
        if start_countdown_left <= 1.45 and start_countdown_left > 1.0:
            start_boost_p1 = true
            start_early_p1 = false
        elif start_countdown_left > 1.45:
            start_early_p1 = true
            start_boost_p1 = false

    if player2 and is_instance_valid(player2) and Input.is_action_just_pressed("p2_accelerate"):
        if start_countdown_left <= 1.45 and start_countdown_left > 1.0:
            start_boost_p2 = true
            start_early_p2 = false
        elif start_countdown_left > 1.45:
            start_early_p2 = true
            start_boost_p2 = false

    start_countdown_left = max(0.0,start_countdown_left-delta)

    if start_countdown_left > 2.0:
        _set_start_light_phase("red","READY")
    elif start_countdown_left > 1.0:
        var hint: String = "YELLOW"
        if start_countdown_left <= 1.45:
            hint = "YELLOW · 지금 가속!"
        _set_start_light_phase("yellow",hint)
    else:
        _start_green_go()

func _start_green_go() -> void:
    if not start_countdown_active:
        return

    start_countdown_active = false
    start_green_display_left = 0.95

    var boost_text: String = "GO!"
    for kart in race_karts:
        if kart and is_instance_valid(kart):
            kart.set_race_locked(false)
            kart.mark_race_started()

    if player and is_instance_valid(player) and start_boost_p1 and not start_early_p1:
        player.apply_start_boost(1.0)
        boost_text = "GO!  START BOOST!"

    if player2 and is_instance_valid(player2) and start_boost_p2 and not start_early_p2:
        player2.apply_start_boost(1.0)

    _set_start_light_phase("green",boost_text)

func _hide_start_lights() -> void:
    if start_light_layer and is_instance_valid(start_light_layer):
        start_light_layer.queue_free()
    start_light_layer = null
    start_light_label = null
    start_red = null
    start_yellow = null
    start_green = null

func _snap_main_camera(kart: KartController) -> void:
    if not race_camera:
        return

    var kart_transform: Transform3D = kart.get_global_transform_interpolated()
    var forward: Vector3 = -kart_transform.basis.z.normalized()
    var kart_position: Vector3 = kart_transform.origin
    var target: Vector3 = kart_position + forward*4.0 + Vector3.UP*0.72

    race_camera.set_physics_interpolation_mode(Node.PHYSICS_INTERPOLATION_MODE_OFF)
    race_camera.set_meta("smooth_camera_ready",true)
    race_camera.set_meta("smooth_forward",forward)
    race_camera.set_meta("smooth_target",target)
    race_camera.global_position = kart_position - forward*8.75 + Vector3.UP*2.95
    race_camera.fov = 74.0
    race_camera.look_at(target,Vector3.UP)
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
    network_names.clear()
    network_karts.clear()
    var nickname: String = lobby_ui.get_player_name() if lobby_ui else "HOST"
    network_specs[1] = selected_kart
    network_names[1] = nickname

    menu_layer.visible = false
    _spawn_network_kart_local(1,selected_kart,nickname)
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
    network_names.clear()
    network_karts.clear()
    menu_layer.visible = false
    network_status_label.text = "호스트에 연결 중..."

func _spawn_network_kart_local(peer_id: int, id: String, nickname: String = "Racer") -> void:
    if network_karts.has(peer_id):
        return

    var local_id: int = multiplayer.get_unique_id()
    var mode: String = "player1" if peer_id == local_id else "remote"
    var lane: float = -3.0 if peer_id % 2 == 0 else 3.0
    var kart: KartController = _spawn_kart(id,mode,-(peer_id % 5)*4,lane)
    kart.driver_name = nickname
    network_karts[peer_id] = kart

    if peer_id == local_id:
        player = kart
        _create_hud(player)
        _snap_main_camera(player)
        if not start_countdown_active and start_green_display_left <= 0.0:
            _begin_start_sequence()

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
        var existing_name: String = str(network_names.get(existing_id,"Racer"))
        _net_spawn_kart.rpc_id(peer_id,int(existing_id),str(network_specs[existing_id]),existing_name)

func _on_peer_disconnected(peer_id: int) -> void:
    if multiplayer.is_server():
        network_specs.erase(peer_id)
        network_names.erase(peer_id)
        _remove_network_kart_local(peer_id)
        _net_remove_kart.rpc(peer_id)

func _on_connected_to_server() -> void:
    network_status_label.text = "LAN 연결 성공"
    var nickname: String = lobby_ui.get_player_name() if lobby_ui else "Racer"
    _request_spawn.rpc_id(1,selected_kart,nickname)

func _on_connection_failed() -> void:
    network_status_label.text = "LAN 연결 실패 · IP/방화벽 확인"
    _return_to_lobby()

func _on_server_disconnected() -> void:
    network_status_label.text = "호스트 연결이 종료됨"
    _return_to_lobby()

@rpc("any_peer","call_remote","reliable")
func _request_spawn(id: String, nickname: String) -> void:
    if not multiplayer.is_server():
        return
    var peer_id: int = multiplayer.get_remote_sender_id()
    var clean_name: String = ProfileManager.sanitize_nickname(nickname)
    if clean_name.is_empty():
        clean_name = "Racer"
    network_specs[peer_id] = id
    network_names[peer_id] = clean_name
    _spawn_network_kart_local(peer_id,id,clean_name)
    _net_spawn_kart.rpc(peer_id,id,clean_name)

@rpc("authority","call_remote","reliable")
func _net_spawn_kart(peer_id: int, id: String, nickname: String) -> void:
    network_specs[peer_id] = id
    network_names[peer_id] = nickname
    _spawn_network_kart_local(peer_id,id,nickname)

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

func _on_kart_finished(total_time: float, kart: KartController) -> void:
    if race_result_open:
        return
    if kart == null or not is_instance_valid(kart):
        return
    if finished_order.has(kart):
        return

    finished_order.append(kart)
    finished_times[kart.get_instance_id()] = total_time

    # First finisher opens a 10-second grace period for everybody else.
    if not finish_countdown_active:
        finish_countdown_active = true
        finish_countdown_left = 10.0
        _show_finish_countdown()

    # If everyone has already finished, end immediately.
    var active_count: int = 0
    for race_kart in race_karts:
        if race_kart and is_instance_valid(race_kart):
            active_count += 1
    if finished_order.size() >= active_count:
        _finalize_race_after_countdown()

func _show_finish_countdown() -> void:
    if finish_countdown_layer and is_instance_valid(finish_countdown_layer):
        finish_countdown_layer.queue_free()

    finish_countdown_layer = CanvasLayer.new()
    finish_countdown_layer.layer = 55
    add_child(finish_countdown_layer)

    var panel: PanelContainer = PanelContainer.new()
    panel.anchor_left = 0.5
    panel.anchor_right = 0.5
    panel.anchor_top = 0.0
    panel.anchor_bottom = 0.0
    panel.offset_left = -190.0
    panel.offset_right = 190.0
    panel.offset_top = 220.0
    panel.offset_bottom = 290.0
    finish_countdown_layer.add_child(panel)

    var style: StyleBoxFlat = StyleBoxFlat.new()
    style.bg_color = Color(0.03,0.035,0.05,0.94)
    style.border_color = Color(1.0,0.34,0.12,1.0)
    style.set_border_width_all(3)
    style.corner_radius_top_left = 10
    style.corner_radius_top_right = 10
    style.corner_radius_bottom_left = 10
    style.corner_radius_bottom_right = 10
    panel.add_theme_stylebox_override("panel",style)

    finish_countdown_label = Label.new()
    finish_countdown_label.text = "FINISH WINDOW  10.0"
    finish_countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    finish_countdown_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    finish_countdown_label.add_theme_font_size_override("font_size",24)
    panel.add_child(finish_countdown_label)

func _finalize_race_after_countdown() -> void:
    if race_result_open:
        return

    finish_countdown_active = false
    if finish_countdown_layer and is_instance_valid(finish_countdown_layer):
        finish_countdown_layer.queue_free()
    finish_countdown_layer = null
    finish_countdown_label = null

    race_result_open = true

    # Everybody who failed to cross during the grace period is eliminated.
    for kart in race_karts:
        if kart and is_instance_valid(kart):
            kart.set_physics_process(false)

    var player_place: int = 0
    var completed: bool = false
    if player and is_instance_valid(player):
        var pos: int = finished_order.find(player)
        if pos >= 0:
            player_place = pos + 1
            completed = true

    if lobby_ui:
        last_race_reward = lobby_ui.award_race_result(player_place,completed)

    var first_time: float = 0.0
    if not finished_order.is_empty():
        first_time = float(finished_times.get(finished_order[0].get_instance_id(),0.0))
    _show_podium(first_time)

func _show_podium(total_time: float) -> void:
    if podium_layer and is_instance_valid(podium_layer):
        podium_layer.queue_free()

    var ranked: Array[Dictionary] = _get_ranked_entries()

    podium_layer = CanvasLayer.new()
    podium_layer.layer = 60
    add_child(podium_layer)

    var root: Control = Control.new()
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    podium_layer.add_child(root)

    var dim: ColorRect = ColorRect.new()
    dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    dim.color = Color(0.008,0.010,0.018,0.94)
    root.add_child(dim)

    var center: CenterContainer = CenterContainer.new()
    center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.add_child(center)

    var main_v: VBoxContainer = VBoxContainer.new()
    main_v.custom_minimum_size = Vector2(940,560)
    main_v.add_theme_constant_override("separation",12)
    center.add_child(main_v)

    var title: Label = Label.new()
    title.text = "RACE RESULT"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size",38)
    main_v.add_child(title)

    var subtitle: Label = Label.new()
    subtitle.text = "TOP 3 AWARDS · 완주 기록"
    subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    subtitle.add_theme_font_size_override("font_size",18)
    subtitle.modulate = Color(0.80,0.82,0.88)
    main_v.add_child(subtitle)

    var podium_row: HBoxContainer = HBoxContainer.new()
    podium_row.alignment = BoxContainer.ALIGNMENT_CENTER
    podium_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
    podium_row.add_theme_constant_override("separation",20)
    main_v.add_child(podium_row)

    var order: Array[int] = [1,0,2]
    for rank_index in order:
        if rank_index >= ranked.size():
            continue
        var entry: Dictionary = ranked[rank_index]
        var rank_number: int = rank_index + 1
        var is_player: bool = entry.get("kart",null) == player
        var first_time: float = float(ranked[0].get("time",0.0)) if not ranked.is_empty() else 0.0
        var card: PanelContainer = _make_podium_card(rank_number,entry,is_player,first_time)
        podium_row.add_child(card)

    if not last_race_reward.is_empty():
        var reward_panel: PanelContainer = PanelContainer.new()
        reward_panel.custom_minimum_size = Vector2(480,72)
        var reward_style: StyleBoxFlat = StyleBoxFlat.new()
        reward_style.bg_color = Color(0.10,0.075,0.018,0.94)
        reward_style.border_color = Color(1.0,0.72,0.12,1.0)
        reward_style.set_border_width_all(2)
        reward_style.corner_radius_top_left = 10
        reward_style.corner_radius_top_right = 10
        reward_style.corner_radius_bottom_left = 10
        reward_style.corner_radius_bottom_right = 10
        reward_panel.add_theme_stylebox_override("panel",reward_style)
        reward_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
        main_v.add_child(reward_panel)

        var reward_label: Label = Label.new()
        var bonus: int = int(last_race_reward.get("streak_bonus",0))
        reward_label.text = "이번 경기  +%d GOLD   (+%d XP)%s" % [
            int(last_race_reward.get("gold",0)),
            int(last_race_reward.get("xp",0)),
            ("   연승 보너스 +%d" % bonus if bonus > 0 else "")
        ]
        reward_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        reward_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
        reward_label.add_theme_font_size_override("font_size",21)
        reward_label.modulate = Color(1.0,0.84,0.28)
        reward_panel.add_child(reward_label)
        var reward_tween: Tween = create_tween()
        reward_panel.scale = Vector2(0.92,0.92)
        reward_panel.pivot_offset = Vector2(240,36)
        reward_tween.tween_property(reward_panel,"scale",Vector2.ONE,0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

    var note: Label = Label.new()
    note.text = "1위 · 2위 · 3위까지 시상"
    note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    note.add_theme_font_size_override("font_size",17)
    main_v.add_child(note)

    var eliminated: Array[String] = _get_eliminated_names()
    if not eliminated.is_empty():
        var dnf: Label = Label.new()
        dnf.text = "탈락(DNF): " + ", ".join(eliminated)
        dnf.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        dnf.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        dnf.modulate = Color(1.0,0.45,0.38)
        dnf.add_theme_font_size_override("font_size",15)
        main_v.add_child(dnf)

    # Fixed result-screen action button.
    # It is attached directly to the full-screen root instead of the result VBox,
    # so long podium/reward/DNF content can never push it outside the viewport.
    var lobby_button: Button = Button.new()
    lobby_button.text = "로비로 복귀"
    lobby_button.anchor_left = 1.0
    lobby_button.anchor_right = 1.0
    lobby_button.anchor_top = 1.0
    lobby_button.anchor_bottom = 1.0
    lobby_button.offset_left = -270.0
    lobby_button.offset_right = -24.0
    lobby_button.offset_top = -84.0
    lobby_button.offset_bottom = -24.0
    lobby_button.add_theme_font_size_override("font_size",21)
    lobby_button.z_index = 30
    lobby_button.mouse_filter = Control.MOUSE_FILTER_STOP

    var lobby_normal: StyleBoxFlat = StyleBoxFlat.new()
    lobby_normal.bg_color = Color(0.05,0.52,0.86,0.98)
    lobby_normal.border_color = Color(0.40,0.88,1.0,1.0)
    lobby_normal.set_border_width_all(2)
    lobby_normal.corner_radius_top_left = 10
    lobby_normal.corner_radius_top_right = 10
    lobby_normal.corner_radius_bottom_left = 10
    lobby_normal.corner_radius_bottom_right = 10
    lobby_normal.shadow_color = Color(0.0,0.0,0.0,0.55)
    lobby_normal.shadow_size = 8

    var lobby_hover: StyleBoxFlat = lobby_normal.duplicate()
    lobby_hover.bg_color = Color(0.08,0.66,1.0,1.0)
    lobby_hover.border_color = Color(0.72,0.96,1.0,1.0)

    lobby_button.add_theme_stylebox_override("normal",lobby_normal)
    lobby_button.add_theme_stylebox_override("hover",lobby_hover)
    lobby_button.add_theme_stylebox_override("pressed",lobby_hover)
    lobby_button.add_theme_color_override("font_color",Color.WHITE)
    lobby_button.add_theme_color_override("font_hover_color",Color.WHITE)
    lobby_button.pressed.connect(_return_to_lobby)
    root.add_child(lobby_button)

func _make_podium_card(rank_number: int, entry: Dictionary, is_player: bool, first_time: float) -> PanelContainer:
    var card: PanelContainer = PanelContainer.new()
    var heights: Dictionary = {1:350,2:315,3:295}
    card.custom_minimum_size = Vector2(295,float(heights.get(rank_number,300)))

    var style: StyleBoxFlat = StyleBoxFlat.new()
    if rank_number == 1:
        style.bg_color = Color(0.28,0.20,0.035,0.96)
        style.border_color = Color(1.0,0.78,0.16,1.0)
    elif rank_number == 2:
        style.bg_color = Color(0.16,0.18,0.21,0.96)
        style.border_color = Color(0.78,0.84,0.90,1.0)
    else:
        style.bg_color = Color(0.23,0.12,0.055,0.96)
        style.border_color = Color(0.83,0.46,0.20,1.0)
    style.set_border_width_all(3)
    style.corner_radius_top_left = 14
    style.corner_radius_top_right = 14
    style.corner_radius_bottom_left = 14
    style.corner_radius_bottom_right = 14
    card.add_theme_stylebox_override("panel",style)

    var margin: MarginContainer = MarginContainer.new()
    margin.add_theme_constant_override("margin_left",16)
    margin.add_theme_constant_override("margin_right",16)
    margin.add_theme_constant_override("margin_top",14)
    margin.add_theme_constant_override("margin_bottom",14)
    card.add_child(margin)

    var v: VBoxContainer = VBoxContainer.new()
    v.alignment = BoxContainer.ALIGNMENT_CENTER
    v.add_theme_constant_override("separation",7)
    margin.add_child(v)

    var medal: Label = Label.new()
    medal.text = "%d위" % rank_number
    medal.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    medal.add_theme_font_size_override("font_size",34 if rank_number == 1 else 28)
    v.add_child(medal)

    var kart_id_value: String = str(entry.get("kart_id","rookie"))
    var character_color: Color = Color(0.3,0.7,1.0)
    if kart_data.has(kart_id_value):
        var raw_color: Array = (kart_data[kart_id_value] as Dictionary).get("color",[0.3,0.7,1.0])
        if raw_color.size() >= 3:
            character_color = Color(float(raw_color[0]),float(raw_color[1]),float(raw_color[2]))

    var character: PodiumCharacter = PodiumCharacter.new()
    character.custom_minimum_size = Vector2(150,120)
    character.set_body_color(character_color)
    character.set_koala_mode(kart_id_value == "running_seala")
    character.set_dragon_armor(kart_id_value == "gold")
    v.add_child(character)

    var name_label: Label = Label.new()
    name_label.text = str(entry.get("name","UNKNOWN"))
    name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    name_label.add_theme_font_size_override("font_size",17)
    v.add_child(name_label)

    var record_time: float = float(entry.get("time",0.0))
    var record_label: Label = Label.new()
    record_label.text = "기록  %.2f초" % record_time
    record_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    record_label.add_theme_font_size_override("font_size",18)
    v.add_child(record_label)

    var gap_label: Label = Label.new()
    if rank_number == 1:
        gap_label.text = "BEST RECORD"
    else:
        gap_label.text = "1위와  +%.2f초" % max(0.0,record_time-first_time)
    gap_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    gap_label.modulate = Color(0.83,0.85,0.90)
    v.add_child(gap_label)

    if is_player:
        var you: Label = Label.new()
        you.text = "내 캐릭터"
        you.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        you.add_theme_font_size_override("font_size",15)
        you.modulate = Color(1.0,0.82,0.28)
        v.add_child(you)

    var pedestal: ColorRect = ColorRect.new()
    pedestal.custom_minimum_size = Vector2(0,56 if rank_number == 1 else (44 if rank_number == 2 else 36))
    if rank_number == 1:
        pedestal.color = Color(0.95,0.67,0.10,0.72)
    elif rank_number == 2:
        pedestal.color = Color(0.68,0.72,0.78,0.72)
    else:
        pedestal.color = Color(0.66,0.32,0.12,0.72)
    v.add_child(pedestal)

    return card

func _get_ranked_entries() -> Array[Dictionary]:
    var entries: Array[Dictionary] = []

    for kart in finished_order:
        if kart == null or not is_instance_valid(kart):
            continue
        var display_name: String = kart.driver_name
        if display_name.is_empty():
            display_name = kart.kart_id
        entries.append({
            "kart":kart,
            "kart_id":kart.kart_id,
            "name":display_name,
            "time":float(finished_times.get(kart.get_instance_id(),0.0))
        })

    return entries

func _get_eliminated_names() -> Array[String]:
    var names: Array[String] = []
    for kart in race_karts:
        if kart == null or not is_instance_valid(kart):
            continue
        if finished_order.has(kart):
            continue
        var display_name: String = kart.driver_name
        if display_name.is_empty():
            display_name = kart.kart_id
        names.append(display_name)
    return names

func _return_to_lobby() -> void:
    race_result_open = false
    _clear_race(true)
    menu_layer.visible = true
    if lobby_ui:
        lobby_ui.refresh_hub()
        lobby_ui.show_last_reward(last_race_reward)
    elif result_label and result_label.text.is_empty():
        result_label.text = "로비로 돌아왔습니다."

func _clear_race(disconnect_network: bool) -> void:
    start_countdown_active = false
    start_countdown_left = 0.0
    start_green_display_left = 0.0
    start_boost_p1 = false
    start_boost_p2 = false
    start_early_p1 = false
    start_early_p2 = false
    _hide_start_lights()

    finish_countdown_active = false
    finish_countdown_left = 0.0
    finished_order.clear()
    finished_times.clear()

    if finish_countdown_layer and is_instance_valid(finish_countdown_layer):
        finish_countdown_layer.queue_free()
    finish_countdown_layer = null
    finish_countdown_label = null

    if podium_layer and is_instance_valid(podium_layer):
        podium_layer.queue_free()
    podium_layer = null
    race_result_open = false

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
