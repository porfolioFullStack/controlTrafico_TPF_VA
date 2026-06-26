"""
Detector de estado del semáforo LED por visión artificial.

Pipeline por frame:
  1. Recortar ROI del panel (estático, cargado de config/roi.json)
  2. Bright mask en canal V (HSV) → aislar solo los LEDs encendidos
  3. Clasificar color en 2 pasos (saturación → hue) → red/green/yellow
  4. OCR de 7 segmentos con Otsu local + apertura morfológica
  5. Escribir config/traffic_state.json (escritura atómica)

Uso: python scriptsPy/traffic_detector.py
"""
from pathlib import Path
import cv2
import json
import numpy as np
import sys
import time

BASE_DIR   = Path(__file__).resolve().parent.parent
CONFIG_DIR = BASE_DIR / "config"
ROI_FILE   = CONFIG_DIR / "roi.json"
STATE_FILE = CONFIG_DIR / "traffic_state.json"

# ── Parámetros ────────────────────────────────────────────────────────────────
V_THRESHOLD    = 140   # canal V mínimo para considerar un pixel como LED encendido
MIN_BRIGHT_PX  = 80    # mínimo de píxeles brillantes para dar resultado válido

# Clasificación de color
S_CHROMA_THRESHOLD = 35    # S mínima para considerar un pixel como "cromático"
CHROMA_RATIO_MIN   = 0.18  # fracción mínima de cromáticos para no ser blanco/amarillo
HUE_RED_LO1,  HUE_RED_HI1  =   0,  14
HUE_RED_LO2,  HUE_RED_HI2  = 161, 180
HUE_GREEN_LO, HUE_GREEN_HI =  40, 105

# OCR 7 segmentos
SEG_RATIO_ON = 0.20   # fracción mínima de píxeles activos para segmento ON

# Zonas de cada segmento dentro del bbox de un dígito (x1,y1,x2,y2 en fracción 0-1)
# Convención: a=top, b=top-right, c=bot-right, d=bot, e=bot-left, f=top-left, g=middle
SEG_ZONES: dict[str, tuple] = {
    "a": (0.15, 0.00, 0.85, 0.18),
    "b": (0.72, 0.06, 1.00, 0.48),
    "c": (0.72, 0.52, 1.00, 0.94),
    "d": (0.15, 0.82, 0.85, 1.00),
    "e": (0.00, 0.52, 0.28, 0.94),
    "f": (0.00, 0.06, 0.28, 0.48),
    "g": (0.15, 0.41, 0.85, 0.59),
}
SEG_ORDER = ("a", "b", "c", "d", "e", "f", "g")

SEG_TO_DIGIT: dict[tuple, str] = {
    (1, 1, 1, 1, 1, 1, 0): "0",
    (0, 1, 1, 0, 0, 0, 0): "1",
    (1, 1, 0, 1, 1, 0, 1): "2",
    (1, 1, 1, 1, 0, 0, 1): "3",
    (0, 1, 1, 0, 0, 1, 1): "4",
    (1, 0, 1, 1, 0, 1, 1): "5",
    (1, 0, 1, 1, 1, 1, 1): "6",
    (1, 1, 1, 0, 0, 0, 0): "7",
    (1, 1, 1, 1, 1, 1, 1): "8",
    (1, 1, 1, 1, 0, 1, 1): "9",
}

STATE_COLOR_BGR = {
    "red":     (0,   0,   220),
    "green":   (0,   200, 0),
    "yellow":  (0,   210, 230),
    "unknown": (140, 140, 140),
}


# ── Carga de configuración ─────────────────────────────────────────────────────

def order_points(pts: np.ndarray) -> np.ndarray:
    pts  = pts.astype("float32")
    rect = np.zeros((4, 2), dtype="float32")
    s    = pts.sum(axis=1)
    rect[0] = pts[np.argmin(s)]
    rect[2] = pts[np.argmax(s)]
    d = np.diff(pts, axis=1)
    rect[1] = pts[np.argmin(d)]
    rect[3] = pts[np.argmax(d)]
    return rect


def build_warp_matrix(polygon: list, pw: int, ph: int) -> np.ndarray:
    src = order_points(np.array(polygon, dtype="float32"))
    dst = np.array([[0,0],[pw-1,0],[pw-1,ph-1],[0,ph-1]], dtype="float32")
    return cv2.getPerspectiveTransform(src, dst)


