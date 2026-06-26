extends Control

enum Phase { IDLE, CAL_PANEL, CAL_DIGITS }

var _phase: Phase = Phase.IDLE
var _pid: int = -1
var _poll: float = 0.0

var _root: String
var _python: String
var _pythonw: String

var _btn_cal: Button
var _btn_sim: Button
var _lbl_cal: Label
var _lbl_log: Label


func _ready() -> void:
    set_anchors_preset(Control.PRESET_FULL_RECT)
    _root    = ProjectSettings.globalize_path("res://")
    _python  = _root + ".venv/Scripts/python.exe"
    _pythonw = _root + ".venv/Scripts/pythonw.exe"
    _build_ui()
    _refresh()


func _process(delta: float) -> void:
    if _pid < 0:
        return
    _poll -= delta
    if _poll > 0.0:
        return
    _poll = 0.4
    if not OS.is_process_running(_pid):
        _pid = -1
        _on_step_done()


func _on_step_done() -> void:
    match _phase:
        Phase.CAL_PANEL:
            if _has_polygon():
                _phase = Phase.CAL_DIGITS
                _log("Panel OK. Abriendo calibración de dígitos...")
                _launch("digit_calibrator.py", true)
            else:
                _phase = Phase.IDLE
                _log("Calibración de panel cancelada.")
                _refresh()
        Phase.CAL_DIGITS:
            _phase = Phase.IDLE
            if _has_digits():
                _log("✓ Calibración completa.")
            else:
                _log("Calibración de dígitos cancelada.")
            _refresh()


# ── Botones ──────────────────────────────────────────────────────────────────

func _on_calibrate() -> void:
    if _phase != Phase.IDLE:
        return
    _phase = Phase.CAL_PANEL
    _log("Abriendo selector de panel...  (ajustá los vértices → ENTER)")
    _launch("roi_selector.py", true)
    _refresh()


func _on_simulate() -> void:
    if not _has_digits():
        _log("Primero calibrá el semáforo.")
        return
    _log("Iniciando detector y simulador...")
    var pid: int = OS.create_process(_pythonw, [_root + "scriptsPy/traffic_detector.py"])
    AppState.detector_pid = pid
    get_tree().change_scene_to_file("res://scenes/main.tscn")


# ── Helpers ──────────────────────────────────────────────────────────────────

func _launch(script: String, console: bool) -> void:
    var exe: String = _python if console else _pythonw
    _pid  = OS.create_process(exe, [_root + "scriptsPy/" + script])
    _poll = 0.5


func _roi() -> Variant:
    var path: String = _root + "config/roi.json"
    if not FileAccess.file_exists(path):
        return null
    var text: String = FileAccess.get_file_as_string(path).strip_edges()
    if text.is_empty():
        return null
    return JSON.parse_string(text)


func _has_polygon() -> bool:
    var d = _roi()
    return d is Dictionary and d.has("polygon")


func _has_digits() -> bool:
    var d = _roi()
    if not d is Dictionary or not d.has("digits"):
        return false
    return (d["digits"] as Array).size() == 4


func _refresh() -> void:
    var busy: bool  = _phase != Phase.IDLE
    var has_d: bool = _has_digits()
    var has_p: bool = _has_polygon()

    _btn_cal.disabled = busy
    _btn_sim.disabled = not has_d or busy

    if has_d:
        _lbl_cal.text = "● Panel y dígitos calibrados"
        _lbl_cal.add_theme_color_override("font_color", Color(0.25, 0.9, 0.35))
    elif has_p:
        _lbl_cal.text = "◐ Panel calibrado — faltan dígitos"
        _lbl_cal.add_theme_color_override("font_color", Color(1.0, 0.75, 0.15))
    else:
        _lbl_cal.text = "○ Sin calibración"
        _lbl_cal.add_theme_color_override("font_color", Color(0.85, 0.3, 0.3))


func _log(msg: String) -> void:
    _lbl_log.text = msg
    _refresh()


# ── UI procedural ────────────────────────────────────────────────────────────

func _build_ui() -> void:
    # Fondo oscuro que llena toda la ventana
    var bg := ColorRect.new()
    bg.set_anchors_preset(Control.PRESET_FULL_RECT)
    bg.color = Color(0.07, 0.09, 0.11)
    add_child(bg)

    # CenterContainer para centrar el panel
    var center := CenterContainer.new()
    center.set_anchors_preset(Control.PRESET_FULL_RECT)
    add_child(center)

    # Panel de tamaño fijo
    var panel := PanelContainer.new()
    panel.custom_minimum_size = Vector2(440, 480)
    var panel_style := StyleBoxFlat.new()
    panel_style.bg_color = Color(0.11, 0.14, 0.18)
    panel_style.border_width_left   = 1
    panel_style.border_width_right  = 1
    panel_style.border_width_top    = 1
    panel_style.border_width_bottom = 1
    panel_style.border_color = Color(0.22, 0.28, 0.36)
    panel_style.set_corner_radius_all(8)
    panel_style.content_margin_left   = 48
    panel_style.content_margin_right  = 48
    panel_style.content_margin_top    = 40
    panel_style.content_margin_bottom = 40
    panel.add_theme_stylebox_override("panel", panel_style)
    center.add_child(panel)

    var vbox := VBoxContainer.new()
    vbox.add_theme_constant_override("separation", 16)
    panel.add_child(vbox)

    # Título
    vbox.add_child(_label("Av. Colón / Rivera Indarte", 24, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER))
    vbox.add_child(_label("Panel de Control", 13, Color(0.55, 0.6, 0.68), HORIZONTAL_ALIGNMENT_CENTER))
    vbox.add_child(_sep())

    # Sección semáforo
    vbox.add_child(_label("SEMÁFORO", 11, Color(0.45, 0.5, 0.58)))
    _lbl_cal = _label("", 15, Color.WHITE)
    vbox.add_child(_lbl_cal)

    _btn_cal = _button("  Calibrar semáforo", Color(0.14, 0.32, 0.52))
    _btn_cal.pressed.connect(_on_calibrate)
    vbox.add_child(_btn_cal)

    vbox.add_child(_sep())

    # Sección simulador
    _btn_sim = _button("  Iniciar simulador", Color(0.1, 0.38, 0.2))
    _btn_sim.pressed.connect(_on_simulate)
    vbox.add_child(_btn_sim)

    vbox.add_child(_sep())

    # Log
    vbox.add_child(_label("ESTADO", 11, Color(0.45, 0.5, 0.58)))
    _lbl_log = _label("—", 13, Color(0.72, 0.78, 0.84))
    _lbl_log.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    vbox.add_child(_lbl_log)


func _label(text: String, size: int, color: Color,
            align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
    var l := Label.new()
    l.text = text
    l.horizontal_alignment = align
    l.add_theme_font_size_override("font_size", size)
    l.add_theme_color_override("font_color", color)
    return l


func _button(text: String, color: Color) -> Button:
    var btn := Button.new()
    btn.text = text
    btn.custom_minimum_size = Vector2(0, 50)
    btn.add_theme_font_size_override("font_size", 16)
    for state in ["normal", "hover", "pressed", "focus"]:
        var s := StyleBoxFlat.new()
        s.bg_color = color if state == "normal" else \
                     (color.lightened(0.18) if state == "hover" else color.darkened(0.18))
        s.set_corner_radius_all(6)
        btn.add_theme_stylebox_override(state, s)
    return btn


func _sep() -> HSeparator:
    var s := HSeparator.new()
    var style := StyleBoxLine.new()
    style.color = Color(0.2, 0.25, 0.3)
    s.add_theme_stylebox_override("separator", style)
    return s
