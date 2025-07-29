#!/bin/bash
#$ -l h_rt=2:00:00
#$ -l mem=32G

config_file="$1"
source "$config_file"

# Remove large .valid files (>50MB) to save storage space
echo "Removing large .valid files to save storage space..."
find "${output_dir}/pgi" -type f -name "*.valid" -size +50M -delete

echo "Cleanup completed"

