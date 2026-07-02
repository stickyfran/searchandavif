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

total_converted=0
total_skipped=0
skipped_files_log="$script_dir/skipped_files.txt"

> "$skipped_files_log"

echo ""
echo "Buscando imágenes recursivamente en: $input_dir"

# 4. PROCESO DE CONVERSIÓN RECURSIVA
# Usamos < <(find ...) para evitar el problema del subshell y que los contadores funcionen
while IFS= read -r file; do
    dir=$(dirname "$file")
    filename=$(basename -- "$file")
    filename_without_extension="${filename%.*}"
    
    output_dir="$dir/"
    mkdir -p "$output_dir"
    
    output_filename="$output_dir/$filename_without_extension$target_ext"
    
    echo ""
    echo "Intentando convertir: $file"
    
    # Ejecutar la conversión
    if "$target_exe" "$file" "$output_filename"; then
        echo "Convertido: $file -> $output_filename"
        ((total_converted++))
        
        # Eliminar archivo original
        rm "$file"
        echo "Archivo original eliminado."
    else
        echo "La conversión falló para el archivo: $file"
        ((total_skipped++))
        
        # Registrar falla
        echo "Falla de conversión: $file" >> "$skipped_files_log"
    fi
done < <(find "$input_dir" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.gif" \))

# Registrar el total de omitidos
echo "" >> "$skipped_files_log"
echo "Total archivos omitidos: $total_skipped" >> "$skipped_files_log"

# Mostrar mensaje de resumen
echo ""
echo "===================================="
echo "Resumen de conversión:"
echo "Total archivos convertidos: $total_converted"
echo "Total archivos omitidos: $total_skipped"
echo "Archivos omitidos registrados en: $skipped_files_log"
echo "===================================="