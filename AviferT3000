#!/bin/bash

# Get the directory where the script is located. This is useful to run the script when u want to Search and converter (REMEMBER IT SEARCHS SUBDIRECTORYS RECURSIVELY)
script_dir=$(dirname "$(readlink -f "$0")")

# Input directory relative to the script location.
input_dir="$script_dir/"

# Initialize counters
total_converted=0
total_skipped=0
skipped_files_log="$script_dir/skipped_files.txt"

# Ensure the log file is created or cleared
> "$skipped_files_log"

# Process all image files (jpg, jpeg, png, gif) in the input directory and subdirectories
find "$input_dir" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.gif" \) | while read -r file; do
## U may add another file formats, but try to check compatiblity with heif-enc. (Webp and heic to avif not working for some reason right now)
    # Get the directory path and filename
    dir=$(dirname "$file")
    filename=$(basename -- "$file")
    extension="${filename##*.}"
    filename_without_extension="${filename%.*}"

    # Create output directory if it doesn't exist.
    output_dir="$dir/"
## output_dir="$dir/YouMayAddSubdirectory if u want to use it recursively"
    mkdir -p "$output_dir"

    # Define output filename with .avif extension in the Output directory
    output_filename="$output_dir/$filename_without_extension.avif"

    # Attempt conversion
    if heif-enc "$file" "$output_filename"; then
        echo "Converted: $file -> $output_filename"
        ((total_converted++))  # Increment converted file counter
        # Delete original file after successful conversion. Comment this section if u need to preserve the original file.
        rm "$file"
        echo "Deleted original file: $file"
    else
        echo "Conversion failed for file: $file"
        ((total_skipped++))  # Increment skipped file counter
        # Log skipped filename to the log file (optional)
        # echo "$file" >> "$skipped_files_log"
    fi
done

# Log the total number of skipped files to the log file. Not finished right now btw :p. Not working, dunno why
echo "Total files skipped: $total_skipped" >> "$skipped_files_log"

# Display summary message
echo "Conversion summary:"
echo "Total files converted: $total_converted"
echo "Total files skipped: $total_skipped"
echo "Skipped files logged in: $skipped_files_log"
