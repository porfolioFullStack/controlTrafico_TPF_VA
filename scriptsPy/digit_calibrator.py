"""
Calibración de dígitos — ejecutar después de roi_selector.py.

Muestra el recorte del panel y pide al usuario que seleccione cada dígito
uno por uno (4 en total). Guarda las bboxes en config/roi.json bajo la
clave "digits" como lista de {x, y, w, h} relativos al panel.

Uso: python scriptsPy/digit_calibrator.py
"""
from pathlib import Path
import cv2
import json
import numpy as np
import sys

BASE_DIR   = Path(__file__).resolve().parent.parent
CONFIG_DIR = BASE_DIR / "config"
ROI_FILE   = CONFIG_DIR / "roi.json"


def order_points(pts: np.ndarray) -> np.ndarray:
    pts = pts.astype("float32")
    rect = np.zeros((4, 2), dtype="float32")
    s = pts.sum(axis=1)
    rect[0] = pts[np.argmin(s)]
    rect[2] = pts[np.argmax(s)]
    d = np.diff(pts, axis=1)
    rect[1] = pts[np.argmin(d)]
    rect[3] = pts[np.argmax(d)]
    return rect


def warp_panel(frame: np.ndarray, polygon: list, pw: int, ph: int) -> np.ndarray:
    src = order_points(np.array(polygon, dtype="float32"))
    dst = np.array([[0,0],[pw-1,0],[pw-1,ph-1],[0,ph-1]], dtype="float32")
    M   = cv2.getPerspectiveTransform(src, dst)
    return cv2.warpPerspective(frame, M, (pw, ph))


def main() -> None:
    if not ROI_FILE.exists():
        print(f"[ERROR] No se encontró {ROI_FILE}")
        print("        Ejecutá primero: python scriptsPy/roi_selector.py")
        sys.exit(1)

    cfg       = json.loads(ROI_FILE.read_text())
    cam_index = cfg.get("cam_index", 0)
    polygon   = cfg.get("polygon")
    pw        = cfg.get("panel_w", 800)
    ph        = cfg.get("panel_h", 300)

    if not polygon:
        print("[ERROR] roi.json no tiene polygon. Ejecutá roi_selector.py primero.")
        sys.exit(1)

    # Capturar frame fresco
    cap = cv2.VideoCapture(cam_index, cv2.CAP_DSHOW)
    cap.set(cv2.CAP_PROP_FRAME_WIDTH,  1920)
    cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 1080)

    if not cap.isOpened():
        print(f"[ERROR] No se pudo abrir la cámara {cam_index}.")
        sys.exit(1)

    print("ESPACIO: congelar frame  |  ESC: cancelar")

    frozen_panel = None
    while True:
        ret, frame = cap.read()
        if not ret:
            continue
        panel = warp_panel(frame, polygon, pw, ph)
        disp  = cv2.resize(panel, (pw * 2, ph * 2))
        cv2.putText(disp, "ESPACIO: congelar  |  ESC: cancelar",
                    (10, 30), cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0,255,0), 2)
        cv2.imshow("Panel del semaforo", disp)
        key = cv2.waitKey(1) & 0xFF
        if key == 32:
            frozen_panel = panel.copy()
            break
        elif key == 27:
            cap.release()
            cv2.destroyAllWindows()
            return

    cap.release()
    cv2.destroyAllWindows()

    # Ampliar el panel rectificado para selección fina
    scale = 2
    big   = cv2.resize(frozen_panel, (pw * scale, ph * scale), interpolation=cv2.INTER_LINEAR)

    digits: list[dict] = []
    labels = ["digito 1 (izquierda)",
              "digito 2",
              "digito 3",
              "digito 4 (derecha)"]

    for i, label in enumerate(labels):
        preview = big.copy()
        for prev in digits:
            px = prev["x"] * scale; py = prev["y"] * scale
            pdw = prev["w"] * scale; pdh = prev["h"] * scale
            cv2.rectangle(preview, (px, py), (px+pdw, py+pdh), (0,200,0), 2)

        cv2.putText(preview, f"Selecciona {label}  |  ENTER confirma",
                    (10, 25), cv2.FONT_HERSHEY_SIMPLEX, 0.65, (0,255,255), 2)

        roi = cv2.selectROI(f"Digito {i+1}: {label}", preview,
                            fromCenter=False, showCrosshair=True)
        cv2.destroyAllWindows()

        x, y, dw, dh = (int(v) for v in roi)
        if dw == 0 or dh == 0:
            print(f"Selección vacía para {label}. Cancelado.")
            return

        digits.append({"x": x//scale, "y": y//scale, "w": dw//scale, "h": dh//scale})
        print(f"  Dígito {i+1}: {digits[-1]}")

    cfg["digits"] = digits
    ROI_FILE.write_text(json.dumps(cfg, indent=2))
    print(f"\nPosiciones guardadas en {ROI_FILE}")

    # Preview final
    preview = cv2.resize(frozen_panel, (pw*scale, ph*scale), interpolation=cv2.INTER_LINEAR)
    for i, d in enumerate(digits):
        x  = d["x"]*scale;  y  = d["y"]*scale
        dw = d["w"]*scale;  dh = d["h"]*scale
        cv2.rectangle(preview, (x,y), (x+dw, y+dh), (0,255,0), 2)
        cv2.putText(preview, str(i+1), (x+4, y+22),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0,255,255), 2)
    cv2.imshow("Digitos calibrados — presiona cualquier tecla", preview)
    cv2.waitKey(0)
    cv2.destroyAllWindows()


if __name__ == "__main__":
    main()
