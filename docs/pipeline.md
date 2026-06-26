# Pipeline de detección — Av. Colón / Rivera Indarte Simulator

## Arquitectura general

```
Cámara USB
    │
    ▼
traffic_detector.py  (Python / OpenCV)
    │  lee roi.json
    │  escribe traffic_state.json  (escritura atómica)
    ▼
config/traffic_state.json
    │
    ▼
Godot (GDScript)  ← pendiente de integración
    │  lee JSON cada 0.5 s
    │  llama traffic_light.force_state(state)
    ▼
Simulación 3D sincronizada con semáforo físico
```

---

## Procedimiento de puesta en marcha

### 1. Instalar dependencias Python
```
cd <raiz_proyecto>
python -m venv .venv
.venv\Scripts\activate        # Windows
pip install -r requirements.txt
```

### 2. Calibrar ROI (una sola vez por instalación)
```
python scriptsPy/roi_selector.py
```
- Presionar **ESPACIO** para congelar el frame cuando el display esté visible.
- Dibujar el rectángulo sobre el panel LED y confirmar con **ENTER**.
- Se abre un preview del recorte para verificar.
- Guarda `config/roi.json`.

### 3. Correr el detector
```
python scriptsPy/traffic_detector.py
```
- Abre la cámara, carga `config/roi.json`.
- Procesa cada frame y escribe `config/traffic_state.json`.
- Presionar **ESC** para salir.

### 4. (Pendiente) Integración Godot
- Godot lee `config/traffic_state.json` cada 0.5 s.
- Llama a `traffic_light.force_state(state)` con el valor detectado.

---

## Pipeline interno del detector (por frame)

```
frame BGR
    │
    ├─► recortar ROI (roi.json)
    │
    ▼
panel BGR
    │
    ├─► HSV → canal V → bright_mask  (V > 140: solo LEDs encendidos)
    │
    ├─► CLASIFICACIÓN DE COLOR (2 pasos)
    │     Paso 1: fracción de píxeles brillantes con S > 35
    │             < 18% → YELLOW (blanco/cálido = display en amarillo)
    │     Paso 2: hue dominante entre píxeles cromáticos+brillantes
    │             H 0-14 / 161-180 → RED
    │             H 40-105         → GREEN
    │
    └─► OCR DE DÍGITOS (7 segmentos)
          1. bright_mask → projección horizontal de columnas
          2. Agrupar columnas activas → bboxes de dígitos
          3. Por cada dígito: Otsu local + apertura morfológica
          4. Evaluar 7 zonas fijas (a-g) → tabla de verdad → carácter
          5. Concatenar → string del timer (ej. "0028")
```

---

## Archivos de configuración

### `config/roi.json`
```json
{
  "cam_index": 0,
  "x": 882,
  "y": 113,
  "w": 442,
  "h": 229
}
```

### `config/traffic_state.json` (generado en tiempo real)
```json
{
  "state": "red",
  "timer": "0045",
  "confidence": 73,
  "ts": 1750000000.123
}
```
`state`: `"red"` | `"green"` | `"yellow"` | `"unknown"`

---

## Estado del desarrollo

| Componente | Estado |
|---|---|
| Selector de ROI | ✅ Funcional |
| Detección de color (rojo/verde/amarillo) | ✅ Funcional |
| OCR de dígitos (7 segmentos) | 🔧 En desarrollo |
| Escritura de traffic_state.json | ✅ Funcional |
| Integración con Godot | ⏳ Pendiente |
| Botón de calibración en runtime | ⏳ Pendiente |
