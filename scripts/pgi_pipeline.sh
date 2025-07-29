#!/bin/bash

# Generate PGIs (Polygenic Index scores) using PRSice2 software.

# Check that exactly 2 arguments are provided
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <cohort_name> <target_sample_path>"
    exit 1
fi

# Store command line arguments
cohort_name="$1" # Name of the cohort (e.g., ALSPAC, UKB)
target_sample="$2" # ???

# Define base directories
summary_stats_dir="${output_dir}/summary_statistics"
base_output_dir="${output_dir}/pgi"

# Find all summary statistics files in PRSice2 hg38 format
summary_files=()
while IFS= read -r -d '' file; do
    summary_files+=("$file")
done < <(find "$summary_stats_dir" -name "*PRSice2_hg38.txt" -print0)

echo "Looking for summary files in: $summary_stats_dir"
echo "Found ${#summary_files[@]} summary files to process."
if [ "${#summary_files[@]}" -eq 0 ]; then
    echo "No summary files matched the pattern *PRSice2_hg38.txt. The main processing loop will be skipped."
fi

# Process each summary statistics file
for summary_file in "${summary_files[@]}"; do
    # Extract trait name from the parent directory name
    # e.g., /path/to/height/height_PRSice2_hg38.txt -> height
    trait_name=$(basename "$(dirname "$summary_file")")

    echo -e  "\ntrait name: $trait_name"
    
    # Extract base filename without extension
    # e.g., height_PRSice2_hg38.txt -> height_PRSice2_hg38
    summary_base=$(basename "$summary_file" .txt)

    echo "summary base: $summary_base"
    
    # Create output directory structure: base_dir/cohort/trait/
    output_dir="$base_output_dir/$cohort_name/$trait_name"
    mkdir -p "$output_dir"  # -p creates parent directories if needed
    
    # Define output filenames
    output_file="$output_dir/${cohort_name}_${trait_name}_${summary_base}_PGI_results.txt"
    all_score_file="$output_file.all_score"  # PRSice2 generates this file containing all PGI scores

    echo "output file: $output_file"
    
    # Skip if PGI scores already exist (prevents re-running completed analyses)
    if [ -e "$all_score_file" ] && [ -s "$all_score_file" ]; then
        echo "All_score file $all_score_file already exists and is greater than 0kb. Skipping to the next summary stat."
        continue  # Skip to next trait
    fi

    # Process only if output doesn't exist or is empty
    if [ ! -e "$output_file" ] || [ ! -s "$output_file" ]; then
        echo "Generating PGI for: $trait_name ($summary_base) using $cohort_name"

        # Run PRSice2 with error checking
        if "${software_dir}/PRSice_linux/PRSice_linux" \
	       --base "$summary_file" \
               --target "$target_sample" \
	       --fastscore T \
	       --no-regress \
               --bar-levels 0.05,0.01,1e-5,5e-08 \
               --print-snp \
               --out "$output_file"; then

	    echo "PRSice_linux ran successfully with $summary_file"

	else
	    
            # If PRSice2 fails, it may generate a .valid file with QC-passed SNPs
            echo "Initial run failed - checking for .valid file"
            
            # Check if .valid file exists (contains list of valid SNPs after QC)
            if [[ -f "$output_file.valid" ]]; then
                echo "Retrying with validated SNPs"
                
                # Retry PRSice2 using only the validated SNPs
                "${software_dir}/PRSice_linux/PRSice_linux" \
                    --base "$summary_file" \
                    --target "$target_sample" \
                    --fastscore T \
                    --no-regress \
                    --bar-levels 0.05,0.01,1e-5,5e-08 \
                    --print-snp \
                    --extract "$output_file.valid" \
                    --out "$output_file"
            else
                # No valid SNPs found - skip this trait
                echo "Error: No .valid file generated despite failure for $trait_name"
                continue
            fi
        fi
    else
        # Output already exists - skip processing
        echo "Output file $output_file already exists and is greater than 0kb. Skipping."
    fi
done

echo "Completed PGI generation for $cohort_name."
