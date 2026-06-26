@echo off
setlocal enabledelayedexpansion

echo ============================================
echo  Av. Colon / Rivera Indarte - Setup
echo ============================================
echo.

:: Verificar Python
python --version >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Python no encontrado.
    echo         Instala Python 3.10+ desde https://www.python.org y volvé a correr este script.
    pause
    exit /b 1
)
for /f "tokens=*" %%i in ('python --version') do echo [OK] %%i encontrado

:: Verificar Godot
godot --version >nul 2>&1
if errorlevel 1 (
    echo [AVISO] Godot no encontrado en PATH.
    echo         Descargalo desde https://godotengine.org ^(version 4.6^)
    echo         y agrega la carpeta al PATH, o copia godot.exe a esta carpeta.
    echo.
) else (
    for /f "tokens=*" %%i in ('godot --version') do echo [OK] Godot %%i encontrado
)

:: Crear entorno virtual
if exist ".venv\" (
    echo [OK] .venv ya existe, saltando creacion
) else (
    echo [..] Creando entorno virtual...
    python -m venv .venv
    if errorlevel 1 (
        echo [ERROR] No se pudo crear el entorno virtual.
        pause
        exit /b 1
    )
    echo [OK] .venv creado
)

:: Instalar dependencias
echo [..] Instalando dependencias Python...
.venv\Scripts\pip install -r requirements.txt --quiet
if errorlevel 1 (
    echo [ERROR] Fallo pip install. Verifica requirements.txt y tu conexion a internet.
    pause
    exit /b 1
)
echo [OK] Dependencias instaladas

:: Crear config/ si no existe
if not exist "config\" mkdir config
if not exist "config\.gitkeep" type nul > "config\.gitkeep"

echo.
echo ============================================
echo  Setup completado.
echo.
echo  SIGUIENTE PASO:
echo    1. Conecta la camara USB con el semaforo
echo    2. Corre:  godot --path .
echo    3. En el launcher: calibra el semaforo (primera vez)
echo    4. Presiona "Iniciar simulador"
echo ============================================
echo.
pause
