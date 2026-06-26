class_name VehicleSpawner
extends Node3D

const LOW: String = "cola_baja"
const MEDIUM: String = "cola_media"
const HIGH: String = "cola_alta"
const FREE: String = "flujo_libre"

var traffic_light: TrafficLightController
var vehicles: Array[VehicleController] = []
var lane_positions: Array[float] = [-4.5, -1.5, 1.5, 4.5]
var traffic_state: String = LOW


func setup(light: TrafficLightController) -> void:
    traffic_light = light
    set_traffic_state(LOW)


func set_traffic_state(next_state: String) -> void:
    traffic_state = next_state
    _clear_vehicles()

    var count: int = 8
    var spacing: float = 9.5
    var base_speed: float = 8.0
    match traffic_state:
        FREE:
            count = 6
            spacing = 17.0
            base_speed = 10.5
        LOW:
            count = 8
            spacing = 11.0
            base_speed = 9.0
        MEDIUM:
            count = 16
            spacing = 6.2
            base_speed = 7.2
        HIGH:
            count = 28
            spacing = 3.8
            base_speed = 5.8

    for i in range(count):
        var car: VehicleController = preload("res://scripts/vehicle_controller.gd").new()
        var lane: float = lane_positions[i % lane_positions.size()]
        var slot: int = int(i / lane_positions.size())
        var z: float = -8.0 - float(slot) * spacing - randf_range(0.0, 1.5)
        car.setup(lane, z, base_speed + randf_range(-1.0, 1.0), slot, traffic_light)
        add_child(car)
        vehicles.append(car)


func _clear_vehicles() -> void:
    for vehicle in vehicles:
        if is_instance_valid(vehicle):
            vehicle.queue_free()
    vehicles.clear()
