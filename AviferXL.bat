@echo off
:: =================================================================
:: INTERCEPTOR DE HILOS (Debe ir siempre arriba)
:: Si el script recibe ":Worker" como parámetro, se comporta como un hilo secundario
:: =================================================================
if "%~1"==":Worker" goto Worker

setlocal EnableDelayedExpansion

:: 1. MENÚ DE SELECCIÓN DE FORMATO Y CONCURRENCIA
echo ====================================
echo Seleccione el formato de destino:
echo [1] AVIF    (Usa heif-enc.exe)
echo [2] JPEG-XL (Usa cjxl.exe)
echo ====================================
set /p opcion="Ingrese 1 o 2: "
echo.

echo ====================================
set /p max_jobs="Ingrese cantidad de archivos simultaneos (ej: 4 u 8): "
:: Validación: si está vacío, usar 4 por defecto
if "!max_jobs!"=="" set max_jobs=4

if "!opcion!"=="2" (
    set "target_ext=.jxl"
    set "target_exe=cjxl.exe"
    echo Formato elegido: JPEG-XL
) else (
    set "target_ext=.avif"
    set "target_exe=heif-enc.exe"
    echo Formato elegido: AVIF
)
echo Hilos simultaneos: !max_jobs!
echo.

:: Obtener el directorio donde esta corriendo el script
set "script_dir=%~dp0"
set "input_dir=%script_dir%"

:: Ruta fija donde el comando de PowerShell instala los codecs
set "codec_dir=%USERPROFILE%\Documents\codecs"
set "encoder_cmd=!codec_dir!\!target_exe!"

:: Verificar si el codificador elegido existe
if not exist "!encoder_cmd!" (
    echo [ERROR] No se encontro '!target_exe!' en !codec_dir!.
    echo Por favor, asegurate de ejecutar primero el comando de instalacion.
    pause
    exit /b
)

:: Inicializar logs y temporales
set "skipped_files_log=%script_dir%skipped_files.txt"
set "success_log=%TEMP%\success_log_%RANDOM%.txt"

:: Crear o vaciar los archivos de registro
type nul > "!skipped_files_log!"
type nul > "!success_log!"

echo Buscando imagenes recursivamente en: %input_dir%
echo Iniciando proceso multithread...
echo.

:: 2. PROCESO DE CONVERSIÓN RECURSIVA
for /r "%input_dir%" %%F in (*.jpg *.jpeg *.png *.gif) do (
    
    set "file_dir=%%~dpF"
    set "filename_no_ext=%%~nF"
    
    set "output_filename=!file_dir!!filename_no_ext!!target_ext!"
    
    :: Llamamos a la función que frena el loop si ya hay muchos procesos corriendo
    call :check_jobs

    echo [AGREGADO A COLA] "%%~nxF" ...
    
    :: Lanzar el trabajador en segundo plano (/B) aislando el entorno con cmd /c
    start "" /B cmd /c call "%~f0" :Worker "%%F" "!output_filename!" "!encoder_cmd!" "!success_log!" "!skipped_files_log!"
)

echo.
echo Esperando a que finalicen los ultimos procesos...
:: 3. ESPERA FINAL
:wait_final
for /f %%A in ('tasklist /nh /fi "imagename eq !target_exe!" 2^>nul ^| find /c /i "!target_exe!"') do set active_jobs=%%A
if !active_jobs! gtr 0 (
    timeout /t 1 /nobreak >nul
    goto wait_final
)

:: 4. CALCULAR RESULTADOS (Contando las líneas de los archivos)
set total_converted=0
for /f %%A in ('type "!success_log!" 2^>nul ^| find /c /v ""') do set total_converted=%%A

set total_skipped=0
for /f %%A in ('type "!skipped_files_log!" 2^>nul ^| find /c /v ""') do set total_skipped=%%A

:: Limpieza
del "!success_log!" >nul 2>&1

:: Mostrar mensaje de resumen
echo.
echo ====================================
echo Resumen de conversion (!max_jobs! hilos):
echo Total archivos convertidos: !total_converted!
echo Total archivos omitidos: !total_skipped!
if !total_skipped! gtr 0 (
    echo Archivos omitidos registrados en: !skipped_files_log!
)
echo ====================================
pause
exit /b

:: =================================================================
:: FUNCIÓN DE CONTROL DE CONCURRENCIA
:: Cuenta cuántos procesos (ej: cjxl.exe) están corriendo. Si son igual o
:: mayor al límite (!max_jobs!), pausa 1 segundo y vuelve a chequear.
:: =================================================================
:check_jobs
for /f %%A in ('tasklist /nh /fi "imagename eq !target_exe!" 2^>nul ^| find /c /i "!target_exe!"') do set active_jobs=%%A
if !active_jobs! geq !max_jobs! (
    timeout /t 1 /nobreak >nul
    goto check_jobs
)
goto :eof

:: =================================================================
:: HILO TRABAJADOR (WORKER)
:: Este bloque solo se ejecuta cuando el script se llama a sí mismo en 2do plano.
:: =================================================================
:Worker
set "original_file=%~2"
set "output_filename=%~3"
set "encoder_cmd=%~4"
set "success_log=%~5"
set "skipped_log=%~6"

:: Silenciamos la salida interna (>nul 2>&1) para no ensuciar la consola general
"%encoder_cmd%" "%original_file%" "%output_filename%" >nul 2>&1

if %errorlevel% equ 0 (
    :: Anotamos 1 éxito en el temporal y borramos original
    echo 1>>"%success_log%"
    del "%original_file%"
) else (
    :: Anotamos falla
    echo Falla de conversion: %original_file%>>"%skipped_log%"
)
:: Finaliza este sub-proceso cmd
exit
