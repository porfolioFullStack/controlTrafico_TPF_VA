# Simulador Av. Colón / Rivera Indarte

Simulador 3D de tráfico en Godot 4.6 para el trabajo final de Visión Artificial (UTN).
El semáforo de la simulación responde al estado del semáforo físico detectado en tiempo
real por una cámara USB mediante OpenCV.

## Arquitectura

```
Cámara USB → scriptsPy/traffic_detector.py → config/traffic_state.json → Godot
```

El detector Python escribe el estado (`red`/`green`/`yellow`) y el valor del timer
en `config/traffic_state.json`. Godot lee ese archivo cada 0.5 s y actualiza el
semáforo y el flujo de vehículos.

## Requisitos

- Godot 4.6
- Python 3.10+ con las dependencias de `requirements.txt`

```bash
python -m venv .venv
.venv\Scripts\activate
pip install -r requirements.txt
```

## Calibración (primera vez o al cambiar de computadora)

Los archivos `config/roi.json` y `config/traffic_state.json` **no están en el repo**
porque son específicos de cada instalación (dependen de la posición física de la
cámara y el panel).

### Etapa 1 — Encuadre del panel

```bash
python scriptsPy/roi_selector.py
```

- Congela un frame con **ESPACIO**.
- Arrastra los 4 vértices hasta los bordes del panel LED.
- Confirma con **ENTER**.
- Guarda el polígono en `config/roi.json`.

### Etapa 2 — Dígitos del display

```bash
python scriptsPy/digit_calibrator.py
```

- Congela el panel rectificado con **ESPACIO**.
- Selecciona cada uno de los 4 dígitos con el mouse (**ENTER** después de cada uno).
- Guarda las bounding boxes en `config/roi.json["digits"]`.

### Detector principal

```bash
python scriptsPy/traffic_detector.py
```

Muestra la vista de cámara con el polígono del panel superpuesto y un thumbnail
del panel rectificado con overlay de segmentos. Escribe `config/traffic_state.json`
en cada cambio de estado o valor.

## Controles de la simulación (Godot)

| Tecla | Acción |
|-------|--------|
| `1` | Cola baja |
| `2` | Cola media |
| `3` | Cola alta |
| `4` | Flujo libre |
| `C` | Siguiente preset de cámara |
| `W / S` | Pitch de cámara |
| `Q / E` | Yaw de cámara |
| `Z / X` | Roll de cámara |

## Estructura del proyecto

```
prueba_godot/
├── config/
│   ├── .gitkeep           # directorio trackeado; los JSON se generan en runtime
│   ├── roi.json           # ← generado por calibración (ignorado por git)
│   └── traffic_state.json # ← generado por el detector (ignorado por git)
├── docs/
│   └── pipeline.md        # documentación técnica del pipeline
├── scenes/
│   └── main.tscn
├── scripts/               # GDScript Godot
├── scriptsPy/             # Python / OpenCV
│   ├── camera_view.py     # visor simple de cámara
│   ├── roi_selector.py    # calibración etapa 1
│   ├── digit_calibrator.py# calibración etapa 2
│   └── traffic_detector.py# detector principal
├── requirements.txt
└── project.godot
```

## Scope actual

- Av. Colón como avenida urbana de 4 carriles.
- Rivera Indarte como cruce peatonal.
- Semáforo clásico: verde 30 s, amarillo 5 s, rojo 45 s.
- Los vehículos se detienen en rojo/amarillo y avanzan en verde.
- El estado puede ser sobreescrito por el detector Python en tiempo real.
- Presets de cámara: derecha, centro, izquierda, ángulo superior, vista detector.
