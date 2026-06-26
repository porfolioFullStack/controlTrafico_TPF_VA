extends Node
## Singleton global — sobrevive cambios de escena.
## Guarda el PID del detector Python y lo mata al cerrar la app.

var detector_pid: int = -1


func _notification(what: int) -> void:
    if what == NOTIFICATION_WM_CLOSE_REQUEST:
        if detector_pid >= 0 and OS.is_process_running(detector_pid):
            OS.kill(detector_pid)
        get_tree().quit()
