#!/bin/bash
#$ -l h_rt=2:00:00
#$ -l mem=32G

config_file="$1"
source "$config_file"

# Extract chromosome 3 data from dbSNP reference for fast version checking
# Uncompress the dbSNP reference file and extract only rows where the second column (chromosome) is '3'
# Output is written to a temporary file containing only chromosome 3 data
zcat "${reference_dir}/dbsnp_rsid_chr_bp_grch38.txt.gz" | awk '$2 == 3' > "${reference_dir}/dbsnp_chr3.txt"

# Sort the chromosome 3 data by the first column (usually rsID) and write to the final output file
sort -k1,1 "${reference_dir}/dbsnp_chr3.txt" > "${reference_dir}/dbsnp_chr3_sorted.txt"

echo "Sorting complete, output file preview as follows"
head "${reference_dir}/dbsnp_chr3_sorted.txt"

# Remove the temporary unsorted chromosome 3 file to save space
rm "${reference_dir}/dbsnp_chr3.txt"
