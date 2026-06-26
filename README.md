# Av. Colon / Rivera Indarte Simulator

Prototype Godot scene for the traffic-light AIoT final project.

The first version is intentionally self-contained: it creates a simplified 3D
avenue, pedestrian crossing, traffic light, timer, vehicles, camera presets and
traffic queue presets without webcam input.

## Controls

- `1`: cola baja.
- `2`: cola media.
- `3`: cola alta.
- `4`: flujo libre.
- `C`: next camera preset.
- `W/S`: camera pitch on X.
- `Q/E`: camera yaw.
- `Z/X`: camera roll on Z.

## Current Scope

- Av. Colon represented as a 4-lane urban avenue.
- Rivera Indarte represented as a pedestrian crossing only.
- Classical traffic-light timer: green 30s, yellow 5s, red 45s.
- Vehicles stop on red/yellow and move on green.
- Camera presets: right, center, left, top-angle and detector-like view.

## Next Steps

- Add external visual detection of the physical traffic light/timer.
- Add per-camera ROI presets for the Percepta detector.
- Add optional traffic-map data layer for Cordoba simulation scenarios.
