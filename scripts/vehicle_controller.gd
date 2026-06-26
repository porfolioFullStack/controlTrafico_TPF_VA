class_name VehicleController
extends Node3D

var lane_x: float = 0.0
var speed: float = 8.0

const STOP_Z: float    = -8.5   # línea de detención
const END_Z: float     =  72.0  # sale de escena
const DESIRED_GAP: float = 4.4  # distancia al auto de adelante
const MIN_GAP: float     = 1.4  # brecha mínima antes de frenar a 0

var traffic_light: TrafficLightController
var fleet: Array        # referencia al array del spawner (para car-following)
var stopped: bool = false


func setup(p_lane_x: float, p_z: float, p_speed: float,
           p_light: TrafficLightController, p_fleet: Array) -> void:
    lane_x    = p_lane_x
    speed     = p_speed
    traffic_light = p_light
    fleet     = p_fleet
    position  = Vector3(lane_x, 0.45, p_z)


func _ready() -> void:
    _build_model()


func _process(delta: float) -> void:
    var green: bool = traffic_light == null or traffic_light.is_vehicle_green()
    var gap: float  = _leader_gap()

    # Velocidad limitada por el vehículo de adelante
    var v: float = speed * clamp((gap - MIN_GAP) / DESIRED_GAP, 0.0, 1.0)

    # En rojo: frenar si pasamos la línea de detención
    if not green and position.z >= STOP_Z:
        stopped = true
        return

    stopped = v < 0.3
    position.z += v * delta

    if position.z > END_Z:
        queue_free()


func _leader_gap() -> float:
    var best: float = 999.0
    for v in fleet:
        if v == self or not is_instance_valid(v):
            continue
        var other := v as VehicleController
        if abs(other.position.x - position.x) > 0.8:
            continue  # carril distinto
        var dz: float = other.position.z - position.z
        if dz > 0.0 and dz < 60.0:
            best = min(best, dz)
    return best


func _build_model() -> void:
    var body := MeshInstance3D.new()
    var bm   := BoxMesh.new()
    bm.size  = Vector3(1.7, 0.8, 3.2)
    body.mesh = bm
    body.material_override = _mat(_random_color())
    add_child(body)

    var cabin := MeshInstance3D.new()
    var cm    := BoxMesh.new()
    cm.size   = Vector3(1.35, 0.55, 1.45)
    cabin.mesh = cm
    cabin.position = Vector3(0.0, 0.58, -0.25)
    cabin.material_override = _mat(Color(0.75, 0.82, 0.9, 0.95))
    add_child(cabin)

    for wx in [-0.95, 0.95]:
        for wz in [-1.15, 1.15]:
            var w := MeshInstance3D.new()
            var wm := CylinderMesh.new()
            wm.height = 0.22; wm.top_radius = 0.32; wm.bottom_radius = 0.32
            w.mesh = wm
            w.rotation_degrees.z = 90.0
            w.position = Vector3(wx, -0.35, wz)
            w.material_override = _mat(Color(0.02, 0.02, 0.02))
            add_child(w)


func _random_color() -> Color:
    var palette: Array[Color] = [
        Color(0.9,  0.9,  0.86),
        Color(0.95, 0.82, 0.1),
        Color(0.75, 0.08, 0.05),
        Color(0.2,  0.25, 0.3),
        Color(0.05, 0.18, 0.5),
        Color(0.55, 0.55, 0.55),
    ]
    return palette[randi() % palette.size()]


func _mat(color: Color) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.albedo_color = color
    m.roughness    = 0.8
    return m
