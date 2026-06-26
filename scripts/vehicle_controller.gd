class_name VehicleController
extends Node3D

@export var lane_x: float = 0.0
@export var speed: float = 8.0
@export var stop_z: float = -8.0
@export var end_z: float = 70.0
@export var start_z: float = -75.0

var queue_slot: int = 0
var desired_gap: float = 4.6
var traffic_light: TrafficLightController
var stopped: bool = false


func setup(
    p_lane_x: float,
    p_z: float,
    p_speed: float,
    p_queue_slot: int,
    p_light: TrafficLightController
) -> void:
    lane_x = p_lane_x
    position = Vector3(lane_x, 0.45, p_z)
    speed = p_speed
    queue_slot = p_queue_slot
    traffic_light = p_light


func _ready() -> void:
    _build_model()


func _process(delta: float) -> void:
    var target_stop: float = stop_z - float(queue_slot) * desired_gap
    var should_stop: bool = traffic_light != null and not traffic_light.is_vehicle_green()
    stopped = should_stop and position.z >= target_stop - 0.8 and position.z <= stop_z + 2.0

    if stopped:
        return

    if should_stop and position.z < target_stop:
        var dist: float = max(target_stop - position.z, 0.0)
        var brake_factor: float = clamp(dist / 16.0, 0.18, 1.0)
        position.z += speed * brake_factor * delta
    else:
        position.z += speed * delta

    if position.z > end_z:
        position.z = start_z - randf_range(0.0, 22.0)


func _build_model() -> void:
    var body: MeshInstance3D = MeshInstance3D.new()
    body.name = "Body"
    var body_mesh: BoxMesh = BoxMesh.new()
    body_mesh.size = Vector3(1.7, 0.8, 3.2)
    body.mesh = body_mesh
    body.position = Vector3.ZERO
    body.material_override = _mat(_random_car_color())
    add_child(body)

    var cabin: MeshInstance3D = MeshInstance3D.new()
    cabin.name = "Cabin"
    var cabin_mesh: BoxMesh = BoxMesh.new()
    cabin_mesh.size = Vector3(1.35, 0.55, 1.45)
    cabin.mesh = cabin_mesh
    cabin.position = Vector3(0.0, 0.58, -0.25)
    cabin.material_override = _mat(Color(0.75, 0.82, 0.9, 0.95))
    add_child(cabin)

    for x in [-0.95, 0.95]:
        for z in [-1.15, 1.15]:
            var wheel: MeshInstance3D = MeshInstance3D.new()
            var wheel_mesh: CylinderMesh = CylinderMesh.new()
            wheel_mesh.height = 0.22
            wheel_mesh.top_radius = 0.32
            wheel_mesh.bottom_radius = 0.32
            wheel.mesh = wheel_mesh
            wheel.rotation_degrees.z = 90.0
            wheel.position = Vector3(x, -0.35, z)
            wheel.material_override = _mat(Color(0.02, 0.02, 0.02))
            add_child(wheel)


func _random_car_color() -> Color:
    var colors: Array[Color] = [
        Color(0.9, 0.9, 0.86),
        Color(0.95, 0.82, 0.1),
        Color(0.75, 0.08, 0.05),
        Color(0.2, 0.25, 0.3),
        Color(0.05, 0.18, 0.5),
        Color(0.55, 0.55, 0.55),
    ]
    return colors[randi() % colors.size()]


func _mat(color: Color) -> StandardMaterial3D:
    var material: StandardMaterial3D = StandardMaterial3D.new()
    material.albedo_color = color
    material.roughness = 0.8
    return material
