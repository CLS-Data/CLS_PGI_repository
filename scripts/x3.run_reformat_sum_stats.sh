#!/bin/bash
#$ -l h_rt=24:00:00
#$ -l mem=32G

#load R

# to import the module command
source /etc/profile.d/modules.sh

module purge
module load r/r-4.2.3

# Run reformat summary statistics script to correctly format GWAS summary statistics.

# This script processes a list of GWAS summary statistics files for multiple phenotypes.
# For each phenotype, it:
#   - Reformats the summary statistics to PRSice2 format.
#   - Checks if the summary statistics are in hg38 build by comparing chromosome 3 SNPs to a dbSNP reference panel.
#   - If the build is not hg38, performs liftover from hg19 to hg38 and updates the summary statistics.
#
# Outputs (per phenotype):
#   - <output_prefix>_PRSice2_hg38.txt : Final harmonised summary statistics in hg38 build, PRSice2 format. 
# -----------------------------------------------------------------------------

config_file="$1"
source "$config_file"

# Define base directories and file paths
script_dir="${base_dir}/scripts"

# Software directories 
liftover="${software_dir}/LiftOver/liftOver"
chain_file="${software_dir}/LiftOver/chain_files/hg19ToHg38.over.chain.gz"

# File containing list of phenotypes to process (CSV format: phenotype,original_file,base_output_name)
parameter_file="${reference_dir}/phenotype_list.txt"

# Check if the parameter file exists before processing
if [ ! -f "$parameter_file" ]; then
    echo "Error: Parameter file '$parameter_file' not found."
    exit 1
fi

# Read parameter file line by line and process each phenotype
while IFS=',' read -r phenotype original_file base_output_name; do

    echo "Processing phenotype $phenotype in ${summary_dir}/${phenotype}"

    # Define input and output file paths for current phenotype
    input_file="$summary_dir/$phenotype/$original_file"

    # Check if input file exists before processing
    if [ ! -f "$input_file" ]; then
	echo "Error: Input file '$input_file' not found. Skipping."
	continue
    fi

    pheno_output_dir=${output_dir}/summary_statistics/${phenotype}
    mkdir -p ${pheno_output_dir}

    # File path variables
    summary_reformatted=${pheno_output_dir}/${base_output_name}_PRSice2.txt
    summary_hg38=${pheno_output_dir}/${base_output_name}_PRSice2_hg38.txt
    summary_hg38_bed=${pheno_output_dir}/${base_output_name}_PRSice2_hg38.bed
    
    # Reformat summary statistics to PRSice2 format
    echo "Reformatting summary statistics..."
    ${script_dir}/reformat_sumstats.sh ${input_file} ${summary_reformatted}
  
    if [[ -f ${summary_reformatted} ]]; then
	echo "reformatted summary file: ${summary_reformatted}"
    else
	echo "reformatted summary file: ${summary_reformatted} not found"
    fi    


    # Extract chromosome 3 data for genome build checking (header + chr3 SNPs)
    awk 'FNR==1 || $2 == 3' ${summary_reformatted} > ${pheno_output_dir}/${base_output_name}_chr3.txt
    # Sort chromosome 3 data by SNP ID for joining with reference
    sort -k1,1 ${pheno_output_dir}/${base_output_name}_chr3.txt > ${pheno_output_dir}/${base_output_name}_chr3_sorted.txt  

    # Compare chromosome 3 SNPs with dbSNP hg38 reference to check if SNP positions match hg38 positions. If this is not the case, SNP positions have to be lifted over to hg38

    # Ensure the files exist, even if nothing is written later
    : > "${pheno_output_dir}/${base_output_name}_matched_snps_chr3.txt"
    : > "${pheno_output_dir}/${base_output_name}_mismatched_snps_chr3.txt"

    # Join on SNP ID and compare chromosome and position to determine matches/mismatches
    join -1 1 -2 1 ${reference_dir}/dbsnp_chr3_sorted.txt ${pheno_output_dir}/${base_output_name}_chr3_sorted.txt |
	awk -v matched="${pheno_output_dir}/${base_output_name}_matched_snps_chr3.txt" \
	    -v mismatched="${pheno_output_dir}/${base_output_name}_mismatched_snps_chr3.txt" '{
	    if ($2 == $4 && $3 == $5)								     
  	    ##  Matches (same chr and position)							     
  	    print $1 >> matched;	
  	    else
  	    ## Mismatches (different chr or position)
    	    print $1 >> mismatched;
}'	    

  
    # Count matched and mismatched SNPs to determine if liftover is needed
    matched_count=$(wc -l < ${pheno_output_dir}/${base_output_name}_matched_snps_chr3.txt)
    mismatched_count=$(wc -l < ${pheno_output_dir}/${base_output_name}_mismatched_snps_chr3.txt)

    # Decision logic: if more matches than mismatches, assume already hg38; otherwise liftover
    if [[ $matched_count -gt $mismatched_count ]]; then
	echo "More matched SNPs than mismatched SNPs; no need for liftover."
      
	# Simply rename the file to indicate it's in hg38 format
	mv ${summary_reformatted} ${summary_hg38}

	if [[ -f ${summary_hg38} ]]; then
	    echo "renamed summary file: ${summary_hg38}"
	else
	    echo "renamed summary file not found: ${summary_hg38}"
	fi  

    else
	echo "More mismatched SNPs than matched SNPs; liftover is required."
      
	# Perform liftover from hg19 to hg38
	echo "Running liftover..."
	${script_dir}/run_liftover.sh ${summary_reformatted} ${summary_hg38_bed}

	if [[ -f ${summary_hg38_bed} ]]; then
	    echo "liftover bed file: ${summary_hg38_bed}"
	else
	    echo "liftover bed file not found: ${summary_hg38_bed}"
	fi    

	# Update summary statistics with lifted-over coordinates
	echo "Updating summary statistics with liftover results..."
    
	Rscript ${script_dir}/update_sumstats_hg38.r ${summary_dir}/${phenotype} ${summary_reformatted} ${summary_hg38_bed} ${summary_hg38}

	if [[ -f ${summary_hg38} ]]; then
	    echo "liftover summary file: ${summary_hg38}"
	else
	    echo "liftover summary file not found: ${summary_hg38}"
	fi    
    fi

  
    # Clean up intermediate files to save disk space
    rm ${pheno_output_dir}/${base_output_name}_chr3.txt ${pheno_output_dir}/${base_output_name}_chr3_sorted.txt ${pheno_output_dir}/${base_output_name}_matched_snps_chr3.txt ${pheno_output_dir}/${base_output_name}_mismatched_snps_chr3.txt ${pheno_output_dir}/${base_output_name}_PRSice2_unmapped.txt ${pheno_output_dir}/${base_output_name}_PRSice2.bed ${summary_hg38_bed}

    echo "Finished processing phenotype: $phenotype"
    echo "-----------------------------------------"

done < "$parameter_file"  # Read from the parameter file

echo "All phenotypes processed."