def load_roi() -> dict:
    if not ROI_FILE.exists():
        print(f"[ERROR] No se encontró {ROI_FILE}")
        print("        Ejecutá primero: python scriptsPy/roi_selector.py")
        sys.exit(1)
    cfg = json.loads(ROI_FILE.read_text())
    if "polygon" not in cfg:
        print("[ERROR] roi.json usa formato antiguo. Volvé a correr roi_selector.py")
        sys.exit(1)
    if "digits" not in cfg:
        print("[WARN] Sin dígitos calibrados — OCR deshabilitado.")
        print("       Ejecutá: python scriptsPy/digit_calibrator.py")
    return cfg


# ── Clasificación de color ─────────────────────────────────────────────────────

def classify_color(panel_hsv: np.ndarray, bright_mask: np.ndarray) -> tuple[str, int]:
    """Clasificación en 2 pasos:
    1. Cromaticidad (saturación): pocos píxeles cromáticos → amarillo/blanco.
    2. Hue dominante entre píxeles cromáticos → rojo o verde.
    Tolera la auto-exposición que baja S sin cambiar H.
    """
    total_bright = int(cv2.countNonZero(bright_mask))
    if total_bright < MIN_BRIGHT_PX:
        return "unknown", 0

    s_channel = panel_hsv[:, :, 1]
    chroma_mask = cv2.threshold(s_channel, S_CHROMA_THRESHOLD, 255, cv2.THRESH_BINARY)[1]
    chroma_bright = cv2.bitwise_and(chroma_mask, bright_mask)
    chroma_count = int(cv2.countNonZero(chroma_bright))
    chroma_ratio = chroma_count / total_bright

    if chroma_ratio < CHROMA_RATIO_MIN:
        conf = min(99, int((1.0 - chroma_ratio / CHROMA_RATIO_MIN) * 99))
        return "yellow", conf

    h = panel_hsv[:, :, 0]
    red_hue   = cv2.bitwise_or(cv2.inRange(h, HUE_RED_LO1, HUE_RED_HI1),
                                cv2.inRange(h, HUE_RED_LO2, HUE_RED_HI2))
    green_hue = cv2.inRange(h, HUE_GREEN_LO, HUE_GREEN_HI)

    red_count   = int(cv2.countNonZero(cv2.bitwise_and(red_hue,   chroma_bright)))
    green_count = int(cv2.countNonZero(cv2.bitwise_and(green_hue, chroma_bright)))

    if green_count > red_count:
        return "green", int(green_count / chroma_count * 100)
    return "red", int(red_count / chroma_count * 100)


# ── OCR de 7 segmentos ────────────────────────────────────────────────────────

def _decode_single(digit_bin: np.ndarray) -> str:
    """Decodifica un parche binario de un dígito usando las 7 zonas de segmento."""
    h, w = digit_bin.shape
    if h < 6 or w < 4:
        return "?"
    bits = []
    for seg in SEG_ORDER:
        x1r, y1r, x2r, y2r = SEG_ZONES[seg]
        x1, y1 = int(x1r * w), int(y1r * h)
        x2, y2 = max(x1 + 2, int(x2r * w)), max(y1 + 2, int(y2r * h))
        zone  = digit_bin[y1:y2, x1:x2]
        ratio = zone.sum() / 255.0 / max(zone.size, 1)
        bits.append(1 if ratio >= SEG_RATIO_ON else 0)
    return SEG_TO_DIGIT.get(tuple(bits), "?")


def decode_digits(panel_gray: np.ndarray, bright_mask: np.ndarray,
                  digit_rects: list[dict]) -> str:
    """Decodifica los 4 dígitos usando bboxes calibradas fijas.

    digit_rects: lista de {x, y, w, h} relativas al panel, desde roi.json.
    """
    masked = cv2.bitwise_and(panel_gray, panel_gray, mask=bright_mask)
    result = ""

    for d in digit_rects:
        x, y, w, h = d["x"], d["y"], d["w"], d["h"]
        crop = masked[y: y + h, x: x + w]

        if crop.max() < 30:
            result += "?"
            continue

        # CLAHE: mejora contraste local aunque la imagen esté sobreexpuesta
        clahe = cv2.createCLAHE(clipLimit=3.0, tileGridSize=(4, 4))
        enhanced = clahe.apply(crop)

        # Otsu local sobre imagen con contraste mejorado
        _, binary = cv2.threshold(enhanced, 0, 255, cv2.THRESH_BINARY + cv2.THRESH_OTSU)

        # Apertura morfológica — elimina halos entre segmentos
        k = cv2.getStructuringElement(cv2.MORPH_RECT, (2, 2))
        binary = cv2.morphologyEx(binary, cv2.MORPH_OPEN, k)

        result += _decode_single(binary)

    return result or "?"


