class_name VehicleSpawner
extends Node3D

# Niveles de cola detectados
const FREE:   String = "flujo_libre"
const LOW:    String = "cola_baja"
const MEDIUM: String = "cola_media"
const HIGH:   String = "cola_alta"

const LANES:    Array = [-4.5, -1.5, 1.5, 4.5]
const SPAWN_Z:  float = -72.0
const QUEUE_Z:  float = -10.0   # zona de conteo de cola (desde stop hacia atrás)
const QUEUE_END: float = -68.0

# Umbrales de cola por carril (autos en zona de cola)
const THRESH_LOW:    int = 2
const THRESH_MEDIUM: int = 5
const THRESH_HIGH:   int = 9

var traffic_light: TrafficLightController
var fleet: Array = []       # todos los vehículos vivos

var _spawn_timer:  float = 0.0
var _spawn_interval: float = 2.5   # segundos entre spawns (varía aleatoriamente)
var _rate_timer:   float = 0.0    # tiempo hasta próximo cambio de tasa

var detected_queue: String = FREE


func setup(light: TrafficLightController) -> void:
    traffic_light = light
    _rate_timer   = randf_range(10.0, 25.0)
    _spawn_initial()


func _process(delta: float) -> void:
    _tick_rate(delta)
    _tick_spawn(delta)
    _prune_fleet()
    _detect_queue()


# ── Detección de cola ────────────────────────────────────────────────────────

func _detect_queue() -> void:
    var counts: Array = [0, 0, 0, 0]
    for v in fleet:
        if not is_instance_valid(v):
            continue
        var vc := v as VehicleController
        if vc.position.z <= QUEUE_Z and vc.position.z >= QUEUE_END:
            for i in range(LANES.size()):
                if abs(vc.position.x - LANES[i]) < 0.8:
                    counts[i] += 1
                    break

    var peak: int = 0
    for c in counts:
        if c > peak:
            peak = c

    if peak <= 0:
        detected_queue = FREE
    elif peak <= THRESH_LOW:
        detected_queue = LOW
    elif peak <= THRESH_MEDIUM:
        detected_queue = MEDIUM
    else:
        detected_queue = HIGH


# ── Spawning continuo ────────────────────────────────────────────────────────

func _tick_rate(delta: float) -> void:
    _rate_timer -= delta
    if _rate_timer > 0.0:
        return
    # Cambiar tasa de spawn aleatoriamente (simula variación de tráfico real)
    _rate_timer    = randf_range(15.0, 40.0)
    _spawn_interval = randf_range(0.8, 5.5)


func _tick_spawn(delta: float) -> void:
    _spawn_timer -= delta
    if _spawn_timer > 0.0:
        return
    _spawn_timer = _spawn_interval + randf_range(-0.4, 0.4)

    # Carril aleatorio (los carriles no se llenan igual → realismo)
    var lane_x: float = LANES[randi() % LANES.size()]
    if _lane_clear_to_spawn(lane_x):
        _spawn(lane_x)


func _lane_clear_to_spawn(lane_x: float) -> bool:
    for v in fleet:
        if not is_instance_valid(v):
            continue
        var vc := v as VehicleController
        if abs(vc.position.x - lane_x) < 0.8 and vc.position.z < SPAWN_Z + 10.0:
            return false
    return true


func _spawn(lane_x: float) -> void:
    var vc: VehicleController = preload("res://scripts/vehicle_controller.gd").new()
    vc.setup(lane_x, SPAWN_Z, randf_range(7.0, 11.5), traffic_light, fleet)
    add_child(vc)
    fleet.append(vc)


func _spawn_initial() -> void:
    for i in range(8):
        var lane_x: float = LANES[i % LANES.size()]
        var z: float = randf_range(-18.0, -60.0)
        var vc: VehicleController = preload("res://scripts/vehicle_controller.gd").new()
        vc.setup(lane_x, z, randf_range(7.5, 11.0), traffic_light, fleet)
        add_child(vc)
        fleet.append(vc)


func _prune_fleet() -> void:
    fleet = fleet.filter(func(v): return is_instance_valid(v))
