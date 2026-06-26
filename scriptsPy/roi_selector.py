"""
Calibración de panel — Etapa 1.

1. Congela un frame de la cámara.
2. Autodetecta el panel LED buscando el rectángulo brillante más grande.
3. Coloca 4 vértices arrastrables en las esquinas detectadas.
4. El usuario ajusta los vértices al borde exacto del panel.
5. Aplica transformada de perspectiva y muestra el panel rectificado.
6. Guarda polygon + tamaño de salida en config/roi.json.

Siguiente paso: python scriptsPy/digit_calibrator.py

Uso: python scriptsPy/roi_selector.py [indice_camara]
"""
from pathlib import Path
import cv2
import json
import numpy as np
import sys

BASE_DIR   = Path(__file__).resolve().parent.parent
CONFIG_DIR = BASE_DIR / "config"
ROI_FILE   = CONFIG_DIR / "roi.json"

PANEL_W = 800   # ancho del panel rectificado (píxeles de salida)
PANEL_H = 300   # alto  del panel rectificado

VERTEX_R = 14   # radio de los nodos en pantalla (px)
HIT_R    = 20   # radio de captura para clic/drag


def order_points(pts: np.ndarray) -> np.ndarray:
    """Ordena 4 puntos: TL, TR, BR, BL."""
    pts = pts.astype("float32")
    rect = np.zeros((4, 2), dtype="float32")
    s = pts.sum(axis=1)
    rect[0] = pts[np.argmin(s)]   # TL: menor suma
    rect[2] = pts[np.argmax(s)]   # BR: mayor suma
    d = np.diff(pts, axis=1)
    rect[1] = pts[np.argmin(d)]   # TR: menor diferencia
    rect[3] = pts[np.argmax(d)]   # BL: mayor diferencia
    return rect


def auto_detect_panel(frame: np.ndarray) -> list:
    """Detecta el panel LED como el rectángulo brillante más grande del frame."""
    gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)

    # El panel es significativamente más brillante que el fondo
    _, thresh = cv2.threshold(gray, 155, 255, cv2.THRESH_BINARY)

    # Cerrar huecos entre LEDs individuales
    k = cv2.getStructuringElement(cv2.MORPH_RECT, (30, 30))
    closed = cv2.morphologyEx(thresh, cv2.MORPH_CLOSE, k)

    contours, _ = cv2.findContours(closed, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)

    h, w = frame.shape[:2]
    min_area = w * h * 0.008

    best_pts  = None
    best_area = 0

    for c in contours:
        area = cv2.contourArea(c)
        if area < min_area:
            continue
        peri   = cv2.arcLength(c, True)
        approx = cv2.approxPolyDP(c, 0.03 * peri, True)
        if len(approx) == 4 and area > best_area:
            best_pts  = approx.reshape(4, 2).astype(float)
            best_area = area

    if best_pts is not None:
        return order_points(best_pts).astype(int).tolist()

    # Fallback: rectángulo centrado
    m = 0.15
    return [[int(w*m), int(h*m)], [int(w*(1-m)), int(h*m)],
            [int(w*(1-m)), int(h*(1-m))], [int(w*m), int(h*(1-m))]]


class PolygonEditor:
    """Editor interactivo de polígono de 4 vértices arrastrables."""

    LABELS  = ["TL", "TR", "BR", "BL"]
    COLORS  = [(0,255,0), (0,200,255), (255,100,0), (200,0,255)]

    def __init__(self, frame: np.ndarray, pts: list) -> None:
        self.base     = frame
        self.pts      = [list(map(int, p)) for p in pts]
        self.selected = -1

    def on_mouse(self, event, x, y, flags, param) -> None:
        if event == cv2.EVENT_LBUTTONDOWN:
            for i, p in enumerate(self.pts):
                if abs(p[0]-x) <= HIT_R and abs(p[1]-y) <= HIT_R:
                    self.selected = i
                    return
        elif event == cv2.EVENT_MOUSEMOVE and self.selected >= 0:
            self.pts[self.selected] = [x, y]
        elif event == cv2.EVENT_LBUTTONUP:
            self.selected = -1

    def render(self) -> np.ndarray:
        img = self.base.copy()
        arr = np.array(self.pts, np.int32)
        cv2.polylines(img, [arr], True, (0, 255, 0), 2)
        for i, (p, col) in enumerate(zip(self.pts, self.COLORS)):
            filled = col if i != self.selected else (255, 255, 255)
            cv2.circle(img, tuple(p), VERTEX_R, filled, -1)
            cv2.circle(img, tuple(p), VERTEX_R, (255, 255, 255), 1)
            cv2.putText(img, self.LABELS[i], (p[0]+VERTEX_R+4, p[1]+6),
                        cv2.FONT_HERSHEY_SIMPLEX, 0.6, col, 2)
        cv2.putText(img,
                    "Arrastra los vertices al borde del panel  |  ENTER: confirmar  |  ESC: cancelar",
                    (20, img.shape[0]-20), cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0,255,0), 2)
        return img


