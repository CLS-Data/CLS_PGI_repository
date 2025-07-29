#!/bin/bash

if [ "$#" -ne 2 ]; then
    echo "Usage: $0 [Input File] [Output File]"
    exit 1
fi

INPUT_FILE="$1"
OUTPUT_FILE="$2"

LIFTOVER="${software_dir}/LiftOver/liftOver"
CHAIN_FILE="${software_dir}/LiftOver/chain_files/hg19ToHg38.over.chain.gz"

if [[ ! -f "${INPUT_FILE}" ]]; then
    echo "The input summary statistics file does not exist: ${INPUT_FILE}"
    exit 1
fi

BED_FILE="${INPUT_FILE%.txt}.bed"
UNMAPPED_FILE="${INPUT_FILE%.txt}_unmapped.txt"

echo "Creating BED file from ${INPUT_FILE}"
awk 'BEGIN {OFS="\t"} NR > 1 && $2 ~ /^[0-9]+$/ && $3 ~ /^[0-9]+$/ {print "chr"$2, $3, $3, $1}' "${INPUT_FILE}" > "${BED_FILE}"

if [[ ! -s "${BED_FILE}" ]]; then
    echo "Failed to create BED file or it's empty: ${BED_FILE}"
    exit 1
fi

echo "Running LiftOver on ${BED_FILE}"
"${LIFTOVER}" "${BED_FILE}" "${CHAIN_FILE}" "${OUTPUT_FILE}" "${UNMAPPED_FILE}"

if [[ -f "${OUTPUT_FILE}" ]]; then
    echo "LiftOver operation is completed for ${OUTPUT_FILE}"
else
    echo "LiftOver operation failed for ${BED_FILE}"
fi

if [[ -f "${UNMAPPED_FILE}" && -s "${UNMAPPED_FILE}" ]]; then
    echo "Unmapped records are saved in ${UNMAPPED_FILE}"
else
    echo "No unmapped records were generated"
fi

exit 0
