class_name CameraRig
extends Node3D

var camera: Camera3D
var preset_names: Array[String] = [
    "vista_detector",
    "derecha_alta",
    "centro_frontal",
    "izquierda_alta",
    "angular_superior",
]
var current_index: int = 0
var target: Vector3 = Vector3(0.0, 0.0, -4.0)

var presets: Dictionary = {
    "vista_detector": {
        "position": Vector3(16.0, 12.0, -35.0),
        "target": Vector3(0.0, 0.2, -4.0),
        "fov": 55.0,
    },
    "derecha_alta": {
        "position": Vector3(22.0, 16.0, -42.0),
        "target": Vector3(0.0, 0.0, -4.0),
        "fov": 58.0,
    },
    "centro_frontal": {
        "position": Vector3(0.0, 12.0, -48.0),
        "target": Vector3(0.0, 0.0, -2.0),
        "fov": 52.0,
    },
    "izquierda_alta": {
        "position": Vector3(-22.0, 16.0, -42.0),
        "target": Vector3(0.0, 0.0, -4.0),
        "fov": 58.0,
    },
    "angular_superior": {
        "position": Vector3(14.0, 34.0, -30.0),
        "target": Vector3(0.0, 0.0, -2.0),
        "fov": 62.0,
    },
}


func _ready() -> void:
    camera = Camera3D.new()
    camera.name = "Camera3D"
    add_child(camera)
    camera.current = true
    apply_preset(preset_names[current_index])


func next_preset() -> void:
    current_index = (current_index + 1) % preset_names.size()
    apply_preset(preset_names[current_index])


func current_preset_name() -> String:
    return preset_names[current_index]


func apply_preset(preset_name: String) -> void:
    var preset: Dictionary = presets[preset_name]
    position = preset["position"]
    target = preset["target"]
    camera.fov = preset["fov"]
    look_at_target()


func adjust_rotation(delta_x: float, delta_y: float, delta_z: float) -> void:
    rotation_degrees.x += delta_x
    rotation_degrees.y += delta_y
    rotation_degrees.z += delta_z


func move_local(right: float, up: float, forward: float) -> void:
    var basis := global_transform.basis
    var movement := basis.x * right + Vector3.UP * up - basis.z * forward
    global_position += movement
    target += movement
    look_at_target()


func move_camera_local(right: float, up: float, forward: float) -> void:
    var basis := global_transform.basis
    var movement := basis.x * right + Vector3.UP * up - basis.z * forward
    global_position += movement


func zoom(delta_fov: float) -> void:
    camera.fov = clamp(camera.fov + delta_fov, 24.0, 85.0)


func look_at_target() -> void:
    look_at(target, Vector3.UP)


func reset_current_preset() -> void:
    apply_preset(preset_names[current_index])
