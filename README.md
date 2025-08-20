# CLS PGI Pipeline (v1.0)

## Contributors
**Tim Morris**	- Designed the pipline and led development and implementation.  
**Gemma Shireby** - Designed the pipline and led curation of genotype data.  
**Georg Otto** - Contributed to pipeline design including feature suggestions.  
**David Bann** - Provided code annotations and documentation support.  
**Liam Wright** - Checked PGIs and designed PGI visualations.

## Contact
For queries and to report errors, please contact [Tim Morris](mailto:t.t.morris@ucl.ac.uk).

## Cohort background
This pipeline was designed to run on the British cohort studies managed by the Centre for Longitudinal Studies. Further information about the cohorts can be found on the [CLS](https://cls.ucl.ac.uk/) website and in the [CLS genomics cohort profile paper](https://www.medrxiv.org/content/10.1101/2024.11.06.24316761v1). 

The [CLS genomics GitHub website](https://cls-genetics.github.io/) contains detailed information about the genotyping, imputation and quality control of the underlying genetic resources used in this pipeline. 

## Overview
This pipeline generates Polygenic Indices (PGIs) across multiple cohorts using GWAS summary statistics and cohort genotype data. The pipeline was designed to run on the CLS cohorts but can be applied simply to other cohort studies. The pipeline uses the following steps:
1. Prepares a lookup file for fast build checking. 
2. Harmonises SNPs across all input cohorts to ensure consistent variant sets for PGI.
3. Reformat GWAS summary statistics, checking the genome build and performing liftover to hg38 where neccessary. 
4. Computes PGIs using a clumping and thresholding approach as applied in PRSice2.
5. Cleans up large intermediary files to save disk space. 

## Prerequisites
### Required Software
The pipeline requires the following software packages to be installed: 
- [PLINK v1.9](https://www.cog-genomics.org/plink/).
- [PRSice2](https://choishingwan.github.io/PRSice/).
- [LiftOver](https://genome-store.ucsc.edu/).
- [R (with required packages)](https://cran.r-project.org/).
- Standard Unix tools (awk, sort, comm, etc.).

### Required Data
- Genotype data for each cohort in PLINK binary format (.bed/.bim/.fam).
- GWAS summary statistics for each trait.
- dbSNP reference file relevant to the genome build of your cohort genotype data (here, _hg38_).
- LiftOver chain file relevant to the genome build of your cohort genotype data (here, _hg19 to hg38_).

## Setup
###
### 1. Pipeline configuration

   Pull the scripts from GitHub: 
```bash
   git clone https://github.com/CLS-Data/CLS_PGI_repository.git
   ```
   Navigate to the script directory:
   ```bash
   cd pgi_pipeline
   ```

### 2. Set up the config file

   Edit the config template to map the correct paths for the pipeline:
```bash
   cp scripts/config_template.sh scripts/config.sh
   nano scripts/config.sh
   ```

### 3. Select GWAS summary statistics

   GWAS summary statistics files for each trait need to be placed in trait-specific directories with the below structure. The naming of the trait-specific directories is upto the analyst; we recommend brevity.

```
   |--- reference/
      |--- summary_statistics/
           |--- [trait]/
                |---gwas_summary_statistics.txt.gz
```

### 4. Create list of phenotypes
   Phenotypes need to be specified in the below _phenotype_list.txt_ file in the reference folder. 

```
   |--- reference/
      |--- phenotype_list.txt
```

   The the _phenotype_list.txt_ file must contain one row for each trait with comma separated specifications for each of `folder name, sumstats file, trait name`. For example:
   ```
   alcohol,DrinksPerWeek.txt.gz,drinksperweek
   bmi,BMI_summary_stats.txt.gz,bmi
   ```

### 5. Obtain dbsnp lookup
   The dbsnp lookup relevant to the build of your cohort genome data needs to be downloaded to the following location:
   ```
   |--- reference/
   ```

## Running the pipeline
### Step 1: Run the genome build check preparation script
```bash
qsub scripts/x1.genome_build_check_prep.sh scripts/config.sh
```
This script prepares reference files for genome build checking. 

### Step 2: Harmonise SNPs across cohorts  
```bash
qsub scripts/x2.harmonise_snps.sh
```
This script creates harmonised SNP lists across all cohorts for consistent PGI calculation. 

### Step 3: Reformat summary statistics
```bash
qsub scripts/x3.run_reformat_sum_stats.sh
```
This script reformats GWAS summary statistics and handles genome build conversion where needed.

### Step 4: Generate PGIs
The submission script needs to be run once for each cohort.

```bash
qsub scripts/x4.submit_pgi_pipeline.sh scripts/config.sh [cohort] results/cross_cohort/[cohort]/[cohort]_cross_cohort
```
This script generates the PGIs for each cohort from the cleaned genotype data and GWAS summary statistics.

### Step 6: Clean up large .valid files (optional)
PRSice creates a .valid file for each trait containing the SNPs used to estimate the PGI, which can be very large. Analysts may wish to use this (optional) script to remove valid files over a pre-specified size. 
```bash
qsub scripts/x5.rm_valid.sh
```

## Outputs
The pipeline will output all derived files to the following folders:
```
   |--- results/
      |--- cross-cohort/
            |--- [cohort]
            |--- snplists
      |--- pgi/
            |--- [cohort]
               |--- [trait]
      |--- summary_statistics
            |--- [trait]
```

Generated PGIs can be found for each cohort in `results/pgi/[cohort]/[trait]/`, with the cleaned genotype files and shared snplist in `results/cross-cohort/`, and the cleaned summary statistics in `results/summary_statistics/[trait]`.

## Troubleshooting
### Common Issues
- **Missing files**: Check that all paths in `scripts/config.sh` are correct.
- **Software**: Ensure all required software is installed and paths are correct.
- **Permissions**: Check file permissions, execution and cluster job submission rights.
- **Memory**: The pipeline was designed to run on cohorts with sample sizes of N<10,000 genotyped individuals. For cohorts with larger sample sizes you may need to assign more memory in the scripts. 

### Logs
Check logs for detailed error messages.

## Pipeline Flow
For the initial run, the pipeline must be run iterively in the following order:
```
scripts/x1.genome_build_check_prep.sh
scripts/x2.harmonise_snps.sh
scripts/x3.run_reformat_sum_stats.sh
scripts/x4.submit_pgi_pipeline.sh
scripts/x5.rm_valid.sh
```
After the pipeline has been run once, scripts 3-5 can be run again for additional traits. 

## Citation
If you use this pipeline, we ask that you cite the UK Data Service documentation that describes the PGIs generated from the pipeline.
