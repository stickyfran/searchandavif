#!/bin/bash

# 1. MENÚ DE SELECCIÓN DE FORMATO
echo "===================================="
echo "Seleccione el formato de destino:"
echo "[1] AVIF                      (Usa heif-enc)"
echo "[2] JPEG-XL Lossless          (Usa cjxl - Por defecto)"
echo "[3] JPEG-XL Lossy (Equiv AVIF) (Usa cjxl -d 2.5 --effort 7)"
echo "===================================="
read -p "Ingrese 1, 2 o 3: " opcion

# Configuración de variables según la opción elegida
if [ "$opcion" == "1" ]; then
    target_ext=".avif"
    target_exe="heif-enc"
    pkg_arch="libheif"
    pkg_deb="libheif-examples"
elif [ "$opcion" == "3" ]; then
    target_ext=".jxl"
    target_exe="cjxl"
    pkg_arch="libjxl"
    pkg_deb="libjxl-tools"
    jxl_mode="lossy"
else
    target_ext=".jxl"
    target_exe="cjxl"
    pkg_arch="libjxl"
    pkg_deb="libjxl-tools"
    jxl_mode="lossless"
fi

# 2. VERIFICACIÓN DE DEPENDENCIAS
if ! command -v "$target_exe" &> /dev/null; then
    echo "===================================="
    echo "[ERROR] No se encontró el comando '$target_exe'."
    echo "Necesitas instalar las dependencias antes de continuar."
    echo "===================================="
    exit 1
fi

# 3. SELECCIÓN DE CONCURRENCIA CON TIMEOUT (10 SEGUNDOS)
echo ""
echo "===================================="
echo "¿Cuántos archivos querés procesar al mismo tiempo?"
echo " -> Podés elegir cualquier número del 1 al 8."
echo " -> Si no tocás nada, en 10 segundos empezará con 2 hilos."
echo "===================================="

if ! read -t 10 -p "Cantidad de hilos (1-8) [Por defecto 2]: " max_jobs; then
    echo "" # Salto de línea estético si hace timeout
fi

if [ -z "$max_jobs" ]; then
    max_jobs=2
    echo "Tiempo agotado o vacío. Iniciando automáticamente con 2 hilos..."
elif ! [[ "$max_jobs" =~ ^[1-8]$ ]]; then
    max_jobs=2
    echo "Valor inválido detectado. Usando 2 hilos por defecto."
else
    echo "Configurado correctamente a $max_jobs hilo(s) simultáneo(s)."
fi

# 4. INICIALIZACIÓN DE ENTORNO
script_dir=$(dirname "$(readlink -f "$0")")
input_dir="$script_dir/"

skipped_files_log="$script_dir/skipped_files.txt"
> "$skipped_files_log"

success_log=$(mktemp)

echo ""
echo "Buscando imágenes recursivamente en: $input_dir"
echo "Iniciando conversión..."
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
    
    # Ejecución dinámica según el codificador y el modo elegido
    local convert_status=1
    if [ "$target_exe" == "cjxl" ]; then
        if [ "$jxl_mode" == "lossy" ]; then
            # Modo JPEG XL Lossy optimizado para igualar peso de AVIF
            "$target_exe" "$file" "$output_filename" -d 2.5 --effort 7 &> /dev/null
            convert_status=$?
        else
            # Modo JPEG XL Lossless estándar
            "$target_exe" "$file" "$output_filename" &> /dev/null
            convert_status=$?
        fi
    else
        # Modo AVIF estándar
        "$target_exe" "$file" "$output_filename" &> /dev/null
        convert_status=$?
    fi
    
    # Validar el resultado de la ejecución
    if [ $convert_status -eq 0 ]; then
        echo "✅ [ÉXITO] $filename -> $filename_without_extension$target_ext"
        echo "1" >> "$success_log"
        rm "$file"
    else
        echo "❌ [FALLA] No se pudo convertir: $filename"
        echo "Falla de conversión: $file" >> "$skipped_files_log"
    fi
}

# 5. PROCESO DE CONVERSIÓN RECURSIVA CON CONTROL DE TRABAJOS (JOBS)
while IFS= read -r file; do
    process_file "$file" &
    
    while [ "$(jobs -r -p | wc -l)" -ge "$max_jobs" ]; do
        wait -n 2>/dev/null || true
    done
done < <(find "$input_dir" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.gif" \))

wait

# 6. CÁLCULO DE TOTALES
total_converted=$(wc -l < "$success_log")
total_skipped=$(wc -l < "$skipped_files_log")

rm -f "$success_log"

if [ "$total_skipped" -gt 0 ]; then
    echo "" >> "$skipped_files_log"
    echo "Total archivos omitidos: $total_skipped" >> "$skipped_files_log"
fi

# Mostrar mensaje de resumen
echo ""
echo "===================================="
echo "Resumen de conversión ($max_jobs hilos):"
echo "Total archivos convertidos: $total_converted"
echo "Total archivos omitidos: $total_skipped"
if [ "$total_skipped" -gt 0 ]; then
    echo "Archivos omitidos registrados en: $skipped_files_log"
fi
echo "===================================="
