#!/bin/bash -l
#$ -l h_rt=12:00:00
#$ -l mem=32G

config_file="$1"
source "$config_file"

# Analyst input
cohort_name="$2"
genotype_path="$3"

# Check inputs
if [ -z "$cohort_name" ] || [ -z "$genotype_path" ]; then
  echo "Usage: $0 <CohortName> </path/to/genotype_data>"
  exit 1
fi

# Run PGI script
bash ${base_dir}/scripts/pgi_pipeline.sh "$cohort_name" "$genotype_path"
