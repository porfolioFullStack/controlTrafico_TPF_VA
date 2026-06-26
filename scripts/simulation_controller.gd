extends Node3D

const TrafficLight := preload("res://scripts/traffic_light_controller.gd")
const VehicleSpawnerScript := preload("res://scripts/vehicle_spawner.gd")
const CameraRigScript := preload("res://scripts/camera_rig.gd")
const PythonBridgeScript := preload("res://scripts/python_bridge.gd")

var traffic_light: TrafficLightController
var spawner: VehicleSpawner
var camera_rig: CameraRig
var bridge: PythonBridge
var hud_label: Label
var traffic_state := VehicleSpawner.LOW


func _ready() -> void:
    randomize()
    _build_lighting()
    _build_city()
    _build_crosswalk()
    _build_traffic_light()
    _build_spawner()
    _build_camera()
    _build_hud()
    _build_bridge()


func _process(_delta: float) -> void:
    _handle_camera_adjustment()
    _update_hud()


func _unhandled_input(event: InputEvent) -> void:
    if not event is InputEventKey:
        return
    var key_event := event as InputEventKey
    if not key_event.pressed or key_event.echo:
        return

    if key_event.keycode == KEY_1:
        traffic_state = VehicleSpawner.LOW
        spawner.set_traffic_state(traffic_state)
    elif key_event.keycode == KEY_2:
        traffic_state = VehicleSpawner.MEDIUM
        spawner.set_traffic_state(traffic_state)
    elif key_event.keycode == KEY_3:
        traffic_state = VehicleSpawner.HIGH
        spawner.set_traffic_state(traffic_state)
    elif key_event.keycode == KEY_4:
        traffic_state = VehicleSpawner.FREE
        spawner.set_traffic_state(traffic_state)
    elif key_event.keycode == KEY_C:
        camera_rig.next_preset()
    elif key_event.keycode == KEY_R:
        camera_rig.reset_current_preset()


func _handle_camera_adjustment() -> void:
    var move_step: float = 0.35
    var rot_step: float = 0.45
    if Input.is_key_pressed(KEY_LEFT):
        camera_rig.move_local(-move_step, 0.0, 0.0)
    if Input.is_key_pressed(KEY_RIGHT):
        camera_rig.move_local(move_step, 0.0, 0.0)
    if Input.is_key_pressed(KEY_UP):
        camera_rig.move_camera_local(0.0, 0.0, move_step)
    if Input.is_key_pressed(KEY_DOWN):
        camera_rig.move_camera_local(0.0, 0.0, -move_step)
    if Input.is_key_pressed(KEY_PAGEUP):
        camera_rig.move_local(0.0, move_step, 0.0)
    if Input.is_key_pressed(KEY_PAGEDOWN):
        camera_rig.move_local(0.0, -move_step, 0.0)
    if Input.is_key_pressed(KEY_EQUAL) or Input.is_key_pressed(KEY_KP_ADD):
        camera_rig.zoom(-0.4)
    if Input.is_key_pressed(KEY_MINUS) or Input.is_key_pressed(KEY_KP_SUBTRACT):
        camera_rig.zoom(0.4)

    if Input.is_key_pressed(KEY_W):
        camera_rig.adjust_rotation(-rot_step, 0.0, 0.0)
    if Input.is_key_pressed(KEY_S):
        camera_rig.adjust_rotation(rot_step, 0.0, 0.0)
    if Input.is_key_pressed(KEY_Q):
        camera_rig.adjust_rotation(0.0, -rot_step, 0.0)
    if Input.is_key_pressed(KEY_E):
        camera_rig.adjust_rotation(0.0, rot_step, 0.0)
    if Input.is_key_pressed(KEY_Z):
        camera_rig.adjust_rotation(0.0, 0.0, -rot_step)
    if Input.is_key_pressed(KEY_X):
        camera_rig.adjust_rotation(0.0, 0.0, rot_step)


func _build_lighting() -> void:
    var world := WorldEnvironment.new()
    var env := Environment.new()
    env.background_mode = Environment.BG_COLOR
    env.background_color = Color(0.55, 0.62, 0.68)
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color(0.85, 0.85, 0.82)
    env.ambient_light_energy = 0.75
    world.environment = env
    add_child(world)

    var sun := DirectionalLight3D.new()
    sun.name = "Sun"
    sun.rotation_degrees = Vector3(-48.0, 34.0, 0.0)
    sun.light_energy = 1.4
    add_child(sun)


func _build_city() -> void:
    _add_box("Road", Vector3(13.0, 0.08, 150.0), Vector3(0.0, -0.04, 0.0), Color(0.18, 0.18, 0.18))
    _add_box("LeftSidewalk", Vector3(5.0, 0.18, 150.0), Vector3(-9.3, 0.02, 0.0), Color(0.45, 0.44, 0.4))
    _add_box("RightSidewalk", Vector3(5.0, 0.18, 150.0), Vector3(9.3, 0.02, 0.0), Color(0.48, 0.47, 0.43))

    for x in [-3.0, 0.0, 3.0]:
        _add_lane_line(x)

    for i in range(12):
        var z := -64.0 + i * 12.0
        _add_building(Vector3(-14.0, 0.0, z), 5.0 + randf_range(0.0, 6.0))
        _add_building(Vector3(14.0, 0.0, z + randf_range(-3.0, 3.0)), 6.0 + randf_range(0.0, 8.0))

    for z in [-45.0, -20.0, 5.0, 30.0]:
        _add_lamp_post(Vector3(-7.0, 0.0, z))
        _add_lamp_post(Vector3(7.0, 0.0, z + 8.0))


