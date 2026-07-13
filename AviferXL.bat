@echo off
:: =================================================================
:: INTERCEPTOR DE HILOS (Debe ir siempre arriba)
:: Si el script recibe ":Worker" como parámetro, se comporta como un hilo secundario
:: =================================================================
if "%~1"==":Worker" goto Worker

setlocal EnableDelayedExpansion

:: 1. MENÚ DE SELECCIÓN DE FORMATO
echo ====================================
echo Seleccione el formato de destino:
echo [1] AVIF                      (Usa heif-enc.exe)
echo [2] JPEG-XL Lossless          (Usa cjxl.exe - Por defecto)
echo [3] JPEG-XL Lossy (Equiv AVIF) (Usa cjxl.exe -d 2.5 --effort 7)
echo ====================================
:: El comando choice ahora acepta 1, 2 o 3. /D 2 por defecto si se agota el tiempo.
choice /C 123 /T 10 /D 2 /N /M "Ingrese 1, 2 o 3: "
set opcion=!errorlevel!
echo.

if "!opcion!"=="1" (
    set "target_ext=.avif"
    set "target_exe=heif-enc.exe"
    set "jxl_mode=none"
    echo Formato elegido: AVIF
) else if "!opcion!"=="3" (
    set "target_ext=.jxl"
    set "target_exe=cjxl.exe"
    set "jxl_mode=lossy"
    echo Formato elegido: JPEG-XL Lossy (Equivalente AVIF)
) else (
    set "target_ext=.jxl"
    set "target_exe=cjxl.exe"
    set "jxl_mode=lossless"
    echo Formato elegido: JPEG-XL Lossless
)
echo.

:: 2. SELECCIÓN DE CONCURRENCIA CON TIMEOUT (10 SEGUNDOS)
echo ====================================
echo Cuantos archivos queres procesar al mismo tiempo?
echo  - Podes elegir cualquier numero del 1 al 8.
echo  - Si no tocas nada, en 10 segundos empezará con 2 hilos.
echo ====================================
choice /C 12345678 /T 10 /D 2 /N /M "Cantidad de hilos (1-8) [Por defecto 2]: "
set max_jobs=!errorlevel!

echo.
echo Configurado correctamente a !max_jobs! hilo(s) simultaneo(s).
echo.

:: 3. INICIALIZACIÓN DE ENTORNO
set "script_dir=%~dp0"
set "input_dir=%script_dir%"

set "codec_dir=%USERPROFILE%\Documents\codecs"
set "encoder_cmd=!codec_dir!\!target_exe!"

if not exist "!encoder_cmd!" (
    echo [ERROR] No se encontro '!target_exe!' en !codec_dir!.
    echo Por favor, asegurate de ejecutar primero el comando de instalacion.
    pause
    exit /b
)

set "skipped_files_log=%script_dir%skipped_files.txt"
set "success_log=%TEMP%\success_log_%RANDOM%.txt"

type nul > "!skipped_files_log!"
type nul > "!success_log!"

echo Buscando imagenes recursivamente en: %input_dir%
echo Iniciando proceso multithread...
echo.

:: 4. PROCESO DE CONVERSIÓN RECURSIVA
for /r "%input_dir%" %%F in (*.jpg *.jpeg *.png *.gif) do (
    
    set "file_dir=%%~dpF"
    set "filename_no_ext=%%~nF"
    
    set "output_filename=!file_dir!!filename_no_ext!!target_ext!"
    
    call :check_jobs

    echo [AGREGADO A COLA] "%%~nxF" ...
    
    :: Lanzar el trabajador pasando el parámetro extra !jxl_mode!
    start "" /B cmd /c call "%~f0" :Worker "%%F" "!output_filename!" "!encoder_cmd!" "!success_log!" "!skipped_files_log!" "!jxl_mode!"
)

echo.
echo Esperando a que finalicen los ultimos procesos...
:: 5. ESPERA FINAL
:wait_final
for /f %%A in ('tasklist /nh /fi "imagename eq !target_exe!" 2^>nul ^| find /c /i "!target_exe!"') do set active_jobs=%%A
if !active_jobs! gtr 0 (
    timeout /t 1 /nobreak >nul
    goto wait_final
)

:: 6. CALCULAR RESULTADOS
set total_converted=0
for /f %%A in ('type "!success_log!" 2^>nul ^| find /c /v ""') do set total_converted=%%A

set total_skipped=0
for /f %%A in ('type "!skipped_files_log!" 2^>nul ^| find /c /v ""') do set total_skipped=%%A

del "!success_log!" >nul 2>&1

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
:: =================================================================
:Worker
set "original_file=%~2"
set "output_filename=%~3"
set "encoder_cmd=%~4"
set "success_log=%~5"
set "skipped_log=%~6"
set "jxl_mode=%~7"

:: Ejecución condicional en base al tipo de JXL configurado
if "%jxl_mode%"=="lossy" (
    "%encoder_cmd%" "%original_file%" "%output_filename%" -d 2.5 --effort 7 >nul 2>&1
) else (
    "%encoder_cmd%" "%original_file%" "%output_filename%" >nul 2>&1
)

if %errorlevel% equ 0 (
    echo 1>>"%success_log%"
    del "%original_file%"
) else (
    echo Falla de conversion: %original_file%>>"%skipped_log%"
)
exit