def warp_panel(frame: np.ndarray, pts: list) -> np.ndarray:
    src = order_points(np.array(pts, dtype="float32"))
    dst = np.array([[0,0],[PANEL_W-1,0],[PANEL_W-1,PANEL_H-1],[0,PANEL_H-1]],
                   dtype="float32")
    M = cv2.getPerspectiveTransform(src, dst)
    return cv2.warpPerspective(frame, M, (PANEL_W, PANEL_H))


def main() -> None:
    # Prioridad: argumento CLI > cam_index guardado en roi.json > 0
    if len(sys.argv) > 1:
        cam_index = int(sys.argv[1])
    elif ROI_FILE.exists():
        try:
            cam_index = json.loads(ROI_FILE.read_text()).get("cam_index", 0)
        except Exception:
            cam_index = 0
    else:
        cam_index = 0
    cap = cv2.VideoCapture(cam_index, cv2.CAP_DSHOW)
    cap.set(cv2.CAP_PROP_FRAME_WIDTH,  1920)
    cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 1080)

    if not cap.isOpened():
        print(f"[ERROR] No se pudo abrir la cámara {cam_index}.")
        sys.exit(1)

    print("ESPACIO: congelar frame  |  ESC: cancelar")

    WIN = "Calibracion Panel  [Etapa 1]"
    cv2.namedWindow(WIN, cv2.WINDOW_NORMAL | cv2.WINDOW_KEEPRATIO)
    cv2.resizeWindow(WIN, 1280, 720)

    frozen = None
    while True:
        ret, frame = cap.read()
        if not ret:
            continue
        cv2.putText(frame, "ESPACIO: congelar  |  ESC: cancelar",
                    (20, 50), cv2.FONT_HERSHEY_SIMPLEX, 1.2, (0,255,0), 2)
        cv2.imshow(WIN, frame)
        key = cv2.waitKey(1) & 0xFF
        if key == 32:
            frozen = frame.copy()
            break
        elif key == 27:
            cap.release()
            cv2.destroyAllWindows()
            return
    cap.release()
    cv2.destroyAllWindows()

    # Autodetectar vértices iniciales
    print("Autodetectando panel...")
    pts = auto_detect_panel(frozen)
    print(f"  Vertices detectados: {pts}")

    # Editor interactivo — ventana 1: frame completo con polígono
    editor   = PolygonEditor(frozen, pts)
    WIN_POLY = "Ajuste de vertices del panel  [ENTER confirmar | ESC cancelar]"
    WIN_PREV = "Preview panel rectificado"

    cv2.namedWindow(WIN_POLY, cv2.WINDOW_NORMAL | cv2.WINDOW_KEEPRATIO)
    cv2.resizeWindow(WIN_POLY, 1280, 720)
    cv2.setMouseCallback(WIN_POLY, editor.on_mouse)

    # Ventana 2: preview en tiempo real del panel rectificado
    cv2.namedWindow(WIN_PREV, cv2.WINDOW_NORMAL | cv2.WINDOW_KEEPRATIO)
    cv2.resizeWindow(WIN_PREV, 800, 300)

    while True:
        cv2.imshow(WIN_POLY, editor.render())
        cv2.imshow(WIN_PREV, warp_panel(frozen, editor.pts))
        key = cv2.waitKey(20) & 0xFF
        if key == 13:   # ENTER
            break
        elif key == 27:
            cv2.destroyAllWindows()
            return
    cv2.destroyAllWindows()

    CONFIG_DIR.mkdir(parents=True, exist_ok=True)
    config = {
        "cam_index": cam_index,
        "polygon":   editor.pts,
        "panel_w":   PANEL_W,
        "panel_h":   PANEL_H,
    }
    ROI_FILE.write_text(json.dumps(config, indent=2))
    print(f"Guardado en {ROI_FILE}")
    print("Siguiente paso: python scriptsPy/digit_calibrator.py")


if __name__ == "__main__":
    main()
