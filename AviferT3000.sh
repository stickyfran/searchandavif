#!/bin/bash

# 1. MENÚ DE SELECCIÓN DE FORMATO
echo "===================================="
echo "Seleccione el formato de destino:"
echo "[1] AVIF    (Usa heif-enc)"
echo "[2] JPEG-XL (Usa cjxl)"
echo "===================================="
read -p "Ingrese 1 o 2: " opcion

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

# -t 10 espera exactamente 10 segundos. Si se agota el tiempo, el comando falla y entra al if.
if ! read -t 10 -p "Cantidad de hilos (1-8) [Por defecto 2]: " max_jobs; then
    echo "" # Salto de línea estético si hace timeout
fi

# Si quedó vacío (porque se agotó el tiempo o porque diste ENTER sin escribir)
if [ -z "$max_jobs" ]; then
    max_jobs=2
    echo "Tiempo agotado o vacío. Iniciando automáticamente con 2 hilos..."
# Si escribió algo, pero NO es un número del 1 al 8
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

# Archivo temporal para contar los éxitos de forma segura en paralelo
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
    
    # Ejecutar la conversión
    if "$target_exe" "$file" "$output_filename" &> /dev/null; then
        echo "✅ [ÉXITO] $filename -> $filename_without_extension$target_ext"
        echo "1" >> "$success_log" # Registrar éxito
        
        # Eliminar archivo original
        rm "$file"
    else
        echo "❌ [FALLA] No se pudo convertir: $filename"
        echo "Falla de conversión: $file" >> "$skipped_files_log"
    fi
}

# 5. PROCESO DE CONVERSIÓN RECURSIVA CON CONTROL DE TRABAJOS (JOBS)
while IFS= read -r file; do
    # Lanzar la tarea en segundo plano
    process_file "$file" &
    
    # Control de límite: si hay tareas activas >= a los hilos elegidos, esperamos
    while [ "$(jobs -r -p | wc -l)" -ge "$max_jobs" ]; do
        wait -n 2>/dev/null || true
    done
done < <(find "$input_dir" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.gif" \))

# Esperar a que terminen los últimos procesos si quedó alguno corriendo
wait

# 6. CÁLCULO DE TOTALES
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
echo "Resumen de conversión ($max_jobs hilos):"
echo "Total archivos convertidos: $total_converted"
echo "Total archivos omitidos: $total_skipped"
if [ "$total_skipped" -gt 0 ]; then
    echo "Archivos omitidos registrados en: $skipped_files_log"
fi
echo "===================================="
