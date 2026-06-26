class_name PythonBridge
extends Node

## Lee config/traffic_state.json escrito por traffic_detector.py y emite
## state_updated cada vez que cambia el timestamp (es decir, hay dato nuevo).

signal state_updated(state: String, remaining: float)

@export var poll_interval: float = 0.5

var _state_path: String
var _last_ts: float = -1.0
var _last_update_time: float = -999.0
var _timer: Timer


func _ready() -> void:
	_state_path = ProjectSettings.globalize_path("res://config/traffic_state.json")
	_timer = Timer.new()
	_timer.wait_time = poll_interval
	_timer.one_shot = false
	_timer.timeout.connect(_poll)
	add_child(_timer)
	_timer.start()


func seconds_since_last_update() -> float:
	return Time.get_ticks_msec() / 1000.0 - _last_update_time


func _poll() -> void:
	if not FileAccess.file_exists(_state_path):
		return
	var f := FileAccess.open(_state_path, FileAccess.READ)
	if f == null:
		return
	var text := f.get_as_text()
	f.close()

	var data = JSON.parse_string(text)
	if not data is Dictionary:
		return

	var ts: float = data.get("ts", -1.0)
	if ts == _last_ts:
		return
	_last_ts = ts
	_last_update_time = Time.get_ticks_msec() / 1000.0

	var state: String = data.get("state", "")
	if state not in ["red", "green", "yellow"]:
		return

	var remaining := _parse_timer(data.get("timer", "?"))
	state_updated.emit(state, remaining)


func _parse_timer(t: String) -> float:
	# Formato "MMSS" de 4 dígitos: "0028" → 28 s, "0130" → 90 s
	# Retorna -1 si contiene '?' o no es parseable
	if t.length() == 4 and not "?" in t:
		var mm := t.substr(0, 2).to_int()
		var ss := t.substr(2, 2).to_int()
		return float(mm * 60 + ss)
	return -1.0
