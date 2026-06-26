# Pipeline de detección — Av. Colón / Rivera Indarte Simulator

## Arquitectura general

```
Cámara USB
    │
    ▼
traffic_detector.py  (Python / OpenCV)
    │  lee config/roi.json  (polígono + bboxes de dígitos)
    │  escribe config/traffic_state.json
    ▼
config/traffic_state.json
    │
    ▼
Godot — PythonBridge (python_bridge.gd)
    │  lee JSON cada 0.5 s
    │  llama traffic_light.force_state(state)
    │  sincroniza traffic_light.remaining con timer del display físico
    ▼
Simulación 3D sincronizada con semáforo físico
```

---

## Procedimiento de puesta en marcha

### 1. Instalar dependencias Python (una sola vez)
```
cd <raiz_proyecto>
python -m venv .venv
.venv\Scripts\activate        # Windows
pip install -r requirements.txt
```

### 2. Calibración — Etapa 1: encuadre del panel
```
python scriptsPy/roi_selector.py
```
- Presionar **ESPACIO** para congelar el frame.
- Arrastrar los 4 vértices hasta los bordes exactos del panel LED.
- Confirmar con **ENTER**.
- Se abre un segundo preview con el panel rectificado (800×300 px).
- Guarda `config/roi.json` con `polygon`, `panel_w`, `panel_h`.

### 3. Calibración — Etapa 2: selección de dígitos
```
python scriptsPy/digit_calibrator.py
```
- Presionar **ESPACIO** para congelar el panel rectificado.
- Seleccionar cada uno de los 4 dígitos con el mouse (**ENTER** después de cada uno).
- Guarda `config/roi.json["digits"]` con 4 bboxes `{x, y, w, h}` relativas al panel.

### 4. Correr el detector
```
python scriptsPy/traffic_detector.py
```
- Aplica `warpPerspective` con el polígono calibrado → panel 800×300.
- Clasifica color y decodifica dígitos en cada frame.
- Escribe `config/traffic_state.json` solo cuando hay cambio (comparación por `ts`).
- Presionar **ESC** para salir.

### 5. Correr la simulación Godot
```
godot --path <raiz_proyecto>
```
- `PythonBridge` sondea `traffic_state.json` cada 0.5 s.
- El semáforo y los vehículos responden al estado del display físico en tiempo real.
- El HUD muestra `Python: OK` cuando hay dato fresco (< 2 s).

> **Nota:** El detector Python debe estar corriendo **antes** de abrir Godot,
> o al menos antes de que el display físico cambie de estado.

---

## Pipeline interno del detector (por frame)

```
frame BGR  (cámara USB, 1920×1080)
    │
    ▼
warpPerspective(polygon, 800×300)  → panel rectificado
    │
    ├─► HSV → canal V → bright_mask  (V > 140: solo LEDs encendidos)
    │
    ├─► CLASIFICACIÓN DE COLOR (2 pasos)
    │     Paso 1: chroma_ratio = px_brillantes_con_S>35 / total_brillantes
    │             < 0.18 → YELLOW (display blanco/cálido = amarillo)
    │     Paso 2: hue dominante entre px cromáticos+brillantes
    │             H 0–14 / 161–180 → RED
    │             H 40–105         → GREEN
    │
    └─► OCR DE DÍGITOS (7 segmentos)
          1. Cargar 4 bboxes calibradas de roi.json["digits"]
          2. Por cada dígito:
             a. Enmascarar con bright_mask
             b. CLAHE (clipLimit=3, tileGrid=4×4)
             c. Otsu local → binario
             d. Apertura morfológica (kernel 2×2)
             e. Evaluar 7 zonas fijas (a–g) → ratio de píxeles ON
             f. Lookup en tabla de verdad → carácter ('0'–'9' / '?')
          3. Concatenar → string MMSS (ej. "0028" = 00:28)
```

---

## Archivos de configuración

### `config/roi.json`  *(generado por calibración, no en git)*
```json
{
  "cam_index": 0,
  "polygon": [[474,200],[970,184],[972,379],[480,398]],
  "panel_w": 800,
  "panel_h": 300,
  "digits": [
    {"x": 21,  "y": 25, "w": 160, "h": 241},
    {"x": 183, "y": 25, "w": 159, "h": 241},
    {"x": 447, "y": 24, "w": 163, "h": 244},
    {"x": 611, "y": 23, "w": 159, "h": 245}
  ]
}
```

### `config/traffic_state.json`  *(generado en tiempo real, no en git)*
```json
{
  "state": "red",
  "timer": "0045",
  "confidence": 85,
  "ts": 1750000000.123
}
```
- `state`: `"red"` | `"green"` | `"yellow"` | `"unknown"`
- `timer`: 4 dígitos MMSS (`"0028"` = 28 s, `"0130"` = 90 s), `"?"` si no legible
- `confidence`: porcentaje de confianza del clasificador de color (0–99)
- `ts`: Unix timestamp del momento de escritura (usado por Godot para detectar cambios)

---

## Estado del desarrollo

| Componente | Estado |
|---|---|
| Selector de ROI (polígono arrastrable) | ✅ Funcional |
| Preview en tiempo real del panel rectificado | ✅ Funcional |
| Calibración de dígitos (selectROI × 4) | ✅ Funcional |
| Clasificación de color rojo/verde | ✅ Funcional (conf. > 85%) |
| Clasificación de color amarillo | ✅ Funcional |
| OCR de dígitos 7 segmentos | ✅ Funcional |
| Escritura atómica de traffic_state.json | ✅ Funcional |
| Integración Godot via PythonBridge | ✅ Implementado |
| Botón de recalibración en runtime | ⏳ Pendiente |
