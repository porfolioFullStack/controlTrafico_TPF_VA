import cv2
import sys

def find_camera(max_index: int = 5) -> int:
    for i in range(max_index):
        cap = cv2.VideoCapture(i, cv2.CAP_DSHOW)
        if cap.isOpened():
            cap.release()
            return i
    return -1


def main():
    cam_index = int(sys.argv[1]) if len(sys.argv) > 1 else find_camera()

    if cam_index < 0:
        print("No se encontró ninguna cámara conectada.")
        sys.exit(1)

    cap = cv2.VideoCapture(cam_index, cv2.CAP_DSHOW)
    cap.set(cv2.CAP_PROP_FRAME_WIDTH, 1280)
    cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 720)

    if not cap.isOpened():
        print(f"No se pudo abrir la cámara en índice {cam_index}.")
        sys.exit(1)

    w = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH))
    h = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))
    fps = cap.get(cv2.CAP_PROP_FPS)
    print(f"Cámara {cam_index} abierta: {w}x{h} @ {fps:.1f} fps  —  ESC para salir")

    while True:
        ret, frame = cap.read()
        if not ret:
            print("Error al leer frame.")
            break

        cv2.imshow("Camara USB", frame)

        if cv2.waitKey(1) & 0xFF == 27:  # ESC
            break

    cap.release()
    cv2.destroyAllWindows()


if __name__ == "__main__":
    main()
