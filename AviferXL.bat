@echo off
:: =================================================================
:: INTERCEPTOR DE HILOS
:: =================================================================
if "%~1"==":Worker" goto Worker

setlocal EnableDelayedExpansion

:: 1. MENÚ DE SELECCIÓN DE FORMATO
echo ====================================
echo Seleccione el formato de destino:
echo [1] AVIF                      (Usa heif-enc.exe - Por defecto)
echo [2] JPEG-XL Lossless          (Usa cjxl.exe)
echo [3] JPEG-XL Lossy (Equiv AVIF) (Usa cjxl.exe -d 2.5 -e 7)
echo ====================================

set "opcion=1"
set /p opcion="Ingrese 1, 2 o 3: "
echo.

set "opcion=!opcion: =!"

if "!opcion!"=="2" (
    set "target_ext=.jxl"
    set "target_exe=cjxl.exe"
    set "jxl_mode=lossless"
    echo Formato elegido: JPEG-XL Lossless
)

if "!opcion!"=="3" (
    set "target_ext=.jxl"
    set "target_exe=cjxl.exe"
    set "jxl_mode=lossy"
    echo Formato elegido: JPEG-XL Lossy - Equivalente AVIF
)

if not "!opcion!"=="2" if not "!opcion!"=="3" (
    set "target_ext=.avif"
    set "target_exe=heif-enc.exe"
    set "jxl_mode=none"
    echo Formato elegido: AVIF
)
echo.

:: 2. SELECCIÓN DE CONCURRENCIA
echo ====================================
echo Cuantos archivos queres procesar al mismo tiempo?
echo  - Podes elegir cualquier numero del 1 al 8.
echo ====================================
choice /C 12345678 /T 10 /D 2 /N /M "Cantidad de hilos (1-8) [Por defecto 2]: "
set max_jobs=!errorlevel!

echo.
echo Configurado correctamente a !max_jobs! hilo(s) simultaneo(s).
echo.

:: 3. INICIALIZACIÓN
set "script_dir=%~dp0"
set "codec_dir=%USERPROFILE%\Documents\codecs"
set "encoder_cmd=!codec_dir!\!target_exe!"

if not exist "!encoder_cmd!" (
    echo [ERROR] No se encontro '!target_exe!' en !codec_dir!.
    pause
    exit /b
)

set "skipped_files_log=%script_dir%skipped_files.txt"
set "success_log=%TEMP%\success_log_%RANDOM%.txt"

type nul > "!skipped_files_log!"
type nul > "!success_log!"

echo Buscando imagenes recursivamente en: !script_dir!
echo Iniciando proceso multithread...
echo.

:: 4. PROCESO DE CONVERSIÓN
for /r "%script_dir%" %%F in (*.jpg *.jpeg *.png *.gif) do (
    set "file_dir=%%~dpF"
    set "filename_no_ext=%%~nF"
    set "output_filename=!file_dir!!filename_no_ext!!target_ext!"
    
    call :check_jobs

    echo [AGREGADO A COLA] "%%~nxF" ...
    start "" /B cmd /c call "%~f0" :Worker "%%F" "!output_filename!" "!encoder_cmd!" "!success_log!" "!skipped_files_log!" "!jxl_mode!"
)

echo.
echo Esperando a que finalicen los procesos...
:wait_final
for /f %%A in ('tasklist /nh /fi "imagename eq !target_exe!" 2^>nul ^| find /c /i "!target_exe!"') do set active_jobs=%%A
if !active_jobs! gtr 0 (
    timeout /t 1 /nobreak >nul
    goto wait_final
)

:: 5. RESULTADOS
set total_converted=0
for /f %%A in ('type "!success_log!" 2^>nul ^| find /c /v ""') do set total_converted=%%A

set total_skipped=0
for /f %%A in ('type "!skipped_files_log!" 2^>nul ^| find /c /v ""') do set total_skipped=%%A

del "!success_log!" >nul 2>&1

echo.
echo ====================================
echo Resumen de conversion:
echo Total archivos convertidos: !total_converted!
echo Total archivos omitidos: !total_skipped!
echo ====================================
pause
exit /b

:check_jobs
for /f %%A in ('tasklist /nh /fi "imagename eq !target_exe!" 2^>nul ^| find /c /i "!target_exe!"') do set active_jobs=%%A
if !active_jobs! geq !max_jobs! (
    timeout /t 1 /nobreak >nul
    goto check_jobs
)
goto :eof

:Worker
set "original_file=%~2"
set "output_filename=%~3"
set "encoder_cmd=%~4"
set "success_log=%~5"
set "skipped_log=%~6"
set "jxl_mode=%~7"

if "%jxl_mode%"=="lossy" (
    "%encoder_cmd%" --lossless_jpeg=0 -d 2.5 -e 7 "%original_file%" "%output_filename%" >nul 2>&1
) else (
    "%encoder_cmd%" "%original_file%" "%output_filename%" >nul 2>&1
)

if %errorlevel% equ 0 (
    echo 1>>"%success_log%"
    del "%original_file%"
) else (
    echo Falla: %original_file%>>"%skipped_log%"
)
exit
