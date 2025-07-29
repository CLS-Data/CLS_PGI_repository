#!/bin/bash
#$ -l h_rt=2:00:00
#$ -l mem=32G

# Generate harmonised cross-cohort SNP lists.

# This script generates harmonised cross-cohort SNP lists and genotype datasets for multiple cohorts.
# 	SNP lists will be generated for each cohort using PLINK and saved in ${cross_cohort}/snplists/
# 	SNP list will be cleaned to keep only rsIDs
# 	The script will find SNPs shared across all cohorts and save the result as shared_snplist.txt
# 	Line counts for each SNP list and the shared list will be printed for tracking
# 	Harmonised genotype datasets (PLINK .bed/.bim/.fam) will be created for each cohort using the shared SNPs

config_file="$1"
source "$config_file"

# Define paths to genotype data for each cohort (update as needed)
geno_mcs=${gen_dir}/CLS/MCS/TOPMed/MCS_topmed_EUR_KING_QCd_rsID_PCs_SD4
geno_bcs=${gen_dir}/CLS/BCS70/TOPMed/BCS70_TOPMed_EUR_rsid_BNN
geno_ncds=${gen_dir}/CLS/NCDS/TOPMed/NCDS_TOPMed_EUR_CLSIDs
geno_nshd=${gen_dir}/LHA/NSHD/TOPMed/NSHD_TOPMEd_EUR_NSHD_IDs
geno_ns=${gen_dir}/CLS/Next_Steps/TOPMed/NextSteps_TOPMed_EUR

# Define output directory for cross-cohort results
cross_cohort=${output_dir}/cross_cohort

# Create output directories if they do not exist
mkdir -p ${cross_cohort}/snplists
mkdir -p ${cross_cohort}/nshd
mkdir -p ${cross_cohort}/ncds
mkdir -p ${cross_cohort}/bcs
mkdir -p ${cross_cohort}/ns
mkdir -p ${cross_cohort}/mcs

# Generate SNP lists for each cohort using PLINK
${software_dir}/plink/plink --bfile ${geno_nshd} --write-snplist --out ${cross_cohort}/snplists/nshd
${software_dir}/plink/plink --bfile ${geno_ncds} --write-snplist --out ${cross_cohort}/snplists/ncds
${software_dir}/plink/plink --bfile ${geno_bcs} --write-snplist --out ${cross_cohort}/snplists/bcs
${software_dir}/plink/plink --bfile ${geno_mcs} --write-snplist --out ${cross_cohort}/snplists/mcs
${software_dir}/plink/plink --bfile ${geno_ns} --write-snplist --out ${cross_cohort}/snplists/ns

# Clean and sort SNP lists for each cohort (keep only rsIDs)
for cohort in nshd ncds bcs ns mcs; do
	LC_ALL=C grep '^rs' ${cross_cohort}/snplists/${cohort}.snplist | sort > ${cross_cohort}/snplists/${cohort}.cleaned.snplist
done

# Find SNPs shared across all cohorts using comm (pairwise intersection)
comm -12 ${cross_cohort}/snplists/nshd.cleaned.snplist ${cross_cohort}/snplists/ncds.cleaned.snplist > ${cross_cohort}/snplists/part1.txt
comm -12 ${cross_cohort}/snplists/part1.txt ${cross_cohort}/snplists/bcs.cleaned.snplist > ${cross_cohort}/snplists/part2.txt
comm -12 ${cross_cohort}/snplists/part2.txt ${cross_cohort}/snplists/ns.cleaned.snplist > ${cross_cohort}/snplists/part3.txt
comm -12 ${cross_cohort}/snplists/part3.txt ${cross_cohort}/snplists/mcs.cleaned.snplist > ${cross_cohort}/snplists/shared_snplist.txt

# Print the number of SNPs at each stage
wc -l ${cross_cohort}/snplists/nshd.cleaned.snplist
wc -l ${cross_cohort}/snplists/ncds.cleaned.snplist
wc -l ${cross_cohort}/snplists/bcs.cleaned.snplist
wc -l ${cross_cohort}/snplists/ns.cleaned.snplist
wc -l ${cross_cohort}/snplists/mcs.cleaned.snplist
wc -l ${cross_cohort}/snplists/shared_snplist.txt

# Extract the shared SNPs from each cohort's genotype data to create harmonised datasets
${software_dir}/plink/plink --bfile ${geno_nshd} --extract ${cross_cohort}/snplists/shared_snplist.txt --make-bed --out ${cross_cohort}/nshd/nshd_cross_cohort
${software_dir}/plink/plink --bfile ${geno_ncds} --extract ${cross_cohort}/snplists/shared_snplist.txt --make-bed --out ${cross_cohort}/ncds/ncds_cross_cohort
${software_dir}/plink/plink --bfile ${geno_bcs} --extract ${cross_cohort}/snplists/shared_snplist.txt --make-bed --out ${cross_cohort}/bcs/bcs_cross_cohort
${software_dir}/plink/plink --bfile ${geno_ns} --extract ${cross_cohort}/snplists/shared_snplist.txt --make-bed --out ${cross_cohort}/ns/ns_cross_cohort
${software_dir}/plink/plink --bfile ${geno_mcs} --extract ${cross_cohort}/snplists/shared_snplist.txt --make-bed --out ${cross_cohort}/mcs/mcs_cross_cohort