def _draw_seg_overlay(panel_bgr: np.ndarray, digit_rects: list[dict]) -> np.ndarray:
    """Overlay de debug: dibuja las zonas de los 7 segmentos sobre cada dígito calibrado."""
    out = panel_bgr.copy()
    colors_seg = {"a": (0,255,0), "b": (0,200,255), "c": (255,200,0),
                  "d": (0,0,255), "e": (255,0,200), "f": (200,255,0), "g": (255,128,0)}
    for d in digit_rects:
        x0, y0, dw, dh = d["x"], d["y"], d["w"], d["h"]
        cv2.rectangle(out, (x0, y0), (x0 + dw, y0 + dh), (200, 200, 200), 1)
        for seg in SEG_ORDER:
            x1r, y1r, x2r, y2r = SEG_ZONES[seg]
            x1 = x0 + int(x1r * dw); y1 = y0 + int(y1r * dh)
            x2 = x0 + int(x2r * dw); y2 = y0 + int(y2r * dh)
            cv2.rectangle(out, (x1, y1), (x2, y2), colors_seg[seg], 1)
    return out


# ── Escritura atómica de estado ───────────────────────────────────────────────

def write_state(state: str, timer: str, confidence: int) -> None:
    data = {"state": state, "timer": timer, "confidence": confidence,
            "ts": round(time.time(), 3)}
    content = json.dumps(data)
    try:
        tmp = STATE_FILE.with_suffix(".tmp")
        tmp.write_text(content)
        tmp.replace(STATE_FILE)   # atómico en Linux/Mac
    except PermissionError:
        # Windows bloquea el archivo si otro proceso lo tiene abierto;
        # escribimos directo como fallback
        STATE_FILE.write_text(content)


# ── Main ──────────────────────────────────────────────────────────────────────

def main() -> None:
    CONFIG_DIR.mkdir(parents=True, exist_ok=True)
    cfg         = load_roi()
    cam_index   = cfg.get("cam_index", 0)
    polygon     = cfg["polygon"]
    pw          = cfg.get("panel_w", 800)
    ph          = cfg.get("panel_h", 300)
    digit_rects = cfg.get("digits", [])
    ocr_enabled = len(digit_rects) == 4

    # Matriz de perspectiva calculada una sola vez
    M = build_warp_matrix(polygon, pw, ph)

    cap = cv2.VideoCapture(cam_index, cv2.CAP_DSHOW)
    cap.set(cv2.CAP_PROP_FRAME_WIDTH,  1920)
    cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 1080)

    if not cap.isOpened():
        print(f"[ERROR] No se pudo abrir la cámara {cam_index}.")
        sys.exit(1)

    print(f"Detector activo — ESC para salir")
    print(f"OCR: {'habilitado' if ocr_enabled else 'deshabilitado — correr digit_calibrator.py'}")
    print(f"Estado en: {STATE_FILE}")

    last_state, last_timer = "unknown", "?"

    # Polígono para dibujar en el frame original
    poly_arr = np.array(polygon, np.int32)

    while True:
        ret, frame = cap.read()
        if not ret:
            continue

        # Aplicar perspectiva → panel rectificado
        panel      = cv2.warpPerspective(frame, M, (pw, ph))
        panel_hsv  = cv2.cvtColor(panel, cv2.COLOR_BGR2HSV)
        panel_gray = cv2.cvtColor(panel, cv2.COLOR_BGR2GRAY)

        _, bright_mask = cv2.threshold(
            panel_hsv[:, :, 2], V_THRESHOLD, 255, cv2.THRESH_BINARY)

        state, confidence = classify_color(panel_hsv, bright_mask)
        timer = decode_digits(panel_gray, bright_mask, digit_rects) if ocr_enabled else "--"

        if state != last_state or timer != last_timer:
            write_state(state, timer, confidence)
            print(f"  [{state.upper():7s}] {timer}  conf={confidence}%")
            last_state, last_timer = state, timer

        # ── Anotaciones sobre el frame original ──
        bgr = STATE_COLOR_BGR.get(state, (200, 200, 200))
        cv2.polylines(frame, [poly_arr], True, bgr, 2)
        cv2.putText(frame, f"{state.upper()}  {timer}  ({confidence}%)",
                    (poly_arr[:,0].min(), max(poly_arr[:,1].min() - 10, 20)),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.8, bgr, 2)

        # Thumbnail del panel rectificado con overlay de segmentos
        seg_panel = _draw_seg_overlay(panel, digit_rects) if ocr_enabled else panel
        thumb     = cv2.resize(seg_panel, (280, int(ph * 280 / pw)))
        frame[10: 10 + thumb.shape[0], 10: 10 + 280] = thumb

        cv2.imshow("Traffic Detector  [ESC salir]", frame)
        if cv2.waitKey(1) & 0xFF == 27:
            break

    cap.release()
    cv2.destroyAllWindows()


if __name__ == "__main__":
    main()
