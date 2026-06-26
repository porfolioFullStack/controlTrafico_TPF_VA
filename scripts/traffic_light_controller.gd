class_name TrafficLightController
extends Node3D

signal state_changed(state: String)

const GREEN: String = "green"
const YELLOW: String = "yellow"
const RED: String = "red"

@export var green_seconds: float = 30.0
@export var yellow_seconds: float = 5.0
@export var red_seconds: float = 45.0

var state: String = GREEN
var remaining: float = green_seconds

var red_lamp: MeshInstance3D
var yellow_lamp: MeshInstance3D
var green_lamp: MeshInstance3D
var timer_label: Label3D


func _ready() -> void:
    _build_model()
    _apply_state()


func _process(delta: float) -> void:
    remaining -= delta
    if remaining <= 0.0:
        _advance_state()
    _update_timer()


func is_vehicle_green() -> bool:
    return state == GREEN


func is_vehicle_yellow() -> bool:
    return state == YELLOW


func force_state(next_state: String) -> void:
    state = next_state
    match state:
        GREEN:
            remaining = green_seconds
        YELLOW:
            remaining = yellow_seconds
        RED:
            remaining = red_seconds
        _:
            state = RED
            remaining = red_seconds
    _apply_state()
    state_changed.emit(state)


func _advance_state() -> void:
    if state == GREEN:
        state = YELLOW
        remaining = yellow_seconds
    elif state == YELLOW:
        state = RED
        remaining = red_seconds
    else:
        state = GREEN
        remaining = green_seconds
    _apply_state()
    state_changed.emit(state)


func _build_model() -> void:
    var pole: MeshInstance3D = MeshInstance3D.new()
    pole.name = "Pole"
    var pole_mesh: CylinderMesh = CylinderMesh.new()
    pole_mesh.height = 5.5
    pole_mesh.top_radius = 0.08
    pole_mesh.bottom_radius = 0.08
    pole.mesh = pole_mesh
    pole.position = Vector3(0.0, 2.75, 0.0)
    pole.material_override = _mat(Color(0.12, 0.12, 0.12))
    add_child(pole)

    var head: MeshInstance3D = MeshInstance3D.new()
    head.name = "SignalHead"
    var head_mesh: BoxMesh = BoxMesh.new()
    head_mesh.size = Vector3(0.8, 2.0, 0.35)
    head.mesh = head_mesh
    head.position = Vector3(0.0, 5.0, 0.0)
    head.material_override = _mat(Color(0.03, 0.03, 0.03))
    add_child(head)

    red_lamp = _lamp(Vector3(0.0, 5.55, -0.2), Color.RED)
    yellow_lamp = _lamp(Vector3(0.0, 5.0, -0.2), Color.YELLOW)
    green_lamp = _lamp(Vector3(0.0, 4.45, -0.2), Color.GREEN)
    add_child(red_lamp)
    add_child(yellow_lamp)
    add_child(green_lamp)

    timer_label = Label3D.new()
    timer_label.name = "TimerLabel"
    timer_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    timer_label.font_size = 72
    timer_label.modulate = Color(1.0, 0.1, 0.1)
    timer_label.outline_size = 8
    timer_label.position = Vector3(0.0, 6.35, -0.05)
    add_child(timer_label)


func _lamp(pos: Vector3, color: Color) -> MeshInstance3D:
    var lamp: MeshInstance3D = MeshInstance3D.new()
    var sphere: SphereMesh = SphereMesh.new()
    sphere.radius = 0.22
    sphere.height = 0.44
    lamp.mesh = sphere
    lamp.position = pos
    lamp.material_override = _mat(color.darkened(0.65))
    return lamp


func _apply_state() -> void:
    red_lamp.material_override = _mat(Color.RED if state == RED else Color.RED.darkened(0.75))
    yellow_lamp.material_override = _mat(Color.YELLOW if state == YELLOW else Color.YELLOW.darkened(0.75))
    green_lamp.material_override = _mat(Color.GREEN if state == GREEN else Color.GREEN.darkened(0.75))


func _update_timer() -> void:
    var seconds: int = max(0, int(ceil(remaining)))
    timer_label.text = "%02d" % seconds
    if state == GREEN:
        timer_label.modulate = Color(0.1, 1.0, 0.1)
    elif state == YELLOW:
        timer_label.modulate = Color(1.0, 0.9, 0.1)
    else:
        timer_label.modulate = Color(1.0, 0.1, 0.1)


func _mat(color: Color) -> StandardMaterial3D:
    var material: StandardMaterial3D = StandardMaterial3D.new()
    material.albedo_color = color
    material.emission_enabled = true
    material.emission = color
    material.emission_energy_multiplier = 0.5
    return material
