#!/bin/bash

# 1. MENÚ DE SELECCIÓN DE FORMATO Y CONCURRENCIA
echo "===================================="
echo "Seleccione el formato de destino:"
echo "[1] AVIF    (Usa heif-enc)"
echo "[2] JPEG-XL (Usa cjxl)"
echo "===================================="
read -p "Ingrese 1 o 2: " opcion

echo "===================================="
read -p "Ingrese cantidad de archivos simultáneos (ej: 4 u 8): " max_jobs
# Validación: si no ingresa nada o no es número, por defecto usamos 4
if ! [[ "$max_jobs" =~ ^[0-9]+$ ]]; then
    max_jobs=4
    echo "Valor inválido o vacío. Usando $max_jobs hilos por defecto."
fi

if [ "$opcion" == "2" ]; then
    target_ext=".jxl"
    target_exe="cjxl"
    pkg_arch="libjxl"
    pkg_deb="libjxl-tools"
else
    target_ext=".avif"
    target_exe="heif-enc"
    pkg_arch="libheif"
    pkg_deb="libheif-examples"
fi

# 2. VERIFICACIÓN DE DEPENDENCIAS
if ! command -v "$target_exe" &> /dev/null; then
    echo "===================================="
    echo "[ERROR] No se encontró el comando '$target_exe'."
    echo "Necesitas instalar las dependencias antes de continuar."
    echo ""
    echo "Recomendaciones de instalación:"
    echo " -> En Arch Linux / CachyOS: sudo pacman -S $pkg_arch"
    echo " -> En Debian / Ubuntu:      sudo apt install $pkg_deb"
    echo " -> En Fedora:               sudo dnf install $pkg_arch"
    echo "===================================="
    exit 1
fi

# 3. INICIALIZACIÓN
script_dir=$(dirname "$(readlink -f "$0")")
input_dir="$script_dir/"

skipped_files_log="$script_dir/skipped_files.txt"
> "$skipped_files_log"

# Archivo temporal para contar los éxitos de forma segura en multithreading
success_log=$(mktemp)

echo ""
echo "Buscando imágenes recursivamente en: $input_dir"
echo "Iniciando conversión de hasta $max_jobs archivos al mismo tiempo..."
echo ""

# FUNCIÓN DE PROCESAMIENTO INDIVIDUAL
process_file() {
    local file="$1"
    local dir
    dir=$(dirname "$file")
    local filename
    filename=$(basename -- "$file")
    local filename_without_extension="${filename%.*}"
    
    local output_dir="$dir/"
    local output_filename="$output_dir/$filename_without_extension$target_ext"
    
    echo "⏳ [INICIO] Convirtiendo: $filename ..."
    
    # Ejecutar la conversión. Silenciamos la salida de la herramienta para no saturar la terminal.
    if "$target_exe" "$file" "$output_filename" &> /dev/null; then
        echo "✅ [ÉXITO] $filename -> $filename_without_extension$target_ext (Original eliminado)"
        echo "1" >> "$success_log" # Registrar éxito sumando 1 al temporal
        
        # Eliminar archivo original
        rm "$file"
    else
        echo "❌ [FALLA] No se pudo convertir: $filename"
        echo "Falla de conversión: $file" >> "$skipped_files_log"
    fi
}

# 4. PROCESO DE CONVERSIÓN RECURSIVA CON CONTROL DE TRABAJOS (JOBS)
while IFS= read -r file; do
    # Lanzar la tarea en segundo plano usando la función
    process_file "$file" &
    
    # Si el número de procesos en segundo plano alcanza el máximo, esperamos a que liberen un espacio
    while [ "$(jobs -r -p | wc -l)" -ge "$max_jobs" ]; do
        wait -n 2>/dev/null || true
    done
done < <(find "$input_dir" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.gif" \))

# Esperar a que terminen los procesos en segundo plano restantes
wait

# 5. CÁLCULO DE TOTALES
total_converted=$(wc -l < "$success_log")
total_skipped=$(wc -l < "$skipped_files_log")

# Limpieza del archivo temporal
rm -f "$success_log"

# Registrar el total de omitidos en el log si hubo errores
if [ "$total_skipped" -gt 0 ]; then
    echo "" >> "$skipped_files_log"
    echo "Total archivos omitidos: $total_skipped" >> "$skipped_files_log"
fi

# Mostrar mensaje de resumen
echo ""
echo "===================================="
echo "Resumen de conversión ($max_jobs hilos simultáneos):"
echo "Total archivos convertidos: $total_converted"
echo "Total archivos omitidos: $total_skipped"
if [ "$total_skipped" -gt 0 ]; then
    echo "Archivos omitidos registrados en: $skipped_files_log"
fi
echo "===================================="
