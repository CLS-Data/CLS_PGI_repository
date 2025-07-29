# Usage:
# Rscript update_genomic_build.R <working_directory> <sumstats_filename> <bed_filename> <output_filename>

args <- commandArgs(trailingOnly = TRUE)
working_dir <- args[1]
sumstats_filename <- args[2]
bed_filename <- args[3]
output_filename <- args[4]

library(data.table)
setwd(working_dir)

sumstats <- fread(sumstats_filename,h=T)
bedfile <- fread(bed_filename)
sumstats_hg38 <- sumstats[match(bedfile$V4, sumstats$SNP),]

if (!all.equal(sumstats_hg38$SNP, bedfile$V4)) {
  stop("ERROR: Mismatch detected between SNP identifiers in the summary statistics and the BED file.")
}

sumstats_hg38$BP <- bedfile$V2
write.table(sumstats_hg38,output_filename, quote = FALSE, col.names = TRUE, row.names = FALSE)
