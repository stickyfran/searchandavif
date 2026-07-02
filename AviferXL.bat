@echo off
setlocal EnableDelayedExpansion

:: 1. MENÚ DE SELECCIÓN DE FORMATO
echo ====================================
echo Seleccione el formato de destino:
echo [1] AVIF    (Usa heif-enc.exe)
echo [2] JPEG-XL (Usa cjxl.exe)
echo ====================================
set /p opcion="Ingrese 1 o 2: "

if "!opcion!"=="2" (
    set "target_ext=.jxl"
    set "target_exe=cjxl.exe"
    echo Formato elegido: JPEG-XL
) else (
    set "target_ext=.avif"
    set "target_exe=heif-enc.exe"
    echo Formato elegido: AVIF
)
echo.

:: Obtener el directorio donde esta corriendo el script
set "script_dir=%~dp0"
set "input_dir=%script_dir%"

:: Ruta fija donde el comando de PowerShell instala los codecs
set "codec_dir=%USERPROFILE%\Documents\codecs"
set "encoder_cmd=!codec_dir!\!target_exe!"

:: Verificar si el codificador elegido existe en Documentos
if not exist "!encoder_cmd!" (
    echo [ERROR] No se encontro '!target_exe!' en !codec_dir!.
    echo Por favor, asegurate de ejecutar primero el comando de instalacion del README.
    pause
    exit /b
)

:: Inicializar contadores y log
set /a total_converted=0
set /a total_skipped=0
set "skipped_files_log=%script_dir%skipped_files.txt"

:: Crear o vaciar el archivo de registro
type nul > "!skipped_files_log!"

echo Buscando imagenes recursivamente en: %input_dir%

:: 2. PROCESO DE CONVERSIÓN RECURSIVA
for /r "%input_dir%" %%F in (*.jpg *.jpeg *.png *.gif) do (
    
    set "file_dir=%%~dpF"
    set "filename_no_ext=%%~nF"
    set "original_file=%%F"
    
    set "output_filename=!file_dir!!filename_no_ext!!target_ext!"
    
    echo.
    echo Intentando convertir: !original_file!

    :: Ejecutar la conversion utilizando el binario centralizado
    "!encoder_cmd!" "!original_file!" "!output_filename!"
    
    if !errorlevel! equ 0 (
        echo Convertido: !original_file! -^> !output_filename!
        set /a total_converted+=1
        
        del "!original_file!"
        echo Archivo original eliminado.
    ) else (
        echo La conversion fallo para el archivo: !original_file!
        set /a total_skipped+=1
        
        echo Falla de conversion: !original_file! >> "!skipped_files_log!"
    )
)

:: Registrar el total de archivos omitidos
echo. >> "!skipped_files_log!"
echo Total archivos omitidos: !total_skipped! >> "!skipped_files_log!"

:: Mostrar mensaje de resumen
echo.
echo ====================================
echo Resumen de conversion:
echo Total archivos convertidos: !total_converted!
echo Total archivos omitidos: !total_skipped!
echo Archivos omitidos registrados en: !skipped_files_log!
echo ====================================
pause