func _build_crosswalk() -> void:
    for i in range(8):
        var x := -5.4 + i * 1.55
        _add_box("CrosswalkStripe", Vector3(0.9, 0.03, 4.0), Vector3(x, 0.08, -6.0), Color(0.9, 0.9, 0.85))
    _add_box("RiveraIndartePedestrianAxis", Vector3(22.0, 0.025, 0.6), Vector3(0.0, 0.09, -6.0), Color(0.75, 0.75, 0.68))


func _build_traffic_light() -> void:
    traffic_light = TrafficLight.new()
    traffic_light.name = "TrafficLight"
    traffic_light.position = Vector3(7.2, 0.0, -8.4)
    traffic_light.rotation_degrees.y = -28.0
    add_child(traffic_light)


func _build_spawner() -> void:
    spawner = VehicleSpawnerScript.new()
    spawner.name = "VehicleSpawner"
    add_child(spawner)
    spawner.setup(traffic_light)


func _build_camera() -> void:
    camera_rig = CameraRigScript.new()
    camera_rig.name = "CameraRig"
    add_child(camera_rig)


func _build_bridge() -> void:
    bridge = PythonBridgeScript.new()
    bridge.name = "PythonBridge"
    add_child(bridge)
    bridge.state_updated.connect(_on_python_state)


func _on_python_state(state: String, remaining: float) -> void:
    traffic_light.force_state(state)
    if remaining >= 0.0:
        traffic_light.remaining = remaining


func _build_hud() -> void:
    var layer := CanvasLayer.new()
    layer.name = "HUD"
    add_child(layer)
    hud_label = Label.new()
    hud_label.position = Vector2(16, 14)
    hud_label.add_theme_font_size_override("font_size", 18)
    hud_label.add_theme_color_override("font_color", Color.WHITE)
    hud_label.add_theme_color_override("font_shadow_color", Color.BLACK)
    hud_label.add_theme_constant_override("shadow_offset_x", 2)
    hud_label.add_theme_constant_override("shadow_offset_y", 2)
    layer.add_child(hud_label)


func _update_hud() -> void:
    var state := traffic_light.state if traffic_light != null else "?"
    var seconds := int(ceil(traffic_light.remaining)) if traffic_light != null else 0
    var bridge_status := "sin señal"
    if bridge != null:
        var age := bridge.seconds_since_last_update()
        if age < 2.0:
            bridge_status = "OK"
        elif age < 10.0:
            bridge_status = "%.0fs sin dato" % age
    hud_label.text = (
        "Av. Colon / Rivera Indarte\n"
        + "Trafico: " + traffic_state + "\n"
        + "Semaforo: " + state + "  timer: " + str(seconds) + "s\n"
        + "Python: " + bridge_status + "\n"
        + "Camara: " + camera_rig.current_preset_name() + "\n"
        + "1 baja | 2 media | 3 alta | 4 libre | C camara | R reset\n"
        + "Arriba/abajo avanzar | Izq/der lateral | PgUp/PgDn altura | +/- zoom\n"
        + "W/S pitch | Q/E yaw | Z/X roll"
    )


func _add_lane_line(x: float) -> void:
    for i in range(26):
        _add_box("LaneLine", Vector3(0.12, 0.025, 3.0), Vector3(x, 0.08, -70.0 + i * 6.0), Color(0.92, 0.86, 0.42))


func _add_building(pos: Vector3, height: float) -> void:
    var width := randf_range(3.8, 6.5)
    var depth := randf_range(7.0, 12.0)
    var building := _add_box("Building", Vector3(width, height, depth), Vector3(pos.x, height / 2.0, pos.z), Color(0.45, 0.46, 0.47))
    for floor_i in range(int(height / 1.5)):
        for side in [-1, 1]:
            var window := _add_box("Window", Vector3(0.04, 0.55, 0.75), Vector3(pos.x + side * width / 2.0, 1.2 + floor_i * 1.35, pos.z - 2.5), Color(0.7, 0.82, 0.9))
            window.reparent(building)


func _add_lamp_post(pos: Vector3) -> void:
    var post := _add_box("LampPost", Vector3(0.08, 4.5, 0.08), Vector3(pos.x, 2.25, pos.z), Color(0.08, 0.08, 0.08))
    var lamp := _add_box("LampGlow", Vector3(0.8, 0.16, 0.8), Vector3(pos.x, 4.55, pos.z), Color(1.0, 0.9, 0.6))
    lamp.reparent(post)


func _add_box(name: String, size: Vector3, pos: Vector3, color: Color) -> MeshInstance3D:
    var node := MeshInstance3D.new()
    node.name = name
    var mesh := BoxMesh.new()
    mesh.size = size
    node.mesh = mesh
    node.position = pos
    node.material_override = _mat(color)
    add_child(node)
    return node


func _mat(color: Color) -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    material.roughness = 0.85
    return material
