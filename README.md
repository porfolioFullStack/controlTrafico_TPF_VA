# Simulador Av. Colón / Rivera Indarte

![Godot 4.6](https://img.shields.io/badge/Godot-4.6-478CBF?logo=godotengine&logoColor=white)
![Python 3.10+](https://img.shields.io/badge/Python-3.10%2B-3776AB?logo=python&logoColor=white)
![OpenCV](https://img.shields.io/badge/OpenCV-4.x-5C3EE8?logo=opencv&logoColor=white)
![Plataforma](https://img.shields.io/badge/Plataforma-Windows-0078D6?logo=windows&logoColor=white)
![Estado](https://img.shields.io/badge/Estado-En%20desarrollo-yellow)

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
│   ├── .gitkeep            # directorio trackeado; los JSON se generan en runtime
│   ├── roi.json            # ← generado por calibración (ignorado por git)
│   └── traffic_state.json  # ← generado por el detector (ignorado por git)
├── docs/
│   └── pipeline.md         # documentación técnica del pipeline
├── scenes/
│   ├── launcher.tscn       # pantalla inicial con botones de calibración/simulador
│   └── main.tscn           # escena 3D del simulador
├── scripts/                # GDScript Godot
│   ├── app_state.gd        # singleton: PID del detector Python
│   ├── launcher.gd         # lógica del dashboard inicial
│   ├── simulation_controller.gd
│   ├── vehicle_controller.gd
│   ├── vehicle_spawner.gd
│   ├── traffic_light_controller.gd
│   ├── python_bridge.gd
│   └── camera_rig.gd
├── scriptsPy/              # Python / OpenCV
│   ├── roi_selector.py     # calibración etapa 1 (polígono panel)
│   ├── digit_calibrator.py # calibración etapa 2 (bboxes dígitos)
│   └── traffic_detector.py # detector principal (escribe traffic_state.json)
├── requirements.txt
└── project.godot
```

---

## Correr en otra PC (distribución por repositorio)

Este proyecto se distribuye como repositorio git. No requiere instalador — un script
de setup configura el entorno automáticamente.

### Requisitos previos

| Herramienta | Versión | Descarga |
|-------------|---------|----------|
| Godot       | 4.6     | https://godotengine.org |
| Python      | 3.10+   | https://www.python.org  |
| Git         | cualquiera | https://git-scm.com  |

> Godot debe estar disponible en el PATH del sistema (o copiar `godot.exe` a la raíz del proyecto).

### Pasos

```bat
:: 1. Clonar el repositorio
git clone <url-del-repo>
cd prueba_godot

:: 2. Correr el setup (una sola vez)
setup.bat

:: 3. Lanzar
godot --path .
```

`setup.bat` crea el entorno virtual `.venv` e instala todas las dependencias Python
listadas en `requirements.txt`. Al terminar indica los pasos siguientes.

### Primera vez en una PC nueva

La calibración del semáforo es **específica de cada instalación** (depende de la
posición de la cámara y el panel LED). Luego de correr `setup.bat`:

1. Conectá la cámara USB apuntando al semáforo físico.
2. Abrí el launcher con `godot --path .`.
3. Presioná **"Calibrar semáforo"** y seguí los pasos (panel → dígitos).
4. Presioná **"Iniciar simulador"**.

Los archivos `config/roi.json` y `config/traffic_state.json` se generan localmente
y **no se versionan** (están en `.gitignore`), por lo que cada PC tiene su propia calibración.

---

## Scope actual

- Av. Colón como avenida urbana de 4 carriles.
- Rivera Indarte como cruce peatonal.
- Semáforo clásico: verde 30 s, amarillo 5 s, rojo 45 s.
- Los vehículos se detienen en rojo/amarillo y avanzan en verde.
- El estado puede ser sobreescrito por el detector Python en tiempo real.
- Presets de cámara: derecha, centro, izquierda, ángulo superior, vista detector.
