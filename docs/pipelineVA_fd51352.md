# Pipeline de Visión Artificial — estado al commit `fd51352`

## Pipeline completo — end to end

---

### 1. Calibración (una sola vez por instalación)

**`roi_selector.py`** — el operador congela un frame y arrastra 4 vértices sobre los bordes del panel LED. Guarda en `config/roi.json`: el polígono, el índice de cámara y las dimensiones de salida del panel rectificado (800×300 px por defecto).

**`digit_calibrator.py`** — sobre el panel ya rectificado, el operador selecciona con el mouse los bboxes de los 4 dígitos. Guarda en el mismo `roi.json["digits"]`: `{x, y, w, h}` de cada dígito.

---

### 2. Por cada frame (traffic_detector.py)

```
Frame 1920×1080
    ↓ warpPerspective (matriz precalculada)
Panel rectificado 800×300
    ↓ cvtColor → HSV + GRAY
    ↓ threshold canal V (>140) → bright_mask  (aisla LEDs encendidos)

    ├─ CLASIFICACIÓN DE COLOR
    │    Paso 1: % píxeles cromáticos (S > 35) sobre bright_mask
    │            < 18% cromáticos → YELLOW  (LEDs blancos/cálidos)
    │    Paso 2: hue dominante entre píxeles cromáticos
    │            H ∈ [0-14] ∪ [161-180] → RED
    │            H ∈ [40-105]            → GREEN
    │
    └─ OCR 7 SEGMENTOS (por cada uno de los 4 dígitos)
         crop según bbox calibrada
         → bitwise_and con bright_mask
         → CLAHE (contraste local)
         → Otsu binarización
         → apertura morfológica 2×2
         → analizar 7 zonas (a-g en fracción del bbox)
         → lookup table → dígito 0-9 o "?"

    ↓ si cambió (state, timer) respecto al frame anterior
    → write_state() → config/traffic_state.json  (escritura atómica)
```

---

### 3. Godot lee el JSON (python_bridge.gd)

Cada 0.5 s abre `traffic_state.json`, parsea `{state, timer, ts}`, y si el timestamp
cambió emite `state_updated(state, remaining)` → `simulation_controller` llama
`traffic_light.force_state()`.

---

### Parámetros clave (traffic_detector.py)

| Parámetro | Valor | Rol |
|-----------|-------|-----|
| `V_THRESHOLD` | 140 | Canal V mínimo para considerar pixel como LED encendido |
| `MIN_BRIGHT_PX` | 80 | Mínimo de píxeles brillantes para dar resultado válido |
| `S_CHROMA_THRESHOLD` | 35 | S mínima para pixel "cromático" |
| `CHROMA_RATIO_MIN` | 0.18 | Fracción mínima de cromáticos para no clasificar como yellow |
| `HUE_RED` | [0-14] ∪ [161-180] | Rango hue para rojo |
| `HUE_GREEN` | [40-105] | Rango hue para verde |
| `SEG_RATIO_ON` | 0.20 | Fracción mínima de píxeles activos para segmento ON |

---

### Puntos débiles identificados

| Problema | Causa |
|----------|-------|
| Amarillo difícil de detectar | LEDs blancos/cálidos tienen S baja — el umbral de cromaticidad es frágil ante cambios de exposición |
| OCR sensible a la posición | Las zonas de segmento son fracciones fijas del bbox — si el dígito no está centrado o la perspectiva varía, falla |
| Sin suavizado temporal | Un frame ruidoso puede cambiar el estado; no hay filtro de mayoría o debounce |
| `bright_mask` con V fijo (140) | Si la cámara ajusta autoexposición, LEDs apagados pueden superar el umbral |
